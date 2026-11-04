// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IDistributionHook} from "./interfaces/IDistributionHook.sol";

/// @title ParticipationToken
/// @notice SIMULATION. ERC-1155 revenue-share participation units. Token id == AppRegistry projectId.
/// Each series has a fixed maxSupply and shareBps (the share of eligible proceeds the whole series
/// represents). Wallet-to-wallet transfers are disabled per series until explicitly enabled
/// (pending legal review). Every balance change checkpoints the distribution hook first.
contract ParticipationToken is ERC1155Supply, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant SERIES_ADMIN_ROLE = keccak256("SERIES_ADMIN_ROLE");

    struct Series {
        bool exists;
        bool transfersEnabled;
        uint16 shareBps;
        uint256 maxSupply;
    }

    IDistributionHook public hook;
    mapping(uint256 seriesId => Series) public series;

    event HookSet(address hook);
    event SeriesCreated(uint256 indexed seriesId, uint256 maxSupply, uint16 shareBps);
    event TransfersEnabledSet(uint256 indexed seriesId, bool enabled);

    error HookAlreadySet();
    error HookNotSet();
    error ZeroAddress();
    error SeriesExists(uint256 seriesId);
    error UnknownSeries(uint256 seriesId);
    error InvalidSeriesParams();
    error MaxSupplyExceeded(uint256 seriesId, uint256 requested, uint256 available);
    error TransfersDisabled(uint256 seriesId);

    constructor(address admin, string memory uri_) ERC1155(uri_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(SERIES_ADMIN_ROLE, admin);
    }

    /// @notice One-time wiring to the PayoutVault. Cannot be changed later, so accounting can't be swapped out.
    function setHook(address hook_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (address(hook) != address(0)) revert HookAlreadySet();
        if (hook_ == address(0)) revert ZeroAddress();
        hook = IDistributionHook(hook_);
        emit HookSet(hook_);
    }

    function createSeries(uint256 seriesId, uint256 maxSupply, uint16 shareBps) external onlyRole(SERIES_ADMIN_ROLE) {
        if (address(hook) == address(0)) revert HookNotSet();
        if (series[seriesId].exists) revert SeriesExists(seriesId);
        if (maxSupply == 0 || shareBps == 0 || shareBps > 10_000) revert InvalidSeriesParams();
        series[seriesId] = Series(true, false, shareBps, maxSupply);
        emit SeriesCreated(seriesId, maxSupply, shareBps);
    }

    function setTransfersEnabled(uint256 seriesId, bool enabled) external onlyRole(SERIES_ADMIN_ROLE) {
        if (!series[seriesId].exists) revert UnknownSeries(seriesId);
        series[seriesId].transfersEnabled = enabled;
        emit TransfersEnabledSet(seriesId, enabled);
    }

    function mint(address to, uint256 seriesId, uint256 amount) external onlyRole(MINTER_ROLE) {
        Series memory s = series[seriesId];
        if (!s.exists) revert UnknownSeries(seriesId);
        uint256 available = s.maxSupply - totalSupply(seriesId);
        if (amount > available) revert MaxSupplyExceeded(seriesId, amount, available);
        _mint(to, seriesId, amount, "");
    }

    /// @notice Used by campaigns to cancel units when a contributor is refunded.
    function burn(address from, uint256 seriesId, uint256 amount) external onlyRole(MINTER_ROLE) {
        _burn(from, seriesId, amount);
    }

    function shareBpsOf(uint256 seriesId) external view returns (uint16) {
        if (!series[seriesId].exists) revert UnknownSeries(seriesId);
        return series[seriesId].shareBps;
    }

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal override {
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            if (from != address(0) && to != address(0) && !series[id].transfersEnabled) revert TransfersDisabled(id);
            // Settle accruals at the pre-transfer balances.
            if (from != address(0)) hook.checkpoint(id, from);
            if (to != address(0) && to != from) hook.checkpoint(id, to);
        }
        super._update(from, to, ids, values);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
