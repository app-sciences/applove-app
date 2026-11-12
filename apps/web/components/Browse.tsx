"use client";
import { useMemo, useState } from "react";
import Showcase from "./Showcase";
import ProjectCard from "./ProjectCard";
import { projects, categories, pct, type Project } from "@/lib/projects";

type Opt = [string, string];
type Filters = {
  q: string; cat: string; status: string[]; platform: string[]; rev: string; goal: string; minInv: string;
  progress: string; from: string; to: string; risk: string[]; test: boolean; closing: boolean; sort: string;
};
const F0: Filters = { q: "", cat: "all", status: [], platform: [], rev: "any", goal: "any", minInv: "any", progress: "any", from: "", to: "", risk: [], test: false, closing: false, sort: "featured" };

const REV: Opt[] = [["any", "Any revenue"], ["0-5000", "Under $5,000"], ["5000-15000", "$5,000 – $15,000"], ["15000-30000", "$15,000 – $30,000"], ["30000-", "$30,000 +"]];
const GOAL: Opt[] = [["any", "Any goal"], ["0-1000", "Under $1,000"], ["1000-5000", "$1,000 – $5,000"], ["5000-", "$5,000 +"]];
const MINV: Opt[] = [["any", "Any minimum"], ["0-11", "Up to $10"], ["0-26", "Up to $25"]];
const PROG: Opt[] = [["any", "Any progress"], ["0-25", "Under 25% funded"], ["25-75", "25% – 75% funded"], ["75-101", "Almost funded (75%+)"]];
const STATUS: Opt[] = [["active", "Open now"], ["upcoming", "Opening soon"], ["funded", "Fully funded"]];
const PLAT = ["iOS", "Android", "Web", "Chrome"];
const RISK = ["Low", "Medium", "High"];
const SORT: Opt[] = [["featured", "Featured"], ["active", "Most active"], ["closing", "Closing soon"], ["revenue", "Highest projected revenue"], ["launch", "Launching soonest"], ["small", "Smallest ask"], ["funded", "Most funded"]];

const inR = (v: string, x: number) => {
  if (v === "any") return true;
  const [a, b] = v.split("-");
  return x >= +a && (b === "" || x < +b);
};

function apply(f: Filters): Project[] {
  const q = f.q.trim().toLowerCase();
  const list = projects.filter(
    (p) =>
      (!q || `${p.name} ${p.tagline} ${p.description} ${p.category}`.toLowerCase().includes(q)) &&
      (f.cat === "all" || p.category === f.cat) &&
      (!f.status.length || f.status.includes(p.status)) &&
      (!f.platform.length || p.platforms.some((x) => f.platform.includes(x))) &&
      inR(f.rev, p.projectedRevenue) && inR(f.goal, p.targetAmount) && inR(f.minInv, p.minInvestment) && inR(f.progress, pct(p)) &&
      (!f.from || p.launchDate >= f.from) && (!f.to || p.launchDate <= f.to) &&
      (!f.risk.length || f.risk.includes(p.risk)) &&
      (!f.test || p.testTeam) && (!f.closing || (p.status === "active" && p.daysLeft <= 30)),
  );
  const by: Record<string, (a: Project, b: Project) => number> = {
    active: (a, b) => b.investorCount - a.investorCount,
    closing: (a, b) => a.daysLeft - b.daysLeft,
    revenue: (a, b) => b.projectedRevenue - a.projectedRevenue,
    launch: (a, b) => a.launchDate.localeCompare(b.launchDate),
    small: (a, b) => a.targetAmount - b.targetAmount,
    funded: (a, b) => b.raisedAmount / b.targetAmount - a.raisedAmount / a.targetAmount,
  };
  return by[f.sort] ? [...list].sort(by[f.sort]) : list;
}

const activeCount = (f: Filters) =>
  f.status.length + f.platform.length + f.risk.length + +(f.rev !== "any") + +(f.goal !== "any") + +(f.minInv !== "any") +
  +(f.progress !== "any") + +!!(f.from || f.to) + +f.test + +f.closing;

