# AppLove mainnet launch readiness

Assessed 2026-11-08 against branch `claude/applove-phase0-discovery-core` at commit `1ce02a9`.
Every claim below was checked against code, a test run, or a live RPC call. Nothing here is legal advice.

## Verdict

**Do not launch the existing contracts on mainnet today.** They are well tested but they are the wrong
thing to deploy for this launch, and there is no website or wallet flow at all.

**What is feasible today:** a small, separate, non-financial demo NFT contract on **Base**, priced in
native USDC, verified on BaseScan, with proceeds going to a multisig. The contract is a few hours of work
including tests. A public website with wallet connection and a mint button is **missing entirely** and is
the real schedule risk: plan on 1 to 2 days for a minimal, reviewed version, not hours.

The largest risk is not technical. Selling NFTs as part of a fundraising campaign, with any suggestion of
app revenue, is likely a securities offering in the US and many other places. Get counsel before any sale.

## Phase 1: Repository audit

Status key: **Working** = implemented and passing tests. **Untested** = implemented, no test.
**Partial**, **Missing**, **Blocked** (by something outside the repo).

| Component | Status | Evidence |
|---|---|---|
| Monorepo layout | Working | `package.json` npm workspaces: `apps/*`, `packages/*` |
| Frontend (`apps/web`) | **Missing** | Folder contains only `package.json` with `echo 'TODO: setup'` scripts. No framework installed, no pages. |
| Backend API (`apps/api`) | **Missing** | Same: placeholder `package.json` only. |
| AI package (`packages/ai`) | **Missing** | Placeholder only. |
| App discovery library | Working | `packages/shared/src/discovery.ts` (`parseAppleFeed`, `computeMovements`, `fastestClimbers`), `src/apple.ts` (`fetchAppleChart`); 10 tests in `packages/shared/test/discovery.test.ts`. Not connected to any UI. |
| Blockchain networks | Partial | `packages/contracts/hardhat.config.ts` defines `baseSepolia` (84532) and `baseSepoliaFork`. **No mainnet network is configured.** |
| Smart contracts | Working | 11 contracts in `packages/contracts/contracts/`; 110 Solidity tests + 4 TypeScript tests pass; 100% line coverage. |
| NFT standard | Working | ERC-1155 only: `ParticipationToken.sol` (participation units) and `PredictionMarket.sol` (outcome units). No ERC-721. |
| Wallet integration | **Missing** | No wagmi, viem client, RainbowKit, OnchainKit or WalletConnect code in any app. viem is used only in tests. |
| Stablecoin payments | Working (mock) | `CrowdfundCampaign.reserve()` takes any `IERC20` at a fixed `unitPrice`. Tested only with `MockUSDC`, never with real USDC. |
| Deployment scripts | Partial | `ignition/modules/AppLove.ts` deploys the whole testnet system, **including MockUSDC (public mint) and the APLOV token**. Not suitable for mainnet. |
| Contract verification | Untested | `@nomicfoundation/hardhat-verify` and a BaseScan entry in `chainDescriptors` are configured; never run, no `ETHERSCAN_API_KEY`. |
| Security controls | Working | OpenZeppelin `AccessControl`, `ReentrancyGuard`, `Pausable`, `SafeERC20`, EIP-712 signatures, replay protection. Reviewed in `docs/AUDIT.md`. **No independent audit.** |
| Production deployments | **Missing** | None on any mainnet. |
| Testnet deployments | **Missing** | Never deployed to Base Sepolia. Only a local fork dry run, which broadcasts nothing. |
| Revenue distribution | Working (on-chain part only) | `PayoutVault.fund()` / `claim()`; see Phase 4. |
| App configuration | Partial | Contract config only. No app config, no `.env.example`. |
| Secrets handling | Working | `configVariable("BASE_SEPOLIA_PRIVATE_KEY")` etc. read at runtime; `.env*` gitignored; no keys in the repository (checked). |

## Phase 2: Network

The code is built for **Base** (OP-stack `chainType: "op"`, Base Sepolia config). Recommendation: **Base mainnet (chain 8453)**.

| | Base | Polygon PoS | Arbitrum One | Ethereum |
|---|---|---|---|---|
| Fits existing contracts/config | Yes, as is | Needs new config | Needs new config | Needs new config |
| Native USDC from Circle | Yes | Yes | Yes | Yes |
| Typical fees | Fractions of a cent (0.006 gwei measured) | Fractions of a cent | Cents | Dollars per mint |
| Wallets | Coinbase Wallet, MetaMask, Rainbow | Broad | Broad | Broad |
| Verification | BaseScan (Etherscan v2 API) | Polygonscan | Arbiscan | Etherscan |
| NFT marketplaces | OpenSea, Magic Eden and others | Yes | Yes | Yes |

