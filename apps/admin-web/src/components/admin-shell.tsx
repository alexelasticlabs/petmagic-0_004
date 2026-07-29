"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import {
  type ReactNode,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  useSyncExternalStore,
} from "react";

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
import { clientLogger } from "@/lib/client-logger";
import { type Locale, getDictionary } from "@/lib/i18n";
import { maskEmail, sanitizeSensitiveText } from "@/lib/sensitive-display";
import { useSupportRealtime } from "@/lib/support-realtime";
import { getSupportUnreadCount } from "@/lib/support-unread-count";
import {
  type AdminTheme,
  applyAdminTheme,
  getAppliedAdminTheme,
  nextAdminTheme,
  publishAdminThemeChange,
  readStoredAdminTheme,
  storeAdminTheme,
  subscribeToAdminTheme,
} from "@/lib/theme";

type AdminShellProps = { locale: Locale; children: ReactNode };

const ADMIN_SIDEBAR_FOCUSABLE_SELECTOR =
  'a[href], button:not(:disabled), [tabindex]:not([tabindex="-1"])';
const ADMIN_SIDEBAR_STORAGE_KEY = "petmagic.admin.sidebar.v1";
const ADMIN_SIDEBAR_CHANGE_EVENT = "petmagic:admin-sidebar-change";

function subscribeToAdminSidebarState(onChange: () => void) {
  window.addEventListener("storage", onChange);
  window.addEventListener(ADMIN_SIDEBAR_CHANGE_EVENT, onChange);
  return () => {
    window.removeEventListener("storage", onChange);
    window.removeEventListener(ADMIN_SIDEBAR_CHANGE_EVENT, onChange);
  };
}

function getAdminSidebarState() {
  try {
    return window.localStorage.getItem(ADMIN_SIDEBAR_STORAGE_KEY) === "collapsed";
  } catch {
    return false;
  }
}

