# web-app.md

# SpecDD: Applove Web App (Next.js)

## Project

Applove: stake-based crowdfunding for apps, on Base.

## Purpose

Define the first version of the Applove web app (`apps/web`). It is the investor-facing site and the public face of the platform. This version is a **beta front end running on mock data**. The real contracts (see `contracts.md`), real payments and a real AI backend are wired in later, behind interfaces defined here.

Related docs: `spec.md` (product), `specs/contracts.md` (on-chain).

---

## Goals and Non-Goals

**Goals**
- A beautiful, calm, easy-on-the-eye gallery of apps that investors can browse, filter and understand in seconds.
- Every app has a page that lets you *experience* the app (live preview, video or screenshots) before investing.
- Make the Applove ideas tangible: APLOV currency, ownership NFTs, AI revenue projections, tester perks, the mascot Happy.
- Collect emails for the beta team and for the Trade waitlist.
- Light and dark mode, equal quality, prominent toggle.

**Non-goals for this version**
- Real money movement, real wallets, real mints. All of it is simulated and clearly labelled "Beta, demo data".
- Developer-side site (submission, campaign dashboard). Separate spec later.
- Trading. Only a Coming Soon page.
- Admin tooling.

---

## Tech Stack

| Concern | Choice | Notes |
|---|---|---|
| Framework | Next.js (App Router), TypeScript | Server components by default |
| Styling | Tailwind CSS + CSS variables for theme tokens | |
| Components | shadcn/ui (Radix) | Accessible primitives; we own the code |
| Theming | `next-themes` | `light`, `dark`, `system`; no flash on load |
| Auth | Auth.js (NextAuth v5) | Google provider + email one-time code |
| Email | Resend (or any SMTP) | Sends login codes and waitlist confirmations |
| Data (v1) | Typed mock data in `apps/web/src/data/*.ts` behind a repository interface | Swap for API/DB later without touching UI |
| Persistence (v1) | SQLite via Prisma, only for users, sessions, waitlist and beta signups | Move to PostgreSQL later |
| Carousel | Embla Carousel | Light, accessible, touch friendly |
| Charts | Recharts (or visx) | Sparklines and projection bands |
| Wallet (later) | wagmi + viem + RainbowKit, Base chain | Interface stubbed in v1 |
| AI chat | Anthropic API via a Next.js route handler, streaming | Mock responder if no API key is set |
| Tests | Vitest (unit), Playwright (e2e smoke) | |

Package lives in `apps/web` (`@applove/web`). Shared types go in `packages/shared`.

---

## Information Architecture

```text
/                         Home: carousel, filters, app tile grid
/apps/[slug]              App detail page
/about                    About Applove
/how-it-works             How it works
/trade                    Coming soon + email form
/my-investments           Signed-in: owned NFTs, value, earnings
/buy-aplov                Buy APLOV with crypto (also opened as a modal)
/login                    Google or email code
/beta                     Join the beta team (also opened as a modal)
/api/waitlist             POST email (type: trade | beta)
/api/happy                POST chat messages, streams a reply
```

### Global navigation

Left: logo (heart + app-tile mark) and wordmark, with a **BETA** pill next to it.
Center / links: **Apps**, **How it works**, **Trade** (with a small "soon" tag), **About**.
Right: **APLOV balance chip** (when signed in; "Get APLOV" when not), **theme toggle**, **Join beta** button, and avatar or **Sign in** button.

Avatar menu: My investments, Buy APLOV, Settings (placeholder), Sign out.

A thin dismissible banner under the nav says: *"Applove is in beta. Everything you see is demo data. [Join the beta team]"*.

On mobile the nav collapses into a sheet; the theme toggle and Happy button stay visible.

---

## Screens

### 1. Home (`/`)

**Hero carousel** (top of page, large images)
- 5 to 8 slides, each a large key visual of an app (16:9, edge to edge within the page container, rounded corners).
- Slide selection: top apps by one of three "boards", switchable with small tabs above the carousel: **Top invested**, **Top revenue**, **Top downloads**. Default is Top invested.
- Each slide overlays: app name, tagline, developer name (clickable, filters the list), stage badge, and a stat row:
  - Raised / goal (progress bar)
  - Downloads
  - Monthly revenue
  - **AI projection**: projected 12-month revenue with range, plus confidence (e.g. `AI projects $42k (28k–61k) next 12 mo · High confidence`)
