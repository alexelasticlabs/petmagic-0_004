import { TemplateTestPage } from "@/components/templates/template-test-page";
import { isLocale } from "@/lib/i18n";
import { notFound } from "next/navigation";

type VideoTemplateTestRoutePageProps = {
  params: Promise<{ locale: string; templateId: string }>;
};

export default async function VideoTemplateTestRoutePage({ params }: VideoTemplateTestRoutePageProps) {
  const { locale, templateId } = await params;

  if (!isLocale(locale)) {
    notFound();
  }

  return <TemplateTestPage locale={locale} templateId={templateId} />;
}
