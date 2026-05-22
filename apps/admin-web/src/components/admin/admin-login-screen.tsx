import { type ReactNode } from "react";

import { BrandMark } from "@/components/admin/admin-icons";
import { AdminLangDropdown } from "@/components/admin/admin-lang-dropdown";
import styles from "@/components/admin/admin-login-screen.module.css";
import { type Locale } from "@/lib/i18n";

type AdminLoginScreenProps = {
  locale: Locale;
  children: ReactNode;
};

export function AdminLoginScreen({ locale, children }: AdminLoginScreenProps) {
  const welcomeTitle = locale === "ru" ? "Добро пожаловать!" : "Welcome!";
  const welcomeSubtitle = locale === "ru"
    ? "Войдите в панель администратора, чтобы продолжить работу"
    : "Sign in to the admin panel to continue your work";
  const copyright = locale === "ru"
    ? "© 2026 Admin Panel. Все права защищены."
    : "© 2026 Admin Panel. All rights reserved.";

  return (
    <div className={styles.screen}>
      <div className={styles.left}>
        <BrandMark className={styles.brandMark} />
        <h2 className={styles.welcome}>{welcomeTitle}</h2>
        <p className={styles.tagline}>{welcomeSubtitle}</p>
        <LoginDashboardPreview locale={locale} />
      </div>

      <div className={styles.right}>
        <div className={styles.topbar}>
          <AdminLangDropdown locale={locale} ruPath="/ru" enPath="/en" />
        </div>
        <div className={styles.body}>{children}</div>
        <footer className={styles.copyright}>{copyright}</footer>
      </div>
    </div>
  );
}

function LoginDashboardPreview({ locale }: { locale: Locale }) {
  const isRu = locale === "ru";

  return (
    <div className={styles.preview} aria-hidden="true">
      <div className={styles.previewTitlebar}>
        <span className={`${styles.previewDot} ${styles.previewDotRed}`} />
        <span className={`${styles.previewDot} ${styles.previewDotYellow}`} />
        <span className={`${styles.previewDot} ${styles.previewDotGreen}`} />
        <span className={styles.previewWindowTitle}>Dashboard</span>
      </div>

      <div className={styles.previewBody}>
        <div className={styles.previewSidebar}>
          {[0, 1, 2, 3, 4].map((index) => (
            <span
              key={index}
              className={`${styles.previewSidebarItem} ${index === 1 ? styles.previewSidebarItemActive : ""}`}
            />
          ))}
        </div>

        <div className={styles.previewMain}>
          <div className={styles.previewChart}>
            <svg viewBox="0 0 180 52" fill="none" preserveAspectRatio="none" width="100%" height="100%">
              <defs>
                <linearGradient id="loginDashboardGradient" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#22c55e" stopOpacity="0.35" />
                  <stop offset="100%" stopColor="#22c55e" stopOpacity="0" />
                </linearGradient>
              </defs>
              <polygon points="0,44 22,34 44,38 70,21 90,27 110,15 130,19 155,11 180,14 180,52 0,52" fill="url(#loginDashboardGradient)" />
              <polyline points="0,44 22,34 44,38 70,21 90,27 110,15 130,19 155,11 180,14" stroke="#22c55e" strokeWidth="1.8" fill="none" strokeLinejoin="round" />
            </svg>
          </div>

          <div className={styles.previewStats}>
            <PreviewStat label={isRu ? "Польз." : "Users"} value="1 256" delta="▲ 12.5%" />
            <PreviewStat label={isRu ? "Заказы" : "Orders"} value="3 846" delta="▲ 8.1%" />
            <PreviewStat label={isRu ? "Шаблоны" : "Templ."} value="74%" delta="▲ 4.3%" />
          </div>
        </div>
      </div>
    </div>
  );
}

function PreviewStat({ label, value, delta }: { label: string; value: string; delta: string }) {
  return (
    <div className={styles.previewStat}>
      <span className={styles.previewStatLabel}>{label}</span>
      <span className={styles.previewStatValue}>{value}</span>
      <span className={styles.previewStatDelta}>{delta}</span>
    </div>
  );
}
