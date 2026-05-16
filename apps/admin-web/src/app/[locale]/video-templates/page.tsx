import { isLocale } from "@/lib/i18n";
import { notFound, redirect } from "next/navigation";

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
