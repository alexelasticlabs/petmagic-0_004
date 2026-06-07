import { notFound } from "next/navigation";

import { RoleManagementPage } from "@/components/role-management-page";
import { type Locale, isLocale } from "@/lib/i18n";

type Props = {
  params: Promise<{ locale: string }>;
};

export default async function RolesPage({ params }: Props) {
  const { locale } = await params;
  if (!isLocale(locale)) {
    notFound();
  }

  return <RoleManagementPage locale={locale as Locale} />;
}
