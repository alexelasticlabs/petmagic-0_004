import { notFound } from "next/navigation";

import { AdminShell } from "@/components/admin-shell";
import { getDictionary, isLocale } from "@/lib/i18n";
import { Providers } from "@/lib/providers";

import type { Metadata } from "next";

type LocaleLayoutProps = {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
};

export async function generateMetadata({
  params,
}: Pick<LocaleLayoutProps, "params">): Promise<Metadata> {
  const { locale } = await params;

  if (!isLocale(locale)) {
    return {
      title: "PetMagic Admin",
      description: "PetMagic Admin",
    };
  }

  const text = getDictionary(locale);

  return {
    title: text.adminMetadataTitle,
    description: text.adminMetadataDescription,
  };
}

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
