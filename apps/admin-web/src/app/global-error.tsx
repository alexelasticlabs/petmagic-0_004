"use client";

import { useEffect } from "react";

import { clientLogger } from "@/lib/client-logger";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

import styles from "./global-error.module.css";

type GlobalErrorProps = {
  error: Error & { digest?: string };
  reset: () => void;
};

function isRussianPath(): boolean {
  if (typeof window === "undefined") {
    return false;
  }

  return window.location.pathname.split("/").filter(Boolean)[0] === "ru";
}

export default function GlobalError({ error, reset }: GlobalErrorProps) {
  const isRu = isRussianPath();

  useEffect(() => {
    clientLogger.error("admin.global_error_boundary_triggered", {
      name: error.name,
      digest: error.digest ? sanitizeSensitiveText(error.digest, 80) : undefined,
      scope: "root",
    });
  }, [error]);

  return (
    <html lang={isRu ? "ru" : "en"}>
      <body className={styles.body}>
        <main className={styles.main}>
          <section
            className={styles.panel}
            aria-labelledby="global-error-title"
            aria-describedby="global-error-description"
          >
            <p className={styles.eyebrow}>PetMagic Admin</p>
            <h1 id="global-error-title" className={styles.title}>
              {isRu ? "Не удалось открыть админ-панель" : "Unable to open the admin panel"}
            </h1>
            <p id="global-error-description" className={styles.description}>
              {isRu
                ? "Произошла критическая ошибка интерфейса. Повторите попытку или вернитесь на страницу входа."
                : "A critical interface error occurred. Try again or return to the sign-in page."}
            </p>
            <div className={styles.actions}>
              <button type="button" className={styles.primaryAction} onClick={reset}>
                {isRu ? "Повторить" : "Retry"}
              </button>
              <a href={isRu ? "/ru" : "/en"} className={styles.secondaryAction}>
                {isRu ? "К входу" : "Go to sign in"}
              </a>
            </div>
          </section>
        </main>
      </body>
    </html>
  );
}
