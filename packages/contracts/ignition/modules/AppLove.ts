import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * Deploys and wires the full AppLove testnet system. TEST TOKENS ONLY.
 *
 * Parameters (ignition/parameters/*.json):
 *   oracleSigner   – revenue-oracle key allowed to sign RevenueRegistry reports
 *   reporter       – public-metrics oracle key allowed to sign PredictionOracle attestations
 *   disputeWindow, maxReportAge, challengeWindow, maxSnapshotAge, minResolutionWindow – seconds
 *
 * The deployer becomes admin of every contract. Hand admin to a multisig before anything real.
 */
export default buildModule("AppLove", (m) => {
  const admin = m.getAccount(0);
  const oracleSigner = m.getParameter("oracleSigner", admin);
  const reporter = m.getParameter("reporter", admin);
  const disputeWindow = m.getParameter("disputeWindow", 2n * 24n * 3600n);
  const maxReportAge = m.getParameter("maxReportAge", 120n * 24n * 3600n);
  const challengeWindow = m.getParameter("challengeWindow", 24n * 3600n);
  const maxSnapshotAge = m.getParameter("maxSnapshotAge", 3n * 24n * 3600n);
  const minResolutionWindow = m.getParameter("minResolutionWindow", 24n * 3600n);
  const unitsUri = m.getParameter("unitsUri", "https://applove.example/units/{id}.json");

  const usdc = m.contract("MockUSDC");
  const aplov = m.contract("APLOVToken", [admin]);
  const appRegistry = m.contract("AppRegistry", [admin]);
  const units = m.contract("ParticipationToken", [admin, unitsUri]);
  const revenue = m.contract("RevenueRegistry", [admin, appRegistry, disputeWindow, maxReportAge]);
  const vault = m.contract("PayoutVault", [admin, usdc, units, revenue]);
  const treasury = m.contract("Treasury", [admin]);
  const predOracle = m.contract("PredictionOracle", [admin, challengeWindow, maxSnapshotAge]);
  const factory = m.contract("PredictionMarketFactory", [admin, predOracle, treasury, minResolutionWindow]);

  // Wiring (each is a one-time call guarded on-chain).
  m.call(units, "setHook", [vault]);
  m.call(predOracle, "setFactory", [factory]);
  m.call(factory, "setCollateralAllowed", [usdc, true], { id: "allowUSDC" });
  m.call(factory, "setCollateralAllowed", [aplov, true], { id: "allowAPLOV" });

  const ORACLE_ROLE = m.staticCall(revenue, "ORACLE_ROLE", []);
  const REPORTER_ROLE = m.staticCall(predOracle, "REPORTER_ROLE", []);
  m.call(revenue, "grantRole", [ORACLE_ROLE, oracleSigner], { id: "grantRevenueOracle" });
  m.call(predOracle, "grantRole", [REPORTER_ROLE, reporter], { id: "grantMetricsReporter" });

  return { usdc, aplov, appRegistry, units, revenue, vault, treasury, predOracle, factory };
});
