import type { Metadata } from "next";
import Header from "@/components/Header";
import "./globals.css";

export const metadata: Metadata = {
  title: "Applove — fund apps, share the profit",
  description: "Stake-based crowdfunding for apps.",
  icons: { icon: "/logo-mark.png" },
};

// Runs before paint so there is no flash: saved choice wins, otherwise follow the system.
const themeInit = `(function(){try{var m=localStorage.getItem('applove-theme')||'system';var d=m==='dark'||(m==='system'&&matchMedia('(prefers-color-scheme: dark)').matches);var r=document.documentElement;r.dataset.theme=d?'dark':'light';r.dataset.mode=m;}catch(e){}})();`;

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeInit }} />
      </head>
      <body>
        <Header />
        <main>{children}</main>
        <footer className="footer">© Applove · Invest in apps, share the upside.</footer>
      </body>
    </html>
  );
}
