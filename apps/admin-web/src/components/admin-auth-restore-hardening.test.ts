import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const adminShellPath = fileURLToPath(new URL("./admin-shell.tsx", import.meta.url));
const loginCardPath = fileURLToPath(new URL("./login-card.tsx", import.meta.url));

describe("admin auth restore hardening", () => {
  it("clears stale sessions and redirects private routes when session restore rejects", () => {
    const source = readFileSync(adminShellPath, "utf8");

    expect(source).toContain(
      ".catch(() => {\n        void logout();\n        router.replace(`/${locale}`);\n      })"
    );
  });

  it("keeps login routes subscribed to auth session and redirects authenticated admins away", () => {
    const source = readFileSync(adminShellPath, "utf8");

    expect(source).toContain("const session = authSession;");
    expect(source).not.toContain("const session = isLoginPage ? null : authSession;");
    expect(source).toContain(
      "if (isLoginPage) {\n      router.replace(getDefaultAdminPath(locale, sessionRoles));\n      return;\n    }"
    );
    expect(source).toContain("function AdminAccessGate({ locale }: { locale: Locale })");
    expect(source).toContain(
      "if (isLoginPage) {\n    if (session !== null) {\n      return <AdminAccessGate locale={locale} />;\n    }"
    );
    expect(source).not.toContain("if (isLoginPage || session == null || needsSessionRestore)");
  });

  it("uses backend aggregate metrics for the support unread nav badge", () => {
    const source = readFileSync(adminShellPath, "utf8");

    expect(source).toContain("fetchSupportInboxMetrics,");
    expect(source).toContain("queryKey: adminQueryKeys.supportInboxMetrics");
    expect(source).toContain("queryFn: ({ signal }) => fetchSupportInboxMetrics(signal)");
    expect(source).toContain("enabled: hasFreshAccessToken && hasPanelAccess && !isLoginPage");
    expect(source).toContain("refetchIntervalInBackground: false");
    expect(source).toContain(
      "const canUseSupportRealtime = hasFreshAccessToken && hasPanelAccess && !isLoginPage;"
    );
    expect(source).toContain(
      "useSupportRealtime(canUseSupportRealtime ? session?.accessToken : undefined"
    );
    expect(source).not.toContain(
      "useSupportRealtime(hasFreshAccessToken ? session?.accessToken : undefined"
    );
    expect(source).toContain('import { getSupportUnreadCount } from "@/lib/support-unread-count";');
    expect(source).toContain(
      "const supportUnreadCount = getSupportUnreadCount(inboxMetricsQuery.data);"
    );
    expect(source).not.toContain(
      'fetchSupportInbox(undefined, "all", { page: 1, pageSize: 50, signal })'
    );
    expect(source).not.toContain("inboxQuery.data?.items.filter((c) => c.unreadForAdmin).length");
  });

  it("clears stale sessions when login-page session restore rejects", () => {
    const source = readFileSync(loginCardPath, "utf8");

    expect(source).toContain(".catch(() => {\n        void logout();\n      })");
  });
});
