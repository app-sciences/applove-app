// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/src/Test.sol";
import {Base} from "./Base.t.sol";
import {MockUSDC} from "../contracts/MockUSDC.sol";
import {ParticipationToken} from "../contracts/ParticipationToken.sol";
import {RevenueRegistry} from "../contracts/RevenueRegistry.sol";
import {PayoutVault} from "../contracts/PayoutVault.sol";
import {PredictionMarket} from "../contracts/PredictionMarket.sol";

/// Drives random funding / transfer / claim sequences against the PayoutVault.
contract VaultHandler is Test {
    MockUSDC usdc;
    ParticipationToken units;
    RevenueRegistry revenue;
    PayoutVault vault;
    uint256 oraclePk;
    uint256 public id;
    address[] public actors;
    uint256 public periodIndex;

    uint256 public ghostFunded;
    uint256 public ghostClaimed;

    constructor(MockUSDC u, ParticipationToken t, RevenueRegistry r, PayoutVault v, uint256 pk, uint256 id_, address[] memory a) {
        (usdc, units, revenue, vault, oraclePk, id) = (u, t, r, v, pk, id_);
        actors = a;
    }

    function actorCount() external view returns (uint256) {
        return actors.length;
    }

    function fundNewPeriod(uint256 eligible, uint256 fraction) external {
        eligible = bound(eligible, 1, 1_000_000e6);
        uint32 period = uint32((2026 + periodIndex / 12) * 100 + (periodIndex % 12) + 1);
        periodIndex++;
        RevenueRegistry.RevenueReport memory rep = RevenueRegistry.RevenueReport(
            id, period, "USD", eligible, eligible, 0, 0, eligible, keccak256(abi.encode(period)), 1, uint64(block.timestamp)
        );
        (uint8 v, bytes32 rr, bytes32 s) = vm.sign(oraclePk, revenue.hashReport(rep));
        revenue.submitReport(rep, abi.encodePacked(rr, s, v));
        vm.warp(block.timestamp + revenue.disputeWindow());
        revenue.finalize(id, period);

        uint256 ent = vault.entitlement(id, period);
        uint256 amount = bound(fraction, 0, ent);
        if (amount == 0) return;
        uint256 left = amount;
        while (left > 0) {
            uint256 n = left > usdc.FAUCET_LIMIT() ? usdc.FAUCET_LIMIT() : left;
            usdc.mint(address(this), n);
            left -= n;
        }
        usdc.approve(address(vault), amount);
        vault.fund(id, period, amount);
        ghostFunded += amount;
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        uint256 bal = units.balanceOf(from, id);
        amount = bound(amount, 0, bal);
        vm.prank(from);
        units.safeTransferFrom(from, to, id, amount, "");
    }

    function claim(uint256 seed) external {
        address who = actors[seed % actors.length];
        if (vault.claimable(id, who) == 0) return;
        vm.prank(who);
        ghostClaimed += vault.claim(id);
    }

}

contract VaultInvariantTest is Base {
    VaultHandler handler;
    uint256 pid;
    address[] holders;

    function setUp() public override {
        super.setUp();
        pid = _registerProject("424242");
        units.createSeries(pid, 1_000_003, 1_234);
        units.setTransfersEnabled(pid, true);
        holders.push(alice);
        holders.push(bob);
        holders.push(carol);
        holders.push(makeAddr("dave"));
        units.mint(alice, pid, 333_334);
        units.mint(bob, pid, 333_333);
        units.mint(carol, pid, 333_336);
        handler = new VaultHandler(usdc, units, revenue, vault, oraclePk, pid, holders);
        targetContract(address(handler));
    }

    /// Vault balance exactly equals funded minus everything paid out.
    function invariant_balanceMatchesLedger() public view {
        assertEq(usdc.balanceOf(address(vault)), handler.ghostFunded() - handler.ghostClaimed());
    }

    /// Everything still owed to holders is covered by funds actually held.
    function invariant_obligationsCovered() public view {
        uint256 owed;
        for (uint256 i = 0; i < holders.length; ++i) owed += vault.claimable(pid, holders[i]);
        assertLe(owed, usdc.balanceOf(address(vault)));
    }

    function invariant_neverPaysMoreThanFunded() public view {
        assertLe(handler.ghostClaimed(), handler.ghostFunded());
        assertEq(vault.totalClaimed(pid), handler.ghostClaimed());
    }

    function invariant_unitSupplyConstant() public view {
        assertEq(units.totalSupply(pid), 1_000_003);
    }
}

