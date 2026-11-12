"use client";
import { useRef, useState } from "react";
import Link from "next/link";
import PhoneFrame from "./PhoneFrame";
import { useInvest } from "./InvestProvider";
import { usd, type Project } from "@/lib/projects";

const own = (x: number, p: Project) => ((x / p.targetAmount) * 100).toFixed(2);

function Slide({ p }: { p: Project }) {
  const { openInvest } = useInvest();
  const [amount, setAmount] = useState<number>(p.minInvestment);
  const remaining = p.targetAmount - p.raisedAmount;
  const can = p.status === "active" && remaining > 0;
  const bad = !Number.isInteger(amount) || amount < p.minInvestment || amount > remaining;
  const quick = [1, 2, 5, 10].map((m) => m * p.minInvestment).filter((q) => q <= remaining);
  const pct = Math.min(100, Math.round((p.raisedAmount / p.targetAmount) * 100));

  return (
    <article className="slide">
      <div className="slide-phone" style={{ background: `linear-gradient(170deg, hsl(${p.hue} 80% 58% / .25), hsl(${(p.hue + 40) % 360} 75% 36% / .06))` }}>
        <PhoneFrame project={p} width={290} />
      </div>
      <div className="slide-info">
        <span className="chip">{p.category}</span>
        <h2>{p.name}</h2>
        <p className="muted slide-desc">{p.description}</p>
        <div className="bar"><div style={{ width: `${pct}%` }} /></div>
        <div className="stats">
          <div><b>{usd(p.raisedAmount)}</b><span>raised of {usd(p.targetAmount)}</span></div>
          <div><b>{p.investorCount}</b><span>investors</span></div>
          <div><b>{usd(p.minInvestment)}</b><span>min.</span></div>
        </div>
        <div className="invest">
          {can ? (
            <>
              <div className="quick">
                {quick.map((q) => <button key={q} className={amount === q ? "on" : ""} onClick={() => setAmount(q)}>{usd(q)}</button>)}
              </div>
              <label className="amt">
                <span>Amount (USD)</span>
                <input type="number" inputMode="numeric" min={p.minInvestment} max={remaining} value={Number.isNaN(amount) ? "" : amount}
                  onChange={(e) => setAmount(e.target.valueAsNumber)} aria-invalid={bad} aria-label="Amount in USD" />
              </label>
              <p className="muted own">{bad ? `Enter ${usd(p.minInvestment)} to ${usd(remaining)}.` : `You would own ${own(amount, p)}% of the revenue share.`}</p>
              <button className="btn" disabled={bad} onClick={() => openInvest(p.name, amount)}>Invest {bad ? "" : usd(amount)}</button>
            </>
          ) : (
            <button className="btn" disabled>{p.status === "upcoming" ? "Opening soon" : "Fully funded"}</button>
          )}
        </div>
        <Link className="more" href={`/projects/${p.id}`}>Full details →</Link>
      </div>
    </article>
  );
}

export default function Showcase({ list }: { list: Project[] }) {
  const rail = useRef<HTMLDivElement>(null);
  const go = (dir: number) => {
    const el = rail.current;
    const s = el?.querySelector<HTMLElement>(".slide");
    if (el && s) el.scrollBy({ left: dir * (s.offsetWidth + 20), behavior: "smooth" });
  };
  return (
    <div className="car-wrap">
      <button className="car-btn prev" aria-label="Previous app" onClick={() => go(-1)}>‹</button>
      <div className="rail" ref={rail} tabIndex={0} aria-label="Featured apps">
        {list.map((p) => <Slide key={p.id} p={p} />)}
      </div>
      <button className="car-btn next" aria-label="Next app" onClick={() => go(1)}>›</button>
    </div>
  );
}
