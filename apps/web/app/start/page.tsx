"use client";
import { useState } from "react";
import Link from "next/link";
import { CATEGORY_LIST, PLATFORM_LIST, emptyDraft, validate, type Draft } from "@/lib/submission";

const STEPS = ["Your app", "Funding", "Team and terms"];

export default function Start() {
  const [d, setD] = useState<Draft>(emptyDraft);
  const [step, setStep] = useState<1 | 2 | 3>(1);
  const [errs, setErrs] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);
  const [fail, setFail] = useState("");
  const [doneId, setDoneId] = useState<string | null>(null);

  const set = <K extends keyof Draft>(k: K, v: Draft[K]) => setD((o) => ({ ...o, [k]: v }));
  const togglePlatform = (p: string) => set("platforms", d.platforms.includes(p) ? d.platforms.filter((x) => x !== p) : [...d.platforms, p]);

  const next = () => {
    const e = validate(step, d);
    setErrs(e);
    if (!Object.keys(e).length) setStep((s) => (s + 1) as 1 | 2 | 3);
  };
  const back = () => {
    setErrs({});
    setStep((s) => (s - 1) as 1 | 2 | 3);
  };
  const submit = async (ev: React.FormEvent) => {
    ev.preventDefault();
    const e = validate("all", d);
    setErrs(e);
    if (Object.keys(e).length) {
      const first = validate(1, d), second = validate(2, d);
      return setStep(Object.keys(first).length ? 1 : Object.keys(second).length ? 2 : 3);
    }
    setBusy(true);
    setFail("");
    try {
      const r = await fetch("/api/submissions", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(d) });
      const j = await r.json().catch(() => ({}));
      if (!r.ok) {
        if (j.errors) setErrs(j.errors);
        throw new Error(j.error || "Something went wrong. Please try again.");
      }
      setDoneId(j.id);
    } catch (x) {
      setFail(x instanceof Error ? x.message : "Something went wrong. Please try again.");
    } finally {
      setBusy(false);
    }
  };

  const F = ({ k, label, hint, children }: { k: string; label: string; hint?: string; children: React.ReactNode }) => (
    <label className="fld">
      <span className="fld-l">{label}</span>
      {children}
      {hint && !errs[k] && <small className="muted">{hint}</small>}
      {errs[k] && <small className="ferr" role="alert">{errs[k]}</small>}
    </label>
  );

  if (doneId)
    return (
      <div className="wiz">
        <div className="okmark" aria-hidden>✓</div>
        <h1>Submitted for review</h1>
        <p className="lead">Thanks, {d.devName}. We’ll review <b>{d.name}</b> and email you at {d.email} within a few business days.</p>
        <p className="muted">Reference: <code>{doneId}</code></p>
        <Link className="btn" href="/" style={{ display: "inline-block", width: "auto", padding: "12px 22px", textAlign: "center" }}>Back to apps</Link>
      </div>
    );

  return (
    <form className="wiz" onSubmit={submit} noValidate>
      <h1>Submit your app</h1>
      <p className="muted">Raise up to $9,999 from investors who share your app’s revenue. It takes about five minutes.</p>
      <ol className="wsteps" aria-label="Progress">
        {STEPS.map((s, i) => (
          <li key={s} className={step === i + 1 ? "cur" : step > i + 1 ? "done" : ""} aria-current={step === i + 1 ? "step" : undefined}>{s}</li>
        ))}
      </ol>

      <div className="hp" aria-hidden="true">
        <label>Company<input tabIndex={-1} autoComplete="off" value={d.company} onChange={(e) => set("company", e.target.value)} /></label>
      </div>

      {step === 1 && (
        <div className="wgrid">
          <F k="name" label="App name"><input value={d.name} maxLength={60} onChange={(e) => set("name", e.target.value)} placeholder="FocusFox" /></F>
          <F k="tagline" label="Tagline" hint="One line investors will see on the card."><input value={d.tagline} maxLength={80} onChange={(e) => set("tagline", e.target.value)} placeholder="Deep work, gamified" /></F>
          <F k="description" label="Description" hint="What it does and who it is for."><textarea rows={4} value={d.description} maxLength={800} onChange={(e) => set("description", e.target.value)} /></F>
          <F k="category" label="Category">
            <select value={d.category} onChange={(e) => set("category", e.target.value)}>
              <option value="">Choose…</option>
              {CATEGORY_LIST.map((c) => <option key={c}>{c}</option>)}
            </select>
          </F>
          <fieldset className="fld">
            <legend className="fld-l">Platforms</legend>
            <div className="fchips">
              {PLATFORM_LIST.map((p) => <button type="button" key={p} className="fchip" aria-pressed={d.platforms.includes(p)} onClick={() => togglePlatform(p)}>{p}</button>)}
            </div>
            {errs.platforms && <small className="ferr" role="alert">{errs.platforms}</small>}
          </fieldset>
          <F k="listing" label="App store status">
            <select value={d.listing} onChange={(e) => set("listing", e.target.value as Draft["listing"])}>
              <option value="planned">Planned listing</option>
              <option value="review">Submitted, in review</option>
              <option value="live">Live in the store</option>
            </select>
          </F>
          <F k="appStoreUrl" label={d.listing === "live" ? "App store link" : "App store link (optional)"} hint="We use your store listing to verify revenue reports.">
            <input type="url" value={d.appStoreUrl} onChange={(e) => set("appStoreUrl", e.target.value)} placeholder="https://apps.apple.com/…" />
          </F>
        </div>
      )}

      {step === 2 && (
        <div className="wgrid">
          <F k="goal" label="Funding goal (USD)" hint="Between $100 and $9,999."><input inputMode="numeric" value={d.goal} onChange={(e) => set("goal", e.target.value.replace(/\D/g, ""))} placeholder="2500" /></F>
          <F k="minInvestment" label="Minimum investment (USD)"><input inputMode="numeric" value={d.minInvestment} onChange={(e) => set("minInvestment", e.target.value.replace(/\D/g, ""))} /></F>
          <F k="sharePct" label="Revenue share for investors (%)" hint="The share of the app’s revenue paid to investors."><input inputMode="numeric" value={d.sharePct} onChange={(e) => set("sharePct", e.target.value.replace(/\D/g, ""))} /></F>
          <F k="launchDate" label="Projected launch date"><input type="date" value={d.launchDate} onChange={(e) => set("launchDate", e.target.value)} /></F>
          <F k="campaignDays" label="Campaign length">
            <select value={d.campaignDays} onChange={(e) => set("campaignDays", e.target.value)}>
              {["30", "45", "60", "90"].map((n) => <option key={n} value={n}>{n} days</option>)}
            </select>
          </F>
          <label className="chk">
            <input type="checkbox" checked={d.testTeam} onChange={(e) => set("testTeam", e.target.checked)} />
            <span>Open a test team so investors can try early builds and send feedback</span>
          </label>
        </div>
      )}

      {step === 3 && (
        <div className="wgrid">
          <F k="devName" label="Your name or team name"><input value={d.devName} maxLength={80} onChange={(e) => set("devName", e.target.value)} /></F>
          <F k="teamInfo" label="About the team" hint="Experience, past apps, who does what."><textarea rows={4} value={d.teamInfo} maxLength={600} onChange={(e) => set("teamInfo", e.target.value)} /></F>
          <F k="email" label="Contact email"><input type="email" autoComplete="email" value={d.email} onChange={(e) => set("email", e.target.value)} /></F>
          <F k="website" label="Website or portfolio (optional)"><input type="url" value={d.website} onChange={(e) => set("website", e.target.value)} placeholder="https://" /></F>
          <label className="chk">
            <input type="checkbox" checked={d.agreeRouting} onChange={(e) => set("agreeRouting", e.target.checked)} />
            <span>I agree to route this app’s app store revenue through the applov revenue router. This is required to list an app.</span>
          </label>
          {errs.agreeRouting && <small className="ferr" role="alert">{errs.agreeRouting}</small>}
          <label className="chk">
            <input type="checkbox" checked={d.agreeTerms} onChange={(e) => set("agreeTerms", e.target.checked)} />
            <span>I have read and accept the terms for developers.</span>
          </label>
          {errs.agreeTerms && <small className="ferr" role="alert">{errs.agreeTerms}</small>}
        </div>
      )}

      {fail && <p className="ferr" role="alert" style={{ marginTop: 14 }}>{fail}</p>}
      <div className="wnav">
        {step > 1 ? <button type="button" className="wback" onClick={back}>Back</button> : <span />}
        {step < 3 ? (
          <button type="button" className="btn wnext" onClick={next}>Continue</button>
        ) : (
          <button type="submit" className="btn wnext" disabled={busy}>{busy ? "Submitting…" : "Submit for review"}</button>
        )}
      </div>
      <p className="fine">You can add screenshots after we review your submission.</p>
    </form>
  );
}
