"use client";

import { useParams } from "next/navigation";

import { AdminPage, AdminPageHero, AdminStateCard } from "@/components/admin/admin-primitives";
import { getAdminPageMetaCopy } from "@/lib/admin-navigation.content";
import { getDictionary, isLocale } from "@/lib/i18n";

export default function Loading() {
  const params = useParams<{ locale?: string | string[] }>();
  const localeParam = Array.isArray(params.locale) ? params.locale[0] : params.locale;
  const locale = typeof localeParam === "string" && isLocale(localeParam) ? localeParam : "en";
  const text = getDictionary(locale);
  const pageMeta = getAdminPageMetaCopy(locale);

  return (
    <AdminPage aria-busy="true" aria-live="polite">
      <AdminPageHero title={pageMeta.workspace.title} description={text.adminLoadingDescription} />
      <AdminStateCard tone="info" title={text.loading} description={text.adminLoadingDescription} />
    </AdminPage>
  );
}
