"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useCallback, useEffect, useId, useMemo, useRef, useState } from "react";

import {
  getAdminChromeCopy,
  type AdminNotificationCategory,
} from "@/components/admin/admin-chrome.content";
import { BellIcon, CaretDownIcon, MenuIcon } from "@/components/admin/admin-icons";
import { AdminLangDropdown } from "@/components/admin/admin-lang-dropdown";
import {
  sanitizeAdminNotificationText,
  useAdminNotifications,
} from "@/components/admin/admin-notifications";
import styles from "@/components/admin/admin-shell.module.css";
import { type Locale } from "@/lib/i18n";
import { type AdminTheme } from "@/lib/theme";

type NotificationFilter =
  "all" | "unread" | "support" | "users" | "templates" | "economy" | "promo" | "system";

type AdminTopbarProps = {
  locale: Locale;
  pageTitle: string;
  pageDescription: string;
  supportUnreadCount: number;
  theme: AdminTheme;
  userName: string;
  userRole: string;
  userInitial: string;
  ruPath: string;
  enPath: string;
  sidebarOpen: boolean;
  onToggleSidebar: () => void;
  onToggleTheme: () => void;
};

const NOTIFICATION_RENDER_TITLE_MAX_LENGTH = 96;
const NOTIFICATION_RENDER_MESSAGE_MAX_LENGTH = 240;

