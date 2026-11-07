import ProjectCard from "@/components/ProjectCard";
import { projects } from "@/lib/projects";

const small = projects.filter((p) => p.targetAmount < 1000);
const rest = projects.filter((p) => p.targetAmount >= 1000);
const sections = [
  { title: "Small asks — under $1,000", list: small },
  { title: "Most active", list: [...rest].sort((a, b) => b.investorCount - a.investorCount) },
];

export default function Home() {
  return (
    <>
      <section className="hero">
        <h1>Fund the apps you believe in.<br />Share the profit.</h1>
        <p className="muted">Buy a small stake in an app before it launches and earn a share of its revenue.</p>
      </section>
      {sections.map((s) => (
        <section key={s.title} className="section">
          <h2>{s.title}</h2>
          <div className="grid">
            {s.list.map((p) => <ProjectCard key={p.id} project={p} />)}
          </div>
        </section>
      ))}
    </>
  );
}
