export const metadata = { title: "How it works — applov" };

export default function How() {
  return (
<div className="guide">
<h1>How applov works</h1>
<p className="lead">applov lets people fund apps before they launch. Investors buy a stake and receive an NFT. Developers get funded. Everyone shares the revenue the app earns.</p>

<section id="g-investors" className="gsec">
<h2>Guide for investors</h2>
<ol className="steps">
<li><b>Find an app</b><span>Browse the gallery. Each app shows its phone preview, funding goal, the dev team, an AI revenue projection and a risk score. Many asks are under $1,000, with stakes starting at $10.</span></li>
<li><b>Choose your amount</b><span>Pick how much you want to put in, at or above the app’s minimum. Your share of the app’s revenue is proportional to your stake.</span></li>
<li><b>Invest</b><span>Check out like any online purchase. Your money is held safely until the app reaches its funding goal. If the goal is not reached by the deadline, you get your money back.</span></li>
<li><b>Get your NFT</b><span>When the app is funded, you receive an NFT that proves your stake. applov holds it for you, so there is nothing to set up or look after. Log in to applov as an investor any time to see your NFT.</span></li>
<li><b>Watch your earnings</b><span>Once the app earns, payouts are calculated from the official app store revenue reports and paid out regularly. Log in to see your payouts, total earnings and how each app is doing.</span></li>
</ol>
<div className="callout">
<h3>Optional: join the test team</h3>
<p>Investors can choose to join an app’s test team. You get weekly updates, early builds to try, a way to send feedback, and the chance to meet the dev team directly. It is entirely optional and does not change your stake or your payouts.</p>
</div>
</section>

<section id="g-developers" className="gsec">
<h2>Guide for developers</h2>
<ol className="steps">
<li><b>Submit your app</b><span>Add the app name, description, platform, team and app store link (an existing listing or a planned one). Set a funding goal under $10,000 and the profit-share terms for investors.</span></li>
<li><b>Verify your store listing</b><span>We check your app store listing so investors know the revenue reports we use come from a real, verified app.</span></li>
<li><b>Run your campaign</b><span>Watch funding progress and investor count, post updates and milestones, and invite investors into your test team to get feedback while you build.</span></li>
<li><b>Get funded</b><span>When the goal is met, escrow releases the funds to you and the investors’ NFTs are issued. If it is not met, everyone is refunded.</span></li>
<li><b>Connect revenue routing</b><span>Before launch you set up the required revenue routing (see below). Without it an app cannot be listed.</span></li>
<li><b>Launch and report</b><span>Once live, earnings are split automatically on each payout cycle. Your dashboard shows app store earnings, distributions made, who holds what stake and the contract status.</span></li>
<li><b>Use APLOV for your stack</b><span>Pay for hosting and infrastructure in APLOV for discounted rates (see APLOV below).</span></li>
</ol>
</section>

<section id="g-routing" className="gsec">
<h2>How app revenue is routed</h2>
<p>Every funded app must send its app store earnings through applov’s financial routing mechanism. This is a requirement for listing, and it is what lets investor payouts be guaranteed instead of depending on the developer to pay out by hand.</p>
<div className="flow" role="img" aria-label="App store revenue goes to the revenue router, which pays NFT holders, the developer and a platform fee">
<div className="fl-box"><b>App stores</b><span>iOS, Google Play, Chrome and others</span></div>
<div className="fl-arrow" aria-hidden="true">→</div>
<div className="fl-box fl-main"><b>Revenue router</b><span>Reads the verified app store report and splits the payout</span></div>
<div className="fl-arrow" aria-hidden="true">→</div>
<div className="fl-out">
<div className="fl-box"><b>NFT holders</b><span>Their agreed profit share, pro rata</span></div>
<div className="fl-box"><b>Developer</b><span>The rest of the revenue</span></div>
<div className="fl-box"><b>Platform fee</b><span>Fee level to be announced</span></div>
</div>
</div>
<ul className="plain">
<li>The developer points the app’s store payouts at the router when setting up the campaign.</li>
<li>App store revenue reports act as the source of truth. The router reads them and calculates each payout.</li>
<li>Payouts are split automatically on a regular schedule, for example monthly, with no manual step.</li>
<li>Every payout is recorded on the blockchain, and investors see it in their applov account.</li>
</ul>
</section>

<section id="g-nft" className="gsec">
<h2>Your NFT</h2>
<p>Each stake is represented by an NFT. It records how much of the app you own and entitles you to your share of every payout. applov holds it on your behalf, and you can view it, along with all related earnings information, by logging in as an investor.</p>
<ul className="plain">
<li><b>Nothing to manage:</b> there are no wallets or extra accounts to set up. Your applov login is all you need.</li>
<li><b>Eventually tradeable:</b> a marketplace for buying and selling NFTs is planned, so you will be able to exit early or buy into an app that is already earning. It is not live yet.</li>
<li>Whoever owns the NFT receives the payouts, so a trade moves the future revenue share with it.</li>
</ul>
</section>

<section id="g-aplov" className="gsec">
<h2>APLOV, the app currency</h2>
<p>APLOV is the native currency of the applov ecosystem. Developers who pay in APLOV can get discounted hosting and infrastructure services for their apps.</p>
<ul className="plain">
<li><b>What it covers:</b> hosting, cloud and other backend infrastructure an app needs to run.</li>
<li><b>Who benefits:</b> developers, who lower their running costs, and investors, since lower costs leave more revenue to share.</li>
<li><b>How:</b> pay a service invoice in APLOV instead of cash and the discount is applied at checkout.</li>
</ul>
<p className="fine">Discount levels, partner providers and APLOV supply details will be published before launch.</p>
</section>

<p className="fine">Investing in apps carries risk and AI projections are estimates, not promises. Terms, fees and eligibility are finalized before launch and may depend on where you live.</p>
</div>
  );
}
