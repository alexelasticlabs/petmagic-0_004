import { notFound } from "next/navigation";

import { GenerationsPage } from "@/components/generations-page";
import { type Locale, isLocale } from "@/lib/i18n";

type Props = {
  params: Promise<{ locale: string }>;
};

export default async function AdminGenerationsPage({ params }: Props) {
  const { locale } = await params;
  if (!isLocale(locale)) {
    notFound();
  }

  return <GenerationsPage locale={locale as Locale} />;
}
