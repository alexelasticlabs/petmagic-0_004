import { notFound, redirect } from "next/navigation";

import { isLocale } from "@/lib/i18n";

type VideoTemplatesPageProps = {
  params: Promise<{ locale: string }>;
};

export default async function VideoTemplatesPage({ params }: VideoTemplatesPageProps) {
  const { locale } = await params;

  if (!isLocale(locale)) {
    notFound();
  }

  redirect(`/${locale}/templates/video`);
}
