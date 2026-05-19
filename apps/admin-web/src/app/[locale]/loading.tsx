"use client";

import { AdminPage, AdminPageHero, AdminStateCard } from "@/components/admin/admin-primitives";
import { getDictionary, isLocale } from "@/lib/i18n";
import { useParams } from "next/navigation";

export default function Loading() {
  const params = useParams<{ locale?: string | string[] }>();
  const localeParam = Array.isArray(params.locale) ? params.locale[0] : params.locale;
  const locale = typeof localeParam === "string" && isLocale(localeParam) ? localeParam : "en";
  const text = getDictionary(locale);

  return (
    <AdminPage>
      <AdminPageHero title="PetMagic Admin" description={text.loading} />
      <AdminStateCard tone="info" title={text.loading} description={text.navDashboard} />
    </AdminPage>
  );
}
