# contracts_spec.md

# SpecDD: Smart Contracts Specification

## Project

Stake-Based Crowdfunding App on Base

## Purpose

Define the initial smart contract architecture for a Base-based application where creators raise funding for app projects and investors receive tokenized ownership certificates representing a right to future revenue distributions.

The system is not intended to put the entire business process on-chain. It should use smart contracts as a transparent settlement and ownership layer while relying on traditional backend services for app-store revenue ingestion, metadata, project review, compliance workflows, and user experience.

---

## Core Concept

The application combines:

- crowdfunding,
- revenue-sharing agreements,
- tokenized ownership certificates,
- automated stablecoin payouts,
- off-chain revenue verification.

High-level flow:

```text
Creator publishes project
        ↓
Investors fund project with USDC
        ↓
Ownership certificates are minted
        ↓
Creator builds and launches app
        ↓
Revenue is tracked off-chain
        ↓
Revenue-share amount is deposited on-chain
        ↓
Investors claim payouts
```

---

## Important Assumption

Apple, Google, Steam, Stripe, and similar revenue sources do not directly pay smart contracts.

Therefore, app revenue must flow through off-chain systems before being deposited into the on-chain revenue distribution contract.

```text
App Store Revenue
        ↓
Traditional Backend / Revenue Processor
        ↓
USDC Deposit into Smart Contract
        ↓
Investor Claim / Distribution
```

---

## Architecture Overview

```text
Frontend App
        ↓
Backend API
        ↓
Project Factory Contract
        ↓
Project Contract
        ↓
Ownership NFT / ERC-1155 Contract
        ↓
Revenue Distribution Contract
        ↓
USDC Payouts on Base
```

---

## Recommended MVP Contract Set

### 1. ProjectFactory Contract

Responsible for creating and registering new project contracts.

Responsibilities:

- create new project contracts,
- store project contract addresses,
- emit project-created events,
- enforce platform-level permissions,
- optionally charge project creation fees.

### 2. Project Contract

Represents a single funded app/project.

Responsibilities:

- store creator wallet,
- store funding goal,
- store revenue-share percentage,
- track project state,
- accept USDC funding,
- mint ownership certificates,
- allow creator withdrawal after funding success,
- refund investors if funding fails.

### 3. Ownership Certificate Contract

Represents investor ownership or revenue-share rights.

Recommended options:

- ERC-721 for unique ownership certificates,
- ERC-1155 for semi-fungible stake units.

For the MVP, ERC-1155 is likely the best fit if each project has many identical stake units.

Responsibilities:

- mint ownership units,
- track stake balances,
- expose ownership data to payout logic,
- support future transferability if allowed.

### 4. Revenue Distribution Contract

Handles revenue-share deposits and investor claims.

Responsibilities:

- accept USDC deposits,
- associate deposits with projects,
- calculate claimable balances,
- allow investors to claim payouts,
- emit payout-related events.

Recommended model:

```text
Pull payments
```

Investors claim their own revenue rather than the contract pushing payments to every investor automatically.

---

## Project Lifecycle

### State: Draft

Project exists off-chain but has not been deployed or opened for funding.

### State: Funding

Project contract is active and accepts USDC funding.

### State: Funded

Funding goal has been reached.

### State: Active

Creator has withdrawn funds and the project is operating.

### State: RevenueGenerating

Revenue deposits are being made into the distribution contract.

### State: Cancelled

Project is cancelled before successful funding.

### State: Refunding

Investors may withdraw their funds if the project does not reach its goal.

---

## Primary User Flows

### Flow 1: Create Project

```text
Creator submits project details
        ↓
Backend reviews / approves project
        ↓
Factory deploys Project Contract
        ↓
Project enters Funding state
```

On-chain data:

- creator address,
- funding goal,
- offered revenue-share percentage,
- accepted payment token,
- funding deadline,
- ownership unit configuration.

Off-chain data:

- app description,
- screenshots,
- milestones,
- videos,
- creator profile,
- legal documents,
- risk disclosures.

---

### Flow 2: Investor Buys Stake

```text
Investor connects wallet
        ↓
Investor approves USDC spend
        ↓
Investor calls invest()
        ↓
Project contract receives USDC
        ↓
Ownership certificate is minted
```

Contract requirements:

- verify project is in Funding state,
- verify funding deadline has not passed,
- verify purchase does not exceed available stake units,
- transfer USDC from investor,
- mint ownership units,
- emit InvestmentReceived event.

---

### Flow 3: Funding Goal Reached

```text
Total funded amount >= funding goal
        ↓
Project state changes to Funded
        ↓
Creator may withdraw funds
```

Contract requirements:

- prevent further overfunding unless explicitly allowed,
- mark project as Funded,
- emit ProjectFunded event.

---

### Flow 4: Creator Withdraws Funds

```text
Creator calls withdrawFunds()
        ↓
Contract sends raised USDC to creator / treasury
        ↓
Project becomes Active
```

Contract requirements:

- only creator or authorized treasury may withdraw,
- funding goal must be reached,
- use nonReentrant protection,
- emit FundsWithdrawn event.

---

### Flow 5: Revenue Deposit

```text
Backend calculates revenue-share amount
        ↓
Authorized account deposits USDC
        ↓
Revenue contract records distribution
```

