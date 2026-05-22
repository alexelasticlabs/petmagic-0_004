import { notFound } from "next/navigation";

import { TemplateAnalyticsPage } from "@/components/templates/template-analytics-page";
import { isLocale } from "@/lib/i18n";

type VideoTemplateAnalyticsRoutePageProps = {
  params: Promise<{ locale: string; templateId: string }>;
};

export default async function VideoTemplateAnalyticsRoutePage({ params }: VideoTemplateAnalyticsRoutePageProps) {
  const { locale, templateId } = await params;

  if (!isLocale(locale)) {
    notFound();
  }

  return <TemplateAnalyticsPage locale={locale} templateId={templateId} />;
}
