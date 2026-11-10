"use client";
import { useInvest } from "./InvestProvider";

export default function InvestButton({ app, amount, disabled, label }: { app: string; amount: number; disabled?: boolean; label: string }) {
  const { openInvest } = useInvest();
  return (
    <button className="btn" disabled={disabled} onClick={() => openInvest(app, amount)}>
      {label}
    </button>
  );
}
