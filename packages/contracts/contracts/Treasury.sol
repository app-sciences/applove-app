// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Treasury
/// @notice SIMULATION. Receives platform fees. Only TREASURER_ROLE can move funds out.
/// Deliberately has no buyback, price-support, or market-making logic. Any future liquidity-provider
/// integration must be a separate, independently authorized contract (see docs/SMART_CONTRACTS.md).
contract Treasury is AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");

    event Withdrawn(address indexed token, address indexed to, uint256 amount, bytes32 memo);

    error ZeroAddress();

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(TREASURER_ROLE, admin);
    }

    function withdraw(IERC20 token, address to, uint256 amount, bytes32 memo) external onlyRole(TREASURER_ROLE) {
        if (to == address(0)) revert ZeroAddress();
        token.safeTransfer(to, amount);
        emit Withdrawn(address(token), to, amount, memo);
    }
}
