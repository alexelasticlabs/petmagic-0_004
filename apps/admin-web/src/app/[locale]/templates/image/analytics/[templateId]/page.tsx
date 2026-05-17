import { TemplateAnalyticsPage } from "@/components/templates/template-analytics-page";
import { isLocale } from "@/lib/i18n";
import { notFound } from "next/navigation";

type ImageTemplateAnalyticsRoutePageProps = {
  params: Promise<{ locale: string; templateId: string }>;
};

export default async function ImageTemplateAnalyticsRoutePage({ params }: ImageTemplateAnalyticsRoutePageProps) {
  const { locale, templateId } = await params;

  if (!isLocale(locale)) {
    notFound();
  }

  return <TemplateAnalyticsPage locale={locale} templateId={templateId} />;
}
