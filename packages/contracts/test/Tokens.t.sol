// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Base} from "./Base.t.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {MockUSDC} from "../contracts/MockUSDC.sol";
import {Treasury} from "../contracts/Treasury.sol";

contract TokensTest is Base {
    function test_MockUSDC_hasSixDecimalsAndFaucetLimit() public {
        assertEq(usdc.decimals(), 6);
        usdc.mint(alice, 10_000e6);
        assertEq(usdc.balanceOf(alice), 10_000e6);
        vm.expectRevert(abi.encodeWithSelector(MockUSDC.FaucetLimitExceeded.selector, 10_000e6 + 1, 10_000e6));
        usdc.mint(alice, 10_000e6 + 1);
    }

    function test_APLOV_metadataMarksTestToken() public view {
        assertEq(aplov.symbol(), "tAPLOV");
        assertEq(aplov.cap(), 1_000_000_000e18);
        assertEq(aplov.totalSupply(), 0);
    }

    function test_APLOV_onlyMinterCanMint() public {
        bytes32 role = aplov.MINTER_ROLE();
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, role));
        aplov.mint(stranger, 1);
    }

    function test_APLOV_cannotExceedCap() public {
        aplov.mint(alice, aplov.cap());
        vm.expectRevert(abi.encodeWithSelector(ERC20Capped.ERC20ExceededCap.selector, aplov.cap() + 1, aplov.cap()));
        aplov.mint(alice, 1);
    }

    function testFuzz_APLOV_supplyNeverExceedsCap(uint256 a, uint256 b) public {
        a = bound(a, 0, aplov.cap());
        aplov.mint(alice, a);
        b = bound(b, 0, type(uint128).max);
        if (a + b > aplov.cap()) {
            vm.expectRevert();
            aplov.mint(bob, b);
        } else {
            aplov.mint(bob, b);
        }
        assertLe(aplov.totalSupply(), aplov.cap());
    }

    function test_APLOV_transfers() public {
        aplov.mint(alice, 100e18);
        vm.prank(alice);
        aplov.transfer(bob, 40e18);
        assertEq(aplov.balanceOf(bob), 40e18);
        assertEq(aplov.balanceOf(alice), 60e18);
    }

    function test_Treasury_onlyTreasurerWithdraws() public {
        usdc.mint(address(treasury), 500e6);
        bytes32 role = treasury.TREASURER_ROLE();
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, role));
        treasury.withdraw(usdc, stranger, 500e6, "steal");

        treasury.withdraw(usdc, carol, 200e6, "ops");
        assertEq(usdc.balanceOf(carol), 200e6);
        vm.expectRevert(Treasury.ZeroAddress.selector);
        treasury.withdraw(usdc, address(0), 1, "");
    }
}
