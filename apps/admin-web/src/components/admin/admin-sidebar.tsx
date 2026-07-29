import Link from "next/link";
import { useMemo, type RefObject } from "react";

import { getAdminChromeCopy } from "@/components/admin/admin-chrome.content";
import {
  BrandMark,
  CaretDownIcon,
  ChartIcon,
  ClockIcon,
  DashboardIcon,
  DollarIcon,
  ImageIcon,
  LogoutIcon,
  PawIcon,
  PromoCodeIcon,
  SupportIcon,
  TemplatesIcon,
  UsersIcon,
  VideoIcon,
} from "@/components/admin/admin-icons";
import styles from "@/components/admin/admin-shell.module.css";
import { getAdminNavItems, matchesAdminPath, type AdminNavEntry } from "@/lib/admin-navigation";
import { buildAdminNavigationAreas } from "@/lib/admin-navigation-areas";
import { type Locale } from "@/lib/i18n";

type AdminSidebarProps = {
  locale: Locale;
  currentPath: string;
  isOpen: boolean;
  isDrawerMode: boolean;
  isCollapsed: boolean;
  sidebarRef: RefObject<HTMLElement | null>;
  onClose: () => void;
  onNavigate: () => void;
  onLogout: () => void;
  logoutDisabled?: boolean;
  logoutLabel: string;
  supportUnreadCount?: number;
  roles?: readonly string[] | null;
};

const iconMap = {
  dashboard: DashboardIcon,
  economy: DollarIcon,
  gamification: PawIcon,
  "promo-codes": PromoCodeIcon,
  support: SupportIcon,
  moderation: ChartIcon,
  audit: ClockIcon,
  users: UsersIcon,
  generations: ChartIcon,
  feedback: SupportIcon,
  "role-management": UsersIcon,
  templates: TemplatesIcon,
  "image-templates": ImageIcon,
  "template-analytics": ChartIcon,
  "video-templates": VideoIcon,
  "template-categories": TemplatesIcon,
  "template-daily-featured": TemplatesIcon,
};

function getTargetPath(href: string) {
  const normalized = href.replace(/^\/(ru|en)(?=\/|$)/, "") || "/";
  return normalized.startsWith("/") ? normalized : `/${normalized}`;
}

function buildNavSections(navItems: readonly AdminNavEntry[], locale: Locale) {
  return buildAdminNavigationAreas(locale, navItems);
}

export function AdminSidebar({
  locale,
  currentPath,
  isOpen,
  isDrawerMode,
  isCollapsed,
  sidebarRef,
  onClose,
  onNavigate,
  onLogout,
  logoutDisabled = false,
  logoutLabel,
  supportUnreadCount = 0,
  roles,
}: AdminSidebarProps) {
  const copy = useMemo(() => getAdminChromeCopy(locale), [locale]);
  const navItems = useMemo(() => getAdminNavItems(locale, roles), [locale, roles]);
  const navSections = useMemo(() => buildNavSections(navItems, locale), [locale, navItems]);
  const brandTitle = copy.sidebar.brandTitle;
  const brandCaption = copy.sidebar.brandCaption;
  const navigationLabel = copy.sidebar.navigationLabel;
  const isDrawerDialog = isDrawerMode && isOpen;

  function renderNavEntry(item: AdminNavEntry) {
    if (item.type === "group") {
      const Icon = iconMap[item.key];
      const groupCurrent = matchesAdminPath(currentPath, getTargetPath(item.href));
      const groupActive = item.items.some((child) =>
        matchesAdminPath(currentPath, getTargetPath(child.href))
      );
      const groupSelected = groupCurrent || groupActive;

      return (
        <div key={item.key} className={styles.navGroup}>
          <Link
            href={item.href}
            className={`${styles.navItem}${groupSelected ? ` ${styles.navItemActive}` : ""}`}
            aria-current={groupCurrent ? "page" : undefined}
            onClick={onNavigate}
            title={isCollapsed ? item.label : undefined}
          >
            <Icon className={styles.navIcon} />
            <span className={styles.navLabel}>{item.label}</span>
            <CaretDownIcon
              className={`${styles.groupCaret}${groupSelected ? ` ${styles.groupCaretOpen}` : ""}`}
            />
          </Link>

          <div className={styles.navChildren} role="group" aria-label={item.label}>
            {item.items.map((child) => {
              const childActive = matchesAdminPath(currentPath, getTargetPath(child.href));

              return (
                <Link
                  key={child.key}
                  href={child.href}
                  className={`${styles.navChild}${childActive ? ` ${styles.navChildActive}` : ""}`}
                  aria-current={childActive ? "page" : undefined}
                  onClick={onNavigate}
                >
                  <span className={styles.navChildLabel}>{child.label}</span>
                </Link>
              );
            })}
          </div>
        </div>
      );
    }

    const Icon = iconMap[item.key];
    const active = matchesAdminPath(currentPath, getTargetPath(item.href));

    return (
      <Link
        key={item.key}
        href={item.href}
        className={`${styles.navItem}${active ? ` ${styles.navItemActive}` : ""}`}
        aria-current={active ? "page" : undefined}
        onClick={onNavigate}
        title={isCollapsed ? item.label : undefined}
      >
        <Icon className={styles.navIcon} />
        <span className={styles.navLabel}>{item.label}</span>
        {item.key === "support" && supportUnreadCount > 0 ? (
          <span
            className={styles.navBadge}
            aria-label={copy.sidebar.supportUnreadLabel(supportUnreadCount)}
          >
            {supportUnreadCount > 99 ? "99+" : supportUnreadCount}
          </span>
        ) : null}
      </Link>
    );
  }

  return (
    <aside
      ref={sidebarRef}
      id="admin-sidebar"
      className={`${styles.sidebar}${isOpen ? ` ${styles.sidebarOpen}` : ""}${isCollapsed ? ` ${styles.sidebarCollapsed}` : ""}`}
      role={isDrawerDialog ? "dialog" : undefined}
      aria-modal={isDrawerDialog ? "true" : undefined}
      aria-label={navigationLabel}
      aria-hidden={isDrawerMode && !isOpen ? "true" : undefined}
      inert={isDrawerMode && !isOpen}
      tabIndex={isDrawerDialog ? -1 : undefined}
    >
      <div className={styles.brand}>
        <BrandMark className={styles.brandMark} />
        <div>
          <span className={styles.brandName}>{brandTitle}</span>
          <span className={styles.brandCaption}>{brandCaption}</span>
        </div>
        <button
          type="button"
          className={styles.sidebarClose}
          onClick={onClose}
          aria-label={copy.sidebar.closeNavigationLabel}
          title={copy.sidebar.closeNavigationLabel}
          data-admin-sidebar-close
        >
          <span aria-hidden="true">×</span>
        </button>
      </div>

      <nav className={styles.nav} aria-label={navigationLabel}>
        {navSections.map((section) => (
          <div key={section.key} className={styles.navSection}>
            <p className={styles.navSectionTitle}>{section.label}</p>
            <div className={styles.navSectionItems}>
              {section.items.map((item) => renderNavEntry(item))}
            </div>
          </div>
        ))}
      </nav>

      <div className={styles.sidebarFooter}>
        <button
          type="button"
          className={styles.logoutButton}
          onClick={onLogout}
          disabled={logoutDisabled}
        >
          <LogoutIcon className={styles.navIcon} />
          <span className={styles.navLabel}>{logoutLabel}</span>
        </button>
      </div>
    </aside>
  );
}
