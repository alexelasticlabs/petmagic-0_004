import { UsersTable } from "@/components/users-table";
import { isLocale } from "@/lib/i18n";
import { notFound } from "next/navigation";

type UsersPageProps = {
  params: Promise<{ locale: string }>;
};

export default async function UsersPage({ params }: UsersPageProps) {
  const { locale } = await params;

  if (!isLocale(locale)) {
    notFound();
  }

  return <UsersTable locale={locale} />;
}
