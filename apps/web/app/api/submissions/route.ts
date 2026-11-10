import { FieldValue } from "firebase-admin/firestore";
import { NextResponse } from "next/server";
import { db } from "@/lib/firebaseAdmin";
import { emptyDraft, validate, type Draft } from "@/lib/submission";

// Never trust the body: keep only known fields, with the right types.
function coerce(raw: Record<string, unknown>): Draft {
  const out = { ...emptyDraft } as Record<string, unknown>;
  for (const [k, def] of Object.entries(emptyDraft)) {
    const v = raw[k];
    if (typeof def === "string") out[k] = typeof v === "string" ? v : def;
    else if (typeof def === "boolean") out[k] = v === true;
    else out[k] = Array.isArray(v) ? v.map(String) : [];
  }
  return out as Draft;
}

export const dynamic = "force-dynamic";

// Developer app submissions. Saved as "pending" for review; nothing is published automatically.
export async function POST(req: Request) {
  let d: Draft;
  try {
    const raw = await req.json();
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) throw new Error("bad body");
    d = coerce(raw as Record<string, unknown>);
  } catch {
    return NextResponse.json({ error: "Invalid request." }, { status: 400 });
  }
  // Honeypot: pretend success so bots learn nothing.
  if (typeof d.company === "string" && d.company.trim()) return NextResponse.json({ ok: true, id: "ok" });

  const errors = validate("all", d);
  if (Object.keys(errors).length) return NextResponse.json({ error: "Please fix the highlighted fields.", errors }, { status: 400 });

  try {
    const ref = await db().collection("submissions").add({
      status: "pending",
      name: d.name.trim(),
      tagline: d.tagline.trim(),
      description: d.description.trim(),
      category: d.category,
      platforms: d.platforms,
      listing: d.listing,
      appStoreUrl: d.appStoreUrl.trim() || null,
      goal: parseInt(d.goal, 10),
      minInvestment: parseInt(d.minInvestment, 10),
      sharePct: parseInt(d.sharePct, 10),
      launchDate: d.launchDate,
      campaignDays: parseInt(d.campaignDays, 10),
      testTeam: !!d.testTeam,
      devName: d.devName.trim(),
      teamInfo: d.teamInfo.trim(),
      email: d.email.trim().toLowerCase(),
      website: d.website.trim() || null,
      agreedRevenueRouting: true,
      agreedTerms: true,
      createdAt: FieldValue.serverTimestamp(),
    });
    return NextResponse.json({ ok: true, id: ref.id });
  } catch (err) {
    console.error("submission write failed", err);
    return NextResponse.json({ error: "We couldn't save your submission. Please try again in a moment." }, { status: 500 });
  }
}
