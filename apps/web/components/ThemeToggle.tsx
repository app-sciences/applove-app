"use client";
import { useEffect, useState } from "react";

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
    return () => mq.removeEventListener("change", onChange);
  }, []);

  const choose = (m: Mode) => {
    setMode(m);
    apply(m);
    try {
      localStorage.setItem(KEY, m);
    } catch {}
  };

  return (
    <div className="theme-toggle" role="radiogroup" aria-label="Color theme">
      {options.map((o) => (
        <button
          key={o.mode}
          role="radio"
          aria-checked={mode === o.mode}
          className={mode === o.mode ? "active" : ""}
          onClick={() => choose(o.mode)}
          title={o.label}
        >
          <span aria-hidden>{o.icon}</span>
          <span className="lbl">{o.label}</span>
        </button>
      ))}
    </div>
  );
}
