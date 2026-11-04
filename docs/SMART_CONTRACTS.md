# Smart contracts for AppLove: a plain-language guide

Simulation only. Everything here targets Base Sepolia test tokens. Whether participation tokens are securities
and whether event contracts are regulated derivatives is a legal question this document does not answer
(see SECURITY_AND_COMPLIANCE.md).

## 1. What a smart contract is
A smart contract is a small program stored on a blockchain. It holds tokens and follows fixed rules that nobody
can quietly change: "if X is true, release the money to Y". Anyone can read the rules and the history.

Two limits matter for AppLove:
1. **It cannot call the internet.** A contract has no way to ask Apple or Google anything. It only knows what is
   written on-chain.
2. **It trusts whatever it is told by an authorized address.** The design question is always "who is allowed to
   tell the contract a fact, and how can we check them?"

## 2. How contracts "talk" to the App Store: they don't. An oracle does.
```
Apple / Google  --HTTPS-->  AppLove oracle backend  --signed transaction-->  Smart contract
```
The oracle backend:
1. Pulls the data (public chart, or the developer's private sales report via App Store Connect API / Google Play
   report files, using credentials the developer authorizes; credentials never leave the backend).
2. Normalizes it (app id, period, currency, integer minor units) and stores the raw file as evidence.
3. Hashes the file (keccak256) so anyone can later prove which report a number came from.
4. Submits `attest(appId, period, amount, reportHash, version)` signed by an oracle key held in a KMS/HSM.
5. The contract checks the signer is authorized, rejects replays, then starts a **dispute window** (for example
   48 hours). Only after the window does the value become final and usable.

Trust honestly: this is a *trusted oracle with auditability*, not trustless. Apple will not sign anything on-chain.
Mitigations: public evidence hashes, a dispute/correction path, multiple signers later, and developer
co-attestation. Revenue is only as truthful as the developer's report access plus our oracle.

## 3. How money actually moves (the part people miss)
Apple and Google pay the **developer's bank account**, not a contract. So revenue-sharing needs a routing step:

```
App Store -> developer bank -> (agreed routing) -> USDC deposited into PayoutVault -> holders claim
```
Options, weakest to strongest: (a) developer deposits manually after each report (trust + reminders),
(b) developer sets up a dedicated payout account/stablecoin off-ramp that AppLove verifies,
(c) legal agreement with enforcement and a funding-shortfall record on-chain.
The contract cannot force a developer to send money. What it can do: record the **entitlement** (finalized
revenue x share %), show the **shortfall** if the deposit is missing, and pay holders **exactly what was
deposited**. A reported entitlement is never shown as "paid" until a transfer happened. This is a documented
requirement of PayoutVault.

## 4. NFT vs token vs staking: which to use
| Option | What it is | Good for | Problem for AppLove |
|---|---|---|---|
| ERC-721 NFT | One unique certificate | One-off rights, art, "this is my specific deal" | Not divisible; 1,000 investors = 1,000 near-identical NFTs; per-unit payout math is awkward |
| **ERC-1155** | One contract, many ids; each id = an app series, with many identical units | Revenue-share units per app | Tradable, so payouts need snapshot/accounting (below) |
| ERC-20 per app | New token contract per app | Simple balances, DEX-friendly | Deploy cost, pool fragmentation, easiest to become an openly traded security |
| "Staking" | Lock a token to earn | Protocol rewards | Staking is a mechanism, not a rights certificate; adds nothing for revenue share |

**Recommendation: ERC-1155 participation units.** Each app series is an id with a fixed total supply (e.g. 1,000
units = 10% of eligible proceeds, so 1 unit = 0.01%). Units are tradable *by the standard*, so you get the
secondary-market property you like, but AppLove can lock transfers (an allow-list / transfer hook) until the legal
position is clear. Your instinct that tradability is valuable is right; the same property is also what raises the
securities question, so ship it switched off.

For predictors, positions are also ERC-1155: one id per (market, outcome). Winning ids redeem for collateral.

## 5. Tradable certificates without double payments
The classic bug: Alice holds units, a payout is declared, Alice sells to Bob, both claim. Fix with an
**accumulator** ("reward per unit") pattern:
- When a period is funded, `rewardPerUnit += deposit / totalUnits`.
- Each holder tracks `paidPerUnit` at their last update; claimable = `units * (rewardPerUnit - paidPerUnit)`.
- On **every transfer** the token calls the vault to settle both parties' accrued amount first.
So accrued money stays with the seller, new money goes to the buyer. Integer rounding dust stays in the vault as
an explicit residual. No transfer can create a second claim.

## 6. End-to-end: funding an app
1. Admin registers the project in `AppRegistry`; creates a series in `ParticipationToken` (supply, share %).
2. Participant (test funds only) pays mock USDC into the campaign; contract mints units to them. If the goal fails by the
   deadline, they refund themselves (pull refund).
3. Each month the oracle attests proceeds to `RevenueRegistry`; after the dispute window it is finalized.
4. Developer deposits the share of proceeds into `PayoutVault` for that period.
5. Holders call `claim()`. Anything unfunded shows as a shortfall.

## 7. End-to-end: a prediction market (e.g. "Top 10 free chart by Friday?")
1. Factory creates a market with *immutable* terms: metric, storefront, deadline, data source, outcomes, dispute window.
2. User deposits collateral and receives outcome units. Fully collateralized: 1 collateral unit mints one
   YES + one NO set; a winning unit redeems for exactly 1 collateral unit. Payouts can never exceed collateral.
3. At the deadline the metrics oracle attests the chart snapshot (evidence hash on-chain, file archived off-chain).
4. Dispute window passes -> `PredictionOracle` finalizes -> market resolves.
5. Winners `claim()`; losing units are worth 0. If data is missing, the market is cancelled and collateral refunded.

## 8. APLOV and the production market (the "plus AI" idea)
Two different things use the word "market":
- the **prediction market** (users trade outcome units), and
- the **AI forecaster** (our own custom model).

The AI layer reads prediction-market prices as one feature next to chart history, category trends, release age,
and ratings, and publishes a calibrated forecast ("market says 38%, model says 52%"). Crowd prices become an
extra signal for the AI, and the model's record can be scored against resolved markets (Brier score) to
retrain it. The AI never settles anything; settlement uses only the oracle path above.
Caveat: thin markets are noisy and manipulable, so the model must weight market price by liquidity and volume.

Token choice (see TOKENOMICS, Phase 5): settle in USDC for obligations; APLOV only for optional utility. If
payouts are in a volatile token, collateral can fall below promised payouts.

## 9. Contract list (implemented in `packages/contracts`)
MockUSDC, APLOVToken, AppRegistry, ParticipationToken (ERC-1155), CrowdfundCampaign, RevenueRegistry, PayoutVault,
PredictionMarketFactory, PredictionMarket, PredictionOracle, Treasury.

Toolchain note: Foundry could not be installed in this environment, so the project uses Hardhat 3, which runs
Foundry-style Solidity tests (forge-std, fuzz and invariant). The tests would port to `forge test` with remappings.

Testing and review status: see `docs/AUDIT.md`.
