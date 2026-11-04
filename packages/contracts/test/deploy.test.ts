import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { network } from "hardhat";
import { keccak256, toHex, parseUnits, zeroAddress } from "viem";
import AppLoveModule from "../ignition/modules/AppLove.js";

/**
 * Integration test: deploys with the SAME Ignition module used for Base Sepolia, then runs a
 * prediction market end to end through viem, signing the oracle attestation as the backend would.
 */
describe("AppLove deployment module", async () => {
  const { ignition, viem, networkHelpers } = await network.create();
  const [deployer, alice, reporterWallet] = await viem.getWalletClients();
  const publicClient = await viem.getPublicClient();

  const c = await ignition.deploy(AppLoveModule, {
    parameters: { AppLove: { reporter: reporterWallet.account.address } },
  });

  it("wires every contract correctly", async () => {
    assert.equal((await c.units.read.hook()).toLowerCase(), c.vault.address.toLowerCase());
    assert.equal((await c.predOracle.read.factory()).toLowerCase(), c.factory.address.toLowerCase());
    assert.equal(await c.factory.read.allowedCollateral([c.usdc.address]), true);
    assert.equal(await c.factory.read.allowedCollateral([c.aplov.address]), true);
    const REPORTER = await c.predOracle.read.REPORTER_ROLE();
    assert.equal(await c.predOracle.read.hasRole([REPORTER, reporterWallet.account.address]), true);
    const ORACLE = await c.revenue.read.ORACLE_ROLE();
    assert.equal(await c.revenue.read.hasRole([ORACLE, deployer.account.address]), true);
    assert.equal(await c.usdc.read.decimals(), 6);
    assert.equal(await c.aplov.read.symbol(), "tAPLOV");
  });

  it("refuses to re-wire one-time hooks", async () => {
    await assert.rejects(c.units.write.setHook([zeroAddress]));
    await assert.rejects(c.predOracle.write.setFactory([c.factory.address]));
  });

  it("runs a market end to end with an EIP-712 signed attestation", async () => {
    const now = BigInt(await networkHelpers.time.latest());
    await c.factory.write.createMarket([
      {
        termsHash: keccak256(toHex("US iPhone Top 10 Free within 7 days?")),
        metadataURI: "ipfs://demo",
        outcomeCount: 2,
        collateral: c.usdc.address,
        closeTime: now + 7n * 86400n,
        resolveBy: now + 14n * 86400n,
        feeBps: 100,
      },
    ]);
    const marketAddr = await c.factory.read.markets([0n]);
    const market = await viem.getContractAt("PredictionMarket", marketAddr);

    const amount = parseUnits("1000", 6);
    await c.usdc.write.mint([alice.account.address, amount]);
    await c.usdc.write.approve([marketAddr, amount], { account: alice.account });
    await market.write.mintSets([amount], { account: alice.account });
    assert.equal(await market.read.balanceOf([alice.account.address, 0n]), parseUnits("990", 6));

    await networkHelpers.time.increase(7 * 86400 + 60);
    const snapshotTime = BigInt(await networkHelpers.time.latest());
    const attestation = {
      market: marketAddr,
      outcome: 0,
      invalid: false,
      observedValue: 7n,
      snapshotTime,
      sourceHash: keccak256(toHex("apple-rss:us:top-free")),
      evidenceHash: keccak256(toHex("archived snapshot bytes")),
      nonce: 1n,
    };
    const chainId = await publicClient.getChainId();
    const signature = await reporterWallet.signTypedData({
      domain: { name: "AppLove PredictionOracle", version: "1", chainId, verifyingContract: c.predOracle.address },
      types: {
        Attestation: [
          { name: "market", type: "address" },
          { name: "outcome", type: "uint8" },
          { name: "invalid", type: "bool" },
          { name: "observedValue", type: "int256" },
          { name: "snapshotTime", type: "uint64" },
          { name: "sourceHash", type: "bytes32" },
          { name: "evidenceHash", type: "bytes32" },
          { name: "nonce", type: "uint64" },
        ],
      },
      primaryType: "Attestation",
      message: attestation,
    });
    // Off-chain signer (viem) and on-chain hash (EIP712) must agree, or every real report would fail.
    await c.predOracle.write.propose([attestation, signature], { account: alice.account });
    await networkHelpers.time.increase(86400);
    await c.predOracle.write.finalize([marketAddr]);
    assert.equal(await market.read.state(), 1); // Resolved

    const before = await c.usdc.read.balanceOf([alice.account.address]);
    await market.write.redeem({ account: alice.account });
    const after = await c.usdc.read.balanceOf([alice.account.address]);
    assert.equal(after - before, parseUnits("990", 6));
  });

  it("accepts a viem-signed revenue report and pays holders", async () => {
    await c.appRegistry.write.registerProject([deployer.account.address, "1234567890", "", keccak256(toHex("m")), keccak256(toHex("o"))]);
    await c.appRegistry.write.setRevenueSharing([1n, true]);
    await c.units.write.createSeries([1n, 1000n, 1000]);
    const MINTER = await c.units.read.MINTER_ROLE();
    await c.units.write.grantRole([MINTER, deployer.account.address]);
    await c.units.write.mint([alice.account.address, 1n, 1000n]);

    const issuedAt = BigInt(await networkHelpers.time.latest());
    const report = {
      projectId: 1n,
      period: 202606,
      settlementCurrency: toHex("USD", { size: 32 }),
      grossSales: parseUnits("20000", 6),
      storeProceeds: parseUnits("14000", 6),
      refunds: parseUnits("300", 6),
      taxes: parseUnits("1200", 6),
      eligibleProceeds: parseUnits("12500", 6),
      reportHash: keccak256(toHex("apple-financial-report-2026-06.tsv")),
      version: 1,
      issuedAt,
    };
    const chainId = await publicClient.getChainId();
    const signature = await deployer.signTypedData({
      domain: { name: "AppLove RevenueRegistry", version: "1", chainId, verifyingContract: c.revenue.address },
      types: {
        RevenueReport: [
          { name: "projectId", type: "uint256" },
          { name: "period", type: "uint32" },
          { name: "settlementCurrency", type: "bytes32" },
          { name: "grossSales", type: "uint256" },
          { name: "storeProceeds", type: "uint256" },
          { name: "refunds", type: "uint256" },
          { name: "taxes", type: "uint256" },
          { name: "eligibleProceeds", type: "uint256" },
          { name: "reportHash", type: "bytes32" },
          { name: "version", type: "uint32" },
          { name: "issuedAt", type: "uint64" },
        ],
      },
      primaryType: "RevenueReport",
      message: report,
    });
    await c.revenue.write.submitReport([report, signature], { account: alice.account });
    await networkHelpers.time.increase(2 * 86400);
    await c.revenue.write.finalize([1n, 202606]);

    const share = parseUnits("1250", 6); // 10% of eligible proceeds
    assert.equal(await c.vault.read.entitlement([1n, 202606]), share);
    await c.usdc.write.mint([deployer.account.address, share]);
    await c.usdc.write.approve([c.vault.address, share]);
    await c.vault.write.fund([1n, 202606, share]);
    const before = await c.usdc.read.balanceOf([alice.account.address]);
    await c.vault.write.claim([1n], { account: alice.account });
    assert.equal((await c.usdc.read.balanceOf([alice.account.address])) - before, share);
  });
});
