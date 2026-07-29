import { notFound } from "next/navigation";

import { AdminNotificationsView } from "@/components/admin-notifications-view";
import { isLocale, type Locale } from "@/lib/i18n";

type Props = { params: Promise<{ locale: string }> };

export default async function NotificationsPage({ params }: Props) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  return <AdminNotificationsView locale={locale as Locale} />;
}
