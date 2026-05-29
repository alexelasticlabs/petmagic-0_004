import Link from "next/link";

import {
  BrandMark,
  CaretDownIcon,
  ChartIcon,
  DashboardIcon,
  DollarIcon,
  ImageIcon,
  LogoutIcon,
  PromoCodeIcon,
  SupportIcon,
  TemplatesIcon,
  UsersIcon,
  VideoIcon,
} from "@/components/admin/admin-icons";
import styles from "@/components/admin/admin-shell.module.css";
import {
  getAdminNavItems,
  matchesAdminPath,
  type AdminNavEntry,
  type AdminSectionKey,
} from "@/lib/admin-navigation";
import { getDictionary, type Locale } from "@/lib/i18n";

type AdminSidebarProps = {
  locale: Locale;
  currentPath: string;
  isOpen: boolean;
  onNavigate: () => void;
  onLogout: () => void;
  logoutLabel: string;
  supportUnreadCount?: number;
};

const iconMap = {
  dashboard: DashboardIcon,
  economy: DollarIcon,
  "promo-codes": PromoCodeIcon,
  support: SupportIcon,
  users: UsersIcon,
  templates: TemplatesIcon,
  "image-templates": ImageIcon,
  "template-analytics": ChartIcon,
  "video-templates": VideoIcon,
  "template-categories": TemplatesIcon,
};

function getTargetPath(href: string) {
  const normalized = href.replace(/^\/(ru|en)(?=\/|$)/, "") || "/";
  return normalized.startsWith("/") ? normalized : `/${normalized}`;
}

type NavSection = {
  key: string;
  label: string;
  items: AdminNavEntry[];
};

function buildNavSections(navItems: AdminNavEntry[], locale: Locale): NavSection[] {
  const text = getDictionary(locale);
  const byKey = new Map<AdminSectionKey, AdminNavEntry>(navItems.map((item) => [item.key, item]));

  const sections: Array<{ key: string; label: string; itemKeys: AdminSectionKey[] }> = [
    { key: "overview", label: text.navSectionOverview, itemKeys: ["dashboard", "economy"] },
    { key: "growth", label: text.navSectionGrowth, itemKeys: ["promo-codes"] },
    { key: "content", label: text.navSectionContent, itemKeys: ["templates"] },
    { key: "users", label: text.navSectionUsers, itemKeys: ["users", "support"] },
  ];

  return sections
    .map((section) => ({
      key: section.key,
      label: section.label,
      items: section.itemKeys
        .map((itemKey) => byKey.get(itemKey))
        .filter((item): item is AdminNavEntry => Boolean(item)),
    }))
    .filter((section) => section.items.length > 0);
}

export function AdminSidebar({
  locale,
  currentPath,
  isOpen,
  onNavigate,
  onLogout,
  logoutLabel,
  supportUnreadCount = 0,
}: AdminSidebarProps) {
  const navItems = getAdminNavItems(locale);
  const navSections = buildNavSections(navItems, locale);
  const brandCaption = locale === "ru" ? "Операционная админ-зона" : "Operational admin workspace";

  function renderNavEntry(item: AdminNavEntry) {
    if (item.type === "group") {
      const Icon = iconMap[item.key];
      const groupCurrent = matchesAdminPath(currentPath, getTargetPath(item.href));
      const groupActive = item.items.some((child) =>
        matchesAdminPath(currentPath, getTargetPath(child.href))
      );

      return (
        <div key={item.key} className={styles.navGroup}>
          <Link
            href={item.href}
            className={`${styles.navItem}${groupActive ? ` ${styles.navItemActive}` : ""}`}
            aria-current={groupCurrent ? "page" : undefined}
            onClick={onNavigate}
          >
            <Icon className={styles.navIcon} />
            <span className={styles.navLabel}>{item.label}</span>
            <CaretDownIcon
              className={`${styles.groupCaret}${groupActive ? ` ${styles.groupCaretOpen}` : ""}`}
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
      >
        <Icon className={styles.navIcon} />
        <span className={styles.navLabel}>{item.label}</span>
        {item.key === "support" && supportUnreadCount > 0 ? (
          <span
            className={styles.navBadge}
            aria-label={
              locale === "ru"
                ? `${supportUnreadCount} новых сообщений в поддержке`
                : `${supportUnreadCount} new support messages`
            }
          >
            {supportUnreadCount > 99 ? "99+" : supportUnreadCount}
          </span>
        ) : null}
      </Link>
    );
  }

  return (
    <aside
      id="admin-sidebar"
      className={`${styles.sidebar}${isOpen ? ` ${styles.sidebarOpen}` : ""}`}
      aria-label="Admin navigation"
    >
      <div className={styles.brand}>
        <BrandMark className={styles.brandMark} />
        <div>
          <span className={styles.brandName}>PetMagic Admin</span>
          <span className={styles.brandCaption}>{brandCaption}</span>
        </div>
      </div>

      <nav className={styles.nav} aria-label="Main navigation">
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
        <button type="button" className={styles.logoutButton} onClick={onLogout}>
          <LogoutIcon className={styles.navIcon} />
          <span className={styles.navLabel}>{logoutLabel}</span>
        </button>
      </div>
    </aside>
  );
}
