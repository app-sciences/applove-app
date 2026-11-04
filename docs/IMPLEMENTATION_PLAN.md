# Implementation plan
| Phase | Scope | Status |
|---|---|---|
| 0 | Audit, architecture, diagrams, contracts primer | Done (docs) |
| 1 | Apple feed provider, normalization, dedupe, snapshots, movement (`packages/shared`) -> Next.js `/discover` -> screenshots | Core library + tests done; UI not started |
| 2 | Simulated markets, play-money AMM, oracle resolution, `/predictions` | Not started |
| 3 | Contracts on Base Sepolia, wallet | Contracts, 114 tests, internal review done; fork dry-run passed; live deploy waiting for a funded key; wallet UI not started |
| 4 | ParticipationToken, RevenueRegistry, PayoutVault, mock reports | Contracts and tests done; mock report backend not started |
| 5 | Tokenomics sims, compliance, cost | Not started |
Remaining docs from the brief (ORACLE_SPEC, APP_DISCOVERY, PREDICTION_MARKETS, TOKENOMICS, SECURITY_AND_COMPLIANCE, API_REFERENCE) are not yet written.
