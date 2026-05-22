import { notFound } from "next/navigation";

import { TemplatesCategoriesView } from "@/components/templates/templates-categories-view";
import { isLocale } from "@/lib/i18n";

type TemplateCategoriesPageProps = {
  params: Promise<{ locale: string }>;
};

export default async function TemplateCategoriesPage({ params }: TemplateCategoriesPageProps) {
  const { locale } = await params;

  if (!isLocale(locale)) {
    notFound();
  }

  return <TemplatesCategoriesView locale={locale} />;
}
