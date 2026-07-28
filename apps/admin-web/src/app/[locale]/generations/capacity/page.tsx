import { notFound } from "next/navigation";

import { GenerationCapacityPage } from "@/components/generation-capacity-page";
import { type Locale, isLocale } from "@/lib/i18n";

type Props = { params: Promise<{ locale: string }> };

export default async function AdminGenerationCapacityRoute({ params }: Props) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  return <GenerationCapacityPage locale={locale as Locale} />;
}
