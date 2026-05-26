import { notFound } from "next/navigation";

import { PromoCodesView } from "@/components/promo-codes-view";
import { isLocale } from "@/lib/i18n";

type PromoCodesRouteProps = {
  params: Promise<{ locale: string }>;
};

export default async function PromoCodesRoute({ params }: PromoCodesRouteProps) {
  const { locale } = await params;

  if (!isLocale(locale)) {
    notFound();
  }

  return <PromoCodesView locale={locale} />;
}
