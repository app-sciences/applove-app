// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Base} from "./Base.t.sol";
import {PredictionMarket} from "../contracts/PredictionMarket.sol";
import {PredictionOracle} from "../contracts/PredictionOracle.sol";

contract PredictionOracleTest is Base {
    PredictionMarket m;

    function setUp() public override {
        super.setUp();
        m = _market(2, 0);
        _buySets(m, alice, 100e6);
    }

    function _propose(uint256 pk, uint8 outcome, bool invalid, uint64 nonce) internal {
        PredictionOracle.Attestation memory a = _att(m, outcome, invalid, nonce);
        predOracle.propose(a, _signAtt(pk, a));
    }

    function test_happyPath_proposeChallengeWindowFinalize() public {
        vm.warp(m.closeTime() + 1 hours);
        _propose(reporterPk, 0, false, 1);
        vm.expectRevert(
            abi.encodeWithSelector(PredictionOracle.ChallengeWindowOpen.selector, uint64(block.timestamp) + CHALLENGE_WINDOW)
        );
        predOracle.finalize(address(m));
        vm.warp(block.timestamp + CHALLENGE_WINDOW);
        vm.prank(stranger);
        predOracle.finalize(address(m));
        assertEq(uint8(m.state()), uint8(PredictionMarket.State.Resolved));
        assertEq(m.winningOutcome(), 0);
    }

    function test_invalidSignature_rejected() public {
        vm.warp(m.closeTime());
        PredictionOracle.Attestation memory a = _att(m, 0, false, 1);
        bytes memory sig = _signAtt(roguePk, a);
        vm.expectRevert(abi.encodeWithSelector(PredictionOracle.UnauthorizedReporter.selector, vm.addr(roguePk)));
        predOracle.propose(a, sig);
    }

    function test_replay_rejected() public {
        vm.warp(m.closeTime());
        PredictionOracle.Attestation memory a = _att(m, 0, false, 1);
        bytes memory sig = _signAtt(reporterPk, a);
        predOracle.propose(a, sig);
        vm.expectRevert(PredictionOracle.ReplayedAttestation.selector);
        predOracle.propose(a, sig);
    }

    function test_unknownMarket_rejected() public {
        PredictionMarket fake = new PredictionMarket(9, usdc, address(predOracle), address(treasury), uint64(T0 + 1), uint64(T0 + 2 days), 0, 2, keccak256("x"), "");
        vm.warp(T0 + 10);
        PredictionOracle.Attestation memory a = _att(fake, 0, false, 1);
        bytes memory sig = _signAtt(reporterPk, a);
        vm.expectRevert(abi.encodeWithSelector(PredictionOracle.UnknownMarket.selector, address(fake)));
        predOracle.propose(a, sig);
    }

    function test_snapshotTiming_enforced() public {
        // snapshot taken before the market closed is not evidence of the outcome
        PredictionOracle.Attestation memory a = _att(m, 0, false, 1);
        bytes memory sig = _signAtt(reporterPk, a);
        vm.expectRevert(PredictionOracle.SnapshotBeforeClose.selector);
        predOracle.propose(a, sig);

        vm.warp(m.closeTime());
        a = _att(m, 0, false, 2);
        a.snapshotTime = uint64(block.timestamp + 1);
        sig = _signAtt(reporterPk, a);
        vm.expectRevert(PredictionOracle.SnapshotFromFuture.selector);
        predOracle.propose(a, sig);

        a = _att(m, 0, false, 3);
        vm.warp(block.timestamp + MAX_SNAPSHOT_AGE + 1);
        sig = _signAtt(reporterPk, a);
        vm.expectRevert(PredictionOracle.SnapshotTooOld.selector);
        predOracle.propose(a, sig);
    }

    function test_conflictingAttestations_forceDispute() public {
        vm.warp(m.closeTime());
        _propose(reporterPk, 0, false, 1);
        _propose(reporter2Pk, 1, false, 2); // second reporter disagrees
        (PredictionOracle.Status st,,,,,,) = predOracle.proposals(address(m));
        assertEq(uint8(st), uint8(PredictionOracle.Status.Disputed));
        vm.warp(block.timestamp + CHALLENGE_WINDOW);
        vm.expectRevert(abi.encodeWithSelector(PredictionOracle.WrongStatus.selector, PredictionOracle.Status.Disputed));
        predOracle.finalize(address(m));

        vm.prank(stranger);
        vm.expectRevert();
        predOracle.resolveDispute(address(m), 1, false);
        predOracle.resolveDispute(address(m), 1, false);
        assertEq(m.winningOutcome(), 1);
    }

    function test_matchingSecondAttestation_confirms() public {
        vm.warp(m.closeTime());
        _propose(reporterPk, 1, false, 1);
        _propose(reporter2Pk, 1, false, 2);
        (PredictionOracle.Status st,,,,,,) = predOracle.proposals(address(m));
        assertEq(uint8(st), uint8(PredictionOracle.Status.Proposed));
    }

    function test_challenge_permissionsAndWindow() public {
        vm.warp(m.closeTime());
        _propose(reporterPk, 0, false, 1);
        vm.prank(stranger);
        vm.expectRevert();
        predOracle.challenge(address(m), "x");
        vm.warp(block.timestamp + CHALLENGE_WINDOW);
        vm.expectRevert(PredictionOracle.ChallengeWindowClosed.selector);
        predOracle.challenge(address(m), "late");
    }

    function test_challenge_thenArbiterCancels_refunds() public {
        vm.warp(m.closeTime());
        _propose(reporterPk, 0, false, 1);
        predOracle.challenge(address(m), "Apple feed revised");
        predOracle.resolveDispute(address(m), 0, true); // data unreliable -> cancel
        assertEq(uint8(m.state()), uint8(PredictionMarket.State.Cancelled));
        vm.prank(alice);
        assertEq(m.redeem(), 100e6);
    }

    function test_invalidAttestation_cancelsAfterWindow() public {
        vm.warp(m.closeTime());
        _propose(reporterPk, 0, true, 1); // missing data
        vm.warp(block.timestamp + CHALLENGE_WINDOW);
        predOracle.finalize(address(m));
        assertEq(uint8(m.state()), uint8(PredictionMarket.State.Cancelled));
    }

    function test_noNewAttestationsAfterFinal() public {
        vm.warp(m.closeTime());
        _propose(reporterPk, 0, false, 1);
        vm.warp(block.timestamp + CHALLENGE_WINDOW);
        predOracle.finalize(address(m));
        PredictionOracle.Attestation memory a = _att(m, 1, false, 9);
        bytes memory sig = _signAtt(reporter2Pk, a);
        vm.expectRevert(abi.encodeWithSelector(PredictionOracle.WrongStatus.selector, PredictionOracle.Status.Final));
        predOracle.propose(a, sig);
    }

    function test_lateConflictAfterWindow_rejected() public {
        vm.warp(m.closeTime());
        _propose(reporterPk, 0, false, 1);
        vm.warp(block.timestamp + CHALLENGE_WINDOW);
        PredictionOracle.Attestation memory a = _att(m, 1, false, 2);
        a.snapshotTime = m.closeTime();
        bytes memory sig = _signAtt(reporter2Pk, a);
        vm.expectRevert(PredictionOracle.ChallengeWindowClosed.selector);
        predOracle.propose(a, sig);
    }

    function test_factory_canOnlyBeSetOnce() public {
        vm.expectRevert(PredictionOracle.FactoryAlreadySet.selector);
        predOracle.setFactory(factory);
    }

    function test_finalizeOrArbitrate_wrongStatus() public {
        vm.expectRevert(abi.encodeWithSelector(PredictionOracle.WrongStatus.selector, PredictionOracle.Status.None));
        predOracle.finalize(address(m));
        vm.expectRevert(abi.encodeWithSelector(PredictionOracle.WrongStatus.selector, PredictionOracle.Status.None));
        predOracle.resolveDispute(address(m), 0, false);
        vm.expectRevert(abi.encodeWithSelector(PredictionOracle.WrongStatus.selector, PredictionOracle.Status.None));
        predOracle.challenge(address(m), "x");
    }

    /// If the oracle is too slow and anyone cancels after resolveBy, a late finalize cannot resolve it.
    function test_finalizeAfterPublicCancel_reverts_marketStaysRefundable() public {
        vm.warp(m.resolveBy() - 1);
        PredictionOracle.Attestation memory a = _att(m, 0, false, 1);
        predOracle.propose(a, _signAtt(reporterPk, a));
        vm.warp(m.resolveBy() + 1);
        vm.prank(stranger);
        m.cancel();
        vm.warp(block.timestamp + CHALLENGE_WINDOW);
        vm.expectRevert();
        predOracle.finalize(address(m));
        vm.prank(alice);
        assertEq(m.redeem(), 100e6);
    }
}
