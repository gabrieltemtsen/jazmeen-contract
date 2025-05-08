// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./JazmeenToken.sol";

// CELO ERC-20 Interface
interface ICELO {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

// Ubeswap V3 Interfaces (from ubestarter-protocol)
interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function mint(MintParams calldata params) external returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external returns (address pool);
    function factory() external view returns (address);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function getPool(address token0, address token1, uint24 fee) external view returns (address pool);
}

interface IUniswapV3Pool {
    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint8 feeProtocol, bool unlocked);
    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);
}

interface IUniswapV3Factory {
    function feeAmountTickSpacing(uint24 fee) external view returns (int24);
    function getPool(address token0, address token1, uint24 fee) external view returns (address pool);
}

library TickMath {
    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;

    function getSqrtRatioAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96) {
        // Simplified for this example; use the actual TickMath implementation from Ubeswap
        return uint160(1 << 96); // Placeholder
    }
}

contract JazmeenFactory is Ownable {
    using SafeERC20 for IERC20;

    struct TokenInfo {
        address tokenAddress;
        string name;
        string symbol;
        uint256 initiatorFid;
        string imageUrl;
        address creator; // Farcaster user who initiated
        uint256 liquidityTokenId; // Ubeswap V3 NFT position ID
    }

    // Ubeswap V3 addresses (set these for Celo mainnet)
    address public immutable CELO_TOKEN; // CELO ERC-20 interface
    ICELO public immutable celo;
    INonfungiblePositionManager public immutable nftPositionManager;
    address public immutable ubeswapFactory;

    TokenInfo[] public tokens;
    mapping(address => uint256) public tokenToIndex; // Token address to index in tokens array
    mapping(address => uint256) public creatorRewards; // Creator address to accumulated rewards

    event TokenDeployed(
        address indexed tokenAddress,
        uint256 initiatorFid,
        string name,
        string symbol,
        string imageUrl,
        address creator
    );
    event LiquidityAdded(
        address indexed tokenAddress,
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );
    event FeesCollected(address indexed tokenAddress, uint256 amount0, uint256 amount1);
    event RewardsDistributed(address indexed creator, uint256 amount);

    constructor(
        address initialOwner,
        address _nftPositionManager // Ubeswap V3 NFT Position Manager
    ) Ownable() {
        CELO_TOKEN = 0x471EcE3750Da237f93B8E339c536989b8978a438; // CELO ERC-20 on Celo mainnet
        celo = ICELO(CELO_TOKEN);
        nftPositionManager = INonfungiblePositionManager(_nftPositionManager);
        ubeswapFactory = nftPositionManager.factory();
        transferOwnership(initialOwner);
    }

    function deployToken(
        string memory name,
        string memory symbol,
        uint256 initiatorFid,
        string memory imageUrl,
        address creator // Farcaster user address
    ) external payable onlyOwner returns (address tokenAddress) {
        // Verify enough CELO was sent for liquidity
        require(msg.value >= 2 ether, "Must send 2 CELO for liquidity");

        // Deploy token
        uint256 totalSupply = 1_000_000; // 1M tokens
        JazmeenToken token = new JazmeenToken(
            name,
            symbol,
            totalSupply,
            msg.sender, // Bot/agent
            initiatorFid,
            imageUrl
        );
        tokenAddress = address(token);

        // Burn 900K tokens
        uint256 burnAmount = 900_000 * 10**18;
        address burnAddress = 0x000000000000000000000000000000000000dEaD;
        IERC20(tokenAddress).safeTransferFrom(msg.sender, burnAddress, burnAmount);

        // Add liquidity with remaining 100K tokens
        uint256 liquidityAmount = 100_000 * 10**18;
        uint256 celoAmount = 2 ether; // 2 CELO for liquidity
        uint256 tokenId = _addLiquidity(tokenAddress, liquidityAmount, celoAmount);

        // Store token info
        tokens.push(TokenInfo(tokenAddress, name, symbol, initiatorFid, imageUrl, creator, tokenId));
        tokenToIndex[tokenAddress] = tokens.length - 1;

        emit TokenDeployed(tokenAddress, initiatorFid, name, symbol, imageUrl, creator);
        return tokenAddress;
    }

    function collectAndDistributeFees(address tokenAddress) external {
        uint256 index = tokenToIndex[tokenAddress];
        TokenInfo memory tokenInfo = tokens[index];
        require(tokenInfo.tokenAddress == tokenAddress, "Token not found");

        // Collect fees from Ubeswap V3 pool
        (uint128 amount0, uint128 amount1) = _collectFees(tokenInfo.tokenAddress, tokenInfo.liquidityTokenId);

        // Distribute fees to creator (CELO portion)
        if (amount0 > 0 || amount1 > 0) {
            emit FeesCollected(tokenAddress, amount0, amount1);

            // Determine which token is CELO and send to creator
            address token0 = tokenInfo.tokenAddress < CELO_TOKEN ? tokenInfo.tokenAddress : CELO_TOKEN;
            address token1 = tokenInfo.tokenAddress < CELO_TOKEN ? CELO_TOKEN : tokenInfo.tokenAddress;
            if (token0 == CELO_TOKEN && amount0 > 0) {
                celo.transfer(tokenInfo.creator, amount0);
                creatorRewards[tokenInfo.creator] += amount0;
                emit RewardsDistributed(tokenInfo.creator, amount0);
            } else if (token1 == CELO_TOKEN && amount1 > 0) {
                celo.transfer(tokenInfo.creator, amount1);
                creatorRewards[tokenInfo.creator] += amount1;
                emit RewardsDistributed(tokenInfo.creator, amount1);
            }
        }
    }

    function getTokens() external view returns (TokenInfo[] memory) {
        return tokens;
    }

    // Internal functions
    function _addLiquidity(
        address tokenAddress,
        uint256 tokenAmount,
        uint256 celoAmount
    ) internal returns (uint256 tokenId) {
        // Approve CELO for Ubeswap (using ERC-20 interface)
        celo.approve(address(nftPositionManager), celoAmount);

        // Approve tokens for Ubeswap
        IERC20(tokenAddress).safeApprove(address(nftPositionManager), tokenAmount);

        // Create pool and calculate ticks
        (address token0, address token1, uint24 fee, address pool) = _setupPool(tokenAddress);
        (int24 tickLower, int24 tickUpper) = _calculateTicks(fee);

        // Prepare amounts
        (uint256 amount0Desired, uint256 amount1Desired, uint256 amount0Min, uint256 amount1Min) = 
            _prepareAmounts(tokenAddress, tokenAmount, celoAmount, token0);

        // Mint liquidity position
        return _mintLiquidity(tokenAddress, token0, token1, fee, tickLower, tickUpper, amount0Desired, amount1Desired, amount0Min, amount1Min);
    }

    function _setupPool(address tokenAddress) internal returns (address token0, address token1, uint24 fee, address pool) {
        token0 = tokenAddress < CELO_TOKEN ? tokenAddress : CELO_TOKEN;
        token1 = tokenAddress < CELO_TOKEN ? CELO_TOKEN : tokenAddress;
        fee = 3000; // 0.3% fee tier
        pool = nftPositionManager.createAndInitializePoolIfNecessary(
            token0,
            token1,
            fee,
            TickMath.getSqrtRatioAtTick(0) // Initial price (1:1 for simplicity)
        );
    }

    function _calculateTicks(uint24 fee) internal view returns (int24 tickLower, int24 tickUpper) {
        tickLower = -6000; // -0.6% price range
        tickUpper = 6000;  // +0.6% price range
        int24 tickSpacing = IUniswapV3Factory(ubeswapFactory).feeAmountTickSpacing(fee);
        tickLower = (tickLower / tickSpacing) * tickSpacing;
        tickUpper = (tickUpper / tickSpacing) * tickSpacing;
    }

    function _prepareAmounts(
        address tokenAddress,
        uint256 tokenAmount,
        uint256 celoAmount,
        address token0
    ) internal pure returns (uint256 amount0Desired, uint256 amount1Desired, uint256 amount0Min, uint256 amount1Min) {
        amount0Desired = token0 == tokenAddress ? tokenAmount : celoAmount;
        amount1Desired = token0 == tokenAddress ? celoAmount : tokenAmount;
        amount0Min = (amount0Desired * 98) / 100; // 2% slippage
        amount1Min = (amount1Desired * 98) / 100;
    }

    function _mintLiquidity(
        address tokenAddress,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) internal returns (uint256 tokenId) {
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: fee,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: amount0Desired,
            amount1Desired: amount1Desired,
            amount0Min: amount0Min,
            amount1Min: amount1Min,
            recipient: address(this),
            deadline: block.timestamp + 5 minutes
        });

        uint256 amount0;
        uint256 amount1;
        uint128 liquidity;
        (tokenId, liquidity, amount0, amount1) = nftPositionManager.mint(params);
        emit LiquidityAdded(tokenAddress, tokenId, liquidity, amount0, amount1);
    }

    function _collectFees(address tokenAddress, uint256 tokenId) internal returns (uint128 amount0, uint128 amount1) {
        address token0 = tokenAddress < CELO_TOKEN ? tokenAddress : CELO_TOKEN;
        address token1 = tokenAddress < CELO_TOKEN ? CELO_TOKEN : tokenAddress;
        address poolAddress = IUniswapV3Factory(ubeswapFactory).getPool(token0, token1, 3000);
        require(poolAddress != address(0), "Pool not found");

        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
        (amount0, amount1) = pool.collect(
            address(this),
            -6000, // tickLower
            6000,  // tickUpper
            type(uint128).max,
            type(uint128).max
        );
    }

    // Allow factory to receive CELO for liquidity
    receive() external payable {}
}