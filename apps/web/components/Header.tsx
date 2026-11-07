import Link from "next/link";
import ThemeToggle from "./ThemeToggle";

export default function Header() {
  return (
    <header className="header">
      <div className="header-in">
        <Link href="/" className="brand">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/logo-mark.png" alt="" height={36} />
          <span>applove</span>
        </Link>
        <nav className="nav">
          <Link href="/">Explore</Link>
          <Link href="/start">Start a project</Link>
          <Link href="/how-it-works">How it works</Link>
        </nav>
        <ThemeToggle />
      </div>
    </header>
  );
}