export default function Browse() {
  const [f, setF] = useState<Filters>(F0);
  const [open, setOpen] = useState(false);
  const list = useMemo(() => apply(f), [f]);
  const n = activeCount(f);
  const filtered = n > 0 || f.q.trim() !== "" || f.cat !== "all" || f.sort !== "featured";
  const set = <K extends keyof Filters>(k: K, v: Filters[K]) => setF((o) => ({ ...o, [k]: v }));
  const toggle = (k: "status" | "platform" | "risk", v: string) =>
    setF((o) => ({ ...o, [k]: o[k].includes(v) ? o[k].filter((x) => x !== v) : [...o[k], v] }));

  const Chips = ({ k, items }: { k: "status" | "platform" | "risk"; items: (string | Opt)[] }) => (
    <div className="fchips">
      {items.map((it) => {
        const [v, l] = Array.isArray(it) ? it : [it, it];
        return <button key={v} className="fchip" aria-pressed={f[k].includes(v)} onClick={() => toggle(k, v)}>{l}</button>;
      })}
    </div>
  );
  const Sel = ({ k, opts }: { k: "rev" | "goal" | "minInv" | "progress"; opts: Opt[] }) => (
    <select value={f[k]} onChange={(e) => set(k, e.target.value)}>
      {opts.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
    </select>
  );

  const small = list.filter((p) => p.targetAmount < 1000);
  const rest = list.filter((p) => p.targetAmount >= 1000).sort((a, b) => b.investorCount - a.investorCount);

  return (
    <>
      <div className="tbar">
        <select aria-label="Sort by" value={f.sort} onChange={(e) => set("sort", e.target.value)}>
          {SORT.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
        </select>
        <select aria-label="Category" value={f.cat} onChange={(e) => set("cat", e.target.value)}>
          <option value="all">All categories</option>
          {categories.map((c) => <option key={c}>{c}</option>)}
        </select>
        <input type="search" placeholder="Search apps" aria-label="Search apps" value={f.q} onChange={(e) => set("q", e.target.value)} />
        <button className={"fbtn" + (n ? " has" : "")} aria-label="Filters" title="Filters" aria-expanded={open} aria-controls="fpanel" onClick={() => setOpen(!open)}>
          <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden="true">
            <path d="M4 6h9M17 6h3M4 12h3M11 12h9M4 18h11M19 18h1" /><circle cx="15" cy="6" r="2" /><circle cx="9" cy="12" r="2" /><circle cx="17" cy="18" r="2" />
          </svg>
          {n > 0 && <span className="badge">{n}</span>}
        </button>
        <span className="count" aria-live="polite">{list.length} {list.length === 1 ? "app" : "apps"}</span>
      </div>

      <div className="fpanel" id="fpanel" hidden={!open}>
        <div className="fg"><h4>Status</h4><Chips k="status" items={STATUS} /></div>
        <div className="fg"><h4>Platform</h4><Chips k="platform" items={PLAT} /></div>
        <div className="fg"><h4>AI projected 3-yr revenue</h4><Sel k="rev" opts={REV} /></div>
        <div className="fg"><h4>Funding goal</h4><Sel k="goal" opts={GOAL} /></div>
        <div className="fg"><h4>Minimum investment</h4><Sel k="minInv" opts={MINV} /></div>
        <div className="fg"><h4>Funding progress</h4><Sel k="progress" opts={PROG} /></div>
        <div className="fg">
          <h4>Projected launch</h4>
          <div className="dates">
            <label>From<input type="date" value={f.from} onChange={(e) => set("from", e.target.value)} /></label>
            <label>To<input type="date" value={f.to} onChange={(e) => set("to", e.target.value)} /></label>
          </div>
        </div>
        <div className="fg"><h4>Risk</h4><Chips k="risk" items={RISK} /></div>
        <div className="fg">
          <h4>More</h4>
          <div className="fchips">
            <button className="fchip" aria-pressed={f.test} onClick={() => set("test", !f.test)}>Open test team</button>
            <button className="fchip" aria-pressed={f.closing} onClick={() => set("closing", !f.closing)}>Closing within 30 days</button>
          </div>
        </div>
        <div className="fact">
          <button className="clr" onClick={() => setF(F0)}>Clear all</button>
          <button className="done" onClick={() => setOpen(false)}>Show results</button>
        </div>
      </div>

      {list.length === 0 ? (
        <div className="empty">
          <h3>No apps match these filters</h3>
          <button className="btn" style={{ width: "auto", padding: "10px 20px" }} onClick={() => setF(F0)}>Clear filters</button>
        </div>
      ) : (
        <>
          <Showcase list={list} />
          {filtered ? (
            <section className="section">
              <h2>{list.length} {list.length === 1 ? "app matches" : "apps match"}</h2>
              <div className="grid">{list.map((p) => <ProjectCard key={p.id} project={p} />)}</div>
            </section>
          ) : (
            <>
              <section className="section"><h2>Small asks — under $1,000</h2><div className="grid">{small.map((p) => <ProjectCard key={p.id} project={p} />)}</div></section>
              <section className="section"><h2>Most active</h2><div className="grid">{rest.map((p) => <ProjectCard key={p.id} project={p} />)}</div></section>
            </>
          )}
        </>
      )}
    </>
  );
}
