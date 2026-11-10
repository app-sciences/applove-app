import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Applove (beta)",
  description: "Back the apps you love. Share in what they earn.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body style={{ margin: 0, fontFamily: "system-ui, sans-serif" }}>{children}</body>
    </html>
  );
}
