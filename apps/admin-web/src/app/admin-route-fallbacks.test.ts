import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const errorPagePath = fileURLToPath(new URL("./[locale]/error.tsx", import.meta.url));
const globalErrorPagePath = fileURLToPath(new URL("./global-error.tsx", import.meta.url));
const loadingPagePath = fileURLToPath(new URL("./[locale]/loading.tsx", import.meta.url));
const rootNotFoundPagePath = fileURLToPath(new URL("./not-found.tsx", import.meta.url));
const notFoundPagePath = fileURLToPath(
  new URL("../components/admin/admin-not-found-page.tsx", import.meta.url)
);

describe("admin route fallbacks", () => {
  it("uses generic safe fallback copy instead of raw errors or placeholder nav labels", () => {
    const errorSource = readFileSync(errorPagePath, "utf8");
    const globalErrorSource = readFileSync(globalErrorPagePath, "utf8");
    const loadingSource = readFileSync(loadingPagePath, "utf8");

    expect(errorSource).toContain("title={text.adminErrorTitle}");
    expect(errorSource).toContain("description={text.adminErrorDescription}");
    expect(errorSource).not.toContain("description={error.message}");
    expect(errorSource).not.toContain("message: error.message");
    expect(errorSource).not.toContain("description={text.navDashboard}");
    expect(errorSource).toContain("useAuthSession()");
    expect(errorSource).toContain("getDefaultAdminPath(locale, session?.user.roles)");
    expect(errorSource).toContain('fallbackHref.endsWith("/support")');
    expect(errorSource).toContain('fallbackHref.endsWith("/dashboard")');
    expect(errorSource).toContain("text.signIn");
    expect(errorSource).not.toContain('href={`/${locale}/dashboard`}');

    expect(globalErrorSource).toContain('clientLogger.error("admin.global_error_boundary_triggered"');
    expect(globalErrorSource).toContain("<html lang={isRu ? \"ru\" : \"en\"}>");
    expect(globalErrorSource).toContain("onClick={reset}");
    expect(globalErrorSource).toContain('href={isRu ? "/ru" : "/en"}');
    expect(globalErrorSource).not.toContain("{error.message}");
    expect(globalErrorSource).not.toContain("message: error.message");
    expect(globalErrorSource).not.toContain("error.stack");
    expect(globalErrorSource).not.toContain("JSON.stringify(error");

    expect(loadingSource).toContain("description={text.adminLoadingDescription}");
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