- Buttons: **View app**, **Invest**.
- Autoplay every 7s, pauses on hover/focus and when the tab is hidden. Respects `prefers-reduced-motion` (no autoplay). Arrow buttons, dots and swipe.

**Filter bar** (sticky below the carousel)
- **Category**: multi-select chips (Productivity, Games, Utilities, Finance, Health, Social, Developer tools, AI, Other).
- **Stage**: Idea, In development, Alpha, Beta, Launched, Mature.
- **Downloads**: range buckets (Any, under 1k, 1k–10k, 10k–100k, 100k+).
- **Revenue** (monthly): Any, pre-revenue, under $1k, $1k–$10k, $10k+.
- **Platform**: iOS, Android, Web, Chrome extension, Desktop (extra, cheap to add).
- **Sort**: Top invested (default), Newest, Most downloads, Highest revenue, Highest AI projection.
- Search box (name, tagline, developer).
- Active filters shown as removable chips, with **Clear all**.
- A **Developer chip** appears when filtering by developer, e.g. `Developer: App Sciences ×`.

**Filter state lives in the URL** (`/?category=games&stage=beta&dev=app-sciences&sort=revenue`). Links are shareable and the back button works.

**App tile grid**
- Responsive: 1 column on phones, 2 on tablets, 3 to 4 on desktop.
- Tile: icon, name, one-line tagline, developer (clickable), stage badge, category, a mini stat row (downloads, monthly revenue), funding progress bar, and an AI projection mini-chip.
- Tile click goes to `/apps/[slug]`. The developer link inside a tile does **not** navigate to the app; it applies the developer filter.
- Empty state: friendly message with Happy, plus Clear filters.

**Clicking a developer, everywhere**
- Developer names on carousel slides, tiles, app pages and investments all link to `/?dev=<developer-slug>`, scrolled to the grid. This is one shared `DeveloperLink` component so the behavior is identical everywhere.

### 2. App detail (`/apps/[slug]`)

Layout: two columns on desktop (content left, sticky invest panel right), single column on mobile with a sticky bottom "Invest" bar.

**Header**: icon, name, tagline, developer link, stage badge, platform badges, store links (when launched).

**Experience section** (tabs; only the tabs that apply are shown):
1. **Live preview**: a sandboxed iframe running the app (web apps, and the web build of anything that has one). Uses `sandbox` attributes, a "Open full screen" button and a "Reset" button. If the app cannot run in a browser, this tab is hidden.
2. **Videos**: demo reels (MP4/WebM or YouTube/Vimeo embed), poster frames, no autoplay with sound.
3. **Screenshots**: image gallery with lightbox, device frames.

Every app must have at least one of the three (enforced by the data type).

**Stats and AI**
- Funding: raised, goal, backers, days left, stake price, minimum investment.
- Traction: downloads, monthly revenue, trend sparkline (12 months).
- **AI revenue projection**: 12-month fan chart (median line with 80% band), headline number, confidence label, risk tier (Low / Medium / High / Speculative) and a short "why" list (e.g. category growth, similar apps, team track record). Footer: *"Projection by Applove AI. Not financial advice. Can be wrong."*
- Developer card: name, bio, other apps (links to the developer filter), and a contact button (gated, see Perks).

**About the app**: description, roadmap milestones, team, revenue-share terms in plain language (what % of revenue goes to stakeholders, payout cadence, how long).

**Invest panel** (right column)
- Amount input in APLOV, with quick picks, stake preview ("You'd own about 0.42% of revenue share"), fees line and estimated first-year earnings (from the AI projection, labelled as estimate).
- Button: **Invest with APLOV**.
  - Signed out: opens sign-in.
  - Not enough APLOV: shows the shortfall and a **Buy APLOV** button (opens the Buy APLOV modal with the amount pre-filled).
  - Otherwise: confirm dialog, simulated transaction states (Signing, Pending, Confirmed), then a success screen showing the new ownership NFT.
- Below the button: **Get APLOV** link.

**Perks section: "Back it, get closer to it"** (see tiers below).

**Happy** is available on this page with the app preloaded as context ("Ask Happy about {app}").

### 3. My investments (`/my-investments`)

Reached from the avatar menu. Signed-in only (redirects to login).

