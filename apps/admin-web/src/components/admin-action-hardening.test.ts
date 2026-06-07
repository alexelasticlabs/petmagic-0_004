import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const roleManagementPagePath = fileURLToPath(
  new URL("./role-management-page.tsx", import.meta.url)
);
const usersManagementPagePath = fileURLToPath(
  new URL("./users-management-page.tsx", import.meta.url)
);
const useUsersAdminPath = fileURLToPath(new URL("./users/use-users-admin.ts", import.meta.url));
const adminShellPath = fileURLToPath(new URL("./admin-shell.tsx", import.meta.url));
const localeErrorPagePath = fileURLToPath(new URL("../app/[locale]/error.tsx", import.meta.url));

describe("admin action hardening", () => {
  it("guards role management actions and surfaces sanitized backend errors", () => {
    const source = readFileSync(roleManagementPagePath, "utf8");

    expect(source).toContain("import { getAdminErrorMessage }");
    expect(source).toContain("useAuthSession,");
    expect(source).toContain("const session = useAuthSession();");
    expect(source).toContain(
      'const canManageRoles = session?.user.roles.includes("Admin") ?? false;'
    );
    expect(source).toContain("roleActionsAdminOnly: isRu");
    expect(source).toContain("function assertCanManageRoles(): boolean");
    expect(source).toContain('setToast({ type: "error", message: text.roleActionsAdminOnly });');
    expect(source).toContain("if (!pendingAction || isSubmitting) {\n      return;");
    expect(source).toContain(
      "if (!assertCanManageRoles()) {\n      return;\n    }\n\n    setIsSubmitting(true);"
    );
    expect(source).toContain(
      "function confirmAssignModerator(user: UserListItem) {\n    if (!assertCanManageRoles())"
    );
    expect(source).toContain(
      "function confirmRevokeModerator(user: UserListItem) {\n    if (!assertCanManageRoles())"
    );
    expect(source).toContain("getAdminErrorMessage(error, text.failed)");
    expect(source).toContain("const [adminsPage, setAdminsPage] = useState(0);");
    expect(source).toContain("skip: adminsPage * PAGE_SIZE");
    expect(source).toContain("skip: moderatorsPage * PAGE_SIZE");
    expect(source).toContain("queryKey: adminQueryKeys.usersRoot");
    expect(source).toContain("function RolePager(");
    expect(source).toContain("sanitizeSensitiveText(getAdminUserDisplayName(user), 96)");
    expect(source).toContain("shortIdentifier(user.userId)");
    expect(source).toContain("sanitizeSensitiveText(role, 32)");
    expect(source).toContain("disabled={!canManageRoles || isSubmitting}");
    expect(source).toContain('const isAdmin = user.roles.includes("Admin");');
    expect(source).toContain(
      "disabled={!canManageRoles || isAdmin || isModerator || isSubmitting}"
    );
    expect(source).toContain("isAdmin\n                      ? text.adminAlreadyPrivileged");
    expect(source).toContain(': isModerator\n                        ? "Moderator"');
    expect(source).not.toContain("{user.userId} / {text.created}");
    expect(source).not.toContain("{role}\n        </AdminBadge>");
    expect(source).not.toContain(
      '} catch {\n      setToast({ type: "error", message: text.failed });'
    );
  });

  it("guards users confirmation actions against repeated submit", () => {
    const source = readFileSync(usersManagementPagePath, "utf8");
    const hookSource = readFileSync(useUsersAdminPath, "utf8");

    expect(hookSource).toContain("): Promise<boolean> {");
    expect(hookSource).toContain("return true;");
    expect(hookSource).toContain("return false;");
    expect(source).toContain("if (!confirmationDialog || confirmationSubmitting) {\n      return;");
    expect(source).toContain("const succeeded = await runUserAction(confirmationDialog.userId");
    expect(source).toContain("if (succeeded) {\n        confirmationDialog.afterSuccess?.();");
    expect(source).toContain("[confirmationDialog, confirmationSubmitting, runUserAction]");
  });

  it("keeps users financial and destructive controls admin-only in the UI layer", () => {
    const source = readFileSync(usersManagementPagePath, "utf8");

    expect(source).toContain("if (!canManageRoles) {\n        return;");
    expect(source).toContain("if (!canManageRoles || !walletDialog || walletDialogSubmitting) {");
    expect(source).toContain("{canManageRoles ? (\n                              <>");
    expect(source).toContain("{canManageRoles && (\n                  <>");
    expect(source).toContain("{canManageRoles ? (\n                      <section");
    expect(source).toContain("requestPremiumChange(user)");
    expect(source).toContain('openWalletDialog(user.userId, "credit")');
    expect(source).toContain("requestDeleteUser(selectedUser, () => setSelectedUserId(null))");
  });

  it("keeps wallet adjustment dialog recoverable after backend failures", () => {
    const source = readFileSync(usersManagementPagePath, "utf8");

    expect(source).toContain("if (!canManageRoles || !walletDialog || walletDialogSubmitting) {");
    expect(source).toContain("setWalletDialogSubmitting(true);");
    expect(source).toContain("try {\n      const succeeded = await runUserAction(");
    expect(source).toContain("if (succeeded) {\n        setWalletDialog(null);");
    expect(source).toContain("} finally {\n      setWalletDialogSubmitting(false);");
  });

  it("keeps previous users page visible during background refetches", () => {
    const source = readFileSync(usersManagementPagePath, "utf8");
    const hookSource = readFileSync(useUsersAdminPath, "utf8");

    expect(hookSource).toContain("const isLoading = usersQuery.isLoading;");
    expect(hookSource).toContain("const isFetching = usersQuery.isFetching;");
    expect(hookSource).toContain("isFetching,");
    expect(hookSource).toContain("async function refreshUsers()");
    expect(hookSource).toContain("setActionError(null);");
    expect(hookSource).toContain("await refreshUsers();");
    expect(hookSource).toContain("refreshUsers,");
    expect(hookSource).not.toContain(
      "const isLoading = usersQuery.isLoading || usersQuery.isFetching;"
    );
    expect(source).toContain("isFetching: isUsersFetching,");
    expect(source).toContain("refreshUsers,");
    expect(source).toContain("onClick={() => void refreshUsers().catch(() => undefined)}");
    expect(source).toContain("disabled={isUsersFetching}");
    expect(source).toContain('aria-busy={isUsersFetching ? "true" : undefined}');
    expect(source).toContain("disabled={currentPage <= 1 || isUsersFetching}");
    expect(source).toContain("disabled={currentPage >= totalPages || isUsersFetching}");
  });

  it("does not expose browser-only sorting on the paged users table", () => {
    const source = readFileSync(usersManagementPagePath, "utf8");

    expect(source).not.toContain("type SortMode");
    expect(source).not.toContain("sortMode");
    expect(source).not.toContain("sortLastActivity");
    expect(source).not.toContain("sortCreated");
    expect(source).not.toContain("analyticsTargetUsers");
    expect(source).toContain("const pageUsers = users;");
    expect(source).toContain("const pagedUsers = pageUsers;");
  });

  it("blocks obvious last-admin demotion in the frontend while preserving backend source of truth", () => {
    const pageSource = readFileSync(usersManagementPagePath, "utf8");
    const hookSource = readFileSync(useUsersAdminPath, "utf8");

    expect(pageSource).toContain(
      'const ADMIN_COUNT_QUERY_PARAMS = { role: "Admin", skip: 0, take: 1 } as const;'
    );
    expect(pageSource).toContain(
      "queryFn: ({ signal }) => fetchUsers(ADMIN_COUNT_QUERY_PARAMS, signal)"
    );
    expect(pageSource).toContain("const cannotRevokeLastAdmin =");
    expect(pageSource).toContain("totalAdminCount === null || totalAdminCount <= 1");
    expect(pageSource).toContain(
      "disabled={busyUserId === openActionsUser.userId || cannotRevokeLastAdmin}"
    );
    expect(pageSource).toContain(
      "title={cannotRevokeLastAdmin ? ui.lastAdminProtected : undefined}"
    );
    expect(hookSource).toContain("import { getAdminErrorMessage }");
    expect(hookSource).toContain(
      "getAdminErrorMessage(error, options?.errorMessage ?? text.errorLoadingUsers)"
    );
    expect(hookSource).toContain('adminQueryKeys.users({ role: "Admin", skip: 0, take: 1 })');
  });

  it("guards logout confirmation against repeated submit", () => {
    const source = readFileSync(adminShellPath, "utf8");

    expect(source).toContain("import { maskEmail, sanitizeSensitiveText }");
    expect(source).toContain("const safeSessionDisplayName = session?.user?.displayName?.trim()");
    expect(source).toContain("sanitizeSensitiveText(session.user.displayName, 96)");
    expect(source).toContain("const userName = safeSessionDisplayName || maskedSessionEmail;");
    expect(source).toContain('const userInitial = (userName || "A")[0].toUpperCase();');
    expect(source).toContain("const [isLoggingOut, setIsLoggingOut] = useState(false);");
    expect(source).toContain("if (isLoggingOut) {\n      return;");
    expect(source).toContain("isSubmitting={isLoggingOut}");
    expect(source).toContain("if (!isLoggingOut) {\n            setLogoutDialogOpen(false);");
    expect(source).not.toContain(
      "const userName = session?.user?.displayName || maskedSessionEmail;"
    );
    expect(source).not.toContain("session?.user?.displayName ||\n    maskedSessionEmail");
  });

  it("uses generic copy in the route error boundary", () => {
    const source = readFileSync(localeErrorPagePath, "utf8");

    expect(source).toContain("title={text.adminErrorTitle}");
    expect(source).toContain("description={text.adminErrorDescription}");
    expect(source).toContain("{text.adminRetryAction}");
    expect(source).not.toContain("text.errorLoadingTemplates");
    expect(source).not.toContain("text.userAnalyticsLoadError");
  });
});
