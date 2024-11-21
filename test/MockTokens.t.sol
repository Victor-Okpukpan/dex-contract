// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MockUSDT, MockUSDC} from "../src/MockTokens.sol";

contract MockTokensTest is Test {
    MockUSDT public usdt;
    MockUSDC public usdc;
    address public owner;

    function setUp() public {
        owner = address(this);
        usdt = new MockUSDT();
        usdc = new MockUSDC();
    }

    function testInitialSupply() public {
        uint256 expectedSupply = 1000000 * 10 ** 18; // 1 million tokens with 18 decimals
        assertEq(usdt.totalSupply(), expectedSupply, "USDT initial supply incorrect");
        assertEq(usdc.totalSupply(), expectedSupply, "USDC initial supply incorrect");
    }

    function testTokenMetadata() public {
        assertEq(usdt.name(), "Mock USDT", "USDT name incorrect");
        assertEq(usdt.symbol(), "USDT", "USDT symbol incorrect");
        assertEq(usdt.decimals(), 18, "USDT decimals incorrect");

        assertEq(usdc.name(), "Mock USDC", "USDC name incorrect");
        assertEq(usdc.symbol(), "USDC", "USDC symbol incorrect");
        assertEq(usdc.decimals(), 18, "USDC decimals incorrect");
    }

    function testInitialBalances() public {
        uint256 expectedBalance = 1000000 * 10 ** 18;
        assertEq(usdt.balanceOf(owner), expectedBalance, "Owner USDT balance incorrect");
        assertEq(usdc.balanceOf(owner), expectedBalance, "Owner USDC balance incorrect");
    }
} 