- **Summary strip**: total current value, total invested, total earnings (claimed + unclaimed), unrealized gain/loss in APLOV and a USD equivalent.
- **Holdings list**, one row/card per NFT (ownership certificate):
  - NFT artwork thumbnail (generated from the app icon and a certificate number), token ID, app name, developer (clickable)
  - Stake: % of revenue share, APLOV invested, current value, gain/loss %
  - Earnings: claimed, **claimable now** with a **Claim** button (simulated)
  - Perks unlocked (tester, call, direct contact) as small badges
  - Status: Funding (refundable), Active, Revenue generating, Refunding
- Row expands to show the distribution history and a value-over-time chart.
- Empty state: Happy with "Nothing here yet. Find an app you love." and a link to the gallery.
- Trade is not available, so there is a disabled "Sell / Transfer" button with a "Coming soon" tooltip.

### 4. Trade (`/trade`)

Coming Soon page. Short explainer ("A marketplace for stakes: buy, sell and swap ownership certificates"), a preview illustration, and an **email form** ("Notify me when Trade opens"). On submit: success message and confirmation email. Optional checkbox: "Also invite me to the beta team".

### 5. Beta signup

- **BETA pill** in the nav opens a modal; the top banner and footer link there too; `/beta` exists as a plain page.
- Form: email (required), name (optional), "I am a…" (investor / app developer / both), optional note. Stored in the `beta_signup` table. Confirmation email.

### 6. About (`/about`)

Mission, the story (apps deserve patient capital, makers deserve fans who also own a piece), the team (App Sciences), principles (transparent, simple, honest about risk), and a risk and legal summary linking to a full disclosure.

### 7. How it works (`/how-it-works`)

Illustrated four-step flow with the same visual language as the rest of the site:

1. **Discover**: browse apps, try them right on the page.
2. **Invest**: pay with APLOV; you receive an ownership NFT.
3. **Build**: the developer builds and launches; you can help test.
4. **Earn**: app store revenue is verified, deposited, and you claim your share.

Plus sections on: what APLOV is and how to get it, what the AI projection is (and is not), what the tester perks are, what happens if a campaign misses its goal (refund), and a short risk section. FAQ accordion.

### 8. Login (`/login`)

- **Continue with Google** (OAuth).
- **Email**: enter email, receive a 6-digit code (10 minute expiry, 5 attempts, rate-limited per email and IP), enter code to sign in. No password.
- First sign-in creates the user. Wallet connection is a separate, later step in Settings.
- Sessions via secure, httpOnly cookies.

### 9. Buy APLOV (`/buy-aplov`, also a modal)

- Choose a coin: **ETH, USDC, USDT, BTC, SOL** (v1 simulates all; real routing later).
- Enter the pay amount or APLOV amount; live quote with rate, fee and slippage note (mock numbers).
- Network hint (Base is preferred and cheapest; other chains bridged later).
- **Connect wallet** (stub) and **Confirm purchase** (simulated). The balance chip updates after a mock confirmation.
- Banner: *"Demo mode: no real funds move."*

---

## Perks Tiers: Tester, Call, Direct Contact

Shown on every app page, as three cards. Perks are earned by **holding a minimum stake in that app** (not by paying extra), and stay active while the stake is held.

| Tier | What you get | Recommended minimum stake (per app) |
|---|---|---|
| **Test team** | Early access as an official tester of the app, via the stores' test programs | **100 APLOV** |
| **Developer call** | Everything above, plus a group or 1:1 call with the developer (scheduled by the developer, typically one per stage milestone) | **1,000 APLOV** |
| **Direct contact** | Everything above, plus a direct channel to the developer (email or chat; the developer chooses the channel) | **5,000 APLOV** |

Rationale: the test tier is low enough to attract many testers; the call tier is meaningful but reachable for engaged backers; the direct tier is reserved for large backers so developers are not overwhelmed. Developers can set a *higher* minimum on their own app, but not a lower one. For v1 APLOV is displayed at a placeholder rate of **1 APLOV = $1.00**, so these are roughly $100 / $1,000 / $5,000.

**Explanation shown on the page ("What is the test team?")**
> Before an app is public, the app stores let developers invite a small group of real people to try it. On Google Play this is called *closed testing* (Google requires a minimum number of testers who keep the app installed for a set number of days before a new app can go public). On Apple it is *TestFlight*, which can invite up to 10,000 external testers. As a test team member you get an invite, use the app, and tell the developer what is working and what isn't. You help the app launch, and you see it first. You can leave the team any time.

