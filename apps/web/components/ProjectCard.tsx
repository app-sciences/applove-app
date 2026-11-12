import Link from "next/link";
import PhoneFrame from "./PhoneFrame";
import { Project, usd, pct } from "@/lib/projects";

export default function ProjectCard({ project: p }: { project: Project }) {
  return (
    <Link href={`/projects/${p.id}`} className="card">
      <div className="card-phone">
        <PhoneFrame project={p} width={170} />
      </div>
      <div className="card-body">
        <span className="chip">{p.category}</span>
        <h3>{p.name}</h3>
        <p className="muted">{p.tagline}</p>
        <div className="bar"><div style={{ width: `${pct(p)}%` }} /></div>
        <div className="stats">
          <div><b>{usd(p.raisedAmount)}</b><span>raised of {usd(p.targetAmount)}</span></div>
          <div><b>{p.investorCount}</b><span>investors</span></div>
          <div><b>{usd(p.minInvestment)}</b><span>min.</span></div>
        </div>
      </div>
    </Link>
  );
}
