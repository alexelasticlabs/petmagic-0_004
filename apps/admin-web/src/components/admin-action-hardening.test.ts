import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const roleManagementPagePath = fileURLToPath(
  new URL("./role-management-page.tsx", import.meta.url)
);
const roleManagementStylesPath = fileURLToPath(
  new URL("./role-management-page.module.css", import.meta.url)
);
const usersManagementPagePath = fileURLToPath(
  new URL("./users-management-page.tsx", import.meta.url)
);
const userDetailPagePath = fileURLToPath(new URL("./users/user-detail-page.tsx", import.meta.url));
const userInlineAnalyticsPath = fileURLToPath(
  new URL("./users/user-inline-analytics.tsx", import.meta.url)
);
const useAdminUserProfilePath = fileURLToPath(
  new URL("./users/use-admin-user-profile.ts", import.meta.url)
);
const useUsersAdminPath = fileURLToPath(new URL("./users/use-users-admin.ts", import.meta.url));
const adminShellPath = fileURLToPath(new URL("./admin-shell.tsx", import.meta.url));
const localeErrorPagePath = fileURLToPath(new URL("../app/[locale]/error.tsx", import.meta.url));

describe("admin action hardening", () => {
  it("guards role management actions and surfaces sanitized backend errors", () => {
    const source = readFileSync(roleManagementPagePath, "utf8");
    const stylesSource = readFileSync(roleManagementStylesPath, "utf8");

    expect(source).toContain("import { getAdminErrorMessage }");
    expect(source).toContain("useAuthSession,");
    expect(source).toContain("const session = useAuthSession();");
    expect(source).toContain("const sessionRoles = session?.user.roles ?? [];");
    expect(source).toContain('const canManageRoles = sessionRoles.includes("Admin");');
    expect(source).toContain('ensureAdminSession(locale, router, { requiredRole: "Admin" });');
    expect(source).toContain("{!canManageRoles || isLoading ? (");
    expect(source).toContain("{canManageRoles ? (\n        <AdminCard title={text.searchTitle}");
    expect(source).toContain("enabled: canManageRoles");
    expect(source).toContain("enabled: canManageRoles && debouncedSearch.trim().length >= 2");
    expect(source).toContain("roleActionsAdminOnly: isRu");
    expect(source).toContain("assignModeratorLabel: isRu");
    expect(source).toContain("revokeModeratorLabel: isRu");
    expect(source).toContain('eyebrow: isRu ? "Контроль доступа" : "Access control"');
    expect(source).toContain('adminOnly: isRu ? "Только Admin" : "Admin only"');
    expect(source).toContain('adminsTitle: isRu ? "Администраторы" : "Admins"');
    expect(source).toContain('moderatorsTitle: isRu ? "Модераторы" : "Moderators"');
    expect(source).toContain("function assertCanManageRoles(): boolean");
    expect(source).toContain('setToast({ type: "error", message: text.roleActionsAdminOnly });');
    expect(source).toContain("useRef,");
    expect(source).toContain("const roleActionInFlightRef = useRef(false);");
    expect(source).toContain(
      "if (!pendingAction || roleActionInFlightRef.current || isSubmitting) {\n      return;"
    );
    expect(source).toContain(
      "if (!assertCanManageRoles()) {\n      return;\n    }\n\n    roleActionInFlightRef.current = true;\n    setIsSubmitting(true);"
    );
    expect(source).toContain("roleActionInFlightRef.current = true;");
    expect(source).toContain("roleActionInFlightRef.current = false;");
    expect(source).toContain("if (!roleActionInFlightRef.current && !isSubmitting) {");
    expect(source).toContain(
      "function confirmAssignModerator(user: UserListItem) {\n    if (!assertCanManageRoles())"
    );
    expect(source).toContain(
      "function confirmRevokeModerator(user: UserListItem) {\n    if (!assertCanManageRoles())"
    );
    expect(source).toContain("getAdminErrorMessage(error, text.failed)");
    expect(source).toContain("USER_SEARCH_MAX_LENGTH,");
    expect(source).toContain("setSearch(event.target.value.slice(0, USER_SEARCH_MAX_LENGTH))");
    expect(source).toContain('type="search"');
    expect(source).toContain('autoComplete="off"');
    expect(source).toContain("maxLength={USER_SEARCH_MAX_LENGTH}");
    expect(source).toContain("const [adminsPage, setAdminsPage] = useState(0);");
    expect(source).toContain("skip: adminsPage * PAGE_SIZE");
    expect(source).toContain("skip: moderatorsPage * PAGE_SIZE");
    expect(source).toContain("queryKey: adminQueryKeys.usersRoot");
    expect(source).toContain("function RolePager(");
    expect(source).toContain(
      'previousPageLabel: isRu ? "Предыдущая страница списка ролей" : "Previous role list page"'
    );
    expect(source).toContain(
      'nextPageLabel: isRu ? "Следующая страница списка ролей" : "Next role list page"'
    );
    expect(source).toContain("aria-label={text.previousPageLabel}");
    expect(source).toContain("aria-label={text.nextPageLabel}");
    expect(stylesSource).toContain(
      ".pager {\n    flex-direction: column;\n    align-items: stretch;"
    );
    expect(stylesSource).toContain(".pageInfo {\n    width: 100%;");
    expect(stylesSource).toContain(".pagerActions {\n    display: grid;");
    expect(stylesSource).toContain("grid-template-columns: 1fr 1fr;\n    width: 100%;");
    expect(source).toContain("sanitizeSensitiveText(getAdminUserDisplayName(user), 96)");
    expect(source).toContain("shortIdentifier(user.userId)");
    expect(source).toContain("sanitizeSensitiveText(role, 32)");
    expect(source).toContain("disabled={!canManageRoles || isSubmitting}");
    expect(source).toContain(
      "aria-label={`${text.revokeModeratorLabel} ${userDisplayName(user)}`}"
    );
    expect(source).toContain('const isAdmin = user.roles.includes("Admin");');
    expect(source).toContain(
      "disabled={!canManageRoles || isAdmin || isModerator || isSubmitting}"
    );
    expect(source).toContain(
      "aria-label={`${text.assignModeratorLabel} ${userDisplayName(user)}`}"
    );
    expect(source).toContain("text.adminAlreadyPrivileged");
    expect(source).toContain('? "Moderator"');
    expect(stylesSource).toContain("overflow-wrap: anywhere;");
    expect(stylesSource).toContain(".userRow > .button {\n    width: 100%;");
    expect(source).not.toContain("{user.userId} / {text.created}");
    expect(source).not.toContain("{role}\n        </AdminBadge>");
    expect(source).not.toContain("setSearch(event.target.value)");
    expect(source).not.toContain("maxLength={100}");
    expect(source).not.toContain(
      '} catch {\n      setToast({ type: "error", message: text.failed });'
    );
  });

  it("guards users confirmation actions against repeated submit", () => {
    const source = readFileSync(usersManagementPagePath, "utf8");
    const hookSource = readFileSync(useUsersAdminPath, "utf8");

    expect(hookSource).toContain("): Promise<boolean> {");
    expect(hookSource).toContain("useRef,");
    expect(hookSource).toContain("const actionInFlightUserIdRef = useRef<string | null>(null);");
    expect(hookSource).toContain(
      "if (actionInFlightUserIdRef.current !== null) {\n      return false;\n    }\n\n    actionInFlightUserIdRef.current = userId;"
    );
    expect(hookSource).toContain("actionInFlightUserIdRef.current = null;");
    expect(hookSource).toContain("return true;");
    expect(hookSource).toContain("return false;");
    expect(source).toContain("if (!confirmationDialog || confirmationSubmitting) {\n      return;");
    expect(source).toContain("const succeeded = await runUserAction(confirmationDialog.userId");
    expect(source).toContain("if (succeeded) {\n        confirmationDialog.afterSuccess?.();");
    expect(source).toContain("[confirmationDialog, confirmationSubmitting, runUserAction]");
    expect(source).toContain(
      "const isUserActionLocked = confirmationSubmitting || walletDialogSubmitting;"
    );
    expect(source).toContain("if (!canManageRoles || isUserActionLocked) {\n        return;");
    expect(source).toContain("if (isUserActionLocked) {\n        return;");
    expect(source).toContain("const isBusy = busyUserId === user.userId || isUserActionLocked;");
    expect(source).toContain("disabled={isUserActionLocked}");
    expect(source).toContain(
      "disabled={isUserActionLocked || busyUserId === openActionsUser.userId}"
    );
    expect(source).toContain("disabled={isUserActionLocked || busyUserId === selectedUser.userId}");
  });

  it("keeps users financial and destructive controls admin-only in the UI layer", () => {
    const source = readFileSync(usersManagementPagePath, "utf8");

    expect(source).toContain("if (!canManageRoles) {\n        return;");
    expect(source).toContain("if (!canManageRoles || isUserActionLocked) {\n        return;");
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

    expect(source).toContain("USER_WALLET_REASON_MAX_LENGTH,");
    expect(source).toContain("if (!canManageRoles || !walletDialog || walletDialogSubmitting) {");
    expect(source).toContain(
      "const reason = walletDialog.reason.trim().slice(0, USER_WALLET_REASON_MAX_LENGTH);"
    );
    expect(source).toContain('amount: event.target.value.replace(/\\D+/g, "").slice(0, 8)');
    expect(source).toContain("maxLength={8}");
    expect(source).toContain("reason: event.target.value.slice(0, USER_WALLET_REASON_MAX_LENGTH)");
    expect(source).toContain("maxLength={USER_WALLET_REASON_MAX_LENGTH}");
    expect(source).toContain(
      'variant="ghost"\n                    size="sm"\n                    onClick={closeWalletDialog}\n                    disabled={walletDialogSubmitting}'
    );
    expect(source).toContain(
      'variant="secondary"\n                    size="sm"\n                    onClick={() => {\n                      void submitWalletDialog();\n                    }}\n                    disabled={'
    );
    expect(source).toContain("!walletDialog.amount.trim()");
    expect(source).toContain("!walletDialog.reason.trim()");
    expect(source).toContain("setWalletDialogSubmitting(true);");
    expect(source).toContain("try {\n      const succeeded = await runUserAction(");
    expect(source).toContain("if (succeeded) {\n        setWalletDialog(null);");
    expect(source).toContain("} finally {\n      setWalletDialogSubmitting(false);");
    expect(source).not.toContain("reason: event.target.value,");
    expect(source).not.toContain("const reason = walletDialog.reason.trim();");
  });

  it("keeps previous users page visible during background refetches", () => {
    const source = readFileSync(usersManagementPagePath, "utf8");
    const hookSource = readFileSync(useUsersAdminPath, "utf8");

    expect(source).toContain("USER_SEARCH_MAX_LENGTH,");
    expect(source).toContain("setSearch(event.target.value.slice(0, USER_SEARCH_MAX_LENGTH));");
    expect(source).toContain("maxLength={USER_SEARCH_MAX_LENGTH}");
    expect(hookSource).toContain("const isLoading = usersQuery.isLoading;");
    expect(hookSource).toContain("const isFetching = usersQuery.isFetching;");
    expect(hookSource).toContain("isFetching,");
    expect(hookSource).toContain("async function refreshUsers()");
    expect(hookSource).toContain("setActionError(null);");
    expect(hookSource).toContain(
      "if (!canManageRoles) {\n      return usersQuery;\n    }\n\n    const refreshedUsers = await usersQuery.refetch();"
    );
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
    expect(source).not.toContain("setSearch(event.target.value);");
  });

  it("does not expose browser-only sorting on the paged users table", () => {
    const source = readFileSync(usersManagementPagePath, "utf8");

    expect(source).toContain("const ROW_ENRICHMENT_CONCURRENCY = 4;");
    expect(source).toContain("function fetchUserRowEnrichment<TValue>(");
    expect(source).toContain("queryKey: adminQueryKeys.userRowAnalytics(pageUserIds)");
    expect(source).toContain(
      "queryKey: adminQueryKeys.economyUserSubscriptionSummaries(premiumPageUserIds)"
    );
    expect(source).toContain("fetchUserRowEnrichment<AdminUserAnalytics>");
    expect(source).toContain("fetchUserRowEnrichment<AdminEconomyUserSubscriptionSummary>");
    expect(source).not.toContain("useQueries");
    expect(source).not.toContain("type SortMode");
    expect(source).not.toContain("sortMode");
    expect(source).not.toContain("sortLastActivity");
    expect(source).not.toContain("sortCreated");
    expect(source).not.toContain("analyticsTargetUsers");
    expect(source).toContain("const pageUsers = users;");
    expect(source).toContain("const pagedUsers = pageUsers;");
  });

  it("sources users page summary cards from backend aggregate metrics", () => {
    const source = readFileSync(usersManagementPagePath, "utf8");

    expect(source).toContain("fetchAdminUserDashboardMetrics(signal)");
    expect(source).toContain("type AdminUserDashboardMetrics,");
    expect(source).toContain("userMetrics?.totalUsers");
    expect(source).toContain("userMetrics?.activeUsers");
    expect(source).toContain("userMetrics?.premiumUsers");
    expect(source).toContain("userMetrics?.blockedUsers");
    expect(source).toContain("metrics.newUsersLast7Days");
    expect(source).toContain("metrics.newUsersLast30Days");
    expect(source).toContain("metrics.newUsersLast90Days");
    expect(source).not.toContain("value={String(users.length)}");
    expect(source).not.toContain("const activeCount = users.filter");
    expect(source).not.toContain("const premiumCount = users.filter");
    expect(source).not.toContain("const blockedCount = users.filter");
    expect(source).not.toContain("const newUsersCount = users.filter");
  });

  it("blocks obvious last-admin demotion in the frontend while preserving backend source of truth", () => {
    const pageSource = readFileSync(usersManagementPagePath, "utf8");
    const hookSource = readFileSync(useUsersAdminPath, "utf8");

    expect(pageSource).toContain("queryKey: adminQueryKeys.userDashboardMetrics");
    expect(pageSource).toContain("queryFn: ({ signal }) => fetchAdminUserDashboardMetrics(signal)");
    expect(pageSource).toContain("const totalAdminCount = userMetrics?.adminUsers ?? null;");
    expect(pageSource).toContain("const cannotRevokeLastAdmin =");
    expect(pageSource).toContain("totalAdminCount === null || totalAdminCount <= 1");
    expect(pageSource).toContain(
      "isUserActionLocked ||\n                        busyUserId === openActionsUser.userId ||\n                        cannotRevokeLastAdmin"
    );
    expect(pageSource).toContain(
      "title={cannotRevokeLastAdmin ? ui.lastAdminProtected : undefined}"
    );
    expect(hookSource).toContain("import { getAdminErrorMessage }");
    expect(hookSource).toContain(
      "queryClient.invalidateQueries({ queryKey: adminQueryKeys.userDashboardMetrics })"
    );
    expect(hookSource).toContain(
      "getAdminErrorMessage(error, options?.errorMessage ?? text.errorLoadingUsers)"
    );
    expect(pageSource).not.toContain('fetchUsers({ role: "Admin", skip: 0, take: 1 }');
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

  it("guards users page private detail queries behind a restored session", () => {
    const source = readFileSync(usersManagementPagePath, "utf8");
    const hookSource = readFileSync(useUsersAdminPath, "utf8");
    const profileHookSource = readFileSync(useAdminUserProfilePath, "utf8");
    const detailSource = readFileSync(userDetailPagePath, "utf8");
    const inlineSource = readFileSync(userInlineAnalyticsPath, "utf8");

    expect(hookSource).toContain("hasSession: canManageRoles");
    expect(source).toContain("hasSession,");
    expect(source).toContain("enabled: hasSession && pageUserIds.length > 0");
    expect(source).toContain("enabled: hasSession && users.length > 0");
    expect(source).toContain(
      "const selectedUserProfile = useAdminUserProfile({ enabled: hasSession, userId: selectedUserId });"
    );
    expect(source).toContain("enabled: hasSession && Boolean(selectedUserId)");
    expect(source).toContain("enabled: hasSession && premiumPageUserIds.length > 0");
    expect(source).not.toContain("enabled: users.length > 0");
    expect(source).not.toContain("enabled: Boolean(selectedUserId)");
    expect(source).not.toContain("enabled: true,\n      staleTime: 30_000");

    expect(profileHookSource).toContain("enabled?: boolean;");
    expect(profileHookSource).toContain("const canLoadUser = enabled && Boolean(userId);");
    expect(profileHookSource).toContain("enabled: canLoadUser");
    expect(profileHookSource).toContain("const error = userQuery.error ?? analyticsQuery.error ?? null;");
    expect(profileHookSource).toContain("error,");
    expect(source).toContain("selectedUserProfile.hasError && !selectedUser");
    expect(source).toContain(
      "title={getAdminErrorMessage(selectedUserProfile.error, text.errorLoadingUsers)}"
    );
    expect(source).toContain("disabled={selectedUserProfile.isFetching}");
    expect(source).toContain(
      "void selectedUserProfile.refresh().catch(() => undefined)"
    );
    expect(profileHookSource).not.toContain("enabled: Boolean(userId)");
    expect(detailSource).toContain(
      'const canViewUserProfile = session?.user.roles.includes("Admin") ?? false;'
    );
    expect(detailSource).toContain("enabled: canViewUserProfile,");
    expect(detailSource).toContain(
      'ensureAdminSession(locale, router, { requiredRole: "Admin" });'
    );
    expect(detailSource).toContain("if (!canViewUserProfile || isLoading) {");
    expect(detailSource).toContain("disabled={!canViewUserProfile || isFetching}");
    expect(inlineSource).toContain(
      'const canViewUserProfile = session?.user.roles.includes("Admin") ?? false;'
    );
    expect(inlineSource).toContain("enabled: canViewUserProfile,");
    expect(inlineSource).toContain("if (!canViewUserProfile || isLoading) {");
    expect(inlineSource).toContain("disabled={!canViewUserProfile || isFetching}");
  });
});