function getServerAdminSidebarState() {
  return false;
}

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
  const searchParams = useSearchParams();
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
  const sidebarCollapsed = useSyncExternalStore(
    subscribeToAdminSidebarState,
    getAdminSidebarState,
    getServerAdminSidebarState
  );
  const [logoutDialogOpen, setLogoutDialogOpen] = useState(false);
  const [isLoggingOut, setIsLoggingOut] = useState(false);
  const [isSidebarDrawerMode, setIsSidebarDrawerMode] = useState(false);
  const previousPathnameRef = useRef(pathname);
  const sidebarRef = useRef<HTMLElement | null>(null);
  const sidebarTriggerRef = useRef<HTMLButtonElement | null>(null);
  const sidebarPreviouslyFocusedRef = useRef<HTMLElement | null>(null);

  const closeSidebar = useCallback((restoreFocus = false) => {
    setSidebarOpen(false);

    if (!restoreFocus || typeof window === "undefined") {
      return;
    }

    window.requestAnimationFrame(() => {
      const previouslyFocused = sidebarPreviouslyFocusedRef.current;
      const restoreTarget =
        previouslyFocused?.isConnected && previouslyFocused !== document.body
          ? previouslyFocused
          : sidebarTriggerRef.current;

      restoreTarget?.focus();
      sidebarPreviouslyFocusedRef.current = null;
    });
  }, []);

  function handleSidebarToggle() {
    if (!isSidebarDrawerMode) {
      const next = !sidebarCollapsed;
      try {
        window.localStorage.setItem(ADMIN_SIDEBAR_STORAGE_KEY, next ? "collapsed" : "expanded");
        window.dispatchEvent(new Event(ADMIN_SIDEBAR_CHANGE_EVENT));
      } catch (error) {
        clientLogger.warn("admin.sidebar_state_write_failed", {
          errorName: error instanceof Error ? error.name : "UnknownError",
        });
      }
      return;
    }

    if (sidebarOpen) {
      closeSidebar(true);
      return;
    }

    sidebarPreviouslyFocusedRef.current =
      sidebarTriggerRef.current ??
      (document.activeElement instanceof HTMLElement ? document.activeElement : null);
    setSidebarOpen(true);
  }

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
  // The head script makes the persisted theme visible before first paint.
  // The server snapshot keeps hydration deterministic until that DOM state is read.
  const theme = useSyncExternalStore(
    subscribeToAdminTheme,
    getAppliedAdminTheme,
    getServerAdminTheme
  );

  useEffect(() => {
    // The head script skips invalid values rather than logging before React is ready.
    // Reuse the guarded reader to remove an invalid persisted value after hydration.
    readStoredAdminTheme();
  }, []);

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

  /* Keep keyboard focus inside the modal mobile navigation while it is open. */
  useEffect(() => {
    if (!sidebarOpen || !isSidebarDrawerMode) {
      return;
    }

    const sidebar = sidebarRef.current;
    if (!sidebar) {
      return;
    }

    // Keep a non-null snapshot for the keyboard handler's closure. The ref may
    // change during React reconciliation while the drawer effect is still active.
    const focusTrapSidebar: HTMLElement = sidebar;

    const initialFocusTarget =
      focusTrapSidebar.querySelector<HTMLElement>(ADMIN_SIDEBAR_FOCUSABLE_SELECTOR) ??
      focusTrapSidebar;
    initialFocusTarget.focus();

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        event.preventDefault();
        event.stopPropagation();
        closeSidebar(true);
        return;
      }

      if (event.key !== "Tab") {
        return;
      }

      const focusableElements = Array.from(
        focusTrapSidebar.querySelectorAll<HTMLElement>(ADMIN_SIDEBAR_FOCUSABLE_SELECTOR)
      );
      if (focusableElements.length === 0) {
        event.preventDefault();
        focusTrapSidebar.focus();
        return;
      }

      const firstElement = focusableElements[0];
      const lastElement = focusableElements[focusableElements.length - 1];
      const activeElement = document.activeElement;

      if (
        event.shiftKey &&
        (activeElement === firstElement || !focusTrapSidebar.contains(activeElement))
      ) {
        event.preventDefault();
        lastElement.focus();
        return;
      }

      if (
        !event.shiftKey &&
        (activeElement === lastElement || !focusTrapSidebar.contains(activeElement))
      ) {
        event.preventDefault();
        firstElement.focus();
      }
    }

    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, [closeSidebar, isSidebarDrawerMode, sidebarOpen]);

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

    if (sidebarOpen && isSidebarDrawerMode && typeof window !== "undefined") {
      setSidebarOpen(false);
      window.requestAnimationFrame(() => {
        sidebarTriggerRef.current?.focus();
        sidebarPreviouslyFocusedRef.current = null;
        setLogoutDialogOpen(true);
      });
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
    const nextThemeValue = nextAdminTheme(theme);
    applyAdminTheme(nextThemeValue);
    storeAdminTheme(nextThemeValue);
    publishAdminThemeChange();
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
  const currentSearch = searchParams.toString();
  const ruPath = buildLocaleSwitchPath("ru", pathname, currentSearch);
  const enPath = buildLocaleSwitchPath("en", pathname, currentSearch);

  return (
    <div className={`${styles.layout}${sidebarCollapsed ? ` ${styles.layoutCollapsed}` : ""}`}>
      <a
        className={styles.skipLink}
        href="#admin-main"
        aria-hidden={isSidebarDrawerMode && sidebarOpen ? "true" : undefined}
        inert={isSidebarDrawerMode && sidebarOpen}
      >
        {copy.skipToContent}
      </a>

      {sidebarOpen ? (
        <div className={styles.backdrop} onClick={() => closeSidebar(true)} aria-hidden="true" />
      ) : null}

      <AdminSidebar
        locale={locale}
        currentPath={currentPath}
        isOpen={sidebarOpen}
        isDrawerMode={isSidebarDrawerMode}
        isCollapsed={!isSidebarDrawerMode && sidebarCollapsed}
        sidebarRef={sidebarRef}
        onClose={() => closeSidebar(true)}
        onNavigate={() => closeSidebar(true)}
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
          roles={sessionRoles}
          ruPath={ruPath}
          enPath={enPath}
          sidebarOpen={isSidebarDrawerMode ? sidebarOpen : !sidebarCollapsed}
          sidebarTriggerRef={sidebarTriggerRef}
          onToggleSidebar={handleSidebarToggle}
          onToggleTheme={handleToggleTheme}
        />

        <main id="admin-main" className={styles.content} tabIndex={-1}>
          {children}
        </main>
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

function getServerAdminTheme(): AdminTheme {
  return "dark";
}
