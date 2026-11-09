"use client";
import { useEffect, useState } from "react";

export type Session = { email: string; provider: "google" | "email" } | null;
const KEY = "applov-session";
const EVT = "applov-session-change";

export function readSession(): Session {
  try {
    return JSON.parse(localStorage.getItem(KEY) || "null");
  } catch {
    return null;
  }
}
export function saveSession(s: Session) {
  try {
    if (s) localStorage.setItem(KEY, JSON.stringify(s));
    else localStorage.removeItem(KEY);
  } catch {}
  window.dispatchEvent(new Event(EVT));
}
/** undefined while loading on the client, then the session or null. */
export function useSession(): Session | undefined {
  const [s, setS] = useState<Session | undefined>(undefined);
  useEffect(() => {
    const sync = () => setS(readSession());
    sync();
    window.addEventListener(EVT, sync);
    return () => window.removeEventListener(EVT, sync);
  }, []);
  return s;
}
