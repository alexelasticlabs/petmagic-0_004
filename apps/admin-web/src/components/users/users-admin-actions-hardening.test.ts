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
    expect(source).toContain("function getUsersActionErrorDetails(error: unknown)");
    expect(source).toContain('errorName: error instanceof Error ? error.name : "UnknownError"');
    expect(source).toContain("userId: formatUsersLogText(userId)");
    expect(source).toContain("...getUsersActionErrorDetails(error)");
    expect(source).toContain("...getUsersActionErrorDetails(refreshedUsers.error)");
    expect(source).toContain("if (refreshedUsers.isError) {");
    expect(source).toContain("} catch (error) {");
    expect(source).toContain("await Promise.allSettled([refreshUsersAfterAction(userId)]);");
    expect(source).not.toContain("userId,\n          error: refreshedUsers.error");
    expect(source).not.toContain("userId,\n        error");
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

  it("clears the selected user side panel when filters or pages change", () => {
    const pageSource = readFileSync(usersManagementPagePath, "utf8");

    expect(pageSource).toContain("const resetUsersSelection = useCallback(");
    expect(pageSource).toContain("(nextPage = 1) => {");
    expect(pageSource).toContain("setSelectedUserId(null);");
    expect(pageSource).toContain("closeActionsMenu();");
    expect(pageSource).toContain("setWalletDialog(null);");
    expect(pageSource).toContain("setConfirmationDialog(null);");
    expect(pageSource).toContain("setPage(nextPage);");
    expect(pageSource.match(/resetUsersSelection\(\);/g) ?? []).toHaveLength(7);
    expect(pageSource).toContain("resetUsersSelection(Math.max(1, currentPage - 1))");
    expect(pageSource).toContain("resetUsersSelection(Math.min(totalPages, currentPage + 1))");
    expect(pageSource).not.toContain("setSearch(event.target.value.slice(0, USER_SEARCH_MAX_LENGTH));\n              setPage(1);");
    expect(pageSource).not.toContain("setRoleFilter(event.target.value as RoleFilter);\n              setPage(1);");
    expect(pageSource).not.toContain("setPremiumFilter(event.target.value as PremiumFilter);\n              setPage(1);");
    expect(pageSource).not.toContain("setActivityFilter(event.target.value as ActivityFilter);\n              setPage(1);");
    expect(pageSource).not.toContain("setStatusFilter(event.target.value as StatusFilter);\n              setPage(1);");
    expect(pageSource).not.toContain("setRangeDays(Number.parseInt(event.target.value, 10) as RangeDays);\n              setPage(1);");
  });

  it("clears stale users action dialogs and side panel after real page refreshes", () => {
    const pageSource = readFileSync(usersManagementPagePath, "utf8");

    expect(pageSource).toContain("const pageUserIdSet = useMemo(() => new Set(pageUserIds), [pageUserIds]);");
    expect(pageSource).toContain("if (isUsersRefreshing || isUserActionLocked) {\n      return;\n    }");
    expect(pageSource).toContain(
      "openActionsUserId !== null && !pageUserIdSet.has(openActionsUserId)"
    );
    expect(pageSource).toContain(
      "selectedUserId !== null && !pageUserIdSet.has(selectedUserId)"
    );
    expect(pageSource).toContain("walletDialog !== null && !pageUserIdSet.has(walletDialog.userId)");
    expect(pageSource).toContain("function getUsersPageErrorDetails(error: unknown)");
    expect(pageSource).toContain("userId: sanitizeSensitiveText(userId, 80)");
    expect(pageSource).toContain("...getUsersPageErrorDetails(refreshResult.reason)");
    expect(pageSource).toContain(
      "confirmationDialog !== null && !pageUserIdSet.has(confirmationDialog.userId)"
    );
    expect(pageSource).toContain("queueMicrotask(() => {");
    expect(pageSource).toContain("closeActionsMenu();");
    expect(pageSource).toContain("setSelectedUserId(null);");
    expect(pageSource).toContain("setWalletDialog(null);");
    expect(pageSource).toContain("setConfirmationDialog(null);");
    expect(pageSource).toContain("selectedUserId,");
  });
});
