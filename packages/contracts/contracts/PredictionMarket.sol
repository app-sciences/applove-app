// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title PredictionMarket
/// @notice SIMULATION, test collateral only. Fully collateralized complete-set market.
/// Depositing N collateral (minus fee) mints N units of EVERY outcome (token ids 0..outcomeCount-1).
/// Outcome units are ERC-1155 and can be traded peer-to-peer. A complete set can be merged back into
/// collateral at any time before settlement. After resolution each winning unit redeems for exactly
/// one collateral unit; after cancellation each unit of any outcome redeems for 1/outcomeCount.
/// Invariant: while Open, totalSupply(i) == lockedCollateral for every outcome i, so payouts can
/// never exceed collateral held.
contract PredictionMarket is ERC1155Supply, ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum State {
        Open,
        Resolved,
        Cancelled
    }

    uint256 public immutable marketId;
    IERC20 public immutable collateral;
    address public immutable oracle;
    address public immutable treasury;
    uint64 public immutable closeTime;
    uint64 public immutable resolveBy;
    uint16 public immutable feeBps;
    uint8 public immutable outcomeCount;
    bytes32 public immutable termsHash;

    State public state;
    uint8 public winningOutcome;
    uint256 public lockedCollateral;

    event SetsMinted(address indexed account, uint256 deposited, uint256 fee, uint256 sets);
    event SetsMerged(address indexed account, uint256 sets);
    event MarketResolved(uint8 winningOutcome);
    event MarketCancelled(address indexed by);
    event Redeemed(address indexed account, uint256 payout);

    error OnlyOracle();
    error WrongState(State actual);
    error TradingClosed();
    error TooEarly();
    error InvalidOutcome(uint8 outcome);
    error ZeroAmount();
    error NothingToRedeem();

    constructor(
        uint256 marketId_,
        IERC20 collateral_,
        address oracle_,
        address treasury_,
        uint64 closeTime_,
        uint64 resolveBy_,
        uint16 feeBps_,
        uint8 outcomeCount_,
        bytes32 termsHash_,
        string memory uri_
    ) ERC1155(uri_) {
        marketId = marketId_;
        collateral = collateral_;
        oracle = oracle_;
        treasury = treasury_;
        closeTime = closeTime_;
        resolveBy = resolveBy_;
        feeBps = feeBps_;
        outcomeCount = outcomeCount_;
        termsHash = termsHash_;
    }

    modifier onlyOracle() {
        if (msg.sender != oracle) revert OnlyOracle();
        _;
    }

    modifier inState(State s) {
        if (state != s) revert WrongState(state);
        _;
    }

    /// @notice Deposit `amount` collateral; receive (amount - fee) units of every outcome.
    function mintSets(uint256 amount) external nonReentrant inState(State.Open) returns (uint256 sets) {
        if (block.timestamp >= closeTime) revert TradingClosed();
        uint256 fee = (amount * feeBps) / 10_000;
        sets = amount - fee;
        if (sets == 0) revert ZeroAmount();
        lockedCollateral += sets;
        collateral.safeTransferFrom(msg.sender, address(this), amount);
        if (fee != 0) collateral.safeTransfer(treasury, fee);
        _mintBatch(msg.sender, _allIds(), _filled(sets), "");
        emit SetsMinted(msg.sender, amount, fee, sets);
    }

    /// @notice Burn one unit of every outcome per set and get the collateral back (no fee).
    function mergeSets(uint256 sets) external nonReentrant inState(State.Open) {
        if (sets == 0) revert ZeroAmount();
        _burnBatch(msg.sender, _allIds(), _filled(sets));
        lockedCollateral -= sets;
        collateral.safeTransfer(msg.sender, sets);
        emit SetsMerged(msg.sender, sets);
    }

    function resolve(uint8 outcome) external onlyOracle inState(State.Open) {
        if (block.timestamp < closeTime) revert TooEarly();
        if (outcome >= outcomeCount) revert InvalidOutcome(outcome);
        winningOutcome = outcome;
        state = State.Resolved;
        emit MarketResolved(outcome);
    }

    /// @notice Oracle may cancel (missing/unreliable data). Anyone may cancel once resolveBy passes unresolved.
    function cancel() external inState(State.Open) {
        if (msg.sender != oracle && block.timestamp <= resolveBy) revert OnlyOracle();
        state = State.Cancelled;
        emit MarketCancelled(msg.sender);
    }

    /// @notice Burn the caller's redeemable units and pay out. Burning makes double claims impossible.
    function redeem() external nonReentrant returns (uint256 payout) {
        if (state == State.Resolved) {
            payout = balanceOf(msg.sender, winningOutcome);
            if (payout == 0) revert NothingToRedeem();
            _burn(msg.sender, winningOutcome, payout);
        } else if (state == State.Cancelled) {
            uint256 total = 0;
            uint256[] memory ids = _allIds();
            uint256[] memory bals = new uint256[](outcomeCount);
            for (uint256 i = 0; i < outcomeCount; ++i) {
                bals[i] = balanceOf(msg.sender, i);
                total += bals[i];
            }
            payout = total / outcomeCount;
            if (total == 0) revert NothingToRedeem();
            _burnBatch(msg.sender, ids, bals);
        } else {
            revert WrongState(state);
        }
        lockedCollateral -= payout;
        if (payout != 0) collateral.safeTransfer(msg.sender, payout);
        emit Redeemed(msg.sender, payout);
    }

    function _allIds() private view returns (uint256[] memory ids) {
        ids = new uint256[](outcomeCount);
        for (uint256 i = 0; i < outcomeCount; ++i) ids[i] = i;
    }

    function _filled(uint256 v) private view returns (uint256[] memory arr) {
        arr = new uint256[](outcomeCount);
        for (uint256 i = 0; i < outcomeCount; ++i) arr[i] = v;
    }
}
