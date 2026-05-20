import {
  BrandMark,
  CaretDownIcon,
  ChartIcon,
  DashboardIcon,
  DollarIcon,
  ImageIcon,
  LogoutIcon,
  SupportIcon,
  TemplatesIcon,
  UsersIcon,
  VideoIcon,
} from "@/components/admin/admin-icons";
import styles from "@/components/admin/admin-shell.module.css";
import { getAdminNavItems, matchesAdminPath } from "@/lib/admin-navigation";
import { type Locale } from "@/lib/i18n";
import Link from "next/link";

type AdminSidebarProps = {
  locale: Locale;
  currentPath: string;
  isOpen: boolean;
  onNavigate: () => void;
  onLogout: () => void;
  logoutLabel: string;
};

const iconMap = {
  dashboard: DashboardIcon,
  economy: DollarIcon,
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

export function AdminSidebar({ locale, currentPath, isOpen, onNavigate, onLogout, logoutLabel }: AdminSidebarProps) {
  const navItems = getAdminNavItems(locale);
  const brandCaption = locale === "ru" ? "Операционная админ-зона" : "Operational admin workspace";

  return (
    <aside id="admin-sidebar" className={`${styles.sidebar}${isOpen ? ` ${styles.sidebarOpen}` : ""}`} aria-label="Admin navigation">
      <div className={styles.brand}>
        <BrandMark className={styles.brandMark} />
        <div>
          <span className={styles.brandName}>PetMagic Admin</span>
          <span className={styles.brandCaption}>{brandCaption}</span>
        </div>
      </div>

      <nav className={styles.nav} aria-label="Main navigation">
        {navItems.map((item) => {
          if (item.type === "group") {
            const Icon = iconMap[item.key];
            const groupCurrent = matchesAdminPath(currentPath, getTargetPath(item.href));
            const groupActive = item.items.some((child) => matchesAdminPath(currentPath, getTargetPath(child.href)));

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
                  <CaretDownIcon className={`${styles.groupCaret}${groupActive ? ` ${styles.groupCaretOpen}` : ""}`} />
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
            </Link>
          );
        })}
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
