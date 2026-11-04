// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PredictionMarket} from "./PredictionMarket.sol";

/// @title PredictionMarketFactory
/// @notice Deploys approved markets with immutable settlement terms. termsHash commits to the full
/// off-chain market definition (app, metric, data source, storefront, outcome conditions, data policy).
contract PredictionMarketFactory is AccessControl {
    bytes32 public constant MARKET_CREATOR_ROLE = keccak256("MARKET_CREATOR_ROLE");
    uint16 public constant MAX_FEE_BPS = 500;
    uint8 public constant MAX_OUTCOMES = 8;

    struct MarketParams {
        bytes32 termsHash;
        string metadataURI;
        uint8 outcomeCount;
        address collateral;
        uint64 closeTime;
        uint64 resolveBy;
        uint16 feeBps;
    }

    address public immutable oracle;
    address public immutable treasury;
    uint64 public immutable minResolutionWindow;

    address[] public markets;
    mapping(address => bool) public isMarket;
    mapping(address => bool) public allowedCollateral;

    event MarketCreated(uint256 indexed marketId, address indexed market, bytes32 termsHash, address collateral, uint8 outcomeCount, uint64 closeTime, uint64 resolveBy, uint16 feeBps, string metadataURI);
    event CollateralAllowed(address indexed token, bool allowed);

    error CollateralNotAllowed(address token);
    error InvalidOutcomeCount();
    error InvalidTimes();
    error FeeTooHigh();
    error EmptyTerms();
    error ZeroAddress();

    constructor(address admin, address oracle_, address treasury_, uint64 minResolutionWindow_) {
        if (oracle_ == address(0) || treasury_ == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MARKET_CREATOR_ROLE, admin);
        oracle = oracle_;
        treasury = treasury_;
        minResolutionWindow = minResolutionWindow_;
    }

    function setCollateralAllowed(address token, bool allowed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(0)) revert ZeroAddress();
        allowedCollateral[token] = allowed;
        emit CollateralAllowed(token, allowed);
    }

    function createMarket(MarketParams calldata p) external onlyRole(MARKET_CREATOR_ROLE) returns (address market) {
        if (!allowedCollateral[p.collateral]) revert CollateralNotAllowed(p.collateral);
        if (p.outcomeCount < 2 || p.outcomeCount > MAX_OUTCOMES) revert InvalidOutcomeCount();
        if (p.closeTime <= block.timestamp || p.resolveBy < p.closeTime + minResolutionWindow) revert InvalidTimes();
        if (p.feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        if (p.termsHash == bytes32(0)) revert EmptyTerms();
        uint256 marketId = markets.length;
        market = address(
            new PredictionMarket(
                marketId, IERC20(p.collateral), oracle, treasury, p.closeTime, p.resolveBy, p.feeBps, p.outcomeCount,
                p.termsHash, p.metadataURI
            )
        );
        markets.push(market);
        isMarket[market] = true;
        emit MarketCreated(marketId, market, p.termsHash, p.collateral, p.outcomeCount, p.closeTime, p.resolveBy, p.feeBps, p.metadataURI);
    }

    function marketCount() external view returns (uint256) {
        return markets.length;
    }
}
