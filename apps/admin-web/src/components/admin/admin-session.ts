import { hasAdminPanelAccess } from "@/lib/admin-rbac";
import { getSession, isAuthSessionExpired } from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";

type AdminRouter = {
  replace: (href: string) => void;
};

export function ensureAdminSession(locale: Locale, router: AdminRouter) {
  const session = getSession();
  const hasFreshAccessToken =
    Boolean(session?.accessToken) && Boolean(session) && !isAuthSessionExpired(session);
  if (session && hasFreshAccessToken && hasAdminPanelAccess(session.user.roles)) {
    return true;
  }

  router.replace(`/${locale}`);
  return false;
}