export function AdminTopbar({
  locale,
  pageTitle,
  pageDescription,
  supportUnreadCount,
  theme,
  userName,
  userRole,
  userInitial,
  ruPath,
  enPath,
  sidebarOpen,
  onToggleSidebar,
  onToggleTheme,
}: AdminTopbarProps) {
  const copy = useMemo(() => getAdminChromeCopy(locale), [locale]);
  const pathname = usePathname();
  const { clearRead, items, markAllAsRead, markAsRead, markCategoryAsRead, unreadCount } =
    useAdminNotifications();
  const [notificationPanelPathname, setNotificationPanelPathname] = useState<string | null>(null);
  const [notificationFilter, setNotificationFilter] = useState<NotificationFilter>("all");
  const notificationRootRef = useRef<HTMLDivElement | null>(null);
  const notificationTriggerRef = useRef<HTMLButtonElement | null>(null);
  const notificationPanelRef = useRef<HTMLDivElement | null>(null);
  const previousNotificationPathnameRef = useRef(pathname);
  const notificationPanelId = useId();
  const notificationPanelTitleId = useId();
  const themeLabel = copy.topbar.themeLabel(theme);
  const nextThemeAriaLabel = copy.topbar.nextThemeAriaLabel(theme);
  const sidebarToggleLabel = copy.topbar.sidebarToggleLabel(sidebarOpen);
  const notificationFiltersLabel = copy.topbar.notificationFiltersLabel;
  const unreadSupportNotificationCount = items.filter(
    (item) => item.category === "support" && !item.read
  ).length;
  const unreadNonSupportNotificationCount = unreadCount - unreadSupportNotificationCount;
  const totalAttentionCount =
    unreadNonSupportNotificationCount +
    Math.max(unreadSupportNotificationCount, supportUnreadCount);
  const filterOptions = useMemo(
    () => [
      { value: "all" as const, label: copy.topbar.filterLabels.all },
      { value: "unread" as const, label: copy.topbar.filterLabels.unread },
      { value: "support" as const, label: copy.topbar.filterLabels.support },
      { value: "users" as const, label: copy.topbar.filterLabels.users },
      { value: "templates" as const, label: copy.topbar.filterLabels.templates },
      { value: "economy" as const, label: copy.topbar.filterLabels.economy },
      { value: "promo" as const, label: copy.topbar.filterLabels.promo },
      { value: "system" as const, label: copy.topbar.filterLabels.system },
    ],
    [copy]
  );

  const filteredNotifications = useMemo(() => {
    return items.filter((item) => {
      if (notificationFilter === "unread") {
        return !item.read;
      }

      if (notificationFilter === "all") {
        return true;
      }

      return item.category === notificationFilter;
    });
  }, [items, notificationFilter]);
  const pinnedNotifications = useMemo(
    () => filteredNotifications.filter((item) => item.priority === "critical"),
    [filteredNotifications]
  );
  const groupedNotifications = useMemo(
    () =>
      groupNotificationsByDate(
        filteredNotifications.filter((item) => item.priority !== "critical"),
        locale
      ),
    [filteredNotifications, locale]
  );

  const shouldShowSupportSummary =
    supportUnreadCount > 0 &&
    (notificationFilter === "all" ||
      notificationFilter === "unread" ||
      notificationFilter === "support");

  const isNotificationsOpen = notificationPanelPathname === pathname;
  const notificationTriggerLabel = copy.topbar.notificationTriggerLabel(isNotificationsOpen);

  const closeNotificationPanel = useCallback((options?: { restoreFocus?: boolean }) => {
    setNotificationPanelPathname(null);

    if (options?.restoreFocus && typeof window !== "undefined") {
      window.requestAnimationFrame(() => notificationTriggerRef.current?.focus());
    }
  }, []);

  useEffect(() => {
    if (previousNotificationPathnameRef.current === pathname) {
      return;
    }

    previousNotificationPathnameRef.current = pathname;
    setNotificationPanelPathname(null);
  }, [pathname]);

  useEffect(() => {
    if (!isNotificationsOpen) {
      return;
    }

    notificationPanelRef.current?.focus();
  }, [isNotificationsOpen]);

  useEffect(() => {
    const isSupportRoute = /^\/(ru|en)\/support(\/|$)/.test(pathname);
    if (!isSupportRoute) {
      return;
    }

    if (items.some((item) => item.category === "support" && !item.read)) {
      markCategoryAsRead("support");
    }
  }, [items, markCategoryAsRead, pathname]);

  useEffect(() => {
    if (!isNotificationsOpen) {
      return;
    }

    function handlePointerDown(event: MouseEvent) {
      if (
        notificationRootRef.current &&
        event.target instanceof Node &&
        !notificationRootRef.current.contains(event.target)
      ) {
        closeNotificationPanel();
      }
    }

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        closeNotificationPanel({ restoreFocus: true });
      }
    }

    window.addEventListener("mousedown", handlePointerDown);
    window.addEventListener("keydown", handleKeyDown);
    return () => {
      window.removeEventListener("mousedown", handlePointerDown);
      window.removeEventListener("keydown", handleKeyDown);
    };
  }, [closeNotificationPanel, isNotificationsOpen]);

  return (
    <header className={styles.topbar}>
      <button
        type="button"
        className={styles.sidebarToggle}
        onClick={onToggleSidebar}
        aria-expanded={sidebarOpen}
        aria-controls="admin-sidebar"
        aria-label={sidebarToggleLabel}
        title={sidebarToggleLabel}
      >
        <MenuIcon className={styles.navIcon} />
      </button>

      <div className={styles.topbarHeading}>
        <h1 className={styles.topbarTitle}>{pageTitle}</h1>
        <p className={styles.topbarSummary}>{pageDescription}</p>
      </div>

      <div className={styles.topbarActions}>
        <div className={styles.notificationRoot} ref={notificationRootRef}>
          <button
            ref={notificationTriggerRef}
            type="button"
            className={`${styles.localeTrigger} ${styles.notificationTrigger} ${isNotificationsOpen ? styles.notificationTriggerActive : ""}`}
            onClick={() => {
              if (isNotificationsOpen) {
                closeNotificationPanel({ restoreFocus: true });
                return;
              }

              setNotificationPanelPathname(pathname);
            }}
            aria-haspopup="dialog"
            aria-expanded={isNotificationsOpen}
            aria-controls={isNotificationsOpen ? notificationPanelId : undefined}
            aria-label={notificationTriggerLabel}
            title={notificationTriggerLabel}
          >
            <BellIcon className={styles.localeIcon} />
            {totalAttentionCount > 0 ? (
              <span className={styles.notificationBadge}>{totalAttentionCount}</span>
            ) : null}
          </button>

          {isNotificationsOpen ? (
            <div
              id={notificationPanelId}
              ref={notificationPanelRef}
              className={styles.notificationPanel}
              role="dialog"
              aria-labelledby={notificationPanelTitleId}
              tabIndex={-1}
            >
              <div className={styles.notificationPanelHeader}>
                <div className={styles.notificationPanelCopy}>
                  <span className={styles.notificationEyebrow}>{copy.topbar.centerEyebrow}</span>
                  <strong id={notificationPanelTitleId} className={styles.notificationTitle}>
                    {copy.topbar.centerTitle}
                  </strong>
                  <p className={styles.notificationSummary}>
                    {copy.topbar.summary(unreadCount, supportUnreadCount)}
                  </p>
                </div>
                <div className={styles.notificationHeaderActions}>
                  <button
                    type="button"
                    className={styles.notificationTextButton}
                    onClick={markAllAsRead}
                    disabled={unreadCount === 0}
                  >
                    {copy.topbar.markAllRead}
                  </button>
                  <button
                    type="button"
                    className={styles.notificationTextButton}
                    onClick={clearRead}
                    disabled={items.every((item) => !item.read)}
                  >
                    {copy.topbar.clearRead}
                  </button>
                </div>
              </div>

              <div
                className={styles.notificationFilters}
                role="toolbar"
                aria-label={notificationFiltersLabel}
              >
                {filterOptions.map((filterOption) => (
                  <button
                    key={filterOption.value}
                    type="button"
                    className={`${styles.notificationFilterChip} ${notificationFilter === filterOption.value ? styles.notificationFilterChipActive : ""}`}
                    aria-pressed={notificationFilter === filterOption.value}
                    onClick={() => setNotificationFilter(filterOption.value)}
                  >
                    {filterOption.label}
                  </button>
                ))}
              </div>

              <div className={styles.notificationList}>
                {shouldShowSupportSummary ? (
                  <Link
                    href={`/${locale}/support`}
                    className={`${styles.notificationCard} ${styles.notificationCardUnread} ${styles.notificationCardPinned}`}
                    onClick={() => closeNotificationPanel()}
                  >
                    <div className={styles.notificationCardMeta}>
                      <div className={styles.notificationCardMetaLead}>
                        <span className={styles.notificationPinnedMark}>
                          {copy.topbar.critical}
                        </span>
                        <span
                          className={`${styles.notificationCategoryPill} ${styles.notificationCategorySupport}`}
                        >
                          {copy.topbar.categoryLabels.support}
                        </span>
                      </div>
                      <span className={styles.notificationTime}>{copy.topbar.needsAttention}</span>
                    </div>
                    <strong className={styles.notificationCardTitle}>
                      {copy.topbar.supportSummaryTitle(supportUnreadCount)}
                    </strong>
                    <p className={styles.notificationCardMessage}>
                      {copy.topbar.supportSummaryMessage}
                    </p>
                  </Link>
                ) : null}

                {pinnedNotifications.length > 0 ? (
                  <section className={styles.notificationGroupSection}>
                    <div className={styles.notificationGroupHeader}>
                      <span className={styles.notificationGroupTitle}>{copy.topbar.critical}</span>
                    </div>
                    <div className={styles.notificationGroupItems}>
                      {pinnedNotifications.map((item) => {
                        const safeNotificationTitle = sanitizeAdminNotificationText(
                          item.title,
                          NOTIFICATION_RENDER_TITLE_MAX_LENGTH
                        );
                        const safeNotificationMessage = sanitizeAdminNotificationText(
                          item.message,
                          NOTIFICATION_RENDER_MESSAGE_MAX_LENGTH
                        );
                        const content = (
                          <>
                            <div className={styles.notificationCardMeta}>
                              <div className={styles.notificationCardMetaLead}>
                                <span className={styles.notificationPinnedMark}>
                                  {copy.topbar.pinned}
                                </span>
                                <span
                                  className={`${styles.notificationCategoryPill} ${item.category === "support" ? styles.notificationCategorySupport : item.category === "users" ? styles.notificationCategoryUsers : item.category === "templates" ? styles.notificationCategoryTemplates : item.category === "economy" ? styles.notificationCategoryEconomy : item.category === "promo" ? styles.notificationCategoryPromo : styles.notificationCategorySystem}`}
                                >
                                  {getNotificationCategoryLabel(
                                    item.category,
                                    copy.topbar.categoryLabels
                                  )}
                                </span>
                              </div>
                              <span className={styles.notificationTime}>
                                {formatRelativeNotificationTime(item.createdAt, locale)}
                              </span>
                            </div>
                            <strong className={styles.notificationCardTitle}>
                              {safeNotificationTitle}
                            </strong>
                            <p className={styles.notificationCardMessage}>
                              {safeNotificationMessage}
                            </p>
                          </>
                        );

                        if (item.href) {
                          return (
                            <Link
                              key={item.id}
                              href={item.href}
                              className={`${styles.notificationCard} ${styles.notificationCardPinned} ${!item.read ? styles.notificationCardUnread : ""}`}
                              onClick={() => {
                                markAsRead(item.id);
                                closeNotificationPanel();
                              }}
                            >
                              {content}
                            </Link>
                          );
                        }

                        return (
                          <button
                            key={item.id}
                            type="button"
                            className={`${styles.notificationCard} ${styles.notificationCardButton} ${styles.notificationCardPinned} ${!item.read ? styles.notificationCardUnread : ""}`}
                            onClick={() => markAsRead(item.id)}
                          >
                            {content}
                          </button>
                        );
                      })}
                    </div>
                  </section>
                ) : null}

                {groupedNotifications.map((group) => (
                  <section key={group.key} className={styles.notificationGroupSection}>
                    <div className={styles.notificationGroupHeader}>
                      <span className={styles.notificationGroupTitle}>{group.label}</span>
                    </div>
                    <div className={styles.notificationGroupItems}>
                      {group.items.map((item) => {
                        const safeNotificationTitle = sanitizeAdminNotificationText(
                          item.title,
                          NOTIFICATION_RENDER_TITLE_MAX_LENGTH
                        );
                        const safeNotificationMessage = sanitizeAdminNotificationText(
                          item.message,
                          NOTIFICATION_RENDER_MESSAGE_MAX_LENGTH
                        );
                        const content = (
                          <>
                            <div className={styles.notificationCardMeta}>
                              <span
                                className={`${styles.notificationCategoryPill} ${item.category === "support" ? styles.notificationCategorySupport : item.category === "users" ? styles.notificationCategoryUsers : item.category === "templates" ? styles.notificationCategoryTemplates : item.category === "economy" ? styles.notificationCategoryEconomy : item.category === "promo" ? styles.notificationCategoryPromo : styles.notificationCategorySystem}`}
                              >
                                {getNotificationCategoryLabel(
                                  item.category,
                                  copy.topbar.categoryLabels
                                )}
                              </span>
                              <span className={styles.notificationTime}>
                                {formatRelativeNotificationTime(item.createdAt, locale)}
                              </span>
                            </div>
                            <strong className={styles.notificationCardTitle}>
                              {safeNotificationTitle}
                            </strong>
                            <p className={styles.notificationCardMessage}>
                              {safeNotificationMessage}
                            </p>
                          </>
                        );

                        if (item.href) {
                          return (
                            <Link
                              key={item.id}
                              href={item.href}
                              className={`${styles.notificationCard} ${!item.read ? styles.notificationCardUnread : ""}`}
                              onClick={() => {
                                markAsRead(item.id);
                                closeNotificationPanel();
                              }}
                            >
                              {content}
                            </Link>
                          );
                        }

                        return (
                          <button
                            key={item.id}
                            type="button"
                            className={`${styles.notificationCard} ${styles.notificationCardButton} ${!item.read ? styles.notificationCardUnread : ""}`}
                            onClick={() => markAsRead(item.id)}
                          >
                            {content}
                          </button>
                        );
                      })}
                    </div>
                  </section>
                ))}

                {!shouldShowSupportSummary &&
                pinnedNotifications.length === 0 &&
                groupedNotifications.length === 0 ? (
                  <div className={styles.notificationEmptyState}>
                    <strong>{copy.topbar.emptyTitle}</strong>
                    <p>{copy.topbar.emptyMessage}</p>
                  </div>
                ) : null}
              </div>
            </div>
          ) : null}
        </div>

        <button
          type="button"
          className={`${styles.localeTrigger} ${styles.themeTrigger}`}
          onClick={onToggleTheme}
          aria-label={nextThemeAriaLabel}
        >
          <span className={styles.themeIndicator} aria-hidden="true" />
          <span>{themeLabel}</span>
        </button>
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

type NotificationGroup = {
  key: string;
  label: string;
  items: ReturnType<typeof useAdminNotifications>["items"];
};

function getNotificationCategoryLabel(
  category: string,
  labels: Record<AdminNotificationCategory, string>
) {
  const normalizedCategory =
    category in labels ? (category as AdminNotificationCategory) : "system";
  return labels[normalizedCategory];
}

function groupNotificationsByDate(
  items: ReturnType<typeof useAdminNotifications>["items"],
  locale: Locale
): NotificationGroup[] {
  const copy = getAdminChromeCopy(locale);
  const today = new Date();
  const todayKey = toDateKey(today);
  const yesterday = new Date(today);
  yesterday.setDate(today.getDate() - 1);
  const yesterdayKey = toDateKey(yesterday);

  const groups = new Map<string, NotificationGroup>();

  for (const item of items) {
    const itemDate = new Date(item.createdAt);
    const itemKey = toDateKey(itemDate);
    const groupKey =
      itemKey === todayKey ? "today" : itemKey === yesterdayKey ? "yesterday" : "earlier";
    const groupLabel =
      groupKey === "today"
        ? copy.topbar.groupLabels.today
        : groupKey === "yesterday"
          ? copy.topbar.groupLabels.yesterday
          : copy.topbar.groupLabels.earlier;

    const group = groups.get(groupKey);
    if (group) {
      group.items.push(item);
      continue;
    }

    groups.set(groupKey, {
      key: groupKey,
      label: groupLabel,
      items: [item],
    });
  }

  return ["today", "yesterday", "earlier"]
    .map((key) => groups.get(key))
    .filter((group): group is NotificationGroup => Boolean(group));
}

function toDateKey(value: Date) {
  return `${value.getFullYear()}-${value.getMonth()}-${value.getDate()}`;
}

function formatRelativeNotificationTime(value: string, locale: Locale) {
  const copy = getAdminChromeCopy(locale);
  const timestamp = new Date(value).getTime();
  if (!Number.isFinite(timestamp)) {
    return "";
  }

  const diffMs = timestamp - Date.now();
  const diffMinutes = Math.round(diffMs / 60_000);
  const absMinutes = Math.abs(diffMinutes);
  const rtf = new Intl.RelativeTimeFormat(copy.rtfLocale, {
    numeric: "auto",
  });

  if (absMinutes < 60) {
    return rtf.format(diffMinutes, "minute");
  }

  const diffHours = Math.round(diffMinutes / 60);
  if (Math.abs(diffHours) < 24) {
    return rtf.format(diffHours, "hour");
  }

  const diffDays = Math.round(diffHours / 24);
  return rtf.format(diffDays, "day");
}
