import { notFound } from "next/navigation";

import { TemplateTestPage } from "@/components/templates/template-test-page";
import { isLocale } from "@/lib/i18n";

type ImageTemplateTestRoutePageProps = {
    params: Promise<{ locale: string; templateId: string }>;
};

export default async function ImageTemplateTestRoutePage({ params }: ImageTemplateTestRoutePageProps) {
    const { locale, templateId } = await params;

    if (!isLocale(locale)) {
        notFound();
    }

    return <TemplateTestPage locale={locale} templateId={templateId} />;
}
