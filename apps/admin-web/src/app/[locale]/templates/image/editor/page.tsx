import { notFound } from "next/navigation";

import { TemplateEditor } from "@/components/template-editor";
import { isLocale } from "@/lib/i18n";

type ImageTemplateEditorPageProps = {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ templateId?: string | string[] }>;
};

export default async function ImageTemplateEditorPage({
  params,
  searchParams,
}: ImageTemplateEditorPageProps) {
  const { locale } = await params;

  if (!isLocale(locale)) {
    notFound();
  }

  const { templateId } = await searchParams;
  const initialTemplateId = Array.isArray(templateId) ? templateId[0] : templateId;

  return (
    <TemplateEditor locale={locale} templateType="Image" initialTemplateId={initialTemplateId} />
  );
}
