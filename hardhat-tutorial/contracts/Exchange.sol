// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Exchange is ERC20 {
    address public cryptoDevTokenAddress;

    constructor (address _CryptoDevtoken) ERC20("CryptoDev LP Token", "CDLP") {
        require(_CryptoDevtoken != address(0), "Token address passed is a null address");
        cryptoDevTokenAddress = _CryptoDevtoken;
    }

    function getReserve() public view returns (uint) {
        return ERC20(cryptoDevTokenAddress).balanceOf(address(this));
    }

    // add liquidity to the exchange

    function addLiquidity(uint _amount) public payable returns (uint) {
        uint liquidity;
        uint ethBalance = address(this).balance;
        uint cryptoDevTokenReserve = getReserve();
        ERC20 cryptoDevToken = ERC20(cryptoDevTokenAddress);

            /*
        If the reserve is empty, intake any user supplied value for
        `Ether` and `Crypto Dev` tokens because there is no ratio currently
    */
        if (cryptoDevTokenReserve == 0) {
            // Transfer the `cryptoDevToken` from the user's account to the contract
            cryptoDevToken.transferFrom(msg.sender, address(this), _amount);
             // Take the current ethBalance and mint `ethBalance` amount of LP tokens to the user.
            // `liquidity` provided is equal to `ethBalance` because this is the first time user
            // is adding `Eth` to the contract, so whatever `Eth` contract has is equal to the one supplied
            // by the user in the current `addLiquidity` call
            // `liquidity` tokens that need to be minted to the user on `addLiquidity` call should always be proportional
            // to the Eth specified by the user

            liquidity = ethBalance;
            _mint(msg.sender, liquidity);
        } else {
            uint ethReserve = ethBalance - msg.value;
            uint cryptoDevTokenAmount = (msg.value * cryptoDevTokenReserve) / (ethReserve);
            require(_amount >= cryptoDevTokenAmount, "Amount of tokens sent is less than the minimium token required");

            cryptoDevToken.transferFrom(msg.sender, address(this), cryptoDevTokenAmount);

            liquidity = (totalSupply() * msg.value)/ ethReserve;
            _mint(msg.sender, liquidity);
        }
        return liquidity;
    }

    function removeLiquidity(uint _amount) public returns (uint, uint) {
        require(_amount > 0, "amount should be greater than zero");
        uint ethReserve = address(this).balance;
        uint _totalSupply = totalSupply();

        uint ethAmount = (ethReserve * _amount) / _totalSupply;

        uint cryptoDevTokenAmount = (getReserve() * _amount) / _totalSupply;
        _burn(msg.sender, _amount);

        payable(msg.sender).transfer(ethAmount);

        ERC20(cryptoDevTokenAddress).transfer(msg.sender, cryptoDevTokenAmount);
        return (ethAmount, cryptoDevTokenAmount);
    }

    function getAmountOfTokens (
            uint256 inputAmount,
            uint256 inputReserve,
            uint256 outputReserve
    ) public pure returns (uint256) {
        require(inputReserve > 0 && outputReserve > 0, "invalid reserves");
         uint256 inputAmountWithFee = inputAmount * 99;

            // Because we need to follow the concept of `XY = K` curve
            // We need to make sure (x + Δx) * (y - Δy) = x * y
            // So the final formula is Δy = (y * Δx) / (x + Δx)
            // Δy in our case is `tokens to be received`
            // Δx = ((input amount)*99)/100, x = inputReserve, y = outputReserve
            // So by putting the values in the formulae you can get the numerator and denominator

            uint256 numerator = inputAmountWithFee * outputReserve;
            uint256 denominator = (inputReserve * 100) + inputAmountWithFee;
            return numerator / denominator;
    }

    function ethToCryptoDevToken (uint _minTokens) public payable {
        uint256 tokenReserve = getReserve();

        uint256 tokensBought = getAmountOfTokens(
            msg.value,
            address(this).balance - msg.value,
            tokenReserve
        );

        require(tokensBought >= _minTokens, "insufficient output amount");

        ERC20(cryptoDevTokenAddress).transfer(msg.sender, tokensBought);
    }

    function cryptoDevTokenToEth(uint _tokensSold, uint _minEth) public {
        uint256 tokenReserve = getReserve();
        // call the `getAmountOfTokens` to get the amount of Eth
        // that would be returned to the user after the swap
        uint256 ethBought = getAmountOfTokens(
            _tokensSold,
            tokenReserve,
            address(this).balance
        );

        require(ethBought >= _minEth, "insufficient output amount");

        ERC20(cryptoDevTokenAddress).transferFrom(
            msg.sender,
            address(this),
            _tokensSold
        );

        payable(msg.sender).transfer(ethBought);
    }
}