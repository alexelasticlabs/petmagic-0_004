import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const usersAdminHookPath = fileURLToPath(new URL("./use-users-admin.ts", import.meta.url));
const usersManagementPagePath = fileURLToPath(
  new URL("../users-management-page.tsx", import.meta.url)
);

describe("users admin action hardening", () => {
  it("keeps successful user actions independent from best-effort list refresh failures", () => {
    const source = readFileSync(usersAdminHookPath, "utf8");

    expect(source).toContain("async function refreshUsersAfterAction(userId: string)");
    expect(source).toContain('clientLogger.warn("users.action_refresh_failed"');
    expect(source).toContain("if (refreshedUsers.isError) {");
    expect(source).toContain("} catch (error) {");
    expect(source).toContain("await Promise.allSettled([refreshUsersAfterAction(userId)]);");
    expect(source).not.toContain("await refreshUsers();\n\n      await Promise.allSettled([");
  });

  it("keeps manual users retry strict so retry errors still surface in the page state", () => {
    const source = readFileSync(usersAdminHookPath, "utf8");

    expect(source).toContain("async function refreshUsers()");
    expect(source).toContain("const refreshedUsers = await usersQuery.refetch();");
    expect(source).toContain(
      "if (refreshedUsers.isError) {\n      throw refreshedUsers.error;\n    }"
    );
  });

  it("does not expose stale placeholder users while filters or pages refresh", () => {
    const source = readFileSync(usersAdminHookPath, "utf8");
    const pageSource = readFileSync(usersManagementPagePath, "utf8");

    expect(source).toContain(
      "const isRefreshing = usersQuery.isFetching && usersQuery.isPlaceholderData;"
    );
    expect(source).toContain(
      "const visibleUsersPage = usersQuery.isPlaceholderData ? undefined : usersQuery.data;"
    );
    expect(source).toContain("isRefreshing,");
    expect(source).toContain("users: visibleUsersPage?.items ?? []");
    expect(source).toContain("usersPage: visibleUsersPage ?? {");
    expect(source).not.toContain("users: usersQuery.data?.items ?? []");
    expect(source).not.toContain("usersPage: usersQuery.data ?? {");
    expect(pageSource).toContain("isRefreshing: isUsersRefreshing,");
    expect(pageSource).toContain(
      '<AdminStateCard tone="info" className={styles.emptyState} title={text.loading} />'
    );
    expect(pageSource).toContain("{!isUsersRefreshing && !pageUsers.length ? (");
    expect(pageSource).toContain("{!isUsersRefreshing && !!pageUsers.length && (");
    expect(pageSource).not.toContain("{!pageUsers.length ? (");
    expect(pageSource).not.toContain("{!!pageUsers.length && (");
  });
});
