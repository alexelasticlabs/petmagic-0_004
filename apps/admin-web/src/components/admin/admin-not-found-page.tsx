"use client";

import Link from "next/link";

import { AdminPage, AdminPageHero, AdminStateCard } from "@/components/admin/admin-primitives";
import { getDefaultAdminPath } from "@/lib/admin-rbac";
import { useAuthSession } from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";

type AdminNotFoundPageProps = {
  locale: Locale;
};

export function AdminNotFoundPage({ locale }: AdminNotFoundPageProps) {
  const text = getDictionary(locale);
  const isRu = locale === "ru";
  const session = useAuthSession();
  const fallbackHref = getDefaultAdminPath(locale, session?.user.roles);
  const fallbackLabel = fallbackHref.endsWith("/support") ? text.navSupport : text.navDashboard;

  return (
    <AdminPage>
      <AdminPageHero
        eyebrow="404"
        title={isRu ? "Страница не найдена" : "Page not found"}
        description={
          isRu
            ? "Такого раздела в админ-панели нет или ссылка устарела."
            : "This admin section does not exist or the link is no longer valid."
        }
      />
      <AdminStateCard
        tone="info"
        title={isRu ? "Проверьте адрес страницы" : "Check the page address"}
        description={
          isRu
            ? "Вернитесь в доступный раздел или выберите другой пункт в меню."
            : "Return to an available section or choose another item from the menu."
        }
        action={
          <Link href={fallbackHref} className="ui-button ui-button--primary ui-button--md">
            {fallbackLabel}
          </Link>
        }
      />
    </AdminPage>
  );
}
