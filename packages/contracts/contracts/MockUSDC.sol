// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MockUSDC
/// @notice TEST TOKEN WITH NO VALUE. A 6-decimal stand-in for USDC on Base Sepolia.
/// Anyone can mint up to FAUCET_LIMIT per call so demo users can fund wallets.
contract MockUSDC is ERC20 {
    uint256 public constant FAUCET_LIMIT = 10_000e6;

    error FaucetLimitExceeded(uint256 requested, uint256 limit);

    constructor() ERC20("Mock USDC (TEST, no value)", "mUSDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        if (amount > FAUCET_LIMIT) revert FaucetLimitExceeded(amount, FAUCET_LIMIT);
        _mint(to, amount);
    }
}
