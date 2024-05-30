// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {PresalePlatform} from "../src/PresalePlatform.sol";
import {UniswapV2Router} from "../src/Mocks/UniswapV2Router.sol";
import {ERC20Token} from "../src/Mocks/ERC20.sol";

contract PresalePlatformTest is Test {
    PresalePlatform public presalePlatform;
    UniswapV2Router public uniRouter;
    ERC20Token public token;

    uint256 feePercent = 1;
    address feeRecipient = address(0x123);
    uint256 deadline = 7 days;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public team = address(0x3);

    function setUp() public {
        token = new ERC20Token();
        uniRouter = new UniswapV2Router();
        presalePlatform = new PresalePlatform(
            address(uniRouter),
            feeRecipient,
            feePercent,
            deadline
        );

        // Mint tokens for the team and users
        token.mint(team, 1000000 ether);
        token.mint(alice, 100 ether);
        token.mint(bob, 100 ether);

        // Label addresses for better readability in debug logs
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(team, "Team");

    }

    function testCreatePresale() public {
        vm.startPrank(team);

        token.approve(address(presalePlatform), 1000 ether);
        presalePlatform.create(address(token), 0.1 ether, 1000 ether, 5 days, 10 days);

        (address tokenAddr,, uint256 amount,,,,,,,) = presalePlatform.presales(team);
        assertEq(tokenAddr, address(token));
        assertEq(amount, 1000 ether);

        vm.stopPrank();
    }

    function testParticipateInPresale() public {
        vm.startPrank(team);
        token.approve(address(presalePlatform), 1000 ether);
        presalePlatform.create(address(token), 0.1 ether, 1000 ether, 5 days, 10 days);
        vm.stopPrank();

        vm.deal(alice, 10 ether);
        vm.prank(alice);
        presalePlatform.participate{value: 1 ether}(team);

        (,,,,, uint256 raisedAmount,,,,) = presalePlatform.presales(team);
        assertEq(raisedAmount, 1 ether);
    }

    function testTerminatePresale() public {
        vm.startPrank(team);
        token.approve(address(presalePlatform), 1000 ether);
        presalePlatform.create(address(token), 0.1 ether, 1000 ether, 5 days, 10 days);
        presalePlatform.terminate();

        (,,,,,,,,, bool isTerminated) = presalePlatform.presales(team);
        assertTrue(isTerminated);

        vm.stopPrank();
    }

    function testProvideLiquidity() public {
        vm.startPrank(team);
        token.approve(address(presalePlatform), 1000 ether);
        presalePlatform.create(address(token), 0.1 ether, 1000 ether, 5 days, 10 days);
        vm.stopPrank();

        vm.deal(alice, 10 ether);
        vm.prank(alice);
        presalePlatform.participate{value: 1 ether}(team);

        // Move time forward to simulate end of presale
        vm.warp(block.timestamp + 5 days + 1 seconds);

        vm.startPrank(team);
        token.approve(address(presalePlatform), 5);
        presalePlatform.provideLiquidity(5);

        (,,,,,,,, bool isCompleted,) = presalePlatform.presales(team);
        assertTrue(isCompleted);

        vm.stopPrank();
    }

    function testFailProvideLiquidityWithFewTokens() public {
        vm.startPrank(team);
        token.approve(address(presalePlatform), 1000 ether);
        presalePlatform.create(address(token), 0.1 ether, 1000 ether, 5 days, 10 days);
        vm.stopPrank();

        vm.deal(alice, 10 ether);
        vm.prank(alice);
        presalePlatform.participate{value: 1 ether}(team);

        // Move time forward to simulate end of presale
        vm.warp(block.timestamp + 5 days + 1 seconds);

        vm.startPrank(team);
        token.approve(address(presalePlatform), 100 ether);
        presalePlatform.provideLiquidity(100 ether);

        (,,,,,,,, bool isCompleted,) = presalePlatform.presales(team);
        assertTrue(isCompleted);

        vm.stopPrank();
    }

    function testClaimTokens() public {
        vm.startPrank(team);
        token.approve(address(presalePlatform), 1000 ether);
        presalePlatform.create(address(token), 0.1 ether, 1000 ether, 5 days, 10 days);
        vm.stopPrank();

        vm.deal(alice, 10 ether);
        vm.prank(alice);
        presalePlatform.participate{value: 1 ether}(team);

        // Move time forward to simulate end of presale
        vm.warp(block.timestamp + 5 days + 1 seconds);

        vm.startPrank(team);
        token.approve(address(presalePlatform), 5);
        presalePlatform.provideLiquidity(5);
        vm.stopPrank();

        // Move time forward to start vesting
        vm.warp(block.timestamp + 1 days);

        uint256 initialBalance = token.balanceOf(alice);

        vm.prank(alice);
        presalePlatform.claimToken(team);

        uint256 finalBalance = token.balanceOf(alice);
        assertTrue(finalBalance > initialBalance);
    }

    function testClaimETH() public {
        vm.startPrank(team);
        token.approve(address(presalePlatform), 1000 ether);
        presalePlatform.create(address(token), 0.1 ether, 1000 ether, 5 days, 10 days);
        vm.stopPrank();

        vm.deal(alice, 10 ether);
        vm.prank(alice);
        presalePlatform.participate{value: 1 ether}(team);

        // Move time forward to simulate end of presale
        vm.warp(block.timestamp + 5 days + 1 seconds);

        vm.prank(team);
        presalePlatform.terminate();

        uint256 initialBalance = alice.balance;

        vm.prank(alice);
        presalePlatform.claimETH(team);

        uint256 finalBalance = alice.balance;
        assertTrue(finalBalance > initialBalance);
    }

}
