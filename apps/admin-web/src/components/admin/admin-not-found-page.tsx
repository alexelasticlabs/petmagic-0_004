"use client";

import Link from "next/link";

import { getAdminRouteFallbackText } from "@/app/admin-route-fallback.content";
import { AdminPage, AdminStateCard } from "@/components/admin/admin-primitives";
import { getDefaultAdminPath } from "@/lib/admin-rbac";
import { useAuthSession } from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";

type AdminNotFoundPageProps = {
  locale: Locale;
};

export function AdminNotFoundPage({ locale }: AdminNotFoundPageProps) {
  const text = getDictionary(locale);
  const fallbackText = getAdminRouteFallbackText(locale);
  const session = useAuthSession();
  const fallbackHref = getDefaultAdminPath(locale, session?.user.roles);
  const fallbackLabel = fallbackHref.endsWith("/support")
    ? text.navSupport
    : fallbackHref.endsWith("/dashboard")
      ? text.navDashboard
      : text.signIn;

  return (
    <AdminPage>
      <AdminStateCard
        tone="info"
        title={fallbackText.notFoundTitle}
        description={fallbackText.notFoundDescription}
        action={
          <Link href={fallbackHref} className="ui-button ui-button--primary ui-button--md">
            {fallbackLabel}
          </Link>
        }
      />
    </AdminPage>
  );
}
