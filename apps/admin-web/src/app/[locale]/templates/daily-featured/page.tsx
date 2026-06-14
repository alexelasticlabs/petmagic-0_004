import { notFound } from "next/navigation";

import { TemplatesDailyFeaturedPage } from "@/components/templates/templates-daily-featured-page";
import { isLocale } from "@/lib/i18n";

type TemplatesDailyFeaturedRouteProps = {
  params: Promise<{ locale: string }>;
};

export default async function TemplatesDailyFeaturedRoute({
  params,
}: TemplatesDailyFeaturedRouteProps) {
  const { locale } = await params;

  if (!isLocale(locale)) {
    notFound();
  }

  return <TemplatesDailyFeaturedPage locale={locale} />;
}
