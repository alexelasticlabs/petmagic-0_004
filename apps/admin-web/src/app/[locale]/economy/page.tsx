import { EconomyPage } from "@/components/economy-page";
import { isLocale } from "@/lib/i18n";
import { notFound } from "next/navigation";

type EconomyRouteProps = {
    params: Promise<{ locale: string }>;
};

export default async function EconomyRoute({ params }: EconomyRouteProps) {
    const { locale } = await params;

    if (!isLocale(locale)) {
        notFound();
    }

    return <EconomyPage locale={locale} />;
}
