// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Base} from "./Base.t.sol";
import {CrowdfundCampaign} from "../contracts/CrowdfundCampaign.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

contract ReentrantReserver is IERC1155Receiver {
    CrowdfundCampaign public campaign;
    uint256 public reentryAttempts;
    bool public reentrySucceeded;

    function setCampaign(CrowdfundCampaign c) external {
        campaign = c;
    }

    function reserve(uint256 n) external {
        campaign.paymentToken().approve(address(campaign), type(uint256).max);
        campaign.reserve(n);
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external returns (bytes4) {
        reentryAttempts++;
        try campaign.reserve(1) {
            reentrySucceeded = true;
        } catch {}
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }
}

contract CrowdfundCampaignTest is Base {
    uint256 id;
    CrowdfundCampaign c;
    uint256 constant PRICE = 50e6; // 50 mUSDC per unit

    function setUp() public override {
        super.setUp();
        id = _registerProject("1");
        units.createSeries(id, 1_000, 1_000);
        c = new CrowdfundCampaign(usdc, units, id, dev, PRICE, 200, 1_000, uint64(T0 + 30 days));
        units.grantRole(units.MINTER_ROLE(), address(c));
    }

    function _reserve(address who, uint256 n) internal {
        _mintUsdc(who, n * PRICE);
        vm.startPrank(who);
        usdc.approve(address(c), n * PRICE);
        c.reserve(n);
        vm.stopPrank();
    }

    function test_constructor_validates() public {
        vm.expectRevert(CrowdfundCampaign.InvalidParams.selector);
        new CrowdfundCampaign(usdc, units, 42, dev, PRICE, 1, 1, uint64(T0 + 1)); // unknown series
        vm.expectRevert(CrowdfundCampaign.InvalidParams.selector);
        new CrowdfundCampaign(usdc, units, id, dev, PRICE, 10, 5, uint64(T0 + 1)); // cap < goal
        vm.expectRevert(CrowdfundCampaign.InvalidParams.selector);
        new CrowdfundCampaign(usdc, units, id, dev, PRICE, 1, 1_001, uint64(T0 + 1)); // cap > max supply
        vm.expectRevert(CrowdfundCampaign.InvalidParams.selector);
        new CrowdfundCampaign(usdc, units, id, dev, PRICE, 1, 1, uint64(T0)); // deadline not in future
    }

    function test_success_unitsIssuedAtReservation_developerWithdrawsOnce() public {
        _reserve(alice, 150);
        _reserve(bob, 100);
        assertEq(units.balanceOf(alice, id), 150);
        assertEq(units.totalSupply(id), c.unitsSold());
        vm.expectRevert(CrowdfundCampaign.NotEnded.selector);
        c.finalize();
        vm.warp(T0 + 30 days);
        c.finalize();
        assertEq(uint8(c.state()), uint8(CrowdfundCampaign.State.Succeeded));

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(CrowdfundCampaign.WrongState.selector, CrowdfundCampaign.State.Failed, CrowdfundCampaign.State.Succeeded)
        );
        c.refund();

        vm.prank(stranger);
        vm.expectRevert(CrowdfundCampaign.NotDeveloper.selector);
        c.withdrawProceeds();
        vm.prank(dev);
        c.withdrawProceeds();
        assertEq(usdc.balanceOf(dev), 250 * PRICE);
        vm.prank(dev);
        vm.expectRevert(CrowdfundCampaign.AlreadyWithdrawn.selector);
        c.withdrawProceeds();
    }

    /// Regression for a manual-review finding: units used to be minted lazily on claimUnits(), so a
    /// revenue period funded before everyone claimed was split over a partial supply and early
    /// claimers took late claimers' share. Units now exist from the moment they are paid for.
    function test_regression_revenueSplitCoversEveryContributor() public {
        _reserve(alice, 500);
        _reserve(bob, 500);
        c.finalize(); // sold out
        _finalizedPeriod(id, 202606, 10_000e6);
        _fund(id, 202606, 1_000e6);
        assertEq(vault.claimable(id, alice), 500e6);
        assertEq(vault.claimable(id, bob), 500e6);
    }

    function test_reserve_rejectedWhileSeriesTransferable() public {
        units.setTransfersEnabled(id, true);
        _mintUsdc(alice, PRICE);
        vm.startPrank(alice);
        usdc.approve(address(c), PRICE);
        vm.expectRevert(CrowdfundCampaign.SeriesTransferable.selector);
        c.reserve(1);
        vm.stopPrank();
    }

    function test_failure_refundsExactlyOnce() public {
        _reserve(alice, 100);
        vm.warp(T0 + 30 days);
        c.finalize();
        assertEq(uint8(c.state()), uint8(CrowdfundCampaign.State.Failed));
        assertEq(units.balanceOf(alice, id), 100);
        vm.prank(alice);
        c.refund();
        assertEq(usdc.balanceOf(alice), 100 * PRICE);
        assertEq(units.balanceOf(alice, id), 0, "units burned on refund");
        assertEq(units.totalSupply(id), 0);
        vm.prank(alice);
        vm.expectRevert(CrowdfundCampaign.NothingToClaim.selector);
        c.refund();
        vm.prank(dev);
        vm.expectRevert(
            abi.encodeWithSelector(CrowdfundCampaign.WrongState.selector, CrowdfundCampaign.State.Succeeded, CrowdfundCampaign.State.Failed)
        );
        c.withdrawProceeds();
    }

    function test_deadlineAndCapEnforced() public {
        _reserve(alice, 900);
        _mintUsdc(bob, 101 * PRICE);
        vm.startPrank(bob);
        usdc.approve(address(c), 101 * PRICE);
        vm.expectRevert(abi.encodeWithSelector(CrowdfundCampaign.CapExceeded.selector, 101, 100));
        c.reserve(101);
        vm.stopPrank();

        vm.warp(T0 + 30 days);
        _mintUsdc(carol, PRICE);
        vm.startPrank(carol);
        usdc.approve(address(c), PRICE);
        vm.expectRevert(CrowdfundCampaign.DeadlinePassed.selector);
        c.reserve(1);
        vm.stopPrank();
    }

    function test_soldOut_canFinalizeEarly() public {
        _reserve(alice, 1_000);
        c.finalize();
        assertEq(uint8(c.state()), uint8(CrowdfundCampaign.State.Succeeded));
    }

    function test_zeroReservation_reverts() public {
        vm.expectRevert(CrowdfundCampaign.ZeroAmount.selector);
        c.reserve(0);
    }

    function test_insufficientAllowance_reverts() public {
        _mintUsdc(alice, PRICE);
        vm.prank(alice);
        vm.expectRevert();
        c.reserve(1);
        assertEq(c.unitsSold(), 0);
    }

    function test_reentrantReserve_blocked() public {
        ReentrantReserver attacker = new ReentrantReserver();
        attacker.setCampaign(c);
        _mintUsdc(address(attacker), 301 * PRICE);
        attacker.reserve(300);
        assertEq(attacker.reentryAttempts(), 1);
        assertFalse(attacker.reentrySucceeded());
        assertEq(units.balanceOf(address(attacker), id), 300);
        assertEq(c.unitsSold(), 300);
    }

    function testFuzz_escrowConservation(uint256 a, uint256 b, bool succeed) public {
        a = bound(a, 1, 500);
        b = bound(b, 1, 500);
        _reserve(alice, a);
        _reserve(bob, b);
        assertEq(usdc.balanceOf(address(c)), (a + b) * PRICE);
        assertEq(units.totalSupply(id), a + b);
        vm.warp(T0 + 30 days);
        if (!succeed && a + b >= 200) return; // goal reached; failure path not reachable
        c.finalize();
        if (c.state() == CrowdfundCampaign.State.Succeeded) {
            vm.prank(dev);
            c.withdrawProceeds();
            assertEq(usdc.balanceOf(dev), (a + b) * PRICE);
        } else {
            vm.prank(alice);
            c.refund();
            vm.prank(bob);
            c.refund();
            assertEq(usdc.balanceOf(alice) + usdc.balanceOf(bob), (a + b) * PRICE);
            assertEq(units.totalSupply(id), 0);
        }
        assertEq(usdc.balanceOf(address(c)), 0);
    }
}
