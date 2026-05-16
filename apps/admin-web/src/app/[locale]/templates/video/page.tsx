import { TemplatesCatalogView } from "@/components/templates/templates-catalog-view";
import { isLocale } from "@/lib/i18n";
import { notFound } from "next/navigation";

type VideoTemplatesCatalogPageProps = {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ category?: string | string[] }>;
};

export default async function VideoTemplatesCatalogPage({ params, searchParams }: VideoTemplatesCatalogPageProps) {
  const { locale } = await params;

  if (!isLocale(locale)) {
    notFound();
  }

  const { category } = await searchParams;
  const initialCategory = Array.isArray(category) ? category[0] : category;

  return <TemplatesCatalogView locale={locale} templateType="Video" initialCategory={initialCategory} />;
}
