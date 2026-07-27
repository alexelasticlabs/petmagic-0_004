import { notFound } from "next/navigation";

import { GamificationPage } from "@/components/gamification-page";
import { isLocale } from "@/lib/i18n";

type GamificationRouteProps = {
  params: Promise<{ locale: string }>;
};

export default async function GamificationRoute({ params }: GamificationRouteProps) {
  const { locale } = await params;

  if (!isLocale(locale)) {
    notFound();
  }

  return <GamificationPage locale={locale} />;
}