All four are EVM, so the Solidity is portable. Base wins on effort (already targeted), fees, and the Coinbase
on-ramp for USDC. Ethereum mainnet makes a USDC mint cost more in gas than many demo prices.

### USDC addresses (read from chain on 2026-11-08)
| Network | Address | `name()` | `decimals()` | Use? |
|---|---|---|---|---|
| Base mainnet | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` | USD Coin | 6 | **Yes, native USDC** |
| Base mainnet | `0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA` | USD Base Coin (USDbC) | 6 | **No**, legacy bridged |
| Base Sepolia | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` | USDC | 6 | Testnet only |

Cross-check these against Circle's published list before deploying.

USDC facts that affect the design:
- 6 decimals, so 25 USDC is `25_000_000`.
- Paying takes two transactions (`approve`, then the purchase) unless you add EIP-2612 `permit`, which USDC supports, for a single signature.
- Circle can freeze addresses. A transfer to or from a frozen address reverts, which can block refunds or proceeds withdrawals.
- USDC is an upgradeable contract controlled by Circle. That is an external dependency you accept.

## Phase 3: NFT and USDC functionality

| Capability | Status | Evidence / gap |
|---|---|---|
| Create a collection | Partial | `ParticipationToken.createSeries(id, maxSupply, shareBps)`. Every series carries a revenue share (`shareBps` must be 1–10,000), so there is no non-financial series. Requires `setHook()` to a deployed `PayoutVault` first. |
| Metadata | **Partial, launch-blocking** | Single URI set in the constructor (`ERC1155(uri_)`), **with no `setURI` function**. The deploy default is the placeholder `https://applove.example/units/{id}.json`, which does not exist. No metadata JSON or images exist. |
| Fixed USDC price | Working (mock) | `CrowdfundCampaign.unitPrice`, immutable. |
| Purchase with native USDC | Untested | Code accepts any ERC-20; never run against real USDC. |
| Mint to buyer | Working | `reserve()` takes payment and then calls `units.mint()` in the same transaction; tested (`test_success_unitsIssuedAtReservation_developerWithdrawsOnce`). |
| Payment routing | Working | Funds stay in escrow until `finalize()`, then `withdrawProceeds()` sends everything to `developer` once. |
| Refunds | Working | All-or-nothing: `refund()` only if the goal is missed; burns units. No refunds after success. |
| Failed transactions | Working | Missing approval or balance reverts the whole call; nothing is minted (`test_insufficientAllowance_reverts`). |
| Show in wallet | **Missing** | Needs valid metadata (see above). ERC-1155 display in wallets is weaker than ERC-721. |
| Ownership on explorer | Will work after deploy | Standard ERC-1155 events. |
| Public source code | Untested | Verification plugin configured, never run. |
| Show on an AppLove project page | **Missing** | No website. |
| Transfers / marketplace listing | **Disabled by default** | `transfersEnabled` is false per series; transfers revert `TransfersDisabled`. Marketplaces cannot sell them. |

**Standard for today: ERC-721** for a separate demo collection. It is the best supported for wallets,
BaseScan and marketplaces, and "one token per buyer" is easy to understand. Keep ERC-1155 for future
revenue-participation units, where many identical units per app is the right model.

## Phase 4: Economic rights and revenue sharing

| Function | Status | Evidence |
|---|---|---|
| Revenue allocation | Working on-chain | `PayoutVault.entitlement()` = finalized eligible proceeds × `shareBps` / 10,000. |
| Accounting | Working on-chain | Reward-per-unit accumulator (`accPerUnit`, `paidPerUnit`, `accrued`); invariant-tested. |
| Distribution | Working on-chain | Pull model: holder calls `claim()`. |
| Funding | Voluntary | Developer must deposit USDC with `fund()`. Nothing forces it; a gap is shown by `shortfall()`. |
| Revenue verification | **Missing (off-chain)** | `RevenueRegistry` accepts signed reports, but the oracle service that reads Apple/Google reports does not exist. |
| Stripe / Paddle / others | **Missing** | Not modeled. `AppRegistry` stores only Apple and Google IDs. |
| Reconciliation | Partial | Report fields for gross, proceeds, refunds and taxes; corrections by higher version **before** finalization only. |
| Refunds / chargebacks after payout | **Missing** | No clawback once a period is finalized and distributed. |
| Legal agreement tying NFTs to revenue | **Missing** | No terms, offering documents or contracts exist in the repository. |

