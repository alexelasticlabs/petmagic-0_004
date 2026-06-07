"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

import { AdminPage, AdminPageHero, AdminStateCard } from "@/components/admin/admin-primitives";
import { isLocale, type Locale } from "@/lib/i18n";

export default function RootNotFoundPage() {
  const pathname = usePathname();
  const rawLocale = pathname.split("/").filter(Boolean)[0];
  const locale: Locale = isLocale(rawLocale) ? rawLocale : "en";
  const isRu = locale === "ru";

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
            ? "Вернитесь на страницу входа и откройте доступный раздел после проверки сессии."
            : "Return to sign in and open an available section after the session check."
        }
        action={
          <Link href={`/${locale}`} className="ui-button ui-button--primary ui-button--md">
            {isRu ? "К входу" : "Go to sign in"}
          </Link>
        }
      />
    </AdminPage>
  );
}