Mechanics (v1 simulated): after investing, the perk card turns active; a "Join test team" button collects the user's store account email (Google account for Play, Apple ID email for TestFlight) and stores it with the app. Developers export this list later. Perks are checked by looking up the user's NFT balance for the app.

---

## AI Revenue Projection

- A `Projection` object per app: `median12m`, `low12m`, `high12m` (80% interval), `confidence` (Low / Medium / High), `riskTier`, `drivers[]`, `generatedAt`, `modelVersion`.
- v1: seeded mock values per app, deterministic so pages are stable.
- Later: produced by `packages/ai` using store category data, comparable apps and team track record (see `spec.md` §3.4). The UI only reads the `Projection` type.
- Always paired with the disclaimer. Never presented as a guarantee. Never shown without its range.

---

## Happy, the AI Chat Companion

**Character**: Happy is a friendly **mutt dog with cow-like coloring: white with brown spots** (one big brown patch over one eye, spotted back, floppy ears, one ear brown, one white). Warm, a bit goofy, loyal, curious. Delivered as an inline SVG mascot with a few states: idle, wagging, thinking (head tilt), happy, and sleeping.

**Presence**: a floating round button bottom right on every page, with a small wagging tail and a speech bubble hint on first visit ("Woof! Want help picking an app?"). Opens a chat panel (drawer on mobile).

**Abilities (v1)**
- Explain how Applove works, what APLOV and the NFTs are, what the tester perks are.
- Explain an app on the current page, its stats and its AI projection, and compare apps.
- Recommend apps based on stated interests and risk comfort.
- Suggest filters ("Show me beta stage apps under 10k downloads") and apply them with a button.

**Guardrails**
- Not a financial advisor. States risk plainly, never promises returns, never says "you should invest".
- Always grounds numbers in the app data supplied in context; says so when it doesn't know.
- No requests for private keys or seed phrases; warns users never to share them.
- Personality stays light and brief, with an occasional "woof". Not at the expense of clarity.

**Implementation**
- `POST /api/happy` streams a response from the Anthropic API. System prompt defines persona and guardrails; context includes the current page and a compact JSON of relevant apps.
- If `ANTHROPIC_API_KEY` is absent, a scripted mock responder keeps the UI demoable.
- Conversation is kept in the browser for the session (and stored per user later). Rate limited.

---

## Theme and Visual Design

**Feel**: simple, elegant, easy on the eye. Generous whitespace, soft shadows, rounded corners (12 to 20px), calm color, large photographic or illustrated app imagery doing the heavy lifting. Subtle motion only.

**Light and dark mode, prominently featured**
- A sun/moon **toggle in the main nav**, always visible (also on mobile), three states: Light, Dark, System. Default is System.
- Choice is saved and applied before first paint (no flash).
- Both themes are designed, not inverted: dark is a warm deep charcoal (not pure black), light is warm off-white (not pure white).
- Images and charts have per-theme treatments (overlay scrims on carousel images, chart palettes validated for contrast in both).
- A short theme transition (150ms), disabled for `prefers-reduced-motion`.

**Color tokens (CSS variables; starting palette, subject to taste)**

| Token | Light | Dark |
|---|---|---|
| `--bg` | `#FBF9F6` | `#16151A` |
| `--surface` | `#FFFFFF` | `#1F1E25` |
| `--surface-2` | `#F3EFE9` | `#27262E` |
| `--text` | `#1D1B20` | `#EDEAE4` |
| `--muted` | `#6B6672` | `#A19CAA` |
| `--border` | `#E7E1D8` | `#34323C` |
| `--brand` (heart coral) | `#E5484D` | `#FF6369` |
| `--accent` (calm teal) | `#2A9D8F` | `#4DC3B4` |
| `--gold` (APLOV) | `#C98A1B` | `#E3AE45` |

**Type**: a friendly geometric sans for headings (e.g. Plus Jakarta Sans or Outfit) and Inter for body; tabular numerals for stats.

**Stage badge colors** (consistent, color-blind safe with icon + label): Idea (gray), In development (blue), Alpha (violet), Beta (amber), Launched (green), Mature (teal).

