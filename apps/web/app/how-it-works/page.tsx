const steps = [
  ["🔍", "Discover", "Browse promising mobile app projects."],
  ["📊", "Research", "Review the app, team and AI revenue projection."],
  ["💸", "Invest", "Pick an amount (many start at just $10) and buy a stake."],
  ["📈", "Track", "Follow progress and receive your share of revenue."],
];
export default function How() {
  return (
    <div className="narrow">
      <h1>How it works</h1>
      {steps.map(([i, t, d]) => (
        <div key={t} className="step"><div className="step-i">{i}</div><div><h3>{t}</h3><p className="muted">{d}</p></div></div>
      ))}
    </div>
  );
}
