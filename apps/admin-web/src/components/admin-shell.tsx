"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { usePathname, useRouter } from "next/navigation";
import { type ReactNode, useEffect, useMemo, useRef, useState } from "react";

import { getAdminChromeCopy } from "@/components/admin/admin-chrome.content";
import { AdminLoginScreen } from "@/components/admin/admin-login-screen";
import { useAdminNotifications } from "@/components/admin/admin-notifications";
import styles from "@/components/admin/admin-shell.module.css";
import { AdminSidebar } from "@/components/admin/admin-sidebar";
import { AdminTopbar } from "@/components/admin/admin-topbar";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
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
  fetchSupportInboxMetrics,
  isAuthSessionExpired,
  logout,
  restoreSession,
  useAuthSession,
} from "@/lib/api-client";
import { type Locale, getDictionary } from "@/lib/i18n";
import { maskEmail, sanitizeSensitiveText } from "@/lib/sensitive-display";
import { useSupportRealtime } from "@/lib/support-realtime";
import { getSupportUnreadCount } from "@/lib/support-unread-count";
import {
  type AdminTheme,
  applyAdminTheme,
  nextAdminTheme,
  readStoredAdminTheme,
  resolveAdminTheme,
  storeAdminTheme,
} from "@/lib/theme";

type AdminShellProps = { locale: Locale; children: ReactNode };

function AdminAccessGate({ locale }: { locale: Locale }) {
  const copy = getAdminChromeCopy(locale);
  return (
    <div className={styles.authGate} aria-busy="true" aria-live="polite">
      <div className={styles.authGateCard}>
        <span className={styles.authGateMark}>PM</span>
        <span>{copy.accessGateChecking}</span>
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════════════
   MAIN EXPORT
════════════════════════════════════════════════════════════════ */
export function AdminShell({ locale, children }: AdminShellProps) {
  const text = getDictionary(locale);
  const copy = useMemo(() => getAdminChromeCopy(locale), [locale]);
  const pathname = usePathname();
  const router = useRouter();
  const { addNotification } = useAdminNotifications();
  const currentPath = stripLocalePrefix(pathname);
  const isLoginPage = currentPath === "/";
  const authSession = useAuthSession();
  const session = authSession;
  const sessionRoles = useMemo(() => session?.user.roles ?? [], [session?.user.roles]);
  const hasPanelAccess = hasAdminPanelAccess(sessionRoles);
  const needsSessionRestore =
    Boolean(session) && hasPanelAccess && (!session?.accessToken || isAuthSessionExpired(session));
  const hasFreshAccessToken =
    Boolean(session?.accessToken) && Boolean(session) && !isAuthSessionExpired(session);
  const canUseSupportRealtime = hasFreshAccessToken && hasPanelAccess && !isLoginPage;
  const isRestoringSessionRef = useRef(false);

  /* Support unread count for nav badge */
  const queryClient = useQueryClient();
  const inboxMetricsQuery = useQuery({
    queryKey: adminQueryKeys.supportInboxMetrics,
    queryFn: ({ signal }) => fetchSupportInboxMetrics(signal),
    enabled: hasFreshAccessToken && hasPanelAccess && !isLoginPage,
    staleTime: 30_000,
    refetchInterval: 120_000,
    refetchIntervalInBackground: false,
  });
  useSupportRealtime(canUseSupportRealtime ? session?.accessToken : undefined, (event) => {
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

    const supportConversationPathId = encodeURIComponent(event.conversationId);

    addNotification({
      title: copy.realtimeSupport.title,
      message: copy.realtimeSupport.fallback,
      category: "support",
      source: "support-realtime",
      tone: "info",
      href: `/${locale}/support/${supportConversationPathId}`,
      dedupeKey: `${event.conversationId}:${event.updatedAtUtc}`,
    });
  });
  const supportUnreadCount = getSupportUnreadCount(inboxMetricsQuery.data);

  /* Admin panel state */
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [logoutDialogOpen, setLogoutDialogOpen] = useState(false);
  const [isLoggingOut, setIsLoggingOut] = useState(false);
  const [isSidebarDrawerMode, setIsSidebarDrawerMode] = useState(false);
  const previousPathnameRef = useRef(pathname);

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
    document.documentElement.lang = locale;
  }, [locale]);

  useEffect(() => {
    if (!isLoginPage && session === null) {
      router.replace(`/${locale}`);
    }
  }, [isLoginPage, locale, router, session]);

  useEffect(() => {
    if (session == null || needsSessionRestore) {
      return;
    }

    if (!hasPanelAccess) {
      void logout();
      router.replace(`/${locale}`);
      return;
    }

    if (isLoginPage) {
      router.replace(getDefaultAdminPath(locale, sessionRoles));
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

  useEffect(() => {
    if (!sidebarOpen || !isSidebarDrawerMode || typeof document === "undefined") {
      return;
    }

    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";

    return () => {
      document.body.style.overflow = previousOverflow;
    };
  }, [isSidebarDrawerMode, sidebarOpen]);

  useEffect(() => {
    if (previousPathnameRef.current === pathname) {
      return;
    }

    previousPathnameRef.current = pathname;
    setSidebarOpen(false);
  }, [pathname]);

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }

    const media = window.matchMedia("(max-width: 860px)");
    const syncSidebarMode = () => {
      const isDrawerMode = media.matches;
      setIsSidebarDrawerMode(isDrawerMode);
      if (!isDrawerMode) {
        setSidebarOpen(false);
      }
    };

    syncSidebarMode();
    media.addEventListener("change", syncSidebarMode);
    return () => media.removeEventListener("change", syncSidebarMode);
  }, []);

  function handleLogoutRequest() {
    if (isLoggingOut) {
      return;
    }

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
    if (session !== null) {
      return <AdminAccessGate locale={locale} />;
    }

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
    return <AdminAccessGate locale={locale} />;
  }

  /* ── Admin panel layout ────────────────────────────────────── */
  const maskedSessionEmail = session?.user?.email ? maskEmail(session.user.email) : "";
  const safeSessionDisplayName = session?.user?.displayName?.trim()
    ? sanitizeSensitiveText(session.user.displayName, 96)
    : "";
  const userName = safeSessionDisplayName || maskedSessionEmail;
  const userPanelRole = getAdminPanelRole(sessionRoles);
  const userRole = userPanelRole === "Moderator" ? copy.roles.moderator : copy.roles.admin;
  const userInitial = (userName || "A")[0].toUpperCase();
  const userBadgeName = userName || copy.roles.adminFallback;
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
        isDrawerMode={isSidebarDrawerMode}
        onNavigate={() => setSidebarOpen(false)}
        onLogout={handleLogoutRequest}
        logoutDisabled={isLoggingOut}
        logoutLabel={text.navLogout}
        supportUnreadCount={supportUnreadCount}
        roles={sessionRoles}
      />

      <div
        className={styles.main}
        aria-hidden={isSidebarDrawerMode && sidebarOpen ? "true" : undefined}
        inert={isSidebarDrawerMode && sidebarOpen}
      >
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
        title={copy.logoutDialog.title}
        description={copy.logoutDialog.description}
        confirmLabel={text.navLogout}
        cancelLabel={copy.logoutDialog.cancel}
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
