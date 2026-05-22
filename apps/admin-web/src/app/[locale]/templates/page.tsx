import { notFound, redirect } from "next/navigation";

import { isLocale } from "@/lib/i18n";

type TemplatesPageProps = {
  params: Promise<{ locale: string }>;
};

export default async function TemplatesPage({ params }: TemplatesPageProps) {
  const { locale } = await params;

  if (!isLocale(locale)) {
    notFound();
  }

  redirect(`/${locale}/templates/video`);
}
