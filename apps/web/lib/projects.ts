export type Project = {
  id: string;
  name: string;
  tagline: string;
  description: string;
  category: string;
  emoji: string;
  hue: number; // accent hue for generated phone screens
  screenshot?: string; // real screenshot, if we have one
  targetAmount: number;
  raisedAmount: number;
  status: "active" | "funded" | "upcoming";
  investorCount: number;
  minInvestment: number;
  projectedRevenue: number; // AI projected 3-year revenue, USD
  daysLeft: number;
};

// Deterministic PRNG so server and client render the same "random" amounts.
function mulberry32(seed: number) {
  return () => {
    seed |= 0;
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rand = mulberry32(20261107);
const between = (min: number, max: number) => min + rand() * (max - min);

const seeds = [
  ["FitTrack Pro", "Workouts that adapt to you", "AI-powered fitness tracking with personalized workout plans and nutrition guidance.", "Health & Fitness", "💪", 150, true],
  ["EcoMarket", "Shop green, verified", "Sustainable shopping platform connecting eco-conscious consumers with verified green vendors.", "E-commerce", "🌱", 130, false],
  ["KidsLearn AI", "Learning at their pace", "Educational app that uses AI to adapt to each child's learning style and pace.", "Education", "🧸", 38, false],
  ["CryptoWallet Pro", "Simple, secure self-custody", "Secure, user-friendly crypto wallet with a built-in exchange.", "Crypto & Web3", "🔐", 265, false],
  ["SocialChef", "Cook together", "Social network for chefs and food lovers with recipe sharing and cooking challenges.", "Food & Drink", "🍳", 18, true],
  ["Shred Invaders", "Arcade fitness fun", "A retro arcade shooter where your real-world workouts power your ship.", "Gaming", "👾", 285, false],
  ["TripPocket", "Offline travel companion", "Offline maps, itineraries and local tips that work with zero signal.", "Travel & Local", "🧭", 200, true],
  ["FocusFox", "Deep work, gamified", "A pomodoro focus timer that grows a tiny forest as you stay on task.", "Productivity", "🦊", 25, false],
] as const;

const statuses: Project["status"][] = ["active", "active", "active", "funded", "upcoming", "active", "active", "active"];

export const projects: Project[] = seeds.map(([name, tagline, description, category, emoji, hue, small], i) => {
  // Every project asks for less than $10,000; roughly half ask for less than $1,000.
  const target = small
    ? Math.round(between(250, 990) / 10) * 10
    : Math.round(between(1200, 9900) / 10) * 10;
  const status = statuses[i];
  const progress = status === "funded" ? 1 : status === "upcoming" ? 0 : between(0.15, 0.9);
  const raised = Math.round(target * progress);
  const minInvestment = target < 1000 ? 10 : 25;
  return {
    id: name.toLowerCase().replace(/[^a-z0-9]+/g, "-"),
    name,
    tagline,
    description,
    category,
    emoji,
    hue,
    screenshot: name === "Shred Invaders" ? "/shred-invaders.jpg" : undefined,
    targetAmount: target,
    raisedAmount: raised,
    status,
    investorCount: status === "upcoming" ? 0 : Math.max(1, Math.round(raised / between(30, 90))),
    minInvestment,
    projectedRevenue: Math.round((target * between(2.5, 6)) / 100) * 100,
    daysLeft: Math.round(between(12, 80)),
  };
});

export const getProject = (id: string) => projects.find((p) => p.id === id);
export const usd = (n: number) => "$" + n.toLocaleString("en-US");
export const pct = (p: Project) => Math.min(100, Math.round((p.raisedAmount / p.targetAmount) * 100));
