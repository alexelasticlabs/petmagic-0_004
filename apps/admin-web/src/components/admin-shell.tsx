"use client";

import styles from "@/components/admin/admin-shell.module.css";
import { AdminSidebar } from "@/components/admin/admin-sidebar";
import { AdminTopbar } from "@/components/admin/admin-topbar";
import { buildLocaleSwitchPath, getAdminPageMeta, stripLocalePrefix } from "@/lib/admin-navigation";
import { logout, useAuthSession } from "@/lib/api-client";
import { type Locale, getDictionary } from "@/lib/i18n";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { type ReactNode, useEffect, useRef, useState } from "react";

type AdminShellProps = { locale: Locale; children: ReactNode };

/* ═══════════════════════════════════════════════════════════════
   SHARED: Language dropdown  (lld-* CSS from globals.css)
════════════════════════════════════════════════════════════════ */
function LangDropdown({ locale, ruPath, enPath }: { locale: Locale; ruPath: string; enPath: string }) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    if (!open) return;
    function onOut(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    }
    document.addEventListener("mousedown", onOut);
    return () => document.removeEventListener("mousedown", onOut);
  }, [open]);

  return (
    <div className="lld" ref={ref}>
      <button type="button" className="lld__trigger" onClick={() => setOpen((o) => !o)} aria-expanded={open} aria-haspopup="listbox">
        <svg viewBox="0 0 24 24" fill="none" className="lld__globe" aria-hidden="true">
          <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="1.6" />
          <path d="M12 2C8 6 8 12 8 12C8 18 12 22 12 22" stroke="currentColor" strokeWidth="1.6" />
          <path d="M12 2C16 6 16 12 16 12C16 18 12 22 12 22" stroke="currentColor" strokeWidth="1.6" />
          <path d="M2 12H22M4 7H20M4 17H20" stroke="currentColor" strokeWidth="1.4" />
        </svg>
        <span>{locale === "ru" ? "Русский" : "English"}</span>
        <svg viewBox="0 0 12 8" fill="none" className={`lld__caret${open ? " lld__caret--open" : ""}`} aria-hidden="true">
          <path d="M1 1L6 7L11 1" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
        </svg>
      </button>
      {open && (
        <ul className="lld__menu" role="listbox">
          <li role="option" aria-selected={locale === "ru"}>
            <Link href={ruPath} className={`lld__item${locale === "ru" ? " lld__item--active" : ""}`} onClick={() => setOpen(false)}>
              <span>Русский</span>
              {locale === "ru" && <svg viewBox="0 0 16 16" fill="none" className="lld__check" aria-hidden="true"><path d="M3 8L7 12L13 4" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" /></svg>}
            </Link>
          </li>
          <li role="option" aria-selected={locale === "en"}>
            <Link href={enPath} className={`lld__item${locale === "en" ? " lld__item--active" : ""}`} onClick={() => setOpen(false)}>
              <span>English</span>
              {locale === "en" && <svg viewBox="0 0 16 16" fill="none" className="lld__check" aria-hidden="true"><path d="M3 8L7 12L13 4" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" /></svg>}
            </Link>
          </li>
        </ul>
      )}
    </div>
  );
}

/* ═══════════════════════════════════════════════════════════════
   LOGIN SCREEN helpers
════════════════════════════════════════════════════════════════ */
function PetMagicLogo() {
  return (
    <svg viewBox="0 0 80 90" fill="none" className="ls-hex-svg" role="img" aria-label="PetMagic">
      <path d="M40 4L75 23V59L40 78L5 59V23L40 4Z" stroke="#22c55e" strokeWidth="2.5" fill="rgba(34,197,94,0.07)" />
      <path d="M40 18L62 30V54L40 66L18 54V30L40 18Z" stroke="rgba(34,197,94,0.35)" strokeWidth="1.2" fill="none" />
      <text x="40" y="51" textAnchor="middle" fill="#22c55e" fontSize="22" fontWeight="800" fontFamily="system-ui,sans-serif">PM</text>
    </svg>
  );
}

function DashboardPreview({ locale }: { locale: Locale }) {
  const isRu = locale === "ru";
  return (
    <div className="ls-preview" aria-hidden="true">
      <div className="ls-preview__titlebar">
        <span className="ls-preview__dot" data-c="r" /><span className="ls-preview__dot" data-c="y" /><span className="ls-preview__dot" data-c="g" />
        <span className="ls-preview__win-title">Dashboard</span>
      </div>
      <div className="ls-preview__body">
        <div className="ls-preview__sidebar">
          {[1,2,3,4,5].map((i) => <span key={i} className="ls-preview__sb-item" style={{ opacity: i === 2 ? 1 : 0.35 }} />)}
        </div>
        <div className="ls-preview__main">
          <div className="ls-preview__chart">
            <svg viewBox="0 0 180 52" fill="none" preserveAspectRatio="none" width="100%" height="100%">
              <defs>
                <linearGradient id="lsChartGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#22c55e" stopOpacity="0.35" />
                  <stop offset="100%" stopColor="#22c55e" stopOpacity="0" />
                </linearGradient>
              </defs>
              <polygon points="0,44 22,34 44,38 70,21 90,27 110,15 130,19 155,11 180,14 180,52 0,52" fill="url(#lsChartGrad)" />
              <polyline points="0,44 22,34 44,38 70,21 90,27 110,15 130,19 155,11 180,14" stroke="#22c55e" strokeWidth="1.8" fill="none" strokeLinejoin="round" />
            </svg>
          </div>
          <div className="ls-preview__stats">
            <div className="ls-preview__stat"><span className="ls-preview__stat-label">{isRu ? "Польз." : "Users"}</span><span className="ls-preview__stat-val">1 256</span><span className="ls-preview__stat-d">▲ 12.5%</span></div>
            <div className="ls-preview__stat"><span className="ls-preview__stat-label">{isRu ? "Заказы" : "Orders"}</span><span className="ls-preview__stat-val">3 846</span><span className="ls-preview__stat-d">▲ 8.1%</span></div>
            <div className="ls-preview__stat"><span className="ls-preview__stat-label">{isRu ? "Шаблоны" : "Templ."}</span><span className="ls-preview__stat-val">74%</span><span className="ls-preview__stat-d">▲ 4.3%</span></div>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════════════
   MAIN EXPORT
════════════════════════════════════════════════════════════════ */
export function AdminShell({ locale, children }: AdminShellProps) {
  const text = getDictionary(locale);
  const pathname = usePathname();
  const router = useRouter();
  const currentPath = stripLocalePrefix(pathname);
  const isLoginPage = currentPath === "/";
  const authSession = useAuthSession();
  const session = isLoginPage ? null : authSession;

  /* Admin panel state */
  const [sidebarOpen, setSidebarOpen] = useState(false);

  useEffect(() => {
    if (!isLoginPage && session === null) {
      router.replace(`/${locale}`);
    }
  }, [isLoginPage, locale, router, session]);

  /* Keyboard: close sidebar on Escape */
  useEffect(() => {
    if (!sidebarOpen) return;
    function onKey(e: KeyboardEvent) { if (e.key === "Escape") setSidebarOpen(false); }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [sidebarOpen]);

  function handleLogout() {
    void logout();
    router.replace(`/${locale}`);
  }

  /* ── Login screen ───────────────────────────────────────────── */
  if (isLoginPage) {
    const welcomeTitle = locale === "ru" ? "Добро пожаловать!" : "Welcome!";
    const welcomeSub = locale === "ru" ? "Войдите в панель администратора, чтобы продолжить работу" : "Sign in to the admin panel to continue your work";
    const copyright = locale === "ru" ? "© 2026 Admin Panel. Все права защищены." : "© 2026 Admin Panel. All rights reserved.";
    return (
      <div className="ls-screen">
        <div className="ls-left">
          <PetMagicLogo />
          <h2 className="ls-welcome">{welcomeTitle}</h2>
          <p className="ls-tagline">{welcomeSub}</p>
          <DashboardPreview locale={locale} />
        </div>
        <div className="ls-right">
          <div className="ls-topbar">
            <LangDropdown locale={locale} ruPath="/ru" enPath="/en" />
          </div>
          <div className="ls-right__body">{children}</div>
          <footer className="ls-copyright">{copyright}</footer>
        </div>
      </div>
    );
  }

  if (session == null) {
    return (
      <div className={styles.authGate} aria-busy="true" aria-live="polite">
        <div className={styles.authGateCard}>
          <span className={styles.authGateMark}>PM</span>
          <span>{locale === "ru" ? "Проверяем доступ..." : "Checking access..."}</span>
        </div>
      </div>
    );
  }

  /* ── Admin panel layout ────────────────────────────────────── */
  const userName = session?.user?.displayName || session?.user?.email?.split("@")[0] || "";
  const userRole = session?.user?.roles?.[0] || (locale === "ru" ? "Администратор" : "Administrator");
  const userInitial = (session?.user?.displayName || session?.user?.email || "A")[0].toUpperCase();
  const userBadgeName = session?.user?.displayName || session?.user?.email || (locale === "ru" ? "Администратор" : "Administrator");
  const pageMeta = getAdminPageMeta(locale, currentPath, userName);
  const ruPath = buildLocaleSwitchPath("ru", pathname);
  const enPath = buildLocaleSwitchPath("en", pathname);

  return (
    <div className={styles.layout}>
      {sidebarOpen ? <div className={styles.backdrop} onClick={() => setSidebarOpen(false)} aria-hidden="true" /> : null}

      <AdminSidebar
        locale={locale}
        currentPath={currentPath}
        isOpen={sidebarOpen}
        onNavigate={() => setSidebarOpen(false)}
        onLogout={() => void handleLogout()}
        logoutLabel={text.navLogout}
      />

      <div className={styles.main}>
        <AdminTopbar
          locale={locale}
          pageTitle={pageMeta.title}
          pageDescription={pageMeta.description}
          userName={userBadgeName}
          userRole={userRole}
          userInitial={userInitial}
          ruPath={ruPath}
          enPath={enPath}
          sidebarOpen={sidebarOpen}
          onToggleSidebar={() => setSidebarOpen((current) => !current)}
        />

        <main className={styles.content}>{children}</main>
      </div>
    </div>
  );
}
