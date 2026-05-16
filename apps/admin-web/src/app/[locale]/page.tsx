import { LoginCard } from "@/components/login-card";
import { isLocale } from "@/lib/i18n";
import { notFound } from "next/navigation";

type LocalePageProps = {
  params: Promise<{ locale: string }>;
};

export default async function LocaleHomePage({ params }: LocalePageProps) {
  const { locale } = await params;

  if (!isLocale(locale)) {
    notFound();
  }

  return <LoginCard locale={locale} />;
}
