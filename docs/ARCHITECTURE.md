# AppLove architecture (Phase 0)

## Repository audit
| Area | Finding | Decision |
|---|---|---|
| `applove-app` | npm-workspaces scaffold. `apps/web`, `apps/api`, `packages/{shared,ai,contracts}` all contain placeholder `TODO` scripts. Specs only. | Greenfield; reuse the workspace layout. |
| Auth / Firebase / Data Connect | None present. | Add Firebase Auth + Firestore in a later phase; Phase 1 needs neither. |
| Campaigns, developer profiles, NFT, revenue logic, blockchain connectivity | None present. `specs/contracts.md` is a design only. | Implement from spec. |
| `applove` | README + whitepaper only. | Reference. |
| Existing spec conflicts | Old spec says ERC-20 stake tokens, secondary market; `contracts.md` says ERC-1155 and secondary market out of MVP. | ERC-1155, transfers disabled by default. |
| Name | Repo says "Applove" and spec says "AppStake" in places. | Use AppLove. |

## Diagram
See `diagrams/blockchain-architecture.mmd`, `participation-payout.mmd`, `prediction-resolution.mmd`.

## Rule
Contracts never call Apple or Google. A backend oracle fetches, validates, hashes, archives evidence, and submits a signed attestation.

## AI + prediction market
`packages/ai` consumes (a) ranking-history snapshots, (b) category/release features, and (c) market prices
weighted by liquidity, and outputs a calibrated probability per eligible market. It is advisory; it is scored
against resolved outcomes and never touches settlement.

## Open uncertainties
- Google Play public charts have no official API: needs a licensed provider.
- Apple RSS feed carries rank and metadata but not download counts or revenue; those need developer authorization.
- Foundry is not installed in this environment; contract phases need it installed.
- Firebase vs the older spec's Postgres suggestion: Firebase chosen per brief, undecided until Phase 2.
- Legal: see SECURITY_AND_COMPLIANCE.md (not yet written).
