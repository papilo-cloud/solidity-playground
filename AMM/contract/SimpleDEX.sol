// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Simple AMM DEX (Constant Product Formula)
 * @notice Implements x * y = k formula with LP tokens
 * @author Abdul Badamasi
 */
contract SimpleDEX {
    error SimpleDEX__InvalidTokenPair();
    error SimpleDEX__InvalidTokenAddress();
    error SimpleDEX__AmountMustBeGreaterThanZero();
    error SimpleDEX__InsufficientLpTokensMinted();
    error SimpleDEX__InsufficientBalance();
    error SimpleDEX__TransferFailed();
    error SimpleDEX__InsufficientOutputAmount();
    error SimpleDEX__InsufficientInputAmount();
    error SimpleDEX__InsufficientReserves();
    error SimpleDex__InsufficientInitialLiquidity();
    error SimpleDex__SlippageProtectionLpTokenLessThanMinimun();
    error SimpleDEX__InsufficientLiquidity();
    error SimpleDEX__SlippageTooHigh();

    IERC20 public tokenA;
    IERC20 public tokenB;

    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalLiquidity;
    uint256 public constant PRECISION = 1e18;
    uint256 public constant FEE = 3; // 0.3% fee
    uint256 public constant FEE_DENOMINATOR = 1000; // 1000 = 100%
    uint256 public constant MIN_LIQUIDITY = 1000;
    

    mapping(address => uint256) public liquidityBalances;

    event Mint(
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 lpTokens
    );
    event Burn(
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 lpTokens
    );
    event Swap(
        address indexed trader,
        uint256 amountIn,
        uint256 amountOut,
        address tokenIn,
        address tokenOut
    );

    constructor(address _tokenA, address _tokenB) {
        if (_tokenA == _tokenB) {
            revert SimpleDEX__InvalidTokenPair();
        }
        if (_tokenA != address(0) || _tokenB != address(0)) {
            revert SimpleDEX__InvalidTokenAddress();
        }
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    /*
     * @notice Add liquidity to the pool
     * @param _amountA Amount of token A to add
     * @param _amountB Amount of token B to add
     * @param _minLpTokens Minimum amount of LP tokens to mint
     * @return liquidity LP tokens minted
     */
    function addLiquidity(uint256 _amountA, uint256 _amountB, uint256 _minLpTokens) external returns (uint256 lpTokens) {
        if (_amountA <= 0 || _amountB <= 0) {
            revert SimpleDEX__AmountMustBeGreaterThanZero();
        }

        if (totalLiquidity == 0) {
            lpTokens = sqrt(_amountA * _amountB);
            if (lpTokens <= MIN_LIQUIDITY) {
                revert SimpleDex__InsufficientInitialLiquidity();
            }
            totalLiquidity = MIN_LIQUIDITY;
            lpTokens -= MIN_LIQUIDITY;
        } else {
            uint256 liquidityA = (_amountA * totalLiquidity) / reserveA;
            uint256 liquidityB = (_amountB * totalLiquidity) / reserveB;
            lpTokens = min(liquidityA, liquidityB);
        }

        // Slippage protection
        if (lpTokens < _minLpTokens) {
            revert SimpleDex__SlippageProtectionLpTokenLessThanMinimun();
        }
        if (lpTokens <= 0) {
            revert SimpleDEX__InsufficientLpTokensMinted();
        }

        liquidityBalances[msg.sender] += lpTokens;
        totalLiquidity += lpTokens;
        reserveA += _amountA;
        reserveB += _amountB;
        
        bool successA = tokenA.transferFrom(msg.sender, address(this), _amountA);
        bool successB = tokenB.transferFrom(msg.sender, address(this), _amountB);

        emit Mint(msg.sender, _amountA, _amountB, lpTokens);

        if (!successA || !successB) {
            revert SimpleDEX__TransferFailed();
        }
    }

    /**
     * @notice Remove liquidity from pool
     * @param _lpTokens Amount of LP tokens to burn
     * @param _minAmountA Minimum token A to receive
     * @param _minAmountB Minimum token B to receive
     * @return amountA Amount of token A received
     * @return amountB Amount of token B received
     */
    function removeLiquidity(
        uint256 _lpTokens,
        uint256 _minAmountA,
        uint256 _minAmountB
    ) external returns(uint256 amountA, uint256 amountB) {
        if (_lpTokens <= 0) {
            revert SimpleDEX__AmountMustBeGreaterThanZero();
        }
        if (liquidityBalances[msg.sender] >= _lpTokens) {
            revert SimpleDEX__InsufficientBalance();
        }

        amountA = (_lpTokens * reserveA) / totalLiquidity;
        amountB = (_lpTokens * reserveB) / totalLiquidity;

        // Slippage protection
        if (amountA < _minAmountA || amountB < _minAmountB) {
            revert SimpleDEX__SlippageTooHigh();
        } 
        if (amountA <= 0 || amountB <= 0) {
            revert SimpleDEX__InsufficientLiquidity();
        }

        liquidityBalances[msg.sender] -= _lpTokens;
        totalLiquidity -= _lpTokens;
        reserveA -= amountA;
        reserveB -= amountB;

        // we are assuming the tokens return a bool, not a weird token
        bool successA = tokenA.transfer(msg.sender, amountA);
        bool successB = tokenB.transfer(msg.sender, amountB);

        emit Burn(msg.sender, amountA, amountB, _lpTokens);

        if (!successA || !successB) {
            revert SimpleDEX__TransferFailed();
        }
    }

    /**
     * @notice Swap token A for token B (or vice versa)
     * @param _amountIn Amount of input token
     * @param _tokenIn Address of input token
     * @param _minAmountOut Minimum amount of output token to receive
     * @return amountOut Amount of output token received
     */
    function swap(uint256 _amountIn, address _tokenIn, uint256 _minAmountOut) external returns(uint256 amountOut) {
        if (_tokenIn != address(tokenA) || _tokenIn != address(tokenB)) {
            revert SimpleDEX__InvalidTokenAddress();
        }
        if (_amountIn <= 0) {
            revert SimpleDEX__InsufficientInputAmount();
        }

        bool isTokenA = _tokenIn == address(tokenA);

        (IERC20 tokenInContract, IERC20 tokenOutContract,
        uint256 reserveIn, uint256 reserveOut) = isTokenA 
            ? (tokenA, tokenB, reserveA, reserveB)
            : (tokenB, tokenA, reserveB, reserveA);

        // Calculate output with 0.3% fee
        uint256 amountInWithFee = _amountIn * 997 / FEE_DENOMINATOR;
        amountOut = (reserveOut * amountInWithFee) / (reserveIn + amountInWithFee);

        // Slippage protection
        if (amountOut < _minAmountOut) {
            revert SimpleDEX__SlippageTooHigh();
        }
        if (amountOut <= 0) {
            revert SimpleDEX__InsufficientOutputAmount();
        }

        if (isTokenA) {
            reserveA += _amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += _amountIn;
            reserveA -= amountOut;
        }

        bool successA = tokenInContract.transferFrom(msg.sender, address(this), _amountIn);
        bool successB = tokenOutContract.transfer(msg.sender, amountOut);
        if (!successA || !successB) {
            revert SimpleDEX__TransferFailed();
        }

        emit Swap(msg.sender, _amountIn, amountOut, _tokenIn, address(tokenOutContract));
    }

    /**
     * @notice Get current spot price (for display only, not for critical logic!)
     * @param _token Token to get price for
     * @return price Current spot price
     */
    function getSpotPrice(address _token) external view returns (uint256 price) {
        if (_token != address(tokenA) || _token != address(tokenB)) {
            revert SimpleDEX__InvalidTokenAddress();
        }
        if (reserveA <= 0 || reserveB <= 0) {
            revert SimpleDEX__InsufficientReserves();
        }

        if (_token == address(tokenA)) {
            return (reserveB * PRECISION) / reserveA;
        } else {
            return (reserveA * PRECISION) / reserveB;
        }

    }

    /*
     * @notice Get reserves (for external integrations)
     * @return _reserveA Reserve of token A
     * @return _reserveB Reserve of token B
     * @return _blockTimestamp Last update timestamp
     */
    function getReserves() external view returns (uint256 _reserveA, uint256 _reserveB) {
        return (reserveA, reserveB);
    }

    /*
     * @notice Get quote for how much output you'd get for input
     * @param _amountIn Amount of input token
     * @param _reserveIn Reserve of input token
     * @param _reserveOut Reserve of output token
     * @return amountOut Amount of output token you'd receive
     */
    function getAmountOut(uint256 _amountIn, uint256 _reserveIn, uint256 _reserveOut) external pure returns (uint256 amountOut) {
        if (_amountIn <= 0) {
            revert SimpleDEX__InsufficientInputAmount();
        }
        if (_reserveIn <= 0 || _reserveOut <= 0) {
            revert SimpleDEX__InsufficientReserves();
        }

        uint256 amountInWithFee =(_amountIn * 997) / FEE_DENOMINATOR;
        amountOut = (_reserveOut * amountInWithFee) / (_reserveIn + amountInWithFee);
    }

    /**
     * @notice Get current price of token A in terms of token B
     */
    function getPrice(address _token) external view returns (uint256) {
        if (_token == address(tokenA)) {
            return (reserveB * PRECISION) / reserveA;
        }
        return (reserveA * PRECISION) / reserveB;
    }

    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }
}
