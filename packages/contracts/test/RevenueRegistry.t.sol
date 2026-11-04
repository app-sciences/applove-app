// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Base} from "./Base.t.sol";
import {RevenueRegistry} from "../contracts/RevenueRegistry.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract RevenueRegistryTest is Base {
    uint256 id;

    function setUp() public override {
        super.setUp();
        id = _registerProject("1");
    }

    function _submit(RevenueRegistry.RevenueReport memory r) internal {
        revenue.submitReport(r, _signReport(oraclePk, r));
    }

    function test_validReport_isPendingThenFinalizable() public {
        RevenueRegistry.RevenueReport memory r = _report(id, PERIOD, 5_000e6, 1);
        vm.expectEmit(true, true, false, true);
        emit RevenueRegistry.ReportSubmitted(id, PERIOD, 1, r.reportHash, 5_000e6, oracleSigner, T0 + DISPUTE_WINDOW);
        vm.prank(stranger); // anyone can relay a signed report
        revenue.submitReport(r, _signReport(oraclePk, r));

        RevenueRegistry.Record memory rec = revenue.getRecord(id, PERIOD);
        assertEq(uint8(rec.status), uint8(RevenueRegistry.Status.Pending));
        assertEq(rec.signer, oracleSigner);

        vm.expectRevert(abi.encodeWithSelector(RevenueRegistry.NotFinalized.selector, id, PERIOD));
        revenue.finalizedEligibleProceeds(id, PERIOD);
        vm.expectRevert(abi.encodeWithSelector(RevenueRegistry.ChallengeWindowOpen.selector, T0 + DISPUTE_WINDOW));
        revenue.finalize(id, PERIOD);

        vm.warp(T0 + DISPUTE_WINDOW);
        revenue.finalize(id, PERIOD);
        assertEq(revenue.finalizedEligibleProceeds(id, PERIOD), 5_000e6);
    }

    function test_invalidSignature_rejected() public {
        RevenueRegistry.RevenueReport memory r = _report(id, PERIOD, 5_000e6, 1);
        bytes memory rogueSig = _signReport(roguePk, r);
        vm.expectRevert(abi.encodeWithSelector(RevenueRegistry.UnauthorizedSigner.selector, vm.addr(roguePk)));
        revenue.submitReport(r, rogueSig);
    }

    function test_tamperedReport_rejected() public {
        RevenueRegistry.RevenueReport memory r = _report(id, PERIOD, 5_000e6, 1);
        bytes memory sig = _signReport(oraclePk, r);
        r.eligibleProceeds = 4_999e6; // altered after signing: recovers to a different address
        vm.expectRevert();
        revenue.submitReport(r, sig);
    }

    function test_malformedSignature_rejected() public {
        RevenueRegistry.RevenueReport memory r = _report(id, PERIOD, 5_000e6, 1);
        vm.expectRevert(abi.encodeWithSelector(ECDSA.ECDSAInvalidSignatureLength.selector, 3));
        revenue.submitReport(r, hex"010203");
    }

    function test_replay_rejected() public {
        RevenueRegistry.RevenueReport memory r = _report(id, PERIOD, 5_000e6, 1);
        bytes memory sig = _signReport(oraclePk, r);
        revenue.submitReport(r, sig);
        vm.expectRevert(RevenueRegistry.ReplayedReport.selector);
        revenue.submitReport(r, sig);
    }

    function test_revokedSigner_rejected() public {
        revenue.revokeRole(revenue.ORACLE_ROLE(), oracleSigner);
        RevenueRegistry.RevenueReport memory r = _report(id, PERIOD, 1e6, 1);
        bytes memory sig = _signReport(oraclePk, r);
        vm.expectRevert(abi.encodeWithSelector(RevenueRegistry.UnauthorizedSigner.selector, oracleSigner));
        revenue.submitReport(r, sig);
    }

    function test_correction_higherVersionSupersedesAndResetsWindow() public {
        _submit(_report(id, PERIOD, 5_000e6, 1));
        vm.warp(T0 + 1 days);
        RevenueRegistry.RevenueReport memory v2 = _report(id, PERIOD, 4_200e6, 2); // refunds discovered
        _submit(v2);
        RevenueRegistry.Record memory rec = revenue.getRecord(id, PERIOD);
        assertEq(rec.report.version, 2);
        assertEq(rec.report.eligibleProceeds, 4_200e6);
        assertEq(rec.challengeEnds, T0 + 1 days + DISPUTE_WINDOW);
    }

    function test_staleVersion_rejected() public {
        _submit(_report(id, PERIOD, 5_000e6, 2));
        RevenueRegistry.RevenueReport memory v1 = _report(id, PERIOD, 9_999e6, 1);
        bytes memory sig = _signReport(oraclePk, v1);
        vm.expectRevert(abi.encodeWithSelector(RevenueRegistry.StaleVersion.selector, 2, 1));
        revenue.submitReport(v1, sig);
        RevenueRegistry.RevenueReport memory same = _report(id, PERIOD, 1e6, 2);
        sig = _signReport(oraclePk, same);
        vm.expectRevert(abi.encodeWithSelector(RevenueRegistry.StaleVersion.selector, 2, 2));
        revenue.submitReport(same, sig);
    }

    function test_finalized_isImmutable() public {
        _finalizedPeriod(id, PERIOD, 5_000e6);
        RevenueRegistry.RevenueReport memory v2 = _report(id, PERIOD, 1e6, 2);
        bytes memory sig = _signReport(oraclePk, v2);
        vm.expectRevert(RevenueRegistry.AlreadyFinalized.selector);
        revenue.submitReport(v2, sig);
    }

    function test_dispute_blocksFinalize_untilCorrected() public {
        _submit(_report(id, PERIOD, 5_000e6, 1));
        revenue.dispute(id, PERIOD, "refund mismatch");
        vm.warp(T0 + DISPUTE_WINDOW + 1);
        vm.expectRevert(RevenueRegistry.NotPending.selector);
        revenue.finalize(id, PERIOD);

        _submit(_report(id, PERIOD, 4_000e6, 2));
        vm.warp(block.timestamp + DISPUTE_WINDOW);
        revenue.finalize(id, PERIOD);
        assertEq(revenue.finalizedEligibleProceeds(id, PERIOD), 4_000e6);
    }

    function test_dispute_permissionsAndWindow() public {
        _submit(_report(id, PERIOD, 5_000e6, 1));
        vm.prank(stranger);
        vm.expectRevert();
        revenue.dispute(id, PERIOD, "x");
        vm.warp(T0 + DISPUTE_WINDOW);
        vm.expectRevert(RevenueRegistry.ChallengeWindowClosed.selector);
        revenue.dispute(id, PERIOD, "late");
        vm.expectRevert(RevenueRegistry.NotPending.selector);
        revenue.dispute(id, 202601, "none");
    }

    function test_validation_rules() public {
        RevenueRegistry.RevenueReport memory r;
        bytes memory sig;

        r = _report(id, 202613, 1e6, 1);
        sig = _signReport(oraclePk, r);
        vm.expectRevert(abi.encodeWithSelector(RevenueRegistry.InvalidPeriod.selector, 202613));
        revenue.submitReport(r, sig);

        r = _report(id, PERIOD, 1e6, 1);
        r.settlementCurrency = "EUR";
        sig = _signReport(oraclePk, r);
        vm.expectRevert(abi.encodeWithSelector(RevenueRegistry.UnsupportedCurrency.selector, bytes32("EUR")));
        revenue.submitReport(r, sig);

        r = _report(id, PERIOD, 1e6, 1);
        r.eligibleProceeds = r.storeProceeds + 1;
        sig = _signReport(oraclePk, r);
        vm.expectRevert(RevenueRegistry.InconsistentAmounts.selector);
        revenue.submitReport(r, sig);

        r = _report(id, PERIOD, 1e6, 1);
        r.issuedAt = uint64(block.timestamp + 1);
        sig = _signReport(oraclePk, r);
        vm.expectRevert(RevenueRegistry.ReportFromFuture.selector);
        revenue.submitReport(r, sig);

        r = _report(id, PERIOD, 1e6, 1);
        r.issuedAt = uint64(block.timestamp - MAX_REPORT_AGE - 1);
        sig = _signReport(oraclePk, r);
        vm.expectRevert(RevenueRegistry.ReportTooOld.selector);
        revenue.submitReport(r, sig);
    }

    function test_projectMustHaveRevenueSharingEnabled() public {
        uint256 other = appRegistry.registerProject(dev, "2", "", 0, 0);
        RevenueRegistry.RevenueReport memory r = _report(other, PERIOD, 1e6, 1);
        bytes memory sig = _signReport(oraclePk, r);
        vm.expectRevert(abi.encodeWithSelector(RevenueRegistry.ProjectNotEligible.selector, other));
        revenue.submitReport(r, sig);
    }

    function test_signatureBoundToThisChainAndContract() public {
        RevenueRegistry other = new RevenueRegistry(admin, appRegistry, DISPUTE_WINDOW, MAX_REPORT_AGE);
        other.grantRole(other.ORACLE_ROLE(), oracleSigner);
        RevenueRegistry.RevenueReport memory r = _report(id, PERIOD, 1e6, 1);
        bytes memory sigForMain = _signReport(oraclePk, r);
        vm.expectRevert(); // EIP-712 domain separator differs -> different recovered signer
        other.submitReport(r, sigForMain);
    }
}
