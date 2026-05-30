"use client";

import { UsersManagementPage } from "@/components/users-management-page";
import { type Locale } from "@/lib/i18n";

type UsersTableProps = {
  locale: Locale;
};

export function UsersTable({ locale }: UsersTableProps) {
  return <UsersManagementPage locale={locale} />;
}
