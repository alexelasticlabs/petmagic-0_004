import { CaretDownIcon, MenuIcon } from "@/components/admin/admin-icons";
import { AdminLangDropdown } from "@/components/admin/admin-lang-dropdown";
import styles from "@/components/admin/admin-shell.module.css";
import { type Locale } from "@/lib/i18n";

type AdminTopbarProps = {
  locale: Locale;
  pageTitle: string;
  pageDescription: string;
  userName: string;
  userRole: string;
  userInitial: string;
  ruPath: string;
  enPath: string;
  sidebarOpen: boolean;
  onToggleSidebar: () => void;
};

export function AdminTopbar({
  locale,
  pageTitle,
  pageDescription,
  userName,
  userRole,
  userInitial,
  ruPath,
  enPath,
  sidebarOpen,
  onToggleSidebar,
}: AdminTopbarProps) {
  return (
    <header className={styles.topbar}>
      <button
        type="button"
        className={styles.sidebarToggle}
        onClick={onToggleSidebar}
        aria-expanded={sidebarOpen}
        aria-controls="admin-sidebar"
        aria-label={locale === "ru" ? "Открыть навигацию" : "Open navigation"}
      >
        <MenuIcon className={styles.navIcon} />
      </button>

      <div className={styles.topbarHeading}>
        <h1 className={styles.topbarTitle}>{pageTitle}</h1>
        <p className={styles.topbarSummary}>{pageDescription}</p>
      </div>

      <div className={styles.topbarActions}>
        <AdminLangDropdown locale={locale} ruPath={ruPath} enPath={enPath} />
        <div className={styles.userBadge}>
          <div className={styles.userAvatar} aria-hidden="true">
            {userInitial}
          </div>
          <div className={styles.userMeta}>
            <span className={styles.userName}>{userName}</span>
            <span className={styles.userRole}>{userRole}</span>
          </div>
          <CaretDownIcon className={styles.caret} />
        </div>
      </div>
    </header>
  );
}
