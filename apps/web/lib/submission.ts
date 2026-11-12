export const CATEGORY_LIST = [
  "AI & Machine Learning", "Social Networking", "FinTech", "Health & Fitness", "E-commerce", "Education", "Gaming",
  "Productivity", "Travel & Local", "Entertainment", "Food & Drink", "Lifestyle", "Dating", "Crypto & Web3", "IoT & Smart Home",
];
export const PLATFORM_LIST = ["iOS", "Android", "Web", "Chrome"];
export const MAX_GOAL = 9999; // funding goals must stay under $10,000

export type Draft = {
  name: string; tagline: string; description: string; category: string; platforms: string[];
  listing: "live" | "review" | "planned"; appStoreUrl: string;
  goal: string; minInvestment: string; sharePct: string; launchDate: string; campaignDays: string; testTeam: boolean;
  devName: string; teamInfo: string; email: string; website: string;
  agreeRouting: boolean; agreeTerms: boolean;
  company: string; // honeypot: real people leave this empty
};

export const emptyDraft: Draft = {
  name: "", tagline: "", description: "", category: "", platforms: [], listing: "planned", appStoreUrl: "",
  goal: "", minInvestment: "10", sharePct: "20", launchDate: "", campaignDays: "60", testTeam: true,
  devName: "", teamInfo: "", email: "", website: "", agreeRouting: false, agreeTerms: false, company: "",
};

const emailRe = /^\S+@\S+\.\S+$/;
const isUrl = (s: string) => {
  try {
    const u = new URL(s);
    return u.protocol === "http:" || u.protocol === "https:";
  } catch {
    return false;
  }
};
const int = (s: string) => (/^\d+$/.test(s.trim()) ? parseInt(s, 10) : NaN);

/** Validate one wizard step (1-3), or everything with "all". Returns field -> message. */
export function validate(step: 1 | 2 | 3 | "all", d: Draft): Record<string, string> {
  const e: Record<string, string> = {};
  const on = (n: number) => step === "all" || step === n;
  if (on(1)) {
    if (d.name.trim().length < 2 || d.name.length > 60) e.name = "Enter the app name (2 to 60 characters).";
    if (d.tagline.trim().length < 5 || d.tagline.length > 80) e.tagline = "Add a short tagline (5 to 80 characters).";
    if (d.description.trim().length < 40 || d.description.length > 800) e.description = "Describe the app in 40 to 800 characters.";
    if (!CATEGORY_LIST.includes(d.category)) e.category = "Choose a category.";
    if (!d.platforms.length || d.platforms.some((p) => !PLATFORM_LIST.includes(p))) e.platforms = "Choose at least one platform.";
    if (d.listing === "live" && !isUrl(d.appStoreUrl.trim())) e.appStoreUrl = "Paste the link to your live app store listing.";
    if (d.listing !== "live" && d.appStoreUrl.trim() && !isUrl(d.appStoreUrl.trim())) e.appStoreUrl = "Enter a valid link starting with https://";
  }
  if (on(2)) {
    const goal = int(d.goal), min = int(d.minInvestment), share = int(d.sharePct);
    if (!(goal >= 100 && goal <= MAX_GOAL)) e.goal = "Funding goals are between $100 and $9,999.";
    if (!(min >= 5) || (goal >= 100 && min > goal)) e.minInvestment = "Minimum must be at least $5 and no more than the goal.";
    if (!(share >= 1 && share <= 50)) e.sharePct = "Offer between 1% and 50% of revenue.";
    if (!/^\d{4}-\d{2}-\d{2}$/.test(d.launchDate) || d.launchDate <= new Date().toISOString().slice(0, 10)) e.launchDate = "Pick a launch date in the future.";
    if (!["30", "45", "60", "90"].includes(d.campaignDays)) e.campaignDays = "Choose a campaign length.";
  }
  if (on(3)) {
    if (d.devName.trim().length < 2 || d.devName.length > 80) e.devName = "Enter your name or team name.";
    if (d.teamInfo.trim().length < 10 || d.teamInfo.length > 600) e.teamInfo = "Tell investors about the team (10 to 600 characters).";
    if (!emailRe.test(d.email.trim()) || d.email.length > 200) e.email = "Enter a valid email address.";
    if (d.website.trim() && !isUrl(d.website.trim())) e.website = "Enter a valid link starting with https://";
    if (!d.agreeRouting) e.agreeRouting = "Revenue routing is required to list an app.";
    if (!d.agreeTerms) e.agreeTerms = "Please accept the terms to continue.";
  }
  return e;
}
