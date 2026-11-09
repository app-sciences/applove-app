"use client";
import { useEffect, useRef, useState } from "react";

type Mode = "system" | "light" | "dark";
const KEY = "applove-theme";

function apply(mode: Mode) {
  const dark = mode === "dark" || (mode === "system" && matchMedia("(prefers-color-scheme: dark)").matches);
  document.documentElement.dataset.theme = dark ? "dark" : "light";
  document.documentElement.dataset.mode = mode;
}

const options: { mode: Mode; label: string; icon: string }[] = [
  { mode: "light", label: "Light", icon: "☀️" },
  { mode: "system", label: "System", icon: "💻" },
  { mode: "dark", label: "Dark", icon: "🌙" },
];

export default function ThemeToggle() {
  const [mode, setMode] = useState<Mode>("system");
  const [open, setOpen] = useState(false);
  const box = useRef<HTMLDivElement>(null);

  useEffect(() => {
    let saved: Mode = "system";
    try {
      const v = localStorage.getItem(KEY);
      if (v === "light" || v === "dark" || v === "system") saved = v;
    } catch {}
    setMode(saved);
    apply(saved);
    const mq = matchMedia("(prefers-color-scheme: dark)");
    const onChange = () => document.documentElement.dataset.mode === "system" && apply("system");
    mq.addEventListener("change", onChange);
    const onDoc = (e: MouseEvent) => box.current && !box.current.contains(e.target as Node) && setOpen(false);
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    document.addEventListener("mousedown", onDoc);
    document.addEventListener("keydown", onKey);
    return () => {
      mq.removeEventListener("change", onChange);
      document.removeEventListener("mousedown", onDoc);
      document.removeEventListener("keydown", onKey);
    };
  }, []);

  const choose = (m: Mode) => {
    setMode(m);
    apply(m);
    setOpen(false);
    try {
      localStorage.setItem(KEY, m);
    } catch {}
  };

  const cur = options.find((o) => o.mode === mode)!;
  return (
    <div className="theme" ref={box}>
      <button className="theme-btn" aria-haspopup="menu" aria-expanded={open} onClick={() => setOpen(!open)}>
        <span aria-hidden>{cur.icon}</span>
        <span className="lbl">{cur.label}</span>
        <span className="car" aria-hidden>▾</span>
      </button>
      <div className="theme-menu" role="menu" hidden={!open}>
        {options.map((o) => (
          <button key={o.mode} role="menuitemradio" aria-checked={mode === o.mode} onClick={() => choose(o.mode)}>
            <span aria-hidden>{o.icon}</span>
            {o.label}
            <span className="ck" aria-hidden>✓</span>
          </button>
        ))}
      </div>
    </div>
  );
}
