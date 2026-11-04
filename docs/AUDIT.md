# AppLove contracts: internal security review

**This is not an independent audit.** It is a pre-audit review done by the engineer who wrote the
code, using automated tools and manual review. Treat it as preparation for a third-party audit,
which these contracts have not had. Scope is testnet only (Base Sepolia, test tokens with no value).

| | |
|---|---|
| Commit reviewed | branch `claude/applove-phase0-discovery-core` (contracts in `packages/contracts/contracts`) |
| Compiler | solc 0.8.28, optimizer 200 runs, EVM cancun |
| Libraries | OpenZeppelin Contracts 5.6.1 |
| Contracts | MockUSDC, APLOVToken, AppRegistry, ParticipationToken, RevenueRegistry, PayoutVault, CrowdfundCampaign, Treasury, PredictionMarketFactory, PredictionMarket, PredictionOracle (≈1,000 lines) |

## Method
1. **Unit tests**: 110 Solidity tests (Hardhat 3 / forge-std) covering permissions, deadlines, signatures, replay, versions, disputes, payouts, refunds, reentrancy.
2. **Fuzz tests**: 1,000 runs each for supply caps, claim-vs-funding totals, escrow conservation and market solvency.
3. **Invariant (stateful) tests**: 128 runs × depth 64 of random action sequences against PayoutVault and PredictionMarket.
4. **Coverage**: 100% line and statement coverage on all contracts.
5. **Deployment tests**: the production Ignition module deployed locally with viem-signed EIP-712 reports, and dry-run on a fork of live Base Sepolia.
6. **Static analysis**: Slither 0.11.3, all detectors, triaged below.
7. **Manual review** of accounting, access control, oracle trust and lifecycle edge cases.

## Findings fixed during review

### F-01 (Medium): dust sweep could take money a holder was owed. **Fixed.**
`PayoutVault` tracked rounding dust per funding with floor rounding and let the admin sweep it.
Holder claims are floored once across several fundings, which can be one base unit higher than the
per-funding total. Sweeping the counted dust could leave the vault short and make the last claim revert.
Found by `invariant_obligationsCovered`. Proven by `test_regression_multiFundingRounding_allHoldersCanClaim`,
which fails on the old code (`3 > 2`). Fix: the dust counter and `sweepResidual` were removed. Leftover
dust (at most 1 base unit per holder per checkpoint) stays in the vault.

### F-02 (Medium): late unit claims let early claimers take others' revenue. **Fixed.**
`CrowdfundCampaign` minted units only when each contributor called `claimUnits()`. Revenue is split over
the minted supply, so a period funded before everyone claimed gave early claimers the whole distribution.
Found in manual review. Fix: units are minted at reservation and burned on refund, so supply always
equals units sold. Reservations are refused while the series is transferable. Regression test:
`test_regression_revenueSplitCoversEveryContributor`.

## Slither triage (no open High or Medium issues)
| Detector | Where | Verdict |
|---|---|---|
| timestamp | registries, oracle, market, campaign | Intentional. Windows are hours to days; Base block timestamps cannot drift that far. |
| unused-return | CrowdfundCampaign constructor | Intentional partial read of the `series` struct. |
| calls-loop | ParticipationToken `_update`, campaign | Calls go to the trusted, set-once PayoutVault hook. |
| missing-zero-check | PredictionMarket constructor | Markets are only deployed by the factory, which checks both addresses. |
| uninitialized-local | PredictionMarket.redeem | Fixed (explicit `= 0`). |

## Open risks and design notes (accepted for testnet, must be resolved before mainnet)
1. **Centralized admin.** One deployer key holds `DEFAULT_ADMIN_ROLE` everywhere and can pause the vault, grant oracle roles, create markets and arbitrate disputes. Before anything real: a multisig (for example a Safe) plus a timelock on role changes.
2. **Trusted oracle.** A compromised `ORACLE_ROLE` or `REPORTER_ROLE` key can submit false data. Mitigations present: dispute/challenge windows, conflicting attestations force a dispute, signatures are bound to chain and contract (EIP-712), replay protection. Missing: multiple independent signers (k-of-n), keys in an HSM/KMS, monitoring that alerts on every attestation.
3. **Oracle can delay.** A higher-version revenue report resets the dispute window, so the oracle can postpone finalization indefinitely.
4. **Pause can freeze claims.** `PAUSER_ROLE` can stop vault claims indefinitely.
5. **Global minter role.** `MINTER_ROLE` on ParticipationToken applies to every series. A campaign contract only mints its own series, but any other minter could mint any series up to its cap.
6. **Series id convention.** Series id must equal the AppRegistry project id. This is not enforced on-chain.
7. **Enabling transfers on a failed campaign.** If an admin enables transfers before a failed campaign's contributors refund, a contributor who moved units away cannot refund.
8. **Revenue funded during a live campaign** would pay contributors who might later be refunded. Operationally, fund only after campaign success.
9. **No on-chain price discovery.** Markets are fully collateralized complete sets. Users can trade outcome units peer to peer, but there is no AMM, so slippage and liquidity are not modeled on-chain yet.
10. **Outside contract scope.** The off-chain oracle backend, key management, and the legal status of participation units and event contracts. See the compliance notes in SMART_CONTRACTS.md.

## Getting an independent audit
An audit has to come from an outside firm or a competitive audit platform. Neither I nor this repository can produce one.
- **Firms** (fixed-scope reviews), for example OpenZeppelin, Trail of Bits, Spearbit/Cantina, ConsenSys Diligence, Cyfrin, Zellic.
- **Competitive audits**, for example Code4rena, Sherlock, Cantina competitions.
- Get quotes for a ≈1,000-line scope. Timelines and prices vary widely, so don't budget from memory.

Before engaging, freeze the scope at one commit, decide whether to include the oracle backend, resolve items 1–2 above (auditors will flag them first), and give them this file plus `npm test`.
