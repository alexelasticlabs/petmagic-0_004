import { notFound } from "next/navigation";

import { ModerationPage } from "@/components/moderation-page";
import { type Locale, isLocale } from "@/lib/i18n";

type Props = {
  params: Promise<{ locale: string }>;
};

export default async function AdminModerationPage({ params }: Props) {
  const { locale } = await params;
  if (!isLocale(locale)) {
    notFound();
  }

  return <ModerationPage locale={locale as Locale} />;
}
