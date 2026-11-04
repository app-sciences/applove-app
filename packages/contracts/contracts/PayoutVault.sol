// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IDistributionHook} from "./interfaces/IDistributionHook.sol";
import {ParticipationToken} from "./ParticipationToken.sol";
import {RevenueRegistry} from "./RevenueRegistry.sol";

/// @title PayoutVault
/// @notice SIMULATION. Holds settlement funds (mock USDC) and distributes them to participation holders.
/// Entitlement for a period = finalized eligibleProceeds * series shareBps / 10_000.
/// Funding is capped at the entitlement; unfunded entitlement is reported as a shortfall and is never
/// treated as paid. Distribution uses a reward-per-unit accumulator; ParticipationToken checkpoints
/// both parties before every balance change, so transfers cannot duplicate earlier accruals.
/// Rounding: every holder amount is floored, so sum(claims) <= sum(funded). The difference (at most one
/// base unit per holder per checkpoint) stays in the vault. There is intentionally no sweep function:
/// an earlier per-funding dust counter could overstate dust and let a sweep take holder money.
contract PayoutVault is IDistributionHook, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    uint256 public constant ACC_PRECISION = 1e30;

    IERC20 public immutable settlementToken;
    ParticipationToken public immutable units;
    RevenueRegistry public immutable revenueRegistry;

    mapping(uint256 projectId => mapping(uint32 period => uint256)) public funded;
    mapping(uint256 projectId => uint256) public accPerUnit;
    mapping(uint256 projectId => mapping(address => uint256)) public paidPerUnit;
    mapping(uint256 projectId => mapping(address => uint256)) public accrued;
    mapping(uint256 projectId => uint256) public totalFunded;
    mapping(uint256 projectId => uint256) public totalClaimed;

    event PeriodFunded(uint256 indexed projectId, uint32 indexed period, address indexed funder, uint256 amount, uint256 fundedTotal, uint256 entitlement);
    event Claimed(uint256 indexed projectId, address indexed holder, uint256 amount);

    error OnlyUnits();
    error ZeroAmount();
    error ExceedsEntitlement(uint256 requested, uint256 remaining);
    error NoParticipants(uint256 projectId);
    error UnexpectedTransferAmount(uint256 expected, uint256 received);
    error NothingToClaim();

    constructor(address admin, IERC20 settlementToken_, ParticipationToken units_, RevenueRegistry revenueRegistry_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        settlementToken = settlementToken_;
        units = units_;
        revenueRegistry = revenueRegistry_;
    }

    // ---------------------------------------------------------------- views

    /// @notice Reverts if the period is not finalized.
    function entitlement(uint256 projectId, uint32 period) public view returns (uint256) {
        uint256 eligible = revenueRegistry.finalizedEligibleProceeds(projectId, period);
        return (eligible * units.shareBpsOf(projectId)) / 10_000;
    }

    function shortfall(uint256 projectId, uint32 period) external view returns (uint256) {
        return entitlement(projectId, period) - funded[projectId][period];
    }

    function claimable(uint256 projectId, address account) external view returns (uint256) {
        return accrued[projectId][account] + _pending(projectId, account);
    }

    // ---------------------------------------------------------------- funding

    /// @notice Deposit settlement funds for a finalized period. Anyone may fund (normally the developer).
    function fund(uint256 projectId, uint32 period, uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        uint256 ent = entitlement(projectId, period);
        uint256 already = funded[projectId][period];
        if (amount > ent - already) revert ExceedsEntitlement(amount, ent - already);
        uint256 supply = units.totalSupply(projectId);
        if (supply == 0) revert NoParticipants(projectId);

        uint256 before = settlementToken.balanceOf(address(this));
        settlementToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = settlementToken.balanceOf(address(this)) - before;
        if (received != amount) revert UnexpectedTransferAmount(amount, received);

        funded[projectId][period] = already + amount;
        totalFunded[projectId] += amount;
        accPerUnit[projectId] += (amount * ACC_PRECISION) / supply;
        emit PeriodFunded(projectId, period, msg.sender, amount, already + amount, ent);
    }

    // ---------------------------------------------------------------- claims

    function checkpoint(uint256 projectId, address account) external {
        if (msg.sender != address(units)) revert OnlyUnits();
        _checkpoint(projectId, account);
    }

    function claim(uint256 projectId) external nonReentrant whenNotPaused returns (uint256 amount) {
        _checkpoint(projectId, msg.sender);
        amount = accrued[projectId][msg.sender];
        if (amount == 0) revert NothingToClaim();
        accrued[projectId][msg.sender] = 0;
        totalClaimed[projectId] += amount;
        settlementToken.safeTransfer(msg.sender, amount);
        emit Claimed(projectId, msg.sender, amount);
    }

    // ---------------------------------------------------------------- admin

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // ---------------------------------------------------------------- internal

    function _pending(uint256 projectId, address account) private view returns (uint256) {
        uint256 bal = units.balanceOf(account, projectId);
        return (bal * (accPerUnit[projectId] - paidPerUnit[projectId][account])) / ACC_PRECISION;
    }

    function _checkpoint(uint256 projectId, address account) private {
        uint256 owed = _pending(projectId, account);
        if (owed != 0) accrued[projectId][account] += owed;
        paidPerUnit[projectId][account] = accPerUnit[projectId];
    }
}
