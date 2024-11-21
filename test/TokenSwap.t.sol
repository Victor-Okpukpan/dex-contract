// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TokenSwap} from "../src/TokenSwap.sol";
import {MockUSDT, MockUSDC} from "../src/MockTokens.sol";

contract TokenSwapTest is Test {
    TokenSwap public tokenSwap;
    MockUSDT public usdt;
    MockUSDC public usdc;
    
    address public owner;
    address public user1;
    address public user2;

    uint24 public constant POOL_FEE = 300; // 0.3%
    uint256 public constant INITIAL_LIQUIDITY = 100000 * 10 ** 18;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy contracts
        tokenSwap = new TokenSwap();
        usdt = new MockUSDT();
        usdc = new MockUSDC();

        // Create pool
        tokenSwap.createPool(address(usdt), address(usdc), POOL_FEE);

        // Transfer tokens to users
        usdt.transfer(user1, INITIAL_LIQUIDITY);
        usdc.transfer(user1, INITIAL_LIQUIDITY);
        usdt.transfer(user2, INITIAL_LIQUIDITY);
        usdc.transfer(user2, INITIAL_LIQUIDITY);
    }

    function testPoolCreation() public {
        assertTrue(tokenSwap.poolExists(address(usdt), address(usdc)), "Pool should exist");
        assertTrue(tokenSwap.poolExists(address(usdc), address(usdt)), "Reverse pool should exist");
        
        (uint256 token0Balance, uint256 token1Balance, uint256 totalShares, uint24 fee) = 
            tokenSwap.pools(address(usdt), address(usdc));
        
        assertEq(token0Balance, 0, "Initial token0 balance should be 0");
        assertEq(token1Balance, 0, "Initial token1 balance should be 0");
        assertEq(totalShares, 0, "Initial total shares should be 0");
        assertEq(fee, POOL_FEE, "Fee should match input");
    }

    function testAddInitialLiquidity() public {
        uint256 amount0 = 10000 * 10 ** 18;
        uint256 amount1 = 10000 * 10 ** 18;

        vm.startPrank(user1);
        usdt.approve(address(tokenSwap), amount0);
        usdc.approve(address(tokenSwap), amount1);

        tokenSwap.addLiquidity(
            address(usdt),
            address(usdc),
            amount0,
            amount1,
            amount0,
            amount1
        );
        vm.stopPrank();

        (uint256 token0Balance, uint256 token1Balance, uint256 totalShares, uint24 fee) = 
            tokenSwap.pools(address(usdt), address(usdc));

        assertEq(token0Balance, amount0, "Incorrect token0 balance");
        assertEq(token1Balance, amount1, "Incorrect token1 balance");
        assertTrue(totalShares > 0, "Total shares should be greater than 0");
    }

    function testSwap() public {
        // First add liquidity
        uint256 liquidityAmount = 10000 * 10 ** 18;
        vm.startPrank(user1);
        usdt.approve(address(tokenSwap), liquidityAmount);
        usdc.approve(address(tokenSwap), liquidityAmount);
        
        tokenSwap.addLiquidity(
            address(usdt),
            address(usdc),
            liquidityAmount,
            liquidityAmount,
            liquidityAmount,
            liquidityAmount
        );
        vm.stopPrank();

        // Perform swap
        uint256 swapAmount = 100 * 10 ** 18;
        uint256 expectedMinOutput = 99 * 10 ** 18; // Accounting for 0.3% fee
        
        vm.startPrank(user2);
        usdt.approve(address(tokenSwap), swapAmount);
        
        uint256 user2InitialUSDCBalance = usdc.balanceOf(user2);
        
        tokenSwap.swap(
            address(usdt),
            address(usdc),
            swapAmount,
            expectedMinOutput,
            block.timestamp + 1 hours
        );
        
        uint256 user2FinalUSDCBalance = usdc.balanceOf(user2);
        vm.stopPrank();

        assertTrue(
            user2FinalUSDCBalance > user2InitialUSDCBalance,
            "Swap should increase USDC balance"
        );
    }

    function testFailPoolCreationWithSameTokens() public {
        tokenSwap.createPool(address(usdt), address(usdt), POOL_FEE);
    }

    function testFailSwapWithExpiredDeadline() public {
        vm.startPrank(user2);
        usdt.approve(address(tokenSwap), 100 * 10 ** 18);
        
        tokenSwap.swap(
            address(usdt),
            address(usdc),
            100 * 10 ** 18,
            95 * 10 ** 18,
            block.timestamp - 1 // Expired deadline
        );
        vm.stopPrank();
    }

    function testGetAmountOut() public {
        uint256 amountIn = 100 * 10 ** 18;
        uint256 reserveIn = 1000 * 10 ** 18;
        uint256 reserveOut = 1000 * 10 ** 18;
        
        uint256 amountOut = tokenSwap.getAmountOut(
            amountIn,
            reserveIn,
            reserveOut,
            POOL_FEE
        );
        
        assertTrue(amountOut > 0, "Amount out should be greater than 0");
        assertTrue(amountOut < amountIn, "Amount out should be less than amount in due to fee");
    }
} 