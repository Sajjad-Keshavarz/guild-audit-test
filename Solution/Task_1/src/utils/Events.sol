// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

library Events {
    event PresaleCreated(address indexed team, address token, uint256 price, uint256 amount, uint256 duration, uint256 vestingPeriod);
    event PresaleCompleted(address indexed team, uint256 raisedAmount);
    event PresaleTerminated(address indexed team);
    event LiquidityProvided(address indexed team, uint256 tokenAmount, uint256 ethAmount);
    event ETHReturned(address indexed user, uint256 amount);
    event TokensClaimed(address indexed user, uint256 amount);
    event Participated(address indexed team,address indexed user, uint256 amount);
}