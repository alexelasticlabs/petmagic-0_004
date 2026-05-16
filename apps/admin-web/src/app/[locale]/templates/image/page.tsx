import { TemplatesCatalogView } from "@/components/templates/templates-catalog-view";
import { isLocale } from "@/lib/i18n";
import { notFound } from "next/navigation";

type ImageTemplatesCatalogPageProps = {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ category?: string | string[] }>;
};

export default async function ImageTemplatesCatalogPage({ params, searchParams }: ImageTemplatesCatalogPageProps) {
  const { locale } = await params;

  if (!isLocale(locale)) {
    notFound();
  }

  const { category } = await searchParams;
  const initialCategory = Array.isArray(category) ? category[0] : category;

  return <TemplatesCatalogView locale={locale} templateType="Image" initialCategory={initialCategory} />;
}
