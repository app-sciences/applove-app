// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Base} from "./Base.t.sol";
import {ParticipationToken} from "../contracts/ParticipationToken.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract ParticipationTokenTest is Base {
    uint256 id;

    function setUp() public override {
        super.setUp();
        id = _registerProject("1");
        units.createSeries(id, 1_000, 1_000);
    }

    function test_series_paramsValidated() public {
        vm.expectRevert(abi.encodeWithSelector(ParticipationToken.SeriesExists.selector, id));
        units.createSeries(id, 1, 1);
        vm.expectRevert(ParticipationToken.InvalidSeriesParams.selector);
        units.createSeries(2, 0, 100);
        vm.expectRevert(ParticipationToken.InvalidSeriesParams.selector);
        units.createSeries(2, 10, 0);
        vm.expectRevert(ParticipationToken.InvalidSeriesParams.selector);
        units.createSeries(2, 10, 10_001);
    }

    function test_series_requiresHook() public {
        ParticipationToken fresh = new ParticipationToken(admin, "");
        vm.expectRevert(ParticipationToken.HookNotSet.selector);
        fresh.createSeries(1, 10, 10);
    }

    function test_hook_canOnlyBeSetOnce() public {
        vm.expectRevert(ParticipationToken.HookAlreadySet.selector);
        units.setHook(address(0xdead));
    }

    function test_mint_respectsMaxSupply() public {
        units.mint(alice, id, 600);
        units.mint(bob, id, 400);
        assertEq(units.totalSupply(id), 1_000);
        vm.expectRevert(abi.encodeWithSelector(ParticipationToken.MaxSupplyExceeded.selector, id, 1, 0));
        units.mint(carol, id, 1);
    }

    function test_mint_onlyMinter_unknownSeries() public {
        bytes32 role = units.MINTER_ROLE();
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, role));
        units.mint(stranger, id, 1);
        vm.expectRevert(abi.encodeWithSelector(ParticipationToken.UnknownSeries.selector, 77));
        units.mint(alice, 77, 1);
    }

    function test_transfers_disabledByDefault_thenEnabled() public {
        units.mint(alice, id, 10);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ParticipationToken.TransfersDisabled.selector, id));
        units.safeTransferFrom(alice, bob, id, 5, "");

        units.setTransfersEnabled(id, true);
        vm.prank(alice);
        units.safeTransferFrom(alice, bob, id, 5, "");
        assertEq(units.balanceOf(bob, id), 5);
    }

    function test_onlySeriesAdminTogglesTransfers() public {
        vm.prank(stranger);
        vm.expectRevert();
        units.setTransfersEnabled(id, true);
    }

    function testFuzz_supplyNeverExceedsMax(uint256 a, uint256 b) public {
        a = bound(a, 0, 2_000);
        b = bound(b, 0, 2_000);
        if (a <= 1_000) units.mint(alice, id, a);
        if (units.totalSupply(id) + b <= 1_000) units.mint(bob, id, b);
        assertLe(units.totalSupply(id), 1_000);
    }

    function test_hook_zeroAddressRejected() public {
        ParticipationToken fresh = new ParticipationToken(admin, "");
        vm.expectRevert(ParticipationToken.ZeroAddress.selector);
        fresh.setHook(address(0));
    }

    function test_unknownSeries_viewsAndToggles() public {
        vm.expectRevert(abi.encodeWithSelector(ParticipationToken.UnknownSeries.selector, 404));
        units.setTransfersEnabled(404, true);
        vm.expectRevert(abi.encodeWithSelector(ParticipationToken.UnknownSeries.selector, 404));
        units.shareBpsOf(404);
        assertEq(units.shareBpsOf(id), 1_000);
    }

    function test_supportsInterface() public view {
        assertTrue(units.supportsInterface(0xd9b67a26)); // ERC-1155
        assertTrue(units.supportsInterface(0x7965db0b)); // AccessControl
        assertFalse(units.supportsInterface(0xffffffff));
    }

    function test_burn_onlyMinter() public {
        units.mint(alice, id, 10);
        vm.prank(stranger);
        vm.expectRevert();
        units.burn(alice, id, 10);
        units.burn(alice, id, 4);
        assertEq(units.totalSupply(id), 6);
    }
}
