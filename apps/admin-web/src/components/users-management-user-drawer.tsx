"use client";

import Link from "next/link";

import { Button } from "@/components/ui/button";
import { useAdminUserProfile } from "@/components/users/use-admin-user-profile";
import { getAccountStatus } from "@/components/users-management-page.helpers";
import styles from "@/components/users-management-page.module.css";
import type { UserListItem } from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import type { Locale } from "@/lib/i18n";
import { maskEmail, sanitizeSensitiveText } from "@/lib/sensitive-display";

type Props = { locale: Locale; user: UserListItem | null; onClose: () => void };

export function UsersManagementUserDrawer({ locale, user, onClose }: Props) {
  const { analytics, isLoading } = useAdminUserProfile({
    enabled: Boolean(user),
    userId: user?.userId ?? null,
  });
  if (!user) return null;
  const label = sanitizeSensitiveText(user.displayName, 96) || maskEmail(user.email);
  const href = `/${locale}/users/${encodeURIComponent(user.userId)}`;
  const status = getAccountStatus(user);
  return (
    <aside className={styles.userDrawer} role="dialog" aria-modal="true" aria-label={label}>
      <div className={styles.drawerHeader}>
        <div>
          <strong>{label}</strong>
          <span>{maskEmail(user.email)}</span>
        </div>
        <Button variant="ghost" size="sm" onClick={onClose} aria-label="Закрыть">
          ×
        </Button>
      </div>
      <div className={styles.drawerFacts}>
        <span>
          Статус{" "}
          <b className={styles.compactStatus} data-status={status}>
            {status}
          </b>
        </span>
        <span>
          План <b>{user.isPremium ? "Premium" : "Free"}</b>
        </span>
        <span>
          Баланс <b>{isLoading ? "…" : `${analytics?.summary.walletBalance ?? "—"} PawSpark`}</b>
        </span>
        <span>
          Последняя активность{" "}
          <b>{user.lastActivityAtUtc ? formatDateTime(user.lastActivityAtUtc, locale) : "—"}</b>
        </span>
        <span>
          Регистрация <b>{formatDateTime(user.createdAtUtc, locale)}</b>
        </span>
        <span>
          User ID <b>{user.userId}</b>
        </span>
      </div>
      <div className={styles.drawerActions}>
        <Link
          className="ui-button ui-button--primary ui-button--sm"
          href={`${href}?tab=wallet&action=adjust-balance`}
        >
          + PawSpark
        </Link>
        <Link
          className="ui-button ui-button--secondary ui-button--sm"
          href={`${href}?tab=wallet&action=adjust-balance`}
        >
          Изменить баланс
        </Link>
        <Link className="ui-button ui-button--secondary ui-button--sm" href={`${href}?tab=access`}>
          Premium и доступ
        </Link>
      </div>
      <nav className={styles.drawerLinks} aria-label="Разделы досье">
        <Link href={href}>Досье</Link>
        <Link href={`${href}?tab=wallet`}>Платежи</Link>
        <Link href={`${href}?tab=content`}>Генерации</Link>
        <Link href={`${href}?tab=support`}>Обращения</Link>
        <Link href={`${href}?tab=access`}>Email-история и сессии</Link>
      </nav>
      <Link
        className={`${styles.drawerDanger} ui-button ui-button--danger ui-button--sm`}
        href={`${href}?tab=access`}
      >
        {user.isActive ? "Заблокировать" : "Разблокировать"}
      </Link>
    </aside>
  );
}