/// Drives random mint / merge / transfer / settle / redeem sequences against one market.
contract MarketHandler is Test {
    MockUSDC usdc;
    PredictionMarket public m;
    address oracle;
    address[] actors;
    uint256 public ghostDeposited;
    uint256 public ghostFees;
    uint256 public ghostPaidOut;

    constructor(MockUSDC u, PredictionMarket m_, address oracle_, address[] memory a) {
        (usdc, m, oracle) = (u, m_, oracle_);
        actors = a;
    }

    function mintSets(uint256 seed, uint256 amount) external {
        if (m.state() != PredictionMarket.State.Open || block.timestamp >= m.closeTime()) return;
        address who = actors[seed % actors.length];
        amount = bound(amount, 1, usdc.FAUCET_LIMIT());
        if (amount * m.feeBps() / 10_000 == amount) return;
        usdc.mint(who, amount);
        vm.startPrank(who);
        usdc.approve(address(m), amount);
        uint256 sets = m.mintSets(amount);
        vm.stopPrank();
        ghostDeposited += amount;
        ghostFees += amount - sets;
    }

    function merge(uint256 seed, uint256 amount) external {
        if (m.state() != PredictionMarket.State.Open) return;
        address who = actors[seed % actors.length];
        uint256 maxSets = type(uint256).max;
        for (uint256 i = 0; i < m.outcomeCount(); ++i) {
            uint256 b = m.balanceOf(who, i);
            if (b < maxSets) maxSets = b;
        }
        if (maxSets == 0) return;
        amount = bound(amount, 1, maxSets);
        vm.prank(who);
        m.mergeSets(amount);
        ghostPaidOut += amount;
    }

    function transfer(uint256 a, uint256 b, uint256 outcome, uint256 amount) external {
        address from = actors[a % actors.length];
        address to = actors[b % actors.length];
        outcome = outcome % m.outcomeCount();
        amount = bound(amount, 0, m.balanceOf(from, outcome));
        vm.prank(from);
        m.safeTransferFrom(from, to, outcome, amount, "");
    }

    function settle(uint256 outcome, bool cancelIt) external {
        if (m.state() != PredictionMarket.State.Open) return;
        if (block.timestamp < m.closeTime()) vm.warp(m.closeTime());
        vm.prank(oracle);
        if (cancelIt) m.cancel();
        else m.resolve(uint8(outcome % m.outcomeCount()));
    }

    function redeem(uint256 seed) external {
        if (m.state() == PredictionMarket.State.Open) return;
        address who = actors[seed % actors.length];
        vm.prank(who);
        try m.redeem() returns (uint256 p) {
            ghostPaidOut += p;
        } catch {}
    }
}

contract MarketInvariantTest is Base {
    MarketHandler handler;
    PredictionMarket m;
    address[] traders;

    function setUp() public override {
        super.setUp();
        m = _market(3, 200);
        traders.push(alice);
        traders.push(bob);
        traders.push(carol);
        handler = new MarketHandler(usdc, m, address(predOracle), traders);
        targetContract(address(handler));
    }

    function invariant_collateralCoversLocked() public view {
        assertGe(usdc.balanceOf(address(m)), m.lockedCollateral());
    }

    function invariant_conservationOfCollateral() public view {
        assertEq(
            usdc.balanceOf(address(m)),
            handler.ghostDeposited() - handler.ghostFees() - handler.ghostPaidOut()
        );
        assertEq(usdc.balanceOf(address(treasury)), handler.ghostFees());
    }

    function invariant_outcomeSupplyBacked() public view {
        uint256 locked = m.lockedCollateral();
        if (m.state() == PredictionMarket.State.Open) {
            for (uint256 i = 0; i < 3; ++i) assertEq(m.totalSupply(i), locked);
        } else if (m.state() == PredictionMarket.State.Resolved) {
            assertEq(m.totalSupply(m.winningOutcome()), locked);
        } else {
            uint256 total;
            for (uint256 i = 0; i < 3; ++i) total += m.totalSupply(i);
            assertGe(locked, total / 3);
        }
    }
}
