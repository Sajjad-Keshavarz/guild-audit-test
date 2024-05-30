// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

struct Presale {
    address token; // The token being sold in the presale
    uint256 price; // The price per token in ETH
    uint256 amount; // The total amount of tokens for sale
    uint256 startTime; // The start time of the presale
    uint256 duration; // The duration of the presale in seconds
    uint256 raisedAmount; // The amount of ETH raised during the presale
    uint256 vestingStartTime; // The start time of the vesting period
    uint256 vestingPeriod; // The vesting period in seconds
    bool isCompleted; // Flag indicating if the presale is completed
    bool isTerminated; // Flag indicating if the presale is terminated
}
