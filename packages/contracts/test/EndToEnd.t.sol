// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Base} from "./Base.t.sol";
import {CrowdfundCampaign} from "../contracts/CrowdfundCampaign.sol";
import {PredictionMarket} from "../contracts/PredictionMarket.sol";
import {PredictionOracle} from "../contracts/PredictionOracle.sol";
import {RevenueRegistry} from "../contracts/RevenueRegistry.sol";

/// Full demo scenarios matching docs/diagrams/*.mmd.
contract EndToEndTest is Base {
    function test_e2e_crowdfund_thenThreeMonthsOfRevenueShare() public {
        // 1. Register "Shred Invaders" and open a campaign: 1,000 units = 10% of eligible proceeds, $25/unit.
        uint256 id = _registerProject("1234567890");
        units.createSeries(id, 1_000, 1_000);
        CrowdfundCampaign c = new CrowdfundCampaign(usdc, units, id, dev, 25e6, 400, 1_000, uint64(T0 + 21 days));
        units.grantRole(units.MINTER_ROLE(), address(c));

        // 2. Three participants reserve units with test USDC.
        address[3] memory who = [alice, bob, carol];
        uint256[3] memory n = [uint256(500), 300, 200];
        for (uint256 i = 0; i < 3; ++i) {
            _mintUsdc(who[i], n[i] * 25e6);
            vm.startPrank(who[i]);
            usdc.approve(address(c), n[i] * 25e6);
            c.reserve(n[i]);
            vm.stopPrank();
        }
        c.finalize(); // sold out -> early success
        vm.prank(dev);
        c.withdrawProceeds();
        assertEq(usdc.balanceOf(dev), 25_000e6);
        assertEq(units.totalSupply(id), 1_000);

        // 3. Month 1: oracle attests $40,000 eligible proceeds; developer funds the full 10%.
        _finalizedPeriod(id, 202606, 40_000e6);
        _fund(id, 202606, 4_000e6);

        // 4. Month 2: report corrected for refunds before finalizing; developer underfunds.
        RevenueRegistry.RevenueReport memory v1 = _report(id, 202607, 30_000e6, 1);
        revenue.submitReport(v1, _signReport(oraclePk, v1));
        revenue.dispute(id, 202607, "refunds missing");
        RevenueRegistry.RevenueReport memory v2 = _report(id, 202607, 28_000e6, 2);
        revenue.submitReport(v2, _signReport(oraclePk, v2));
        vm.warp(block.timestamp + DISPUTE_WINDOW);
        revenue.finalize(id, 202607);
        _fund(id, 202607, 2_000e6);
        assertEq(vault.shortfall(id, 202607), 800e6);

        // 5. Alice and Bob claim; Carol waits.
        vm.prank(alice);
        assertEq(vault.claim(id), 3_000e6); // 50% of 6,000
        vm.prank(bob);
        assertEq(vault.claim(id), 1_800e6);

        // 6. Month 3, developer tops up month 2 and funds month 3.
        _fund(id, 202607, 800e6);
        _finalizedPeriod(id, 202608, 10_000e6);
        _fund(id, 202608, 1_000e6);

        vm.prank(carol);
        assertEq(vault.claim(id), 200 * (4_000e6 + 2_800e6 + 1_000e6) / 1_000);
        vm.prank(alice);
        assertEq(vault.claim(id), 500 * (800e6 + 1_000e6) / 1_000);
        vm.prank(bob);
        assertEq(vault.claim(id), 300 * (800e6 + 1_000e6) / 1_000);
        assertEq(usdc.balanceOf(address(vault)), 0);
    }

    function test_e2e_predictionMarket_chartRanking() public {
        // "Will app X enter the US iPhone Top 10 Free within 7 days?" YES=0 NO=1, 1% fee.
        PredictionMarket m = _market(2, 100);

        // Alice and Bob each mint 1,000 sets; Alice sells her NO to Bob? Positions move peer-to-peer.
        _buySets(m, alice, 1_000e6); // 990 sets
        _buySets(m, bob, 1_000e6);
        vm.prank(alice);
        m.safeTransferFrom(alice, bob, 1, 990e6, ""); // Alice: all-in YES
        vm.prank(bob);
        m.safeTransferFrom(bob, alice, 0, 990e6, ""); // Bob: all-in NO (swap)

        vm.warp(m.closeTime() + 2 hours);
        // Metrics oracle observed rank 7 in the archived Apple RSS snapshot -> YES.
        PredictionOracle.Attestation memory a = _att(m, 0, false, 1);
        predOracle.propose(a, _signAtt(reporterPk, a));
        PredictionOracle.Attestation memory b = _att(m, 0, false, 2);
        predOracle.propose(b, _signAtt(reporter2Pk, b)); // independent confirmation
        vm.warp(block.timestamp + CHALLENGE_WINDOW);
        predOracle.finalize(address(m));

        vm.prank(alice);
        assertEq(m.redeem(), 1_980e6);
        vm.prank(bob);
        vm.expectRevert(PredictionMarket.NothingToRedeem.selector);
        m.redeem();
        vm.prank(alice);
        vm.expectRevert(PredictionMarket.NothingToRedeem.selector);
        m.redeem();
        assertEq(usdc.balanceOf(address(treasury)), 20e6);
        assertEq(usdc.balanceOf(address(m)), 0);
    }
}
