import { AdminShell } from "@/components/admin-shell";
import { isLocale } from "@/lib/i18n";
import { notFound } from "next/navigation";

type LocaleLayoutProps = {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
};

export default async function LocaleLayout({ children, params }: LocaleLayoutProps) {
  const { locale } = await params;

  if (!isLocale(locale)) {
    notFound();
  }

  return <AdminShell locale={locale}>{children}</AdminShell>;
}
