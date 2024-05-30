// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20Token} from "./Mocks/ERC20.sol";
import "./interfaces/IUniswapV2Router.sol";
import {Errors} from "./utils/Errors.sol";
import {Events} from "./utils/Events.sol";
import {Presale} from "./utils/Types.sol";


contract PresalePlatform {
    using SafeERC20 for ERC20Token;


    IUniswapV2Router02 immutable public uniswapRouter;
    uint256 immutable public feePercent;
    address immutable public feeRecipient;
    uint256 immutable deadline; // period after which the presale is over for team to decide to terminate the presale or continue it

    mapping(address => Presale) public presales; // team => presale
    mapping(address => mapping(address => uint256)) public userContributions; // team => (user => contributed ETH amount)
    mapping(address => mapping(address => uint256)) public userClaimedTokens; // team => (user => claimed tokens amount)

    constructor(
        address _uniswapRouter,
        address _feeRecipient,
        uint256 _feePercent,
        uint256 _deadline
    ) {
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        feeRecipient = _feeRecipient;
        feePercent = _feePercent;
        deadline = _deadline;
    }

    /// @notice Creates a new presale for the team
    /// @param _token Address of the token being sold
    /// @param _price Price per token in ETH
    /// @param _amount Total number of tokens for sale
    /// @param _duration Duration of the presale in seconds
    /// @param _vestingPeriod Vesting period in seconds
    function create(
        address _token,
        uint256 _price,
        uint256 _amount,
        uint256 _duration,
        uint256 _vestingPeriod
    ) external {
        Presale storage presale = presales[msg.sender];

        if (presale.token != address(0)) {
            revert Errors.PresaleExists();
        }
        if (_token == address(0)) {
            revert Errors.InvalidToken(_token);
        }
        if (_amount == 0) {
            revert Errors.ZeroAmount(_amount);
        }
        if (_price == 0) {
            revert Errors.ZeroPrice(_price);
        }
        if (_duration == 0) {
            revert Errors.ZeroDuration(_duration);
        }
        if (_vestingPeriod == 0) {
            revert Errors.ZeroVestingPeriod(_vestingPeriod);
        }

        ERC20Token(_token).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );
        presales[msg.sender] = Presale({
            token: _token,
            price: _price,
            amount: _amount,
            startTime: block.timestamp,
            duration: _duration,
            raisedAmount: 0,
            vestingStartTime: 0,
            vestingPeriod: _vestingPeriod,
            isCompleted: false,
            isTerminated: false
        });
        emit Events.PresaleCreated(
            msg.sender,
            _token,
            _price,
            _amount,
            _duration,
            _vestingPeriod
        );
    }

    /// @notice Allows users to participate in a presale
    /// @param _team Address of the team conducting the presale
    function participate(address _team) external payable {
        Presale storage presale = presales[_team];
        if (
            block.timestamp > presale.startTime + presale.duration ||
            presale.isTerminated == true
        ) {
            revert Errors.PresaleEnded(block.timestamp);
        }
        uint256 tokensToBuy = msg.value / presale.price;
        if (tokensToBuy > presale.amount) {
            revert Errors.InsufficientTokens(tokensToBuy, presale.amount);
        }
        presale.raisedAmount += msg.value;
        presale.amount -= tokensToBuy;
        userContributions[_team][msg.sender] += msg.value;
        emit Events.Participated(_team, msg.sender, tokensToBuy);
    }

    /// @notice Terminates the presale and refunds participants
    function terminate() external {
        address _team = msg.sender;
        Presale storage presale = presales[_team];
        if (presale.isCompleted == true) {
            revert Errors.PresaleCompleted();
        }
        presale.isTerminated = true;
        emit Events.PresaleTerminated(_team);
    }

    /// @notice Provides liquidity on Uniswap after the presale
    /// @param _tokenAmount Amount of tokens to provide as liquidity
    function provideLiquidity(uint256 _tokenAmount) external {
        address _team = msg.sender;
        Presale storage presale = presales[_team];
        if (_tokenAmount == 0) {
            revert Errors.ZeroAmount(_tokenAmount);
        }
        ERC20Token(presale.token).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenAmount
        );
        if (
            block.timestamp > presale.startTime + presale.duration + deadline ||
            presale.isTerminated == true
        ) {
            revert Errors.PresaleTerminatedOrAbandoned();
        }
        uint256 ethAmount = (presale.raisedAmount * (100 - feePercent)) / 100;
        uint256 feeAmount = presale.raisedAmount - ethAmount;
        uint256 price = ethAmount / _tokenAmount;

        if (price < presale.price) {
            revert Errors.PriceLessThanPresalePrice(price, presale.price);
        }

        presale.vestingStartTime = block.timestamp;
        presale.isCompleted = true;

        ERC20Token(presale.token).approve(address(uniswapRouter), _tokenAmount);
        uniswapRouter.addLiquidityETH{
            value: ethAmount
        }(presale.token, _tokenAmount, 0, 0, address(this), block.timestamp);

        payable(feeRecipient).transfer(feeAmount);
        emit Events.LiquidityProvided(_team, _tokenAmount, ethAmount);
    }

    /// @notice Allows users to claim their tokens based on the vesting schedule
    /// @param _team Address of the team conducting the presale
    function claimToken(address _team) external {
        Presale storage presale = presales[_team];
        if (presale.isCompleted != true) {
            revert Errors.PresaleNotCompleted();
        }
        uint256 userShare = userContributions[_team][msg.sender];
        uint256 totalTokens = userShare / presale.price;
        uint256 vestedTokens = (totalTokens *
            (block.timestamp - presale.vestingStartTime)) /
            presale.vestingPeriod;
        uint256 claimableTokens = vestedTokens -
            userClaimedTokens[_team][msg.sender];

        if (claimableTokens > 0) {
            userClaimedTokens[_team][msg.sender] += claimableTokens;
            ERC20Token(presale.token).transfer(msg.sender, claimableTokens);
            emit Events.TokensClaimed(msg.sender, claimableTokens);
        }
    }

    /// @notice Allows users to claim their ETH if the presale is terminated or abandoned
    /// @param _team Address of the team conducting the presale
    function claimETH(address _team) external {
        Presale storage presale = presales[_team];
        if (
            block.timestamp < presale.startTime + presale.duration + deadline &&
            presale.isTerminated == false
        ) {
            revert Errors.PresaleNotTerminatedOrAbandoned();
        }
        uint256 userShare = userContributions[_team][msg.sender];
        userContributions[_team][msg.sender] = 0;
        if (userShare > 0) {
            (bool success,) = msg.sender.call{value:userShare}("");
            require(success);
            emit Events.ETHReturned(msg.sender, userShare);
        }
    }
}
