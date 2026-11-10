"use client";
import { createContext, useCallback, useContext, useEffect, useRef, useState } from "react";

type Ctx = { openInvest: (app: string, amount?: number) => void };
const InvestCtx = createContext<Ctx>({ openInvest: () => {} });
export const useInvest = () => useContext(InvestCtx);

export default function InvestProvider({ children }: { children: React.ReactNode }) {
  const ref = useRef<HTMLDialogElement>(null);
  const [app, setApp] = useState("");
  const [amount, setAmount] = useState<number | undefined>();
  const [email, setEmail] = useState("");
  const [state, setState] = useState<"idle" | "sending" | "done">("idle");
  const [err, setErr] = useState("");

  const openInvest = useCallback((a: string, amt?: number) => {
    setApp(a);
    setAmount(amt);
    setState("idle");
    setErr("");
    ref.current?.showModal();
  }, []);

  useEffect(() => {
    const d = ref.current;
    if (!d) return;
    const onClick = (e: MouseEvent) => e.target === d && d.close(); // click on the backdrop
    d.addEventListener("click", onClick);
    return () => d.removeEventListener("click", onClick);
  }, []);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!/^\S+@\S+\.\S+$/.test(email.trim())) return setErr("Enter a valid email address.");
    setErr("");
    setState("sending");
    try {
      const r = await fetch("/api/notify", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: email.trim(), app, amount }),
      });
      const j = await r.json().catch(() => ({}));
      if (!r.ok) throw new Error(j.error || "Something went wrong. Please try again.");
      setState("done");
    } catch (x) {
      setErr(x instanceof Error ? x.message : "Something went wrong. Please try again.");
      setState("idle");
    }
  };

  return (
    <InvestCtx.Provider value={{ openInvest }}>
      {children}
      <dialog className="dlg" ref={ref} aria-labelledby="dlgt">
        <button className="x" aria-label="Close" onClick={() => ref.current?.close()}>×</button>
        {state === "done" ? (
          <>
            <div className="okmark" aria-hidden>✓</div>
            <h2 id="dlgt">You’re on the list</h2>
            <p className="muted">Thanks. We’ll email you as soon as investing opens, plus occasional updates on {app}.</p>
            <button className="btn" style={{ marginTop: 16 }} onClick={() => ref.current?.close()}>Done</button>
          </>
        ) : (
          <>
            <span className="chip">Coming soon</span>
            <h2 id="dlgt">Investing opens soon</h2>
            <p className="muted">We’re putting the finishing touches on investing. Leave your email and we’ll let you know when it opens, with occasional updates on {app}.</p>
            <form onSubmit={submit}>
              <input type="email" required placeholder="you@example.com" autoComplete="email" aria-label="Email address" value={email} onChange={(e) => setEmail(e.target.value)} />
              {err && <p className="err">{err}</p>}
              <button className="btn" type="submit" disabled={state === "sending"}>{state === "sending" ? "Saving…" : "Notify me"}</button>
            </form>
          </>
        )}
      </dialog>
    </InvestCtx.Provider>
  );
}
