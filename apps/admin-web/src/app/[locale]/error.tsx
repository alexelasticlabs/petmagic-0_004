"use client";

import { AdminPage, AdminPageHero, AdminStateCard } from "@/components/admin/admin-primitives";
import { Button } from "@/components/ui/button";
import { getDictionary, isLocale } from "@/lib/i18n";
import Link from "next/link";
import { useParams } from "next/navigation";
import { useEffect } from "react";

type ErrorPageProps = {
  error: Error & { digest?: string };
  reset: () => void;
};

export default function Error({ error, reset }: ErrorPageProps) {
  const params = useParams<{ locale?: string | string[] }>();
  const localeParam = Array.isArray(params.locale) ? params.locale[0] : params.locale;
  const locale = typeof localeParam === "string" && isLocale(localeParam) ? localeParam : "en";
  const text = getDictionary(locale);

  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <AdminPage>
      <AdminPageHero title="PetMagic Admin" description={text.navDashboard} />
      <AdminStateCard
        tone="danger"
        title={text.errorLoadingTemplates}
        description={text.userAnalyticsLoadError}
        action={
          <div style={{ display: "flex", gap: "0.75rem", flexWrap: "wrap" }}>
            <Button variant="primary" onClick={reset}>
              {locale === "ru" ? "Повторить" : "Retry"}
            </Button>
            <Link href={`/${locale}/dashboard`} className="ui-button ui-button--secondary ui-button--md">
              {text.navDashboard}
            </Link>
          </div>
        }
      />
    </AdminPage>
  );
}
