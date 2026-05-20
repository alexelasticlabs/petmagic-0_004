import { SupportInboxPage } from "@/components/support/support-inbox-page";
import { isLocale, type Locale } from "@/lib/i18n";
import { notFound } from "next/navigation";

type SupportInboxRouteProps = {
    params: Promise<{ locale: string }>;
};

export default async function SupportInboxRoute({ params }: SupportInboxRouteProps) {
    const { locale } = await params;
    if (!isLocale(locale)) {
        notFound();
    }

    return <SupportInboxPage locale={locale as Locale} />;
}