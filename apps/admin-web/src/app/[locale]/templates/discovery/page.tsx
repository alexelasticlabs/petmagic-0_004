import { notFound } from "next/navigation";

import { TemplatesDiscoveryAdminPage } from "@/components/templates/discovery/templates-discovery-admin-page";
import { isLocale } from "@/lib/i18n";

export default async function DiscoveryRoute({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  return <TemplatesDiscoveryAdminPage locale={locale} />;
}