Contract requirements:

- only authorized revenue processor may deposit,
- deposit must reference a valid project,
- deposit must use accepted stablecoin,
- emit RevenueDeposited event.

---

### Flow 6: Investor Claims Revenue

```text
Investor opens app
        ↓
App reads claimable balance
        ↓
Investor clicks Claim
        ↓
Contract transfers USDC to investor
```

Contract requirements:

- calculate claimable amount based on ownership units,
- prevent double-claiming,
- transfer USDC safely,
- emit RevenueClaimed event.

---

## Recommended Token Model

### Preferred MVP Option

Use ERC-1155 ownership units.

Reasoning:

- supports multiple projects under one contract,
- allows semi-fungible stake units,
- simpler than deploying one ERC-20 per project,
- cleaner than fully unique ERC-721s for fractional ownership,
- works well for marketplace-style ownership certificates.

Example:

```text
Project 52
Total units: 1000
Each unit: 0.01% of the offered revenue-share pool
```

If the project offers 10% future revenue share:

```text
1 unit = 0.01% of project revenue
1000 units = 10% total revenue share
```

---

## Payment Token

Use USDC on Base for MVP.

Reasons:

- stable unit of account,
- strong Coinbase ecosystem alignment,
- easier investor understanding,
- avoids ETH volatility,
- simpler payout accounting.

---

## Access Control

Use OpenZeppelin AccessControl.

Suggested roles:

```text
DEFAULT_ADMIN_ROLE
PROJECT_CREATOR_ROLE
REVENUE_PROCESSOR_ROLE
PAUSER_ROLE
```

The platform should control:

- project approval,
- revenue processor authorization,
- emergency pauses,
- contract upgrades if upgradeable contracts are used.

---

## Security Requirements

Use OpenZeppelin libraries wherever possible.

Required protections:

- ReentrancyGuard,
- SafeERC20,
- AccessControl,
- Pausable,
- input validation,
- event logging,
- unit tests for all money flows.

Avoid:

- custom token standards,
- push payments to large investor lists,
- complex governance in MVP,
- unchecked external calls,
- upgradeability unless the team understands proxy risks.

---

## Events

Recommended events:

```solidity
event ProjectCreated(uint256 indexed projectId, address indexed projectContract, address indexed creator);

event InvestmentReceived(uint256 indexed projectId, address indexed investor, uint256 amount, uint256 units);

event ProjectFunded(uint256 indexed projectId, uint256 totalRaised);

event FundsWithdrawn(uint256 indexed projectId, address indexed creator, uint256 amount);

event RevenueDeposited(uint256 indexed projectId, uint256 amount, address indexed depositor);

event RevenueClaimed(uint256 indexed projectId, address indexed investor, uint256 amount);
```

---

## Backend Responsibilities

The backend should handle:

- user accounts,
- project metadata,
- image uploads,
- legal disclosures,
- creator verification,
- investor eligibility checks,
- app-store revenue ingestion,
- revenue-share calculations,
- admin review workflows,
- notifications,
- analytics,
- reporting,
- tax/export support.

The backend should not be the source of truth for ownership or payout claims once contracts are active.

---

## On-Chain Responsibilities

Smart contracts should handle:

- project funding,
- ownership unit minting,
- stake balance tracking,
- revenue deposit records,
- investor claim accounting,
- payout transfers,
- transparent event logs.

---

## Out of Scope for MVP

Do not include the following in the first version:

- DAO governance,
- investor voting,
- secondary marketplace,
- token staking,
- DeFi yield strategies,
- complex royalty routing,
- cross-chain support,
- prediction market mechanics,
- automated app-store oracle integration.

---

## Legal / Compliance Note

This model may involve securities-law, crowdfunding, and investment-contract issues because users are funding a project in exchange for future revenue.

Before launch, this requires legal review around:

- securities compliance,
- investor eligibility,
- fundraising limits,
- disclosures,
- transfer restrictions,
- jurisdiction restrictions,
- KYC/AML,
- tax reporting.

The MVP should be designed so transferability and public trading can be disabled until compliance requirements are clear.

---

## Recommended Development Stack

Smart contracts:

- Solidity
- Foundry
- OpenZeppelin
- Base Sepolia testnet
- Base mainnet

Frontend:

- Next.js or Flutter
- Coinbase Smart Wallet
- WalletConnect / RainbowKit / Privy / Dynamic

Backend:

- Nest.js or Express
- PostgreSQL
- Redis
- object storage for media/documents

---

## Acceptance Criteria

The MVP contracts are complete when:

- a project can be created,
- investors can fund with USDC,
- ownership units are minted,
- funding goal can be reached,
- creator can withdraw funds,
- revenue processor can deposit USDC,
- investors can claim proportional payouts,
- refunds work when funding fails,
- all major events are emitted,
- money-flow tests pass,
- unauthorized users cannot perform privileged actions.

---

## Suggested First Implementation Order

1. ERC-1155 ownership certificate contract
2. Project contract funding logic
3. Project factory contract
4. Revenue distribution contract
5. USDC mock for local tests
6. Full integration tests
7. Base Sepolia deployment
8. Frontend wallet integration
9. Backend revenue processor integration
