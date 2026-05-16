import { TemplatesManager } from "@/components/templates-manager";
import { isLocale } from "@/lib/i18n";
import { notFound } from "next/navigation";

type ImageTemplateEditorPageProps = {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ templateId?: string | string[] }>;
};

export default async function ImageTemplateEditorPage({ params, searchParams }: ImageTemplateEditorPageProps) {
  const { locale } = await params;

  if (!isLocale(locale)) {
    notFound();
  }

  const { templateId } = await searchParams;
  const initialTemplateId = Array.isArray(templateId) ? templateId[0] : templateId;

  return <TemplatesManager locale={locale} templateType="Image" initialTemplateId={initialTemplateId} />;
}
