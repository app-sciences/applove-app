// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title APLOVToken (demo)
/// @notice TEST TOKEN WITH NO VALUE. Testnet-only demonstration of the proposed APLOV ecosystem token.
/// Supply policy: hard cap of 1,000,000,000 tokens. Only MINTER_ROLE may mint. No burn-to-redeem,
/// no market or liquidity integration. Must never be deployed to mainnet from this source.
contract APLOVToken is ERC20Capped, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 public constant MAX_SUPPLY = 1_000_000_000e18;

    constructor(address admin) ERC20("AppLove Test Token (no value)", "tAPLOV") ERC20Capped(MAX_SUPPLY) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
}
