import { notFound } from "next/navigation";

import { EmailBroadcastsPage } from "@/components/email-broadcasts-page";
import { isLocale } from "@/lib/i18n";

export default async function Page({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  return <EmailBroadcastsPage locale={locale} />;
}
