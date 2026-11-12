"use client";
import Link from "next/link";
import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useSession } from "@/lib/session";
import { holdings, PAYOUTS, usd2, fdate } from "@/lib/portfolio";

export default function Portfolio() {
  const session = useSession();
  const router = useRouter();
  useEffect(() => {
    if (session === null) router.replace("/login");
  }, [session, router]);
  if (!session) return null;

  const invested = holdings.reduce((a, h) => a + h.stake, 0);
  const earned = holdings.reduce((a, h) => a + h.earned, 0);

  return (
    <div className="pf">
      <h1>Your portfolio</h1>
      <p className="muted" style={{ margin: 0 }}>Signed in as {session.email}. applov holds your NFTs for you.</p>
      <div className="pf-stats">
        <div className="pf-stat"><b>{usd2(invested)}</b><span>Total invested</span></div>
        <div className="pf-stat"><b>{usd2(earned)}</b><span>Total earned</span></div>
        <div className="pf-stat"><b>{holdings.length}</b><span>NFTs held</span></div>
        <div className="pf-stat"><b>Dec 1, 2026</b><span>Next payout</span></div>
      </div>

      <section className="section">
        <h2>Your NFTs</h2>
        <div className="nfts">
          {holdings.map((h) => (
            <article className="nft" key={h.project.id}>
              <div className="nft-art" style={{ background: `linear-gradient(160deg, hsl(${h.project.hue} 80% 58%), hsl(${(h.project.hue + 40) % 360} 75% 34%))` }}>
                <span className="nft-id">NFT #{h.token}</span>
                {h.project.emoji}
              </div>
              <div className="nft-body">
                <span className={"tag" + (h.earning ? " earn" : "")}>{h.statusLabel}</span>
                <h3>{h.project.name}</h3>
                <dl>
                  <div><dt>Your stake</dt><dd>{usd2(h.stake)}</dd></div>
                  <div><dt>Revenue share</dt><dd>{h.share.toFixed(2)}%</dd></div>
                  <div><dt>Earned so far</dt><dd>{usd2(h.earned)}</dd></div>
                </dl>
                <Link className="more" href={`/projects/${h.project.id}`}>View app →</Link>
              </div>
            </article>
          ))}
        </div>
      </section>

      <section className="section">
        <h2>Recent payouts</h2>
        <table className="tbl">
          <thead><tr><th>Date</th><th>App</th><th>Amount</th></tr></thead>
          <tbody>
            {PAYOUTS.map((p) => (
              <tr key={p.date + p.id}><td>{fdate(p.date)}</td><td>{p.name}</td><td>{usd2(p.amount)}</td></tr>
            ))}
          </tbody>
        </table>
        <p className="fine">Payouts are calculated from the official app store revenue reports. Sample data for this preview.</p>
      </section>
    </div>
  );
}
