import { notFound, redirect } from "next/navigation";

import { UsersTable } from "@/components/users-table";
import { isLocale } from "@/lib/i18n";

type UsersPageProps = {
  params: Promise<{ locale: string }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

export default async function UsersPage({ params, searchParams }: UsersPageProps) {
  const { locale } = await params;

  if (!isLocale(locale)) {
    notFound();
  }

  const query = await searchParams;
  if (query.tab === "broadcasts" || query.broadcastStatus || query.broadcastPage) {
    const next = new URLSearchParams();
    for (const key of ["selected", "broadcastStatus", "broadcastPage"]) {
      const value = query[key];
      if (typeof value === "string") next.set(key, value);
    }
    redirect(`/${locale}/email-broadcasts${next.size ? `?${next}` : ""}`);
  }

  return <UsersTable locale={locale} />;
}
