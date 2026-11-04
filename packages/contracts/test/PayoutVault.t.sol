// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Base} from "./Base.t.sol";
import {PayoutVault} from "../contracts/PayoutVault.sol";
import {RevenueRegistry} from "../contracts/RevenueRegistry.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PayoutVaultTest is Base {
    uint256 id;

    function setUp() public override {
        super.setUp();
        // 1,000 units = 10% of eligible proceeds. Alice 600, Bob 400.
        id = _projectWithHolders(_arr(alice, bob), _nums(600, 400));
    }

    function test_entitlement_isShareOfFinalizedProceeds() public {
        _finalizedPeriod(id, PERIOD, 50_000e6);
        assertEq(vault.entitlement(id, PERIOD), 5_000e6);
        assertEq(vault.shortfall(id, PERIOD), 5_000e6);
    }

    function test_fullMonthlyPayout_proRata() public {
        _finalizedPeriod(id, PERIOD, 50_000e6);
        _fund(id, PERIOD, 5_000e6);
        assertEq(vault.shortfall(id, PERIOD), 0);
        assertEq(vault.claimable(id, alice), 3_000e6);
        assertEq(vault.claimable(id, bob), 2_000e6);

        vm.prank(alice);
        assertEq(vault.claim(id), 3_000e6);
        vm.prank(bob);
        vault.claim(id);
        assertEq(usdc.balanceOf(alice), 3_000e6);
        assertEq(usdc.balanceOf(bob), 2_000e6);
        assertEq(usdc.balanceOf(address(vault)), 0);
    }

    function test_doubleClaim_impossible() public {
        _finalizedPeriod(id, PERIOD, 50_000e6);
        _fund(id, PERIOD, 5_000e6);
        vm.startPrank(alice);
        vault.claim(id);
        vm.expectRevert(PayoutVault.NothingToClaim.selector);
        vault.claim(id);
        vm.stopPrank();
        assertEq(usdc.balanceOf(alice), 3_000e6);
    }

    function test_unfinalizedPeriod_cannotBeFunded() public {
        RevenueRegistry.RevenueReport memory r = _report(id, PERIOD, 50_000e6, 1);
        revenue.submitReport(r, _signReport(oraclePk, r));
        _mintUsdc(dev, 1e6);
        vm.startPrank(dev);
        usdc.approve(address(vault), 1e6);
        vm.expectRevert(abi.encodeWithSelector(RevenueRegistry.NotFinalized.selector, id, PERIOD));
        vault.fund(id, PERIOD, 1e6);
        vm.stopPrank();
    }

    function test_missingFunding_isShortfall_notPaid() public {
        _finalizedPeriod(id, PERIOD, 50_000e6);
        assertEq(vault.claimable(id, alice), 0, "entitlement alone is never claimable");
        _fund(id, PERIOD, 1_000e6); // developer only sent 20%
        assertEq(vault.shortfall(id, PERIOD), 4_000e6);
        assertEq(vault.claimable(id, alice), 600e6);
        assertEq(vault.claimable(id, bob), 400e6);
        _fund(id, PERIOD, 4_000e6); // later top-up
        assertEq(vault.shortfall(id, PERIOD), 0);
        assertEq(vault.claimable(id, alice), 3_000e6);
    }

    function test_overfunding_rejected() public {
        _finalizedPeriod(id, PERIOD, 50_000e6);
        _mintUsdc(dev, 5_001e6);
        vm.startPrank(dev);
        usdc.approve(address(vault), 5_001e6);
        vm.expectRevert(abi.encodeWithSelector(PayoutVault.ExceedsEntitlement.selector, 5_001e6, 5_000e6));
        vault.fund(id, PERIOD, 5_001e6);
        vm.stopPrank();
    }

    function test_noParticipants_rejected() public {
        uint256 empty = _registerProjectWithSeries("999");
        _finalizedPeriod(empty, PERIOD, 1_000e6);
        _mintUsdc(dev, 50e6); // 5% of 1,000
        vm.startPrank(dev);
        usdc.approve(address(vault), 50e6);
        vm.expectRevert(abi.encodeWithSelector(PayoutVault.NoParticipants.selector, empty));
        vault.fund(empty, PERIOD, 50e6);
        vm.stopPrank();
    }

    function _registerProjectWithSeries(string memory appleId) internal returns (uint256 pid) {
        pid = _registerProject(appleId);
        units.createSeries(pid, 100, 500);
    }

    /// Transfers across distribution record dates: accrued money stays with the seller.
    function test_transferAfterFunding_sellerKeepsAccrued_buyerGetsOnlyNew() public {
        units.setTransfersEnabled(id, true);
        _finalizedPeriod(id, PERIOD, 50_000e6);
        _fund(id, PERIOD, 5_000e6); // Alice accrued 3,000

        vm.prank(alice);
        units.safeTransferFrom(alice, carol, id, 600, ""); // Alice sells all units to Carol

        assertEq(vault.claimable(id, alice), 3_000e6);
        assertEq(vault.claimable(id, carol), 0);

        _finalizedPeriod(id, 202606, 10_000e6);
        _fund(id, 202606, 1_000e6); // next month: Carol holds 60%

        assertEq(vault.claimable(id, alice), 3_000e6);
        assertEq(vault.claimable(id, carol), 600e6);
        assertEq(vault.claimable(id, bob), 2_000e6 + 400e6);

        vm.prank(alice);
        vault.claim(id);
        vm.prank(carol);
        vault.claim(id);
        vm.prank(bob);
        vault.claim(id);
        assertEq(usdc.balanceOf(address(vault)), 0);
    }

    /// Ping-pong transfers must not mint money: total claims == total funded.
    function test_transferPingPong_noDuplicateClaims() public {
        units.setTransfersEnabled(id, true);
        _finalizedPeriod(id, PERIOD, 50_000e6);
        _fund(id, PERIOD, 5_000e6);
        for (uint256 i = 0; i < 5; ++i) {
            vm.prank(alice);
            units.safeTransferFrom(alice, carol, id, 600, "");
            vm.prank(carol);
            units.safeTransferFrom(carol, alice, id, 600, "");
        }
        assertEq(vault.claimable(id, alice), 3_000e6);
        assertEq(vault.claimable(id, carol), 0);
    }

    function test_unitsMintedAfterFunding_doNotShareEarlierPeriods() public {
        // series has 1000 max, already fully minted in setUp; use a new project
        uint256 pid = _registerProject("555");
        units.createSeries(pid, 1_000, 1_000);
        units.mint(alice, pid, 500);
        _finalizedPeriod(pid, PERIOD, 10_000e6);
        _fund(pid, PERIOD, 1_000e6);
        units.mint(bob, pid, 500); // late buyer
        assertEq(vault.claimable(pid, alice), 1_000e6);
        assertEq(vault.claimable(pid, bob), 0);
    }

    function test_rounding_holdersPaidAtMostFunded_dustStaysInVault() public {
        uint256 pid = _registerProject("777");
        units.createSeries(pid, 3, 10_000);
        units.mint(alice, pid, 1);
        units.mint(bob, pid, 1);
        units.mint(carol, pid, 1);
        _finalizedPeriod(pid, PERIOD, 100);
        _fund(pid, PERIOD, 100); // 100 base units over 3 holders
        assertEq(vault.claimable(pid, alice), 33);
        vm.prank(alice);
        vault.claim(pid);
        vm.prank(bob);
        vault.claim(pid);
        vm.prank(carol);
        vault.claim(pid);
        assertEq(usdc.balanceOf(address(vault)), 1, "1 base unit of dust remains, never paid twice");
    }

    /// Regression for a bug found by invariant_obligationsCovered: a per-funding dust counter (floored
    /// per funding) could exceed the real dust, because holder claims are floored across fundings.
    /// Sweeping it would have taken a unit Alice was owed. The counter and sweep were removed.
    function test_regression_multiFundingRounding_allHoldersCanClaim() public {
        uint256 pid = _registerProject("314159");
        units.createSeries(pid, 3, 10_000);
        units.mint(alice, pid, 2);
        units.mint(bob, pid, 1);
        _finalizedPeriod(pid, PERIOD, 1);
        _fund(pid, PERIOD, 1);
        _finalizedPeriod(pid, 202606, 1);
        _fund(pid, 202606, 1);
        assertEq(vault.claimable(pid, alice), 1); // floor(2 * 2/3)
        assertLe(vault.claimable(pid, alice) + vault.claimable(pid, bob), usdc.balanceOf(address(vault)));
        vm.prank(alice);
        assertEq(vault.claim(pid), 1);
    }

    function test_pause_blocksFundAndClaim() public {
        _finalizedPeriod(id, PERIOD, 50_000e6);
        _fund(id, PERIOD, 1_000e6);
        vault.pause();
        vm.prank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.claim(id);
        _mintUsdc(dev, 1e6);
        vm.startPrank(dev);
        usdc.approve(address(vault), 1e6);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.fund(id, PERIOD, 1e6);
        vm.stopPrank();
        vault.unpause();
        vm.prank(alice);
        vault.claim(id);
    }

    function test_checkpoint_onlyCallableByUnits() public {
        vm.prank(stranger);
        vm.expectRevert(PayoutVault.OnlyUnits.selector);
        vault.checkpoint(id, stranger);
    }

    function test_zeroFunding_rejected() public {
        _finalizedPeriod(id, PERIOD, 50_000e6);
        vm.expectRevert(PayoutVault.ZeroAmount.selector);
        vault.fund(id, PERIOD, 0);
    }

    /// Fuzz: arbitrary splits, funding amounts and a mid-way transfer never pay out more than funded.
    function testFuzz_claimsNeverExceedFunding(uint256 aUnits, uint256 f1, uint256 f2, uint256 moved) public {
        uint256 pid = _registerProject("888");
        units.createSeries(pid, 1_000_000, 10_000);
        aUnits = bound(aUnits, 1, 999_999);
        units.mint(alice, pid, aUnits);
        units.mint(bob, pid, 1_000_000 - aUnits);
        units.setTransfersEnabled(pid, true);

        f1 = bound(f1, 1, 10_000e6);
        f2 = bound(f2, 1, 10_000e6);
        _finalizedPeriod(pid, PERIOD, f1);
        _fund(pid, PERIOD, f1);
        moved = bound(moved, 0, aUnits);
        vm.prank(alice);
        units.safeTransferFrom(alice, carol, pid, moved, "");
        _finalizedPeriod(pid, 202606, f2);
        _fund(pid, 202606, f2);

        uint256 total = vault.claimable(pid, alice) + vault.claimable(pid, bob) + vault.claimable(pid, carol);
        assertLe(total, f1 + f2);
        assertLe(f1 + f2 - total, 3, "dust bounded by holder count");
    }

    function test_feeOnTransferToken_rejected() public {
        FeeToken fee = new FeeToken();
        PayoutVault v2 = new PayoutVault(admin, fee, units, revenue);
        _finalizedPeriod(id, PERIOD, 50_000e6);
        fee.mint(dev, 1_000e6);
        vm.startPrank(dev);
        fee.approve(address(v2), 1_000e6);
        vm.expectRevert(abi.encodeWithSelector(PayoutVault.UnexpectedTransferAmount.selector, 1_000e6, 990e6));
        v2.fund(id, PERIOD, 1_000e6);
        vm.stopPrank();
    }
}

/// Takes a 1% cut on every transfer, to prove the vault never books more than it received.
contract FeeToken is ERC20 {
    constructor() ERC20("Fee", "FEE") {}

    function mint(address to, uint256 a) external {
        _mint(to, a);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0)) {
            uint256 cut = value / 100;
            super._update(from, address(0xdead), cut);
            value -= cut;
        }
        super._update(from, to, value);
    }
}
