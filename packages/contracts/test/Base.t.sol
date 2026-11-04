// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/src/Test.sol";
import {MockUSDC} from "../contracts/MockUSDC.sol";
import {APLOVToken} from "../contracts/APLOVToken.sol";
import {AppRegistry} from "../contracts/AppRegistry.sol";
import {ParticipationToken} from "../contracts/ParticipationToken.sol";
import {RevenueRegistry} from "../contracts/RevenueRegistry.sol";
import {PayoutVault} from "../contracts/PayoutVault.sol";
import {CrowdfundCampaign} from "../contracts/CrowdfundCampaign.sol";
import {Treasury} from "../contracts/Treasury.sol";
import {PredictionMarketFactory} from "../contracts/PredictionMarketFactory.sol";
import {PredictionMarket} from "../contracts/PredictionMarket.sol";
import {PredictionOracle} from "../contracts/PredictionOracle.sol";

/// Shared fixture: deploys and wires the full AppLove system exactly like the deploy module.
abstract contract Base is Test {
    uint64 constant T0 = 1_780_000_000; // 2026-05-28
    uint64 constant DISPUTE_WINDOW = 2 days;
    uint64 constant MAX_REPORT_AGE = 120 days;
    uint64 constant CHALLENGE_WINDOW = 1 days;
    uint64 constant MAX_SNAPSHOT_AGE = 3 days;
    uint64 constant MIN_RESOLUTION_WINDOW = 1 days;
    uint32 constant PERIOD = 202605;

    address admin = address(this);
    address dev = makeAddr("developer");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address carol = makeAddr("carol");
    address stranger = makeAddr("stranger");

    uint256 oraclePk = 0xA11CE;
    uint256 reporterPk = 0xB0B;
    uint256 reporter2Pk = 0xC0C0;
    uint256 roguePk = 0xBAD;
    address oracleSigner;
    address reporter;
    address reporter2;

    MockUSDC usdc;
    APLOVToken aplov;
    AppRegistry appRegistry;
    ParticipationToken units;
    RevenueRegistry revenue;
    PayoutVault vault;
    Treasury treasury;
    PredictionOracle predOracle;
    PredictionMarketFactory factory;

    function setUp() public virtual {
        vm.warp(T0);
        oracleSigner = vm.addr(oraclePk);
        reporter = vm.addr(reporterPk);
        reporter2 = vm.addr(reporter2Pk);

        usdc = new MockUSDC();
        aplov = new APLOVToken(admin);
        appRegistry = new AppRegistry(admin);
        units = new ParticipationToken(admin, "https://applove.example/units/{id}.json");
        revenue = new RevenueRegistry(admin, appRegistry, DISPUTE_WINDOW, MAX_REPORT_AGE);
        vault = new PayoutVault(admin, usdc, units, revenue);
        units.setHook(address(vault));
        treasury = new Treasury(admin);
        predOracle = new PredictionOracle(admin, CHALLENGE_WINDOW, MAX_SNAPSHOT_AGE);
        factory = new PredictionMarketFactory(admin, address(predOracle), address(treasury), MIN_RESOLUTION_WINDOW);
        predOracle.setFactory(factory);
        factory.setCollateralAllowed(address(usdc), true);
        factory.setCollateralAllowed(address(aplov), true);

        revenue.grantRole(revenue.ORACLE_ROLE(), oracleSigner);
        predOracle.grantRole(predOracle.REPORTER_ROLE(), reporter);
        predOracle.grantRole(predOracle.REPORTER_ROLE(), reporter2);
        units.grantRole(units.MINTER_ROLE(), admin);
    }

    /// MockUSDC caps each faucet call; tests that need more mint in chunks.
    function _mintUsdc(address to, uint256 amount) internal {
        uint256 limit = usdc.FAUCET_LIMIT();
        while (amount > 0) {
            uint256 n = amount > limit ? limit : amount;
            usdc.mint(to, n);
            amount -= n;
        }
    }

    // ------------------------------------------------------------ helpers: revenue side

    function _registerProject(string memory appleId) internal returns (uint256 id) {
        id = appRegistry.registerProject(dev, appleId, "", keccak256("meta"), keccak256("oracle-cfg"));
        appRegistry.setRevenueSharing(id, true);
    }

    /// Registers a project, creates a series (1,000 units = 10%), mints units to holders.
    function _projectWithHolders(address[] memory holders, uint256[] memory amounts) internal returns (uint256 id) {
        id = _registerProject("6741796873");
        units.createSeries(id, 1_000, 1_000);
        for (uint256 i = 0; i < holders.length; ++i) units.mint(holders[i], id, amounts[i]);
    }

    function _report(uint256 projectId, uint32 period, uint256 eligible, uint32 version)
        internal
        view
        returns (RevenueRegistry.RevenueReport memory r)
    {
        r = RevenueRegistry.RevenueReport({
            projectId: projectId,
            period: period,
            settlementCurrency: revenue.USD(),
            grossSales: eligible * 2,
            storeProceeds: eligible,
            refunds: 0,
            taxes: eligible / 10,
            eligibleProceeds: eligible,
            reportHash: keccak256(abi.encode("apple-sales-report", projectId, period, version)),
            version: version,
            issuedAt: uint64(block.timestamp)
        });
    }

    function _signReport(uint256 pk, RevenueRegistry.RevenueReport memory r) internal view returns (bytes memory) {
        (uint8 v, bytes32 rr, bytes32 s) = vm.sign(pk, revenue.hashReport(r));
        return abi.encodePacked(rr, s, v);
    }

    /// Submit + finalize a report for `eligible` USD (6 decimals).
    function _finalizedPeriod(uint256 projectId, uint32 period, uint256 eligible) internal {
        RevenueRegistry.RevenueReport memory r = _report(projectId, period, eligible, 1);
        revenue.submitReport(r, _signReport(oraclePk, r));
        vm.warp(block.timestamp + DISPUTE_WINDOW);
        revenue.finalize(projectId, period);
    }

    function _fund(uint256 projectId, uint32 period, uint256 amount) internal {
        _mintUsdc(dev, amount);
        vm.startPrank(dev);
        usdc.approve(address(vault), amount);
        vault.fund(projectId, period, amount);
        vm.stopPrank();
    }

    // ------------------------------------------------------------ helpers: prediction side

    function _params(uint8 outcomes, uint16 feeBps) internal view returns (PredictionMarketFactory.MarketParams memory) {
        return PredictionMarketFactory.MarketParams({
            termsHash: keccak256("Will app 6741796873 be in the US iPhone Top 10 Free by close?"),
            metadataURI: "https://applove.example/markets/1.json",
            outcomeCount: outcomes,
            collateral: address(usdc),
            closeTime: uint64(block.timestamp + 7 days),
            resolveBy: uint64(block.timestamp + 14 days),
            feeBps: feeBps
        });
    }

    function _market(uint8 outcomes, uint16 feeBps) internal returns (PredictionMarket) {
        return PredictionMarket(factory.createMarket(_params(outcomes, feeBps)));
    }

    function _buySets(PredictionMarket m, address who, uint256 amount) internal returns (uint256 sets) {
        _mintUsdc(who, amount);
        vm.startPrank(who);
        usdc.approve(address(m), amount);
        sets = m.mintSets(amount);
        vm.stopPrank();
    }

    function _att(PredictionMarket m, uint8 outcome, bool invalid, uint64 nonce)
        internal
        view
        returns (PredictionOracle.Attestation memory)
    {
        return PredictionOracle.Attestation({
            market: address(m),
            outcome: outcome,
            invalid: invalid,
            observedValue: 7,
            snapshotTime: uint64(block.timestamp),
            sourceHash: keccak256("apple-rss:us:top-free"),
            evidenceHash: keccak256(abi.encode("snapshot", nonce)),
            nonce: nonce
        });
    }

    function _signAtt(uint256 pk, PredictionOracle.Attestation memory a) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, predOracle.hashAttestation(a));
        return abi.encodePacked(r, s, v);
    }

    function _arr(address a) internal pure returns (address[] memory r) {
        r = new address[](1);
        r[0] = a;
    }

    function _arr(address a, address b) internal pure returns (address[] memory r) {
        r = new address[](2);
        (r[0], r[1]) = (a, b);
    }

    function _nums(uint256 a) internal pure returns (uint256[] memory r) {
        r = new uint256[](1);
        r[0] = a;
    }

    function _nums(uint256 a, uint256 b) internal pure returns (uint256[] memory r) {
        r = new uint256[](2);
        (r[0], r[1]) = (a, b);
    }
}
