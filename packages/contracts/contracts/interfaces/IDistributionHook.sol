// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice Called by ParticipationToken before any balance change so accrued
/// distributions are settled at the old balances (prevents duplicate claims across transfers).
interface IDistributionHook {
    function checkpoint(uint256 seriesId, address account) external;
}