**Accessibility**: WCAG 2.2 AA contrast, full keyboard support, visible focus rings, semantic landmarks, alt text for every image, carousel controls labelled, reduced-motion respected.

**Responsive**: mobile first, tested at 360, 768, 1280, 1920 widths.

---

## Data Model (v1 mock; shapes are what the real API will return)

```ts
type Stage = "idea" | "development" | "alpha" | "beta" | "launched" | "mature";
type Platform = "ios" | "android" | "web" | "chrome" | "desktop";

interface Developer {
  slug: string;            // e.g. "app-sciences"
  name: string;
  bio: string;
  avatarUrl: string;
  contact: { method: "email" | "chat" | "none"; handle?: string };
}

interface AppListing {
  slug: string;
  name: string;
  tagline: string;
  description: string;
  iconUrl: string;
  heroUrl: string;          // large carousel image
  category: string;
  platforms: Platform[];
  stage: Stage;
  developerSlug: string;
  funding: { goalAPLOV: number; raisedAPLOV: number; backers: number; endsAt: string; stakePriceAPLOV: number; minInvestAPLOV: number };
  traction: { downloads: number; monthlyRevenueUSD: number; revenueHistory: number[]; downloadHistory: number[] };
  projection: Projection;
  preview: { liveUrl?: string; videos: Video[]; screenshots: Image[] };   // at least one non-empty
  revenueShare: { percentToHolders: number; payout: "monthly" | "quarterly"; termYears: number };
  perks: { testMin: number; callMin: number; directMin: number };
  storeLinks: { appStore?: string; playStore?: string; chromeStore?: string; web?: string };
  milestones: { title: string; date: string; done: boolean }[];
  isDemoData: true;
}

interface Holding {           // an ownership NFT
  tokenId: string;
  appSlug: string;
  investedAPLOV: number;
  currentValueAPLOV: number;
  sharePercent: number;
  claimedAPLOV: number;
  claimableAPLOV: number;
  status: "funding" | "active" | "revenue" | "refunding";
  purchasedAt: string;
}
```

A `Repository` interface (`listApps(filters)`, `getApp(slug)`, `getHoldings(userId)`, `getProjection(slug)`) is the only thing the UI calls. v1 implements it with mock data; later with the real API and subgraph.

---

## Placeholder Apps

All stats, funding, projections and images are **made-up demo values** and flagged `isDemoData`. The set below comes from your request plus what I found in your NoteDude notes (project tags and notes). Developer for all of them is **App Sciences** (`app-sciences`) unless you say otherwise; I'd add one or two fake third-party developers (e.g. "Mochi Labs", "Northwind Apps") so the developer filter visibly does something.

| Slug | Name | What I know | Notes |
|---|---|---|---|
| `applove` | **Applove** | This platform itself | Fun meta-listing |
| `shredinvaders` | **ShredInvaders** | Name only; no details found | Needs your description. Placeholder: retro arcade-style game |
| `notedude` | **NoteDude** | Keyboard-first notes app with vi-style shortcuts, tags, MCP server; has a paid tier and a planned feature fundraiser | Most real: live web preview candidate |
| `todude` | **ToDude** | Checklist / task companion to NoteDude (todo, in progress, done) | |
| `lickdude` | **LickDude** | Name only | Needs description. Placeholder: music practice / licks app |
| `doughdude` | **DoughDude** | Name only | Needs description. Placeholder: baking / dough calculator |
| `morningdude` | **MorningDude** | Name only | Needs description. Placeholder: morning routine / briefing app |
| `findmydude` | **FindMyDude** | A service for recovering lost or stolen items | |
| `casualfax` | **CasualFax** | Fax app, no account needed, upfront price for large page counts, possibly MCP and marketplace listings | |
| `lildude` | **LilDude** | Name only; a note mentions crowd-financing promotion | Needs description |
| `pawndude` | **PawnDude** | Name only; a note mentions reclaiming and reselling items such as old wood doors | Needs description |

Looked up and **not** used:
- Linear and Notion only contain Trinsic work projects (CallSniper, TaskGlance, InstaAuth, etc.), which look like client or employer work, so I left them out.
- **GoodDude** (vending plus micro-shelter) is a humanitarian infrastructure project, not an app, so it doesn't fit.
- **App Sciences** appears as a consultancy/app studio ("AI is the new UI"), which is a natural developer entity.