**Who is entitled:** the current holder. On every transfer, `ParticipationToken._update()` calls
`PayoutVault.checkpoint()` for both sides first, so money already accrued stays with the seller and later
money goes to the buyer. Tested by `test_transferAfterFunding_sellerKeepsAccrued_buyerGetsOnlyNew` and
`test_transferPingPong_noDuplicateClaims`. Known transfer issues are in `docs/AUDIT.md` (items 5–8),
including that enabling transfers on a failed campaign can block a refund.

**The three NFT categories:**
- **A. Demonstration NFT:** what can launch. No promises.
- **B. Non-financial benefits** (supporter badge, early access, credits): possible if those benefits are actually delivered. Still needs care in how it is described.
- **C. Contractual rights to future revenue:** **not available.** There is no legal framework, no live oracle, and no enforced funding. This category is very likely a security and needs registration or an exemption (in the US, for example, Reg CF or Reg D) before any sale.

The architecture can support USDC distributions to holders later. Today it must not be described as doing so.

## Phase 5: Security review for a mainnet launch

| # | Issue | Severity for mainnet | Fix |
|---|---|---|---|
| 1 | Deploy module deploys **MockUSDC, which anyone can mint**, and wires the vault and market factory to it | **Blocking** | Separate mainnet module using native USDC; never deploy MockUSDC |
| 2 | Deploy module deploys the **APLOV token**, contrary to "no proprietary token" | **Blocking** | Exclude from mainnet |
| 3 | **One externally owned key** holds `DEFAULT_ADMIN_ROLE` on every contract: it can grant itself `MINTER_ROLE` and mint units, pause claims, register oracles | **Blocking** | Admin = multisig (e.g. Safe, 2-of-3 or better); deployer renounces |
| 4 | Metadata URI is immutable and points to a placeholder domain | **Blocking** | Host real metadata first, or add a settable-then-freezable URI |
| 5 | No independent audit | Blocking for anything holding others' money | Third-party audit (see `docs/AUDIT.md`) |
| 6 | Deploying the revenue stack on mainnet would imply working revenue rights | Blocking (disclosure) | Keep it on testnet; launch a separate demo contract |
| 7 | Campaign proceeds go to one `developer` address; if Circle freezes it, `withdrawProceeds()` reverts and there is no rescue path | High | Proceeds to a multisig; consider an admin-recovery path with a timelock |
| 8 | Oracle is a single trusted signer | High (for revenue features) | k-of-n signers in a KMS/HSM |
| Checked: unauthorized minting | OK | `mint()` and `burn()` require `MINTER_ROLE` (tests in `ParticipationToken.t.sol`) |
| Checked: unauthorized withdrawals | OK | Only `claim()`, `refund()`, `withdrawProceeds()` (developer only, once), `Treasury.withdraw()` (role) |
| Checked: reentrancy | OK | `nonReentrant` on all value-moving functions; attack tests in campaign and market suites |
| Checked: token accounting | OK | Fuzz and invariant tests; two accounting bugs found and fixed (`docs/AUDIT.md` F-01, F-02) |
| Checked: upgradeability | None | No proxies. Contracts cannot be changed after deployment, so bugs need a redeploy |

## Smallest credible launch (recommended path)

1. **Today, legal:** decide with counsel whether the demo NFT is free, priced, or a nominal supporter item, and approve the wording. If there is any doubt, mint for free or don't sell.
2. **Contract (hours):** a new `AppLoveDemoNFT` (ERC-721, OpenZeppelin, non-upgradeable): fixed USDC price, capped supply, proceeds sent straight to a multisig on each mint (nothing held in the contract), per-wallet limit, metadata URI that can be frozen, no revenue language on-chain. Unit and fuzz tests, a Base Sepolia deploy with test USDC, then mainnet.
3. **Keys:** fresh deployer key with a little ETH on Base; a Safe multisig as owner and payout recipient; BaseScan verification key.
4. **Website (1–2 days):** one Next.js page with wallet connect (wagmi plus Coinbase Wallet / WalletConnect), approve + mint, links to BaseScan, and two clearly labeled sections: **Live now** (demo NFT on Base, verified source) and **In development** (revenue sharing, store integrations, distributions, all on testnet only).
5. **Keep on testnet:** the full revenue-sharing and prediction-market contracts, until audit, multisig, live oracle and legal framework exist.

## Not covered
The request was cut off partway through Phase 5 (after "Payment"). Any later phases were not received.
