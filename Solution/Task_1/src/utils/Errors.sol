// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

library Errors {
    error PresaleExists();
    error PresaleEnded(uint256 timestamp);
    error PresaleCompleted();
    error PresaleNotCompleted();
    error PresaleTerminatedOrAbandoned();
    error PresaleNotTerminatedOrAbandoned();
    error InsufficientTokens(uint256 amountToBuy, uint256 availableAmount);
    error InvalidToken(address token);
    error ZeroAmount(uint256 amount);
    error ZeroPrice(uint256 price);
    error ZeroDuration(uint256 duration);
    error ZeroVestingPeriod(uint256 vestingPeriod);
    error PriceLessThanPresalePrice(uint256 price, uint256 presalePrice);
}
