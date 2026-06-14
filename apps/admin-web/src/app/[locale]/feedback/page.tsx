import { notFound } from "next/navigation";

import { FeedbackPage } from "@/components/feedback-page";
import { type Locale, isLocale } from "@/lib/i18n";

type Props = {
  params: Promise<{ locale: string }>;
};

export default async function AdminFeedbackPage({ params }: Props) {
  const { locale } = await params;
  if (!isLocale(locale)) {
    notFound();
  }

  return <FeedbackPage locale={locale as Locale} />;
}
