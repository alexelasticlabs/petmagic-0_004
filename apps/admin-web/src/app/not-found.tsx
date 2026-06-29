"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

import { getAdminRouteFallbackText } from "@/app/admin-route-fallback.content";
import { AdminPage, AdminPageHero, AdminStateCard } from "@/components/admin/admin-primitives";
import { isLocale, type Locale } from "@/lib/i18n";

export default function RootNotFoundPage() {
  const pathname = usePathname();
  const rawLocale = pathname.split("/").filter(Boolean)[0];
  const locale: Locale = isLocale(rawLocale) ? rawLocale : "en";
  const text = getAdminRouteFallbackText(locale);

  return (
    <AdminPage>
      <AdminPageHero
        eyebrow="404"
        title={text.notFoundTitle}
        description={text.notFoundDescription}
      />
      <AdminStateCard
        tone="info"
        title={text.adminNotFoundActionTitle}
        description={text.rootNotFoundActionDescription}
        action={
          <Link href={`/${locale}`} className="ui-button ui-button--primary ui-button--md">
            {text.signInActionLabel}
          </Link>
        }
      />
    </AdminPage>
  );
}
