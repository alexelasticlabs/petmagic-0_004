import { getSession } from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";

type AdminRouter = {
  replace: (href: string) => void;
};

export function ensureAdminSession(locale: Locale, router: AdminRouter) {
  if (getSession()) {
    return true;
  }

  router.replace(`/${locale}`);
  return false;
}
