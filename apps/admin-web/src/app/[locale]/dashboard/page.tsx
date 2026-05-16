import { DashboardView } from "@/components/dashboard-view";
import { type Locale, isLocale } from "@/lib/i18n";
import { notFound } from "next/navigation";

type Props = { params: Promise<{ locale: string }> };

export default async function DashboardPage({ params }: Props) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  return <DashboardView locale={locale as Locale} />;
}