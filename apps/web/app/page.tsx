import Showcase from "@/components/Showcase";
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
        <h1>Find cool apps by rockstar devs.<br />Join the testing team.<br />Share the profit.</h1>
        <p className="muted">Your investment is protected by blockchain. Your NFT guarantees regular payouts as per app store reports. Optionally join the testing team for weekly updates, or meet the dev team directly.</p>
      </section>
      <Showcase />
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
