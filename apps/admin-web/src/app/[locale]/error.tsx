"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useEffect } from "react";

import { AdminPage, AdminPageHero, AdminStateCard } from "@/components/admin/admin-primitives";
import { Button } from "@/components/ui/button";
import { getDefaultAdminPath } from "@/lib/admin-rbac";
import { useAuthSession } from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { getDictionary, isLocale } from "@/lib/i18n";

type ErrorPageProps = {
  error: Error & { digest?: string };
  reset: () => void;
};

export default function Error({ error, reset }: ErrorPageProps) {
  const params = useParams<{ locale?: string | string[] }>();
  const localeParam = Array.isArray(params.locale) ? params.locale[0] : params.locale;
  const locale = typeof localeParam === "string" && isLocale(localeParam) ? localeParam : "en";
  const text = getDictionary(locale);
  const session = useAuthSession();
  const fallbackHref = getDefaultAdminPath(locale, session?.user.roles);
  const fallbackLabel = fallbackHref.endsWith("/support") ? text.navSupport : text.navDashboard;

  useEffect(() => {
    clientLogger.error("admin.error_boundary_triggered", {
      name: error.name,
      digest: error.digest,
      error,
    });
  }, [error]);

  return (
    <AdminPage>
      <AdminPageHero title="PetMagic Admin" description={text.adminErrorDescription} />
      <AdminStateCard
        tone="danger"
        title={text.adminErrorTitle}
        description={text.adminErrorDescription}
        action={
          <div style={{ display: "flex", gap: "0.75rem", flexWrap: "wrap" }}>
            <Button variant="primary" onClick={reset}>
              {text.adminRetryAction}
            </Button>
            <Link
              href={fallbackHref}
              className="ui-button ui-button--secondary ui-button--md"
            >
              {fallbackLabel}
            </Link>
          </div>
        }
      />
    </AdminPage>
  );
}
