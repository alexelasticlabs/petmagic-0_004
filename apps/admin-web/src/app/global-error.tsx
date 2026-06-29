"use client";

import { useEffect } from "react";

import { getAdminRouteFallbackText } from "@/app/admin-route-fallback.content";
import { clientLogger } from "@/lib/client-logger";
import { isLocale, type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

import styles from "./global-error.module.css";

type GlobalErrorProps = {
  error: Error & { digest?: string };
  reset: () => void;
};

function getLocaleFromCurrentPath(): Locale {
  if (typeof window === "undefined") {
    return "en";
  }

  const rawLocale = window.location.pathname.split("/").filter(Boolean)[0];
  return isLocale(rawLocale) ? rawLocale : "en";
}

export default function GlobalError({ error, reset }: GlobalErrorProps) {
  const locale = getLocaleFromCurrentPath();
  const text = getAdminRouteFallbackText(locale);

  useEffect(() => {
    clientLogger.error("admin.global_error_boundary_triggered", {
      name: error.name,
      digest: error.digest ? sanitizeSensitiveText(error.digest, 80) : undefined,
      scope: "root",
    });
  }, [error]);

  return (
    <html lang={locale}>
      <body className={styles.body}>
        <main className={styles.main}>
          <section
            className={styles.panel}
            aria-labelledby="global-error-title"
            aria-describedby="global-error-description"
          >
            <p className={styles.eyebrow}>PetMagic Admin</p>
            <h1 id="global-error-title" className={styles.title}>
              {text.globalErrorTitle}
            </h1>
            <p id="global-error-description" className={styles.description}>
              {text.globalErrorDescription}
            </p>
            <div className={styles.actions}>
              <button type="button" className={styles.primaryAction} onClick={reset}>
                {text.retryActionLabel}
              </button>
              <a href={`/${locale}`} className={styles.secondaryAction}>
                {text.signInActionLabel}
              </a>
            </div>
          </section>
        </main>
      </body>
    </html>
  );
}
