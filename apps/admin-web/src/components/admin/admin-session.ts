import { hasAdminPanelAccess } from "@/lib/admin-rbac";
import { getSession, isAuthSessionExpired } from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";

type AdminRouter = {
  replace: (href: string) => void;
};

type EnsureAdminSessionOptions = {
  requiredRole?: "Admin";
};

export function ensureAdminSession(
  locale: Locale,
  router: AdminRouter,
  options: EnsureAdminSessionOptions = {}
) {
  const session = getSession();
  const hasFreshAccessToken =
    Boolean(session?.accessToken) && Boolean(session) && !isAuthSessionExpired(session);
  const hasRequiredRole = options.requiredRole
    ? session?.user.roles.includes(options.requiredRole)
    : hasAdminPanelAccess(session?.user.roles);
  if (session && hasFreshAccessToken && hasRequiredRole) {
    return true;
  }

  router.replace(`/${locale}`);
  return false;
}
