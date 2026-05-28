"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { usePathname, useRouter } from "next/navigation";
import { type ReactNode, useEffect, useMemo, useState } from "react";

import { AdminLoginScreen } from "@/components/admin/admin-login-screen";
import styles from "@/components/admin/admin-shell.module.css";
import { AdminSidebar } from "@/components/admin/admin-sidebar";
import { AdminTopbar } from "@/components/admin/admin-topbar";
import { buildLocaleSwitchPath, getAdminPageMeta, stripLocalePrefix } from "@/lib/admin-navigation";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import { fetchSupportInbox, logout, useAuthSession } from "@/lib/api-client";
import { type Locale, getDictionary } from "@/lib/i18n";
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
  const currentPath = stripLocalePrefix(pathname);
  const isLoginPage = currentPath === "/";
  const authSession = useAuthSession();
  const session = isLoginPage ? null : authSession;

  /* Support unread count for nav badge */
  const queryClient = useQueryClient();
  const inboxQuery = useQuery({
    queryKey: adminQueryKeys.supportInbox("all", "all"),
    queryFn: () => fetchSupportInbox(undefined, "all"),
    enabled: Boolean(session) && !isLoginPage,
    staleTime: 30_000,
    refetchInterval: 120_000,
  });
  useSupportRealtime(session?.accessToken, () => {
    void queryClient.invalidateQueries({ queryKey: adminQueryKeys.supportInboxRoot });
  });
  const supportUnreadCount = useMemo(
    () => inboxQuery.data?.filter((c) => c.unreadForAdmin).length ?? 0,
    [inboxQuery.data],
  );

  /* Admin panel state */
  const [sidebarOpen, setSidebarOpen] = useState(false);
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

  /* Keyboard: close sidebar on Escape */
  useEffect(() => {
    if (!sidebarOpen) return;
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") setSidebarOpen(false);
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [sidebarOpen]);

  function handleLogout() {
    void logout();
    router.replace(`/${locale}`);
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
      <AdminLoginScreen locale={locale} theme={theme} onToggleTheme={handleToggleTheme}>
        {children}
      </AdminLoginScreen>
    );
  }

  if (session == null) {
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
  const userName = session?.user?.displayName || session?.user?.email?.split("@")[0] || "";
  const userRole =
    session?.user?.roles?.[0] || (locale === "ru" ? "Администратор" : "Administrator");
  const userInitial = (session?.user?.displayName || session?.user?.email || "A")[0].toUpperCase();
  const userBadgeName =
    session?.user?.displayName ||
    session?.user?.email ||
    (locale === "ru" ? "Администратор" : "Administrator");
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
        onLogout={() => void handleLogout()}
        logoutLabel={text.navLogout}
        supportUnreadCount={supportUnreadCount}
      />

      <div className={styles.main}>
        <AdminTopbar
          locale={locale}
          pageTitle={pageMeta.title}
          pageDescription={pageMeta.description}
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
    </div>
  );
}
