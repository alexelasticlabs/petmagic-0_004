import { notFound } from "next/navigation";

import { TemplatesAnalyticsHubPage } from "@/components/templates/templates-analytics-hub-page";
import { isLocale } from "@/lib/i18n";

type TemplatesAnalyticsPageProps = {
  params: Promise<{ locale: string }>;
};

export default async function TemplatesAnalyticsPage({ params }: TemplatesAnalyticsPageProps) {
  const { locale } = await params;

  if (!isLocale(locale)) {
    notFound();
  }

  return <TemplatesAnalyticsHubPage locale={locale} />;
}