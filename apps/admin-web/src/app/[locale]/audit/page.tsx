import { notFound } from "next/navigation";

import { AuditEventsPage } from "@/components/audit-events-page";
import { isLocale } from "@/lib/i18n";

type AuditRouteProps = {
  params: Promise<{ locale: string }>;
};

export default async function AuditRoute({ params }: AuditRouteProps) {
  const { locale } = await params;

  if (!isLocale(locale)) {
    notFound();
  }

  return <AuditEventsPage locale={locale} />;
}
