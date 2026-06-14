import { type ReactNode } from "react";

import { AdminLoginPreviewChart, BrandMark } from "@/components/admin/admin-icons";
import { AdminLangDropdown } from "@/components/admin/admin-lang-dropdown";
import styles from "@/components/admin/admin-login-screen.module.css";
import { type Locale } from "@/lib/i18n";

type AdminLoginScreenProps = {
  locale: Locale;
  onToggleTheme: () => void;
  children: ReactNode;
};

export function AdminLoginScreen({
  locale,
  onToggleTheme,
  children,
}: AdminLoginScreenProps) {
  const welcomeTitle = locale === "ru" ? "Добро пожаловать!" : "Welcome!";
  const welcomeSubtitle =
    locale === "ru"
      ? "Войдите в панель администратора, чтобы продолжить работу"
      : "Sign in to the admin panel to continue your work";
  const copyright =
    locale === "ru"
      ? "© 2026 Admin Panel. Все права защищены."
      : "© 2026 Admin Panel. All rights reserved.";
  const themeLabel = locale === "ru" ? "Тема" : "Theme";
  const toggleThemeAriaLabel = locale === "ru" ? "Сменить тему" : "Toggle theme";

  return (
    <div className={styles.screen}>
      <div className={styles.left}>
        <BrandMark className={styles.brandMark} />
        <h2 className={styles.welcome}>{welcomeTitle}</h2>
        <p className={styles.tagline}>{welcomeSubtitle}</p>
        <LoginDashboardPreview />
      </div>

      <div className={styles.right}>
        <div className={styles.topbar}>
          <button
            type="button"
            className={styles.themeToggle}
            onClick={onToggleTheme}
            aria-label={toggleThemeAriaLabel}
          >
            <span className={styles.themeToggleIndicator} aria-hidden="true" />
            <span>{themeLabel}</span>
          </button>
          <AdminLangDropdown locale={locale} ruPath="/ru" enPath="/en" />
        </div>
        <div className={styles.body}>{children}</div>
        <footer className={styles.copyright}>{copyright}</footer>
      </div>
    </div>
  );
}

function LoginDashboardPreview() {
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
            <AdminLoginPreviewChart className={styles.previewChartGraphic} />
          </div>

          <div className={styles.previewStats}>
            <PreviewStatSkeleton />
            <PreviewStatSkeleton />
            <PreviewStatSkeleton />
          </div>
        </div>
      </div>
    </div>
  );
}

function PreviewStatSkeleton() {
  return (
    <div className={styles.previewStat}>
      <span className={styles.previewStatLabel} />
      <span className={styles.previewStatValue} />
      <span className={styles.previewStatDelta} />
    </div>
  );
}
