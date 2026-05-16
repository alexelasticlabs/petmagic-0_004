import { isLocale } from "@/lib/i18n";
import { notFound, redirect } from "next/navigation";

type ImageTemplatesPageProps = {
  params: Promise<{ locale: string }>;
};

export default async function ImageTemplatesPage({ params }: ImageTemplatesPageProps) {
  const { locale } = await params;

  if (!isLocale(locale)) {
    notFound();
  }

  redirect(`/${locale}/templates/image`);
}
