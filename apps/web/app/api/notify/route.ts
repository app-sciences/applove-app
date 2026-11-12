import { createHash } from "crypto";
import { FieldValue } from "firebase-admin/firestore";
import { NextResponse } from "next/server";
import { db } from "@/lib/firebaseAdmin";

export const dynamic = "force-dynamic";

// Collects emails for the "investing is coming soon" waitlist. One document per address.
export async function POST(req: Request) {
  let body: { email?: unknown; app?: unknown; amount?: unknown };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Invalid request." }, { status: 400 });
  }
  const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
  if (!/^\S+@\S+\.\S+$/.test(email) || email.length > 200) {
    return NextResponse.json({ error: "Enter a valid email address." }, { status: 400 });
  }
  const app = typeof body.app === "string" ? body.app.slice(0, 80) : "";
  const amount = typeof body.amount === "number" && Number.isFinite(body.amount) ? body.amount : null;
  try {
    const id = createHash("sha256").update(email).digest("hex");
    await db().collection("waitlist").doc(id).set(
      { email, ...(app ? { apps: FieldValue.arrayUnion(app) } : {}), lastAmount: amount, updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
    return NextResponse.json({ ok: true });
  } catch (err) {
    console.error("waitlist write failed", err);
    return NextResponse.json({ error: "We couldn't save that. Please try again in a moment." }, { status: 500 });
  }
}
