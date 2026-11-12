"use client";
import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { saveSession, useSession } from "@/lib/session";

export default function AccountMenu() {
  const session = useSession();
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const box = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const onDoc = (e: MouseEvent) => box.current && !box.current.contains(e.target as Node) && setOpen(false);
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    document.addEventListener("mousedown", onDoc);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onDoc);
      document.removeEventListener("keydown", onKey);
    };
  }, []);

  const go = (path: string) => {
    setOpen(false);
    router.push(path);
  };

  return (
    <div className="acct" ref={box}>
      <button className="acct-btn" aria-haspopup="menu" aria-expanded={open} onClick={() => setOpen(!open)}>
        Account <span className="car" aria-hidden>▾</span>
      </button>
      <div className="theme-menu" role="menu" hidden={!open}>
        {session ? (
          <>
            <div className="menu-head">{session.email}</div>
            <button role="menuitem" onClick={() => go("/portfolio")}>Portfolio</button>
            <button role="menuitem" onClick={() => go("/start")}>Submit an app</button>
            <button role="menuitem" onClick={() => { saveSession(null); window.location.assign("/"); }}>Log out</button>
          </>
        ) : (
          <>
            <button role="menuitem" onClick={() => go("/login")}>Log in</button>
            <button role="menuitem" onClick={() => go("/start")}>Submit an app</button>
          </>
        )}
      </div>
    </div>
  );
}
