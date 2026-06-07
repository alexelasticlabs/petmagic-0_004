"use client";

import { useParams } from "next/navigation";

import { AdminNotFoundPage } from "@/components/admin/admin-not-found-page";
import { isLocale, type Locale } from "@/lib/i18n";

export default function NotFoundPage() {
  const params = useParams<{ locale?: string | string[] }>();
  const rawLocale = Array.isArray(params.locale) ? params.locale[0] : params.locale;
  const locale: Locale = typeof rawLocale === "string" && isLocale(rawLocale) ? rawLocale : "en";

  return <AdminNotFoundPage locale={locale} />;
}
