import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const errorPagePath = fileURLToPath(new URL("./[locale]/error.tsx", import.meta.url));
const errorStylesPath = fileURLToPath(
  new URL("./[locale]/admin-route-fallback.module.css", import.meta.url)
);
const globalErrorPagePath = fileURLToPath(new URL("./global-error.tsx", import.meta.url));
const globalErrorStylesPath = fileURLToPath(
  new URL("./global-error.module.css", import.meta.url)
);
const loadingPagePath = fileURLToPath(new URL("./[locale]/loading.tsx", import.meta.url));
const rootNotFoundPagePath = fileURLToPath(new URL("./not-found.tsx", import.meta.url));
const notFoundPagePath = fileURLToPath(
  new URL("../components/admin/admin-not-found-page.tsx", import.meta.url)
);

describe("admin route fallbacks", () => {
  it("uses generic safe fallback copy instead of raw errors or placeholder nav labels", () => {
    const errorSource = readFileSync(errorPagePath, "utf8");
    const errorStyles = readFileSync(errorStylesPath, "utf8");
    const globalErrorSource = readFileSync(globalErrorPagePath, "utf8");
    const globalErrorStyles = readFileSync(globalErrorStylesPath, "utf8");
    const nonZeroGlobalErrorLetterSpacing = [
      ...globalErrorStyles.matchAll(/letter-spacing:\s*([^;]+);/g),
    ]
      .map((match) => match[1]?.trim())
      .filter((value) => value !== "0");
    const loadingSource = readFileSync(loadingPagePath, "utf8");

    expect(errorSource).toContain("title={text.adminErrorTitle}");
    expect(errorSource).toContain("description={text.adminErrorDescription}");
    expect(errorSource).toContain('scope: "locale"');
    expect(errorSource).not.toContain("description={error.message}");
    expect(errorSource).not.toContain("message: error.message");
    expect(errorSource).not.toContain("\n      error,");
    expect(errorSource).not.toContain("stack: error.stack");
    expect(errorSource).not.toContain("description={text.navDashboard}");
    expect(errorSource).toContain("useAuthSession()");
    expect(errorSource).toContain("getDefaultAdminPath(locale, session?.user.roles)");
    expect(errorSource).toContain('fallbackHref.endsWith("/support")');
    expect(errorSource).toContain('fallbackHref.endsWith("/dashboard")');
    expect(errorSource).toContain("text.signIn");
    expect(errorSource).not.toContain('href={`/${locale}/dashboard`}');
    expect(errorSource).toContain("className={styles.actionRow}");
    expect(errorSource).not.toContain('style={{ display: "flex"');
    expect(errorStyles).toContain("@media (max-width: 520px)");

    expect(globalErrorSource).toContain('clientLogger.error("admin.global_error_boundary_triggered"');
    expect(globalErrorSource).toContain("<html lang={isRu ? \"ru\" : \"en\"}>");
    expect(globalErrorSource).toContain('import styles from "./global-error.module.css"');
    expect(globalErrorSource).toContain("className={styles.body}");
    expect(globalErrorSource).toContain("className={styles.panel}");
    expect(globalErrorSource).toContain('aria-describedby="global-error-description"');
    expect(globalErrorSource).toContain('id="global-error-description"');
    expect(globalErrorSource).toContain("className={styles.primaryAction}");
    expect(globalErrorSource).toContain("className={styles.secondaryAction}");
    expect(globalErrorSource).toContain("onClick={reset}");
    expect(globalErrorSource).toContain('href={isRu ? "/ru" : "/en"}');
    expect(globalErrorSource).not.toContain("{error.message}");
    expect(globalErrorSource).not.toContain("message: error.message");
    expect(globalErrorSource).not.toContain("error.stack");
    expect(globalErrorSource).not.toContain("JSON.stringify(error");
    expect(globalErrorSource).not.toContain("CSSProperties");
    expect(globalErrorSource).not.toContain("style={");
    expect(globalErrorSource).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(globalErrorStyles).toContain("@media (prefers-color-scheme: dark)");
    expect(globalErrorStyles).toContain("@media (max-width: 520px)");
    expect(globalErrorStyles).toContain(".primaryAction");
    expect(globalErrorStyles).toContain(".secondaryAction");
    expect(globalErrorStyles).toContain("--global-error-surface-0: var(--surface-0");
    expect(globalErrorStyles).toContain("--global-error-accent: var(--accent");
    expect(globalErrorStyles).toContain("min-height: 100dvh;");
    expect(globalErrorStyles).not.toContain("rgba(");
    expect(globalErrorStyles).not.toContain("radial-gradient");
    expect(globalErrorStyles).not.toContain("100vh");
    expect(globalErrorStyles).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(globalErrorStyles).not.toMatch(/font-size:\s*[^;]*vw/);
    expect(nonZeroGlobalErrorLetterSpacing).toEqual([]);

    expect(loadingSource).toContain("description={text.adminLoadingDescription}");
    expect(loadingSource).toContain('<AdminPage aria-busy="true" aria-live="polite">');
    expect(loadingSource).not.toContain("description={text.navDashboard}");
  });

  it("uses a role-aware not-found action instead of hardcoded dashboard navigation", () => {
    const notFoundSource = readFileSync(notFoundPagePath, "utf8");

    expect(notFoundSource).toContain("useAuthSession()");
    expect(notFoundSource).toContain("getDefaultAdminPath(locale, session?.user.roles)");
    expect(notFoundSource).toContain('fallbackHref.endsWith("/support")');
    expect(notFoundSource).toContain('fallbackHref.endsWith("/dashboard")');
    expect(notFoundSource).toContain("text.signIn");
    expect(notFoundSource).not.toContain('href={`/${locale}/dashboard`}');
  });

  it("keeps the root not-found page independent from session providers", () => {
    const rootNotFoundSource = readFileSync(rootNotFoundPagePath, "utf8");

    expect(rootNotFoundSource).not.toContain("AdminNotFoundPage");
    expect(rootNotFoundSource).not.toContain("useAuthSession()");
    expect(rootNotFoundSource).not.toContain("getDefaultAdminPath");
    expect(rootNotFoundSource).toContain('href={`/${locale}`}');
  });
});
