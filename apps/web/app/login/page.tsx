"use client";
import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { GoogleIcon } from "@/lib/icons";
import { saveSession } from "@/lib/session";

// Preview only: no email is sent and no account is created. Any address works and the code is 123456.
const DEMO_CODE = "123456";

export default function Login() {
  const router = useRouter();
  const [step, setStep] = useState<"start" | "code">("start");
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [err, setErr] = useState("");
  const codeRef = useRef<HTMLInputElement>(null);

  const sendCode = (e: React.FormEvent) => {
    e.preventDefault();
    if (!/^\S+@\S+\.\S+$/.test(email.trim())) return setErr("Enter a valid email address.");
    setErr("");
    setStep("code");
    setTimeout(() => codeRef.current?.focus(), 0);
  };
  const verify = (e: React.FormEvent) => {
    e.preventDefault();
    if (code.trim() !== DEMO_CODE) return setErr("That code is not right. Try 123456 in this preview.");
    saveSession({ email: email.trim(), provider: "email" });
    router.push("/portfolio");
  };
  const google = () => {
    saveSession({ email: "demo.investor@gmail.com", provider: "google" });
    router.push("/portfolio");
  };

  if (step === "code")
    return (
      <form className="authcard" onSubmit={verify}>
        <h1>Log in to applov</h1>
        <p className="muted" style={{ margin: 0 }}>Enter the 6-digit code we sent to <b>{email}</b>.</p>
        <input ref={codeRef} className="code" inputMode="numeric" autoComplete="one-time-code" maxLength={6} placeholder="······" aria-label="6-digit code" value={code} onChange={(e) => setCode(e.target.value)} />
        {err && <p className="err">{err}</p>}
        <button className="btn" type="submit">Verify and log in</button>
        <button type="button" className="link" onClick={() => { setStep("start"); setCode(""); setErr(""); }}>Use a different email</button>
        <p className="fine">Preview only: no email is sent. Use code 123456.</p>
      </form>
    );

  return (
    <div className="authcard">
      <h1>Log in to applov</h1>
      <button className="gbtn" onClick={google}><GoogleIcon /> Continue with Google</button>
      <div className="or">or</div>
      <form onSubmit={sendCode} style={{ display: "grid", gap: 12 }}>
        <input type="email" required placeholder="you@example.com" autoComplete="email" aria-label="Email address" value={email} onChange={(e) => setEmail(e.target.value)} />
        {err && <p className="err">{err}</p>}
        <button className="btn" type="submit">Email me a code</button>
      </form>
      <p className="fine">No password to remember. We email you a one-time code that works on any device.</p>
    </div>
  );
}
