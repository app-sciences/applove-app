import { projects, pct, type Project } from "./projects";

// Sample holdings for the preview: [project id, stake in USD, NFT number].
const HOLD: [string, number, string][] = [
  ["cryptowallet-pro", 200, "0412"],
  ["shred-invaders", 150, "0587"],
  ["ecomarket", 250, "0630"],
  ["trippocket", 50, "0721"],
];
export const PAYOUTS: { date: string; id: string; name: string; amount: number }[] = [
  ["2026-11-01", "cryptowallet-pro", 11.0],
  ["2026-10-01", "cryptowallet-pro", 10.4],
  ["2026-09-01", "cryptowallet-pro", 9.8],
].map(([date, id, amount]) => ({ date: date as string, id: id as string, name: projects.find((p) => p.id === id)!.name, amount: amount as number }));

export type Holding = { project: Project; stake: number; token: string; earned: number; share: number; statusLabel: string; earning: boolean };
export const holdings: Holding[] = HOLD.map(([id, stake, token]) => {
  const project = projects.find((p) => p.id === id)!;
  const earned = PAYOUTS.filter((x) => x.id === id).reduce((a, x) => a + x.amount, 0);
  const statusLabel = project.status === "funded" ? "Earning" : project.status === "active" ? `Funding · ${pct(project)}%` : "Opening soon";
  return { project, stake, token, earned, share: (stake / project.targetAmount) * 100, statusLabel, earning: project.status === "funded" };
});
export const usd2 = (n: number) => "$" + n.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
export const fdate = (d: string) => new Date(d + "T00:00:00").toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
