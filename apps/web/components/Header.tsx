import Link from "next/link";
import ThemeToggle from "./ThemeToggle";
import AccountMenu from "./AccountMenu";

export default function Header() {
  return (
    <header className="header">
      <div className="header-in">
        <Link href="/" className="brand">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/logo-mark.png" alt="" height={36} />
          <span>applov</span>
        </Link>
        <div className="hdr-right">
          <ThemeToggle />
          <AccountMenu />
        </div>
      </div>
    </header>
  );
}
