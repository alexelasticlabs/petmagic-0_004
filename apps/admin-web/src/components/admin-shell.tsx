"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { usePathname, useRouter } from "next/navigation";
import { type ReactNode, useEffect, useMemo, useRef, useState } from "react";

import { AdminLoginScreen } from "@/components/admin/admin-login-screen";
import { useAdminNotifications } from "@/components/admin/admin-notifications";
import styles from "@/components/admin/admin-shell.module.css";
import { AdminSidebar } from "@/components/admin/admin-sidebar";
import { AdminTopbar } from "@/components/admin/admin-topbar";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import { formatSupportMessagePreview } from "@/components/support/support-message-preview";
import { buildLocaleSwitchPath, getAdminPageMeta, stripLocalePrefix } from "@/lib/admin-navigation";
import { shouldCreateSupportRealtimeNotification } from "@/lib/admin-notification-policy";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  canAccessAdminPath,
  getAdminPanelRole,
  getDefaultAdminPath,
  hasAdminPanelAccess,
} from "@/lib/admin-rbac";
import {
  fetchSupportInbox,
  isAuthSessionExpired,
  logout,
  restoreSession,
  useAuthSession,
} from "@/lib/api-client";
import { type Locale, getDictionary } from "@/lib/i18n";
import { maskEmail, sanitizeSensitiveText } from "@/lib/sensitive-display";
import { useSupportRealtime } from "@/lib/support-realtime";
import {
  type AdminTheme,
  applyAdminTheme,
  nextAdminTheme,
  readStoredAdminTheme,
  resolveAdminTheme,
  storeAdminTheme,
} from "@/lib/theme";

type AdminShellProps = { locale: Locale; children: ReactNode };

