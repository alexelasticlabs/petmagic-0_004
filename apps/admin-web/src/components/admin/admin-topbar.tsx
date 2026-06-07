"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useMemo, useRef, useState } from "react";

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
  | "all"
  | "unread"
  | "support"
  | "users"
  | "templates"
  | "economy"
  | "promo"
  | "system";

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
  const pathname = usePathname();
  const { clearRead, items, markAllAsRead, markAsRead, markCategoryAsRead, unreadCount } =
    useAdminNotifications();
  const [notificationPanelPathname, setNotificationPanelPathname] = useState<string | null>(null);
  const [notificationFilter, setNotificationFilter] = useState<NotificationFilter>("all");
  const notificationRootRef = useRef<HTMLDivElement | null>(null);
  const themeLabel =
    locale === "ru"
      ? theme === "dark"
        ? "Тёмная"
        : "Светлая"
      : theme === "dark"
        ? "Dark"
        : "Light";
  const nextThemeAriaLabel =
    locale === "ru"
      ? theme === "dark"
        ? "Включить светлую тему"
        : "Включить тёмную тему"
      : theme === "dark"
        ? "Switch to light theme"
        : "Switch to dark theme";
  const totalAttentionCount = Math.max(unreadCount, supportUnreadCount);
  const filterOptions = useMemo(
    () => [
      { value: "all" as const, label: locale === "ru" ? "Все" : "All" },
      { value: "unread" as const, label: locale === "ru" ? "Новые" : "Unread" },
      { value: "support" as const, label: locale === "ru" ? "Поддержка" : "Support" },
      { value: "users" as const, label: locale === "ru" ? "Пользователи" : "Users" },
      { value: "templates" as const, label: locale === "ru" ? "Шаблоны" : "Templates" },
      { value: "economy" as const, label: locale === "ru" ? "Экономика" : "Economy" },
      { value: "promo" as const, label: locale === "ru" ? "Промокоды" : "Promo" },
      { value: "system" as const, label: locale === "ru" ? "Система" : "System" },
    ],
    [locale]
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
        setNotificationPanelPathname(null);
      }
    }

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        setNotificationPanelPathname(null);
      }
    }

    window.addEventListener("mousedown", handlePointerDown);
    window.addEventListener("keydown", handleKeyDown);
    return () => {
      window.removeEventListener("mousedown", handlePointerDown);
      window.removeEventListener("keydown", handleKeyDown);
    };
  }, [isNotificationsOpen]);

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
        <div className={styles.notificationRoot} ref={notificationRootRef}>
          <button
            type="button"
            className={`${styles.localeTrigger} ${styles.notificationTrigger} ${isNotificationsOpen ? styles.notificationTriggerActive : ""}`}
            onClick={() =>
              setNotificationPanelPathname((current) => (current === pathname ? null : pathname))
            }
            aria-haspopup="dialog"
            aria-expanded={isNotificationsOpen}
            aria-label={locale === "ru" ? "Открыть уведомления" : "Open notifications"}
            title={locale === "ru" ? "Уведомления" : "Notifications"}
          >
            <BellIcon className={styles.localeIcon} />
            {totalAttentionCount > 0 ? (
              <span className={styles.notificationBadge}>{totalAttentionCount}</span>
            ) : null}
          </button>

          {isNotificationsOpen ? (
            <div
              className={styles.notificationPanel}
              role="dialog"
              aria-label={locale === "ru" ? "Центр уведомлений" : "Notification center"}
            >
              <div className={styles.notificationPanelHeader}>
                <div className={styles.notificationPanelCopy}>
                  <span className={styles.notificationEyebrow}>
                    {locale === "ru" ? "Центр уведомлений" : "Notification center"}
                  </span>
                  <strong className={styles.notificationTitle}>
                    {locale === "ru" ? "Важные события админки" : "Important admin events"}
                  </strong>
                  <p className={styles.notificationSummary}>
                    {locale === "ru"
                      ? `${unreadCount} новых в ленте${supportUnreadCount > 0 ? `, ${supportUnreadCount} новых сообщений в поддержке` : ""}`
                      : `${unreadCount} unread in feed${supportUnreadCount > 0 ? `, ${supportUnreadCount} new support messages` : ""}`}
                  </p>
                </div>
                <div className={styles.notificationHeaderActions}>
                  <button
                    type="button"
                    className={styles.notificationTextButton}
                    onClick={markAllAsRead}
                    disabled={unreadCount === 0}
                  >
                    {locale === "ru" ? "Прочитать всё" : "Mark all read"}
                  </button>
                  <button
                    type="button"
                    className={styles.notificationTextButton}
                    onClick={clearRead}
                    disabled={items.every((item) => !item.read)}
                  >
                    {locale === "ru" ? "Очистить прочитанное" : "Clear read"}
                  </button>
                </div>
              </div>

              <div className={styles.notificationFilters}>
                {filterOptions.map((filterOption) => (
                  <button
                    key={filterOption.value}
                    type="button"
                    className={`${styles.notificationFilterChip} ${notificationFilter === filterOption.value ? styles.notificationFilterChipActive : ""}`}
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
                    onClick={() => setNotificationPanelPathname(null)}
                  >
                    <div className={styles.notificationCardMeta}>
                      <div className={styles.notificationCardMetaLead}>
                        <span className={styles.notificationPinnedMark}>
                          {locale === "ru" ? "Критично" : "Critical"}
                        </span>
                        <span
                          className={`${styles.notificationCategoryPill} ${styles.notificationCategorySupport}`}
                        >
                          {locale === "ru" ? "Поддержка" : "Support"}
                        </span>
                      </div>
                      <span className={styles.notificationTime}>
                        {locale === "ru" ? "требует внимания" : "needs attention"}
                      </span>
                    </div>
                    <strong className={styles.notificationCardTitle}>
                      {locale === "ru"
                        ? `${supportUnreadCount} новых сообщений в поддержке`
                        : `${supportUnreadCount} new support messages`}
                    </strong>
                    <p className={styles.notificationCardMessage}>
                      {locale === "ru"
                        ? "Открой очередь поддержки и разберите новые или непрочитанные диалоги."
                        : "Open the support queue to process new and unread conversations."}
                    </p>
                  </Link>
                ) : null}

                {pinnedNotifications.length > 0 ? (
                  <section className={styles.notificationGroupSection}>
                    <div className={styles.notificationGroupHeader}>
                      <span className={styles.notificationGroupTitle}>
                        {locale === "ru" ? "Критично" : "Critical"}
                      </span>
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
                                  {locale === "ru" ? "Pinned" : "Pinned"}
                                </span>
                                <span
                                  className={`${styles.notificationCategoryPill} ${item.category === "support" ? styles.notificationCategorySupport : item.category === "users" ? styles.notificationCategoryUsers : item.category === "templates" ? styles.notificationCategoryTemplates : item.category === "economy" ? styles.notificationCategoryEconomy : item.category === "promo" ? styles.notificationCategoryPromo : styles.notificationCategorySystem}`}
                                >
                                  {item.category === "support"
                                    ? locale === "ru"
                                      ? "Поддержка"
                                      : "Support"
                                    : item.category === "users"
                                      ? locale === "ru"
                                        ? "Пользователи"
                                        : "Users"
                                      : item.category === "templates"
                                        ? locale === "ru"
                                          ? "Шаблоны"
                                          : "Templates"
                                        : item.category === "economy"
                                          ? locale === "ru"
                                            ? "Экономика"
                                            : "Economy"
                                          : item.category === "promo"
                                            ? locale === "ru"
                                              ? "Промокоды"
                                              : "Promo"
                                            : locale === "ru"
                                              ? "Система"
                                              : "System"}
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
                                setNotificationPanelPathname(null);
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
                                {item.category === "support"
                                  ? locale === "ru"
                                    ? "Поддержка"
                                    : "Support"
                                  : item.category === "users"
                                    ? locale === "ru"
                                      ? "Пользователи"
                                      : "Users"
                                    : item.category === "templates"
                                      ? locale === "ru"
                                        ? "Шаблоны"
                                        : "Templates"
                                      : item.category === "economy"
                                        ? locale === "ru"
                                          ? "Экономика"
                                          : "Economy"
                                        : item.category === "promo"
                                          ? locale === "ru"
                                            ? "Промокоды"
                                            : "Promo"
                                          : locale === "ru"
                                            ? "Система"
                                            : "System"}
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
                                setNotificationPanelPathname(null);
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
                    <strong>{locale === "ru" ? "Пока пусто" : "Nothing here yet"}</strong>
                    <p>
                      {locale === "ru"
                        ? "Важные действия из поддержки, пользователей и шаблонов будут появляться здесь."
                        : "Important events from support, users, and templates will appear here."}
                    </p>
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

function groupNotificationsByDate(
  items: ReturnType<typeof useAdminNotifications>["items"],
  locale: Locale
): NotificationGroup[] {
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
        ? locale === "ru"
          ? "Сегодня"
          : "Today"
        : groupKey === "yesterday"
          ? locale === "ru"
            ? "Вчера"
            : "Yesterday"
          : locale === "ru"
            ? "Ранее"
            : "Earlier";

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
  const timestamp = new Date(value).getTime();
  if (!Number.isFinite(timestamp)) {
    return "";
  }

  const diffMs = timestamp - Date.now();
  const diffMinutes = Math.round(diffMs / 60_000);
  const absMinutes = Math.abs(diffMinutes);
  const rtf = new Intl.RelativeTimeFormat(locale === "ru" ? "ru" : "en", {
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
