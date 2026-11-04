// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ParticipationToken} from "./ParticipationToken.sol";

/// @title CrowdfundCampaign
/// @notice SIMULATION. All-or-nothing escrow for one participation series, paid in mock USDC.
/// Units are minted to the contributor at reservation time (so the series supply always equals units
/// sold and revenue can never be split over a partial supply) and burned on refund if the goal is missed.
/// Reservations require the series to be non-transferable, so reserved units cannot leave the wallet
/// before the outcome is known. The developer withdraws proceeds once after success.
/// Requires MINTER_ROLE on ParticipationToken.
contract CrowdfundCampaign is ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum State {
        Funding,
        Succeeded,
        Failed
    }

    IERC20 public immutable paymentToken;
    ParticipationToken public immutable units;
    uint256 public immutable seriesId;
    address public immutable developer;
    uint256 public immutable unitPrice;
    uint256 public immutable goalUnits;
    uint256 public immutable capUnits;
    uint64 public immutable deadline;

    State public state;
    uint256 public unitsSold;
    bool public proceedsWithdrawn;
    mapping(address => uint256) public reservedUnits;

    event UnitsReserved(address indexed buyer, uint256 units, uint256 paid);
    event CampaignFinalized(State outcome, uint256 unitsSold);
    event Refunded(address indexed buyer, uint256 amount);
    event ProceedsWithdrawn(address indexed developer, uint256 amount);

    error InvalidParams();
    error WrongState(State expected, State actual);
    error DeadlinePassed();
    error NotEnded();
    error CapExceeded(uint256 requested, uint256 available);
    error ZeroAmount();
    error NothingToClaim();
    error SeriesTransferable();
    error NotDeveloper();
    error AlreadyWithdrawn();

    constructor(
        IERC20 paymentToken_,
        ParticipationToken units_,
        uint256 seriesId_,
        address developer_,
        uint256 unitPrice_,
        uint256 goalUnits_,
        uint256 capUnits_,
        uint64 deadline_
    ) {
        (bool exists,,, uint256 maxSupply) = units_.series(seriesId_);
        if (
            !exists || developer_ == address(0) || unitPrice_ == 0 || goalUnits_ == 0 || capUnits_ < goalUnits_
                || capUnits_ > maxSupply || deadline_ <= block.timestamp
        ) revert InvalidParams();
        paymentToken = paymentToken_;
        units = units_;
        seriesId = seriesId_;
        developer = developer_;
        unitPrice = unitPrice_;
        goalUnits = goalUnits_;
        capUnits = capUnits_;
        deadline = deadline_;
    }

    function reserve(uint256 amount) external nonReentrant {
        _requireState(State.Funding);
        if (block.timestamp >= deadline) revert DeadlinePassed();
        if (amount == 0) revert ZeroAmount();
        uint256 available = capUnits - unitsSold;
        if (amount > available) revert CapExceeded(amount, available);
        (, bool transferable,,) = units.series(seriesId);
        if (transferable) revert SeriesTransferable();
        unitsSold += amount;
        reservedUnits[msg.sender] += amount;
        uint256 cost = amount * unitPrice;
        paymentToken.safeTransferFrom(msg.sender, address(this), cost);
        units.mint(msg.sender, seriesId, amount);
        emit UnitsReserved(msg.sender, amount, cost);
    }

    /// @notice Anyone can close the campaign after the deadline, or early once the cap is sold out.
    function finalize() external {
        _requireState(State.Funding);
        if (block.timestamp < deadline && unitsSold < capUnits) revert NotEnded();
        state = unitsSold >= goalUnits ? State.Succeeded : State.Failed;
        emit CampaignFinalized(state, unitsSold);
    }

    function refund() external nonReentrant {
        _requireState(State.Failed);
        uint256 amount = reservedUnits[msg.sender];
        if (amount == 0) revert NothingToClaim();
        reservedUnits[msg.sender] = 0;
        units.burn(msg.sender, seriesId, amount);
        uint256 paid = amount * unitPrice;
        paymentToken.safeTransfer(msg.sender, paid);
        emit Refunded(msg.sender, paid);
    }

    function withdrawProceeds() external nonReentrant {
        _requireState(State.Succeeded);
        if (msg.sender != developer) revert NotDeveloper();
        if (proceedsWithdrawn) revert AlreadyWithdrawn();
        proceedsWithdrawn = true;
        uint256 amount = unitsSold * unitPrice;
        paymentToken.safeTransfer(developer, amount);
        emit ProceedsWithdrawn(developer, amount);
    }

    function _requireState(State expected) private view {
        if (state != expected) revert WrongState(expected, state);
    }
}
