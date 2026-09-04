import { notFound } from "next/navigation";

import { OperationsProblemsPage } from "@/components/operations-problems-page";
import { isLocale, type Locale } from "@/lib/i18n";

type Props = { params: Promise<{ locale: string }> };

export default async function OperationsPage({ params }: Props) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  return <OperationsProblemsPage locale={locale as Locale} />;
}
