import { notFound } from "next/navigation";
import PhoneFrame from "@/components/PhoneFrame";
import { getProject, projects, usd, pct } from "@/lib/projects";

export function generateStaticParams() {
  return projects.map((p) => ({ id: p.id }));
}

export default async function ProjectPage({ params }: { params: Promise<{ id: string }> }) {
  const p = getProject((await params).id);
  if (!p) notFound();
  return (
    <div className="detail">
      <div className="detail-phone"><PhoneFrame project={p} width={260} /></div>
      <div className="detail-main">
        <span className="chip">{p.category}</span>
        <h1>{p.name}</h1>
        <p className="lead">{p.description}</p>
        <h2>Investment highlights</h2>
        <ul className="hl">
          <li><b>📈 Market opportunity</b><span>Targeting a growing market with real potential.</span></li>
          <li><b>💡 Innovation</b><span>A unique solution with clear advantages.</span></li>
          <li><b>👥 Strong team</b><span>Experienced builders with a proven track record.</span></li>
        </ul>
      </div>
      <aside className="panel">
        <div className="big">{usd(p.raisedAmount)}</div>
        <div className="muted">raised of {usd(p.targetAmount)} goal</div>
        <div className="bar"><div style={{ width: `${pct(p)}%` }} /></div>
        <dl>
          <div><dt>Progress</dt><dd>{pct(p)}%</dd></div>
          <div><dt>Investors</dt><dd>{p.investorCount}</dd></div>
          <div><dt>Minimum investment</dt><dd>{usd(p.minInvestment)}</dd></div>
          <div><dt>✨ AI projected 3-yr revenue</dt><dd>{usd(p.projectedRevenue)}</dd></div>
        </dl>
        <button className="btn" disabled={p.status === "funded"}>
          {p.status === "funded" ? "Fully funded" : "Invest now"}
        </button>
        {p.status === "active" && <p className="warn">Offering closes in {p.daysLeft} days</p>}
        {p.status === "upcoming" && <p className="muted">Opening soon</p>}
      </aside>
    </div>
  );
}