/* ═══════════════════════════════════════════════════════════════
   MAIN EXPORT
════════════════════════════════════════════════════════════════ */
export function AdminShell({ locale, children }: AdminShellProps) {
  const text = getDictionary(locale);
  const pathname = usePathname();
  const router = useRouter();
  const { addNotification } = useAdminNotifications();
  const currentPath = stripLocalePrefix(pathname);
  const isLoginPage = currentPath === "/";
  const authSession = useAuthSession();
  const session = isLoginPage ? null : authSession;
  const sessionRoles = useMemo(() => session?.user.roles ?? [], [session?.user.roles]);
  const hasPanelAccess = hasAdminPanelAccess(sessionRoles);
  const needsSessionRestore =
    Boolean(session) && hasPanelAccess && (!session?.accessToken || isAuthSessionExpired(session));
  const hasFreshAccessToken =
    Boolean(session?.accessToken) && Boolean(session) && !isAuthSessionExpired(session);
  const isRestoringSessionRef = useRef(false);

  /* Support unread count for nav badge */
  const queryClient = useQueryClient();
  const inboxQuery = useQuery({
    queryKey: adminQueryKeys.supportInbox("all", "all", { page: 1, pageSize: 50 }),
    queryFn: ({ signal }) => fetchSupportInbox(undefined, "all", { page: 1, pageSize: 50, signal }),
    enabled: hasFreshAccessToken && hasPanelAccess && !isLoginPage,
    staleTime: 30_000,
    refetchInterval: 120_000,
  });
  useSupportRealtime(hasFreshAccessToken ? session?.accessToken : undefined, (event) => {
    void queryClient.invalidateQueries({ queryKey: adminQueryKeys.supportInboxRoot });

    const isUserMessage =
      (event.adminUnreadCount ?? 0) > 0 &&
      (event.lastMessageSenderType?.toLowerCase() === "user" || !event.lastMessageSenderType);

    if (!isUserMessage) {
      return;
    }

    if (
      !shouldCreateSupportRealtimeNotification({
        currentPath,
        conversationId: event.conversationId,
        isDocumentVisible: document.visibilityState === "visible",
        isWindowFocused: typeof document.hasFocus !== "function" ? true : document.hasFocus(),
      })
    ) {
      return;
    }

    const preview = formatSupportMessagePreview(event.lastMessagePreview, "");
    const message =
      preview
        ? locale === "ru"
          ? `Новое сообщение в поддержке: ${preview}`
          : `New support message: ${preview}`
        : locale === "ru"
          ? "В поддержке появилось новое сообщение"
          : "A new support message arrived";

    addNotification({
      title: locale === "ru" ? "Поддержка" : "Support",
      message,
      category: "support",
      source: "support-realtime",
      tone: "info",
      href: `/${locale}/support/${event.conversationId}`,
      dedupeKey: `${event.conversationId}:${event.updatedAtUtc}`,
    });
  });
  const supportUnreadCount = useMemo(
    () => inboxQuery.data?.filter((c) => c.unreadForAdmin).length ?? 0,
    [inboxQuery.data]
  );

  /* Admin panel state */
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [logoutDialogOpen, setLogoutDialogOpen] = useState(false);
  const [isLoggingOut, setIsLoggingOut] = useState(false);

  useEffect(() => {
    if (!needsSessionRestore || isRestoringSessionRef.current) {
      return;
    }

    isRestoringSessionRef.current = true;
    void restoreSession()
      .then((restored) => {
        if (!restored) {
          void logout();
          router.replace(`/${locale}`);
        }
      })
      .catch(() => {
        void logout();
        router.replace(`/${locale}`);
      })
      .finally(() => {
        isRestoringSessionRef.current = false;
      });
  }, [locale, needsSessionRestore, router]);
  const [theme, setTheme] = useState<AdminTheme>(() => {
    if (typeof window === "undefined") {
      return "dark";
    }

    const media = window.matchMedia("(prefers-color-scheme: dark)");
    return resolveAdminTheme(readStoredAdminTheme(), media.matches);
  });

  useEffect(() => {
    applyAdminTheme(theme);
  }, [theme]);

  useEffect(() => {
    if (!isLoginPage && session === null) {
      router.replace(`/${locale}`);
    }
  }, [isLoginPage, locale, router, session]);

  useEffect(() => {
    if (isLoginPage || session == null || needsSessionRestore) {
      return;
    }

    if (!hasPanelAccess) {
      void logout();
      router.replace(`/${locale}`);
      return;
    }

    if (!canAccessAdminPath(sessionRoles, currentPath)) {
      router.replace(getDefaultAdminPath(locale, sessionRoles));
    }
  }, [
    currentPath,
    hasPanelAccess,
    isLoginPage,
    locale,
    needsSessionRestore,
    router,
    session,
    sessionRoles,
  ]);

  /* Keyboard: close sidebar on Escape */
  useEffect(() => {
    if (!sidebarOpen) return;
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") setSidebarOpen(false);
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [sidebarOpen]);

  function handleLogoutRequest() {
    setSidebarOpen(false);
    setLogoutDialogOpen(true);
  }

  async function handleConfirmLogout() {
    if (isLoggingOut) {
      return;
    }

    setIsLoggingOut(true);
    try {
      await logout();
      setLogoutDialogOpen(false);
      router.replace(`/${locale}`);
    } finally {
      setIsLoggingOut(false);
    }
  }

  function handleToggleTheme() {
    setTheme((currentTheme) => {
      const nextThemeValue = nextAdminTheme(currentTheme);
      applyAdminTheme(nextThemeValue);
      storeAdminTheme(nextThemeValue);
      return nextThemeValue;
    });
  }

  /* ── Login screen ───────────────────────────────────────────── */
  if (isLoginPage) {
    return (
      <AdminLoginScreen locale={locale} onToggleTheme={handleToggleTheme}>
        {children}
      </AdminLoginScreen>
    );
  }

  if (
    session == null ||
    needsSessionRestore ||
    !hasFreshAccessToken ||
    !hasPanelAccess ||
    !canAccessAdminPath(sessionRoles, currentPath)
  ) {
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
  const maskedSessionEmail = session?.user?.email ? maskEmail(session.user.email) : "";
  const safeSessionDisplayName = session?.user?.displayName?.trim()
    ? sanitizeSensitiveText(session.user.displayName, 96)
    : "";
  const userName = safeSessionDisplayName || maskedSessionEmail;
  const userPanelRole = getAdminPanelRole(sessionRoles);
  const userRole =
    userPanelRole === "Moderator"
      ? locale === "ru"
        ? "Модератор"
        : "Moderator"
      : locale === "ru"
        ? "Администратор"
        : "Administrator";
  const userInitial = (userName || "A")[0].toUpperCase();
  const userBadgeName = userName || (locale === "ru" ? "Администратор" : "Administrator");
  const pageMeta = getAdminPageMeta(locale, currentPath, userName);
  const ruPath = buildLocaleSwitchPath("ru", pathname);
  const enPath = buildLocaleSwitchPath("en", pathname);

  return (
    <div className={styles.layout}>
      {sidebarOpen ? (
        <div className={styles.backdrop} onClick={() => setSidebarOpen(false)} aria-hidden="true" />
      ) : null}

      <AdminSidebar
        locale={locale}
        currentPath={currentPath}
        isOpen={sidebarOpen}
        onNavigate={() => setSidebarOpen(false)}
        onLogout={handleLogoutRequest}
        logoutLabel={text.navLogout}
        supportUnreadCount={supportUnreadCount}
        roles={sessionRoles}
      />

      <div className={styles.main}>
        <AdminTopbar
          locale={locale}
          pageTitle={pageMeta.title}
          pageDescription={pageMeta.description}
          supportUnreadCount={supportUnreadCount}
          theme={theme}
          userName={userBadgeName}
          userRole={userRole}
          userInitial={userInitial}
          ruPath={ruPath}
          enPath={enPath}
          sidebarOpen={sidebarOpen}
          onToggleSidebar={() => setSidebarOpen((current) => !current)}
          onToggleTheme={handleToggleTheme}
        />

        <main className={styles.content}>{children}</main>
      </div>

      <ConfirmationDialog
        open={logoutDialogOpen}
        title={locale === "ru" ? "Выйти из админ-панели?" : "Log out of admin panel?"}
        description={
          locale === "ru"
            ? "Текущая сессия будет очищена, и для возврата потребуется повторный вход."
            : "The current session will be cleared and signing in again will be required."
        }
        confirmLabel={text.navLogout}
        cancelLabel={locale === "ru" ? "Отмена" : "Cancel"}
        tone="danger"
        isSubmitting={isLoggingOut}
        onCancel={() => {
          if (!isLoggingOut) {
            setLogoutDialogOpen(false);
          }
        }}
        onConfirm={handleConfirmLogout}
      />
    </div>
  );
}
