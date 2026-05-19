import { AdminShell } from "@/components/admin-shell";
import { isLocale } from "@/lib/i18n";
import { Providers } from "@/lib/providers";
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

  return (
    <Providers>
      <AdminShell locale={locale}>{children}</AdminShell>
    </Providers>
  );
}
