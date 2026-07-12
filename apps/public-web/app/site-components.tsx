import Link from "next/link";
import type { ReactNode } from "react";
import {
  supportedLocales,
  type DocumentRoute,
  type SupportedLocale,
} from "./legal-catalog";

export function LegalShell({
  children,
  locale,
  currentRoute,
}: {
  children: ReactNode;
  locale: SupportedLocale;
  currentRoute?: DocumentRoute;
}) {
  const prefix = locale === "en" ? "" : `/${locale}`;
  return (
    <div className="site-shell">
      <a className="skip-link" href="#main-content">Skip to content</a>
      <header className="site-header">
        <Link className="brand" href={prefix || "/"} aria-label="PetMagic home">
          <span className="brand-mark" aria-hidden="true">P</span>
          <span>PetMagic</span>
        </Link>
        <nav className="header-nav" aria-label="Primary">
          <Link href={`${prefix}/privacy`}>Privacy</Link>
          <Link href={`${prefix}/terms`}>Terms</Link>
          <Link href={`${prefix}/support`}>Support</Link>
        </nav>
      </header>
      <main id="main-content">{children}</main>
      <footer className="site-footer">
        <p>© {new Date().getUTCFullYear()} PetMagic</p>
        <nav aria-label="Languages">
          {supportedLocales.map((code) => (
            <Link
              href={localeRouteHref(code, currentRoute)}
              hrefLang={code}
              key={code}
            >
              {code.toUpperCase()}
            </Link>
          ))}
        </nav>
      </footer>
    </div>
  );
}

function localeRouteHref(
  locale: SupportedLocale,
  currentRoute?: DocumentRoute,
): string {
  if (!currentRoute) return locale === "en" ? "/" : `/${locale}/privacy`;
  return locale === "en" ? `/${currentRoute}` : `/${locale}/${currentRoute}`;
}
