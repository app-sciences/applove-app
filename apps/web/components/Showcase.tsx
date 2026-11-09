"use client";
import { useState } from "react";
import Link from "next/link";
import PhoneFrame from "./PhoneFrame";
import { projects, usd, type Project } from "@/lib/projects";

type Live = Record<string, { raised: number; investors: number; mine: number }>;

const initialOpen = Math.max(0, projects.findIndex((p) => p.screenshot));

export default function Showcase() {
  const [open, setOpen] = useState(initialOpen);
  const [live, setLive] = useState<Live>({});
  const [amount, setAmount] = useState<number>(projects[initialOpen].minInvestment);
  const [done, setDone] = useState<number | null>(null);

  const select = (i: number) => {
    setOpen(i);
    setAmount(projects[i].minInvestment);
    setDone(null);
  };

  const view = (p: Project) => {
    const l = live[p.id];
    return { raised: p.raisedAmount + (l?.mine ?? 0), investors: p.investorCount + (l ? l.investors : 0), mine: l?.mine ?? 0 };
  };

  const invest = (p: Project, v: ReturnType<typeof view>) => {
    const remaining = p.targetAmount - v.raised;
    if (!Number.isInteger(amount) || amount < p.minInvestment || amount > remaining) return;
    setLive({ ...live, [p.id]: { raised: v.raised + amount, investors: (live[p.id]?.investors ?? 0) + (v.mine ? 0 : 1), mine: v.mine + amount } });
    setDone(amount);
  };

  return (
    <div className="show" role="list">
      {projects.map((p, i) => {
        const isOpen = i === open;
        const v = view(p);
        const remaining = p.targetAmount - v.raised;
        const pctRaised = Math.min(100, Math.round((v.raised / p.targetAmount) * 100));
        const canInvest = p.status === "active" && remaining > 0;
        const bad = !Number.isInteger(amount) || amount < p.minInvestment || amount > remaining;
        const quick = [p.minInvestment, p.minInvestment * 2, p.minInvestment * 5, p.minInvestment * 10].filter((q) => q <= remaining);
        const bg = `linear-gradient(170deg, hsl(${p.hue} 80% 58%), hsl(${(p.hue + 40) % 360} 75% 36%))`;
        return (
          <div key={p.id} role="listitem" className={"pane" + (isOpen ? " open" : "")} style={isOpen ? undefined : { background: bg }}>
            {!isOpen && (
              <button className="pane-tab" aria-expanded="false" onClick={() => select(i)}>
                <span className="pane-emoji">{p.emoji}</span>
                <span className="pane-name">{p.name}</span>
              </button>
            )}
            {isOpen && (
              <div className="pane-body">
                <div className="pane-phone" style={{ background: `linear-gradient(170deg, hsl(${p.hue} 80% 58% / .22), hsl(${(p.hue + 40) % 360} 75% 36% / .08))` }}>
                  <PhoneFrame project={p} width={230} />
                </div>
                <div className="pane-info">
                  <span className="chip">{p.category}</span>
                  <h2>{p.name}</h2>
                  <p className="muted pane-desc">{p.description}</p>
                  <div className="bar"><div style={{ width: `${pctRaised}%` }} /></div>
                  <div className="stats">
                    <div><b>{usd(v.raised)}</b><span>raised of {usd(p.targetAmount)}</span></div>
                    <div><b>{v.investors}</b><span>investors</span></div>
                    <div><b>{usd(p.minInvestment)}</b><span>min.</span></div>
                  </div>

                  <div className="invest">
                    {done !== null ? (
                      <div className="invest-ok" role="status">
                        <b>✓ You staked {usd(done)} in {p.name}</b>
                        <span>You now own {((v.mine / p.targetAmount) * 100).toFixed(2)}% of the revenue share. Your NFT would be minted when the goal is reached.</span>
                        <button className="link" onClick={() => setDone(null)}>Invest more</button>
                        <small className="muted">Prototype only. No real funds move.</small>
                      </div>
                    ) : canInvest ? (
                      <>
                        <div className="quick">
                          {quick.map((q) => (
                            <button key={q} className={amount === q ? "on" : ""} onClick={() => setAmount(q)}>{usd(q)}</button>
                          ))}
                        </div>
                        <label className="amt">
                          <span>Amount (USD)</span>
                          <input type="number" inputMode="numeric" min={p.minInvestment} max={remaining} value={Number.isNaN(amount) ? "" : amount}
                            onChange={(e) => setAmount(e.target.valueAsNumber)} aria-invalid={bad} />
                        </label>
                        <p className="muted own">
                          {bad
                            ? `Enter ${usd(p.minInvestment)} to ${usd(remaining)}.`
                            : `You would own ${((amount / p.targetAmount) * 100).toFixed(2)}% of the revenue share.`}
                        </p>
                        <button className="btn" disabled={bad} onClick={() => invest(p, v)}>Invest {bad ? "" : usd(amount)}</button>
                      </>
                    ) : (
                      <button className="btn" disabled>{p.status === "upcoming" ? "Opening soon" : "Fully funded"}</button>
                    )}
                  </div>
                  <Link className="more" href={`/projects/${p.id}`}>Full details →</Link>
                </div>
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}
