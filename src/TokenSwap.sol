// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title TokenSwap
 * @dev Advanced token swap contract with liquidity pools and automated market maker
 * @notice Implements constant product AMM formula (x * y = k)
 */
contract TokenSwap is ReentrancyGuard, Ownable, Pausable {
    using Math for uint256;

    struct Pool {
        uint256 token0Balance;
        uint256 token1Balance;
        uint256 totalShares;
        uint24 fee;  // Move fee before the mapping
        mapping(address => uint256) shares;
    }

    mapping(address => mapping(address => Pool)) public pools;
    mapping(address => mapping(address => bool)) public poolExists;
    
    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    uint256 private constant PRECISION = 1e18;

    event PoolCreated(address indexed token0, address indexed token1, uint24 fee);
    event LiquidityAdded(
        address indexed provider,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 shares
    );
    event LiquidityRemoved(
        address indexed provider,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 shares
    );
    event Swap(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

      /**
     * @dev Constructor that initializes the contract
     * @notice Sets the initial owner of the contract
     */
    constructor() Ownable(msg.sender) {
    }

    /**
     * @dev Creates a new liquidity pool
     * @param token0 Address of the first token
     * @param token1 Address of the second token
     * @param fee Trading fee in basis points
     */
    function createPool(
        address token0,
        address token1,
        uint24 fee
    ) external onlyOwner {
        require(token0 != token1, "Identical tokens");
        require(fee <= 1000, "Fee too high"); // Max 10%
        require(!poolExists[token0][token1], "Pool exists");

        poolExists[token0][token1] = true;
        poolExists[token1][token0] = true;
        pools[token0][token1].fee = fee;
        pools[token1][token0].fee = fee;

        emit PoolCreated(token0, token1, fee);
    }

    /**
     * @dev Adds liquidity to a pool
     * @param token0 Address of the first token
     * @param token1 Address of the second token
     * @param amount0Desired Desired amount of first token
     * @param amount1Desired Desired amount of second token
     * @param amount0Min Minimum amount of first token
     * @param amount1Min Minimum amount of second token
     */
    function addLiquidity(
        address token0,
        address token1,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) external nonReentrant whenNotPaused returns (uint256 shares) {
        require(poolExists[token0][token1], "Pool doesn't exist");
        Pool storage pool = pools[token0][token1];

        uint256 amount0;
        uint256 amount1;

        if (pool.token0Balance == 0 && pool.token1Balance == 0) {
            amount0 = amount0Desired;
            amount1 = amount1Desired;
            shares = Math.sqrt(amount0 * amount1);
            require(shares > MINIMUM_LIQUIDITY, "Insufficient liquidity minted");
        } else {
            uint256 amount1Optimal = (amount0Desired * pool.token1Balance) / pool.token0Balance;
            if (amount1Optimal <= amount1Desired) {
                require(amount1Optimal >= amount1Min, "Insufficient amount1");
                amount0 = amount0Desired;
                amount1 = amount1Optimal;
            } else {
                uint256 amount0Optimal = (amount1Desired * pool.token0Balance) / pool.token1Balance;
                require(amount0Optimal >= amount0Min, "Insufficient amount0");
                amount0 = amount0Optimal;
                amount1 = amount1Desired;
            }
            shares = Math.min(
                (amount0 * pool.totalShares) / pool.token0Balance,
                (amount1 * pool.totalShares) / pool.token1Balance
            );
        }

        require(shares > 0, "Insufficient liquidity minted");

        IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        IERC20(token1).transferFrom(msg.sender, address(this), amount1);

        pool.token0Balance += amount0;
        pool.token1Balance += amount1;
        pool.totalShares += shares;
        pool.shares[msg.sender] += shares;

        emit LiquidityAdded(msg.sender, token0, token1, amount0, amount1, shares);
    }

    /**
     * @dev Calculates the amount of output tokens for a swap
     * @param amountIn Amount of input tokens
     * @param reserveIn Reserve of input token
     * @param reserveOut Reserve of output token
     * @param fee Trading fee in basis points
     */
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint24 fee
    ) public pure returns (uint256) {
        require(amountIn > 0, "Insufficient input");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        uint256 amountInWithFee = amountIn * (10000 - fee);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10000) + amountInWithFee;
        return numerator / denominator;
    }

    /**
     * @dev Swaps tokens
     * @param tokenIn Address of input token
     * @param tokenOut Address of output token
     * @param amountIn Amount of input tokens
     * @param amountOutMin Minimum amount of output tokens
     * @param deadline Transaction deadline
     */
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline
    ) external nonReentrant whenNotPaused returns (uint256 amountOut) {
        require(deadline >= block.timestamp, "Expired");
        require(poolExists[tokenIn][tokenOut], "Pool doesn't exist");

        Pool storage pool = pools[tokenIn][tokenOut];
        
        amountOut = getAmountOut(
            amountIn,
            pool.token0Balance,
            pool.token1Balance,
            pool.fee
        );
        
        require(amountOut >= amountOutMin, "Insufficient output amount");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transfer(msg.sender, amountOut);

        pool.token0Balance += amountIn;
        pool.token1Balance -= amountOut;

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }
} 