Please confirm the list and correct the guessed descriptions.

---

## Security, Privacy, Compliance

- No real funds in v1. Every money screen shows a persistent "Demo mode" notice.
- **Securities notice**: revenue-share tokens are likely regulated securities in many places. Before real money, we need jurisdiction gating, accreditation/KYC as required, and legal sign-off. The beta front end shows risk language and a "not available in all regions" notice.
- Email forms: validation, honeypot, per-IP rate limit, double opt-in email, easy unsubscribe, clear consent text.
- Auth: login codes hashed at rest, single use, expiring, rate limited; OAuth state/PKCE; CSRF protection on all mutations.
- Iframe previews are sandboxed (`allow-scripts allow-same-origin` only where required, never `allow-top-navigation`), with a CSP allowlist of preview origins.
- Standard headers (CSP, HSTS, frame-ancestors, Referrer-Policy). No secrets in client bundles.
- Privacy: only email, name and avatar stored in v1. Analytics are privacy-friendly and cookieless where possible.

---

## Open Decisions and My Defaults

| # | Question | Default I'll use unless you say otherwise |
|---|---|---|
| 1 | **APLOV vs USDC.** `contracts.md` says funding in USDC; this spec says APLOV. | Invest in APLOV in the UI. The contract layer can accept APLOV directly or swap to USDC at deposit. Needs a decision before contracts are built. |
| 2 | What backs APLOV's price (floating, pegged, platform credit)? | UI shows a mock fixed rate of 1 APLOV = $1.00. Real economics TBD. |
| 3 | Are "NFTs" ERC-721 (one per stake) or ERC-1155 (per app, with quantity)? | One NFT per investment in the UI (a certificate). Contracts decide the format. |
| 4 | Real developer for each placeholder app | App Sciences for all, plus two fake outside developers for the demo |
| 5 | Preview hosting | Link to each app's own hosted web build in an iframe. NoteDude first. |
| 6 | Email provider | Resend |
| 7 | Hosting | Vercel for the beta |
| 8 | Brand: name styling and logo | "Applove" with a heart-in-app-tile mark; I'll draft it |

---

## Acceptance Criteria

1. `npm run dev:web` starts the app; `npm run build` and `npm test` pass for `apps/web`.
2. Home shows a working carousel with three boards (invested, revenue, downloads), each slide showing an AI revenue projection.
3. Filters for category, stage, downloads, revenue, platform, sort and search all work, combine, persist in the URL, and show removable chips.
4. Clicking a developer name from the carousel, a tile, an app page or a holding filters the home list to that developer.
5. All 11 placeholder apps render in the grid and have a working detail page with at least one of preview / video / screenshots.
6. App page has the AI projection chart, the invest panel (APLOV), the buy-APLOV path, and the three perk tiers with the test-team explanation.
7. Simulated invest flow creates a holding visible under **My investments** with value, earnings and a working (simulated) claim.
8. Google login and email-code login both work in a configured environment; sessions persist; sign out works.
9. Trade page collects emails; Beta pill and banner open the beta signup; both persist to the database and send confirmation.
10. Happy appears on every page, answers using app context, follows the guardrails, and works in mock mode without an API key.
11. Light/dark/system toggle is in the nav on all breakpoints, with no flash on load, and both themes pass AA contrast.
12. Lighthouse accessibility score 95+ on Home and App pages; no horizontal scroll at 360px.
13. A visible "Beta / demo data" indication on every page.

---

## Suggested Implementation Order

1. Scaffold Next.js in `apps/web` with Tailwind, shadcn/ui, theme tokens and light/dark toggle.
2. Shared types and the mock data repository with the 11 apps and 3 developers.
3. Layout: nav, beta banner, footer, Happy button (UI only).
4. Home: carousel, filter bar (URL state), tile grid, developer filter.
5. App detail page: preview/video/gallery, stats, projection chart, perks, invest panel.
6. Auth (Google + email code) with Prisma/SQLite; waitlist and beta forms and API routes.
7. Buy APLOV flow and simulated invest; My investments page.
8. Trade, About, How it works pages.
9. Happy: SVG mascot, chat panel, `/api/happy` with Anthropic streaming and a mock fallback.
10. Accessibility, responsive and Playwright smoke tests; polish.
