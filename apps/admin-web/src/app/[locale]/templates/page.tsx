import { notFound } from "next/navigation";

import { TemplatesCatalogView } from "@/components/templates/templates-catalog-view";
import { isLocale } from "@/lib/i18n";

type TemplatesPageProps = {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ category?: string | string[] }>;
};

export default async function TemplatesPage({ params, searchParams }: TemplatesPageProps) {
  const { locale } = await params;

  if (!isLocale(locale)) {
    notFound();
  }

  const { category } = await searchParams;
  const initialCategory = Array.isArray(category) ? category[0] : category;

  return <TemplatesCatalogView locale={locale} initialCategory={initialCategory} />;
}
