import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const roleManagementPagePath = fileURLToPath(
  new URL("./role-management-page.tsx", import.meta.url)
);
const roleManagementContentPath = fileURLToPath(
  new URL("./role-management-page.content.ts", import.meta.url)
);
const roleManagementStylesPath = fileURLToPath(
  new URL("./role-management-page.module.css", import.meta.url)
);
const usersManagementPagePath = fileURLToPath(
  new URL("./users-management-page.tsx", import.meta.url)
);
const usersManagementStylesPath = fileURLToPath(
  new URL("./users-management-page.module.css", import.meta.url)
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
const adminSidebarPath = fileURLToPath(new URL("./admin/admin-sidebar.tsx", import.meta.url));
const adminTopbarPath = fileURLToPath(new URL("./admin/admin-topbar.tsx", import.meta.url));
const adminChromeContentPath = fileURLToPath(
  new URL("./admin/admin-chrome.content.ts", import.meta.url)
);
const adminShellStylesPath = fileURLToPath(new URL("./admin/admin-shell.module.css", import.meta.url));
const localeErrorPagePath = fileURLToPath(new URL("../app/[locale]/error.tsx", import.meta.url));

describe("admin action hardening", () => {
  it("guards role management actions and surfaces sanitized backend errors", () => {
    const source = readFileSync(roleManagementPagePath, "utf8");
    const contentSource = readFileSync(roleManagementContentPath, "utf8");
    const stylesSource = readFileSync(roleManagementStylesPath, "utf8");

    expect(source).toContain('import {\n  getRoleManagementPageText,\n  type RoleManagementPageText,\n} from "@/components/role-management-page.content";');
    expect(source).toContain("const text = getRoleManagementPageText(locale);");
    expect(source).not.toContain("function getCopy(locale: Locale)");
    expect(source).not.toContain("const isRu = locale === \"ru\";");
    expect(source).toContain("import { getAdminErrorMessage }");
    expect(source).toContain("useAuthSession,");
    expect(source).toContain("const session = useAuthSession();");
    expect(source).toContain("const sessionRoles = session?.user.roles ?? [];");
    expect(source).toContain('const canManageRoles = sessionRoles.includes("Admin");');
    expect(source).toContain('ensureAdminSession(locale, router, { requiredRole: "Admin" });');
    expect(source).toContain("{!canManageRoles || isLoading ? (");
    expect(source).toContain("{canManageRoles ? (\n        <AdminCard title={text.searchTitle}");
    expect(source).toContain("enabled: canManageRoles");
    expect(source).toContain("const normalizedSearch = debouncedSearch.trim();");
    expect(source).toContain("enabled: canManageRoles && normalizedSearch.length >= 2");
    expect(contentSource).toContain('roleActionsAdminOnly: "Изменять роли может только Admin."');
    expect(contentSource).toContain('assignModeratorLabel: "Назначить Moderator пользователю"');
    expect(contentSource).toContain('revokeModeratorLabel: "Снять Moderator у пользователя"');
    expect(contentSource).toContain('searchHint: "Введите минимум 2 символа. Поиск обновится автоматически."');
    expect(contentSource).toContain('adminAlreadyPrivileged: "Уже Admin"');
    expect(contentSource).toContain('moderatorAlreadyPrivileged: "Уже Moderator"');
    expect(contentSource).toContain('eyebrow: "Контроль доступа"');
    expect(contentSource).toContain('adminOnly: "Только Admin"');
    expect(contentSource).toContain('adminsTitle: "Администраторы"');
    expect(contentSource).toContain('moderatorsTitle: "Модераторы"');
    expect(source).toContain("function assertCanManageRoles(): boolean");
    expect(source).toContain('setToast({ type: "error", message: text.roleActionsAdminOnly });');
    expect(source).toContain("useRef,");
    expect(source).toContain("const roleActionInFlightRef = useRef(false);");
    expect(source).toContain("function isRoleActionLocked(): boolean");
    expect(source).toContain("return roleActionInFlightRef.current || isSubmitting;");
    expect(source).toContain("async function refreshRoleQueries(userId?: string)");
    expect(source).toContain("await Promise.allSettled([\n      queryClient.invalidateQueries({");
    expect(source).not.toContain("await Promise.all([\n      queryClient.invalidateQueries({");
    expect(source).toContain(
      "if (!pendingAction || isRoleActionDisabled || isRoleActionLocked()) {\n      return;"
    );
    expect(source).toContain(
      "if (!assertCanManageRoles()) {\n      return;\n    }\n\n    roleActionInFlightRef.current = true;\n    setIsSubmitting(true);"
    );
    expect(source).toContain("roleActionInFlightRef.current = true;");
    expect(source).toContain("roleActionInFlightRef.current = false;");
    expect(source).toContain("if (!roleActionInFlightRef.current && !isSubmitting) {");
    expect(source).toContain(
      "function confirmAssignModerator(user: UserListItem) {\n    if (isRoleActionDisabled || isRoleActionLocked() || !assertCanManageRoles())"
    );
    expect(source).toContain(
      "function confirmRevokeModerator(user: UserListItem) {\n    if (isRoleActionDisabled || isRoleActionLocked() || !assertCanManageRoles())"
    );
    expect(source).toContain("getAdminErrorMessage(error, text.failed)");
    expect(source).toContain('import { clientLogger } from "@/lib/client-logger";');
    expect(source).toContain("function getRoleActionErrorDetails(error: unknown, targetUserId: string)");
    expect(source).toContain("targetUserId: shortIdentifier(targetUserId)");
    expect(source).toContain('errorName: error instanceof Error ? error.name : "UnknownError"');
    expect(source).toContain('"digest" in error');
    expect(source).toContain(
      'sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)'
    );
    expect(source).not.toContain("sanitizeSensitiveText(error.message, 160)");
    expect(source).toContain('clientLogger.warn(\n        "roles.action_failed",');
    expect(source).not.toContain('clientLogger.warn("roles.action_failed", { error');
    expect(source).toContain("USER_SEARCH_MAX_LENGTH,");
    expect(source).toContain("setSearch(event.target.value.slice(0, USER_SEARCH_MAX_LENGTH))");
    expect(source).toContain('type="search"');
    expect(source).toContain('autoComplete="off"');
    expect(source).toContain('aria-describedby="role-search-hint"');
    expect(source).toContain('<span id="role-search-hint" className={styles.hint}>');
    expect(source).toContain("{text.searchHint}");
    expect(source).toContain("maxLength={USER_SEARCH_MAX_LENGTH}");
    expect(source).toContain("const [adminsPage, setAdminsPage] = useState(0);");
    expect(source).toContain("skip: adminsPage * PAGE_SIZE");
    expect(source).toContain("skip: moderatorsPage * PAGE_SIZE");
    expect(source).toContain("queryKey: adminQueryKeys.usersRoot");
    expect(source).toContain("function RolePager(");
    expect(contentSource).toContain('previousPageLabel: "Предыдущая страница списка ролей"');
    expect(contentSource).toContain('nextPageLabel: "Следующая страница списка ролей"');
    expect(source).toContain('import { CaretDownIcon } from "@/components/admin/admin-icons";');
    expect(source).toContain("aria-label={text.previousPageLabel}");
    expect(source).toContain("aria-label={text.nextPageLabel}");
    expect(source).toContain("title={text.previousPageLabel}");
    expect(source).toContain("title={text.nextPageLabel}");
    expect(source).toContain(
      '<CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconPrevious}`} />'
    );
    expect(source).toContain(
      '<CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconNext}`} />'
    );
    expect(source).not.toContain("{text.previous}\n        </button>");
    expect(source).not.toContain("{text.next}\n        </button>");
    expect(stylesSource).toContain(".pagerButton {");
    expect(stylesSource).toContain(".pageIconPrevious {\n  transform: rotate(90deg);");
    expect(stylesSource).toContain(".pageIconNext {\n  transform: rotate(-90deg);");
    expect(stylesSource).toContain(
      ".pager {\n    flex-direction: column;\n    align-items: stretch;"
    );
    expect(stylesSource).toContain(".search {\n  display: grid;");
    expect(stylesSource).toContain("grid-template-columns: minmax(0, 1fr);");
    expect(stylesSource).not.toContain("grid-template-columns: minmax(14rem, 1fr) auto;");
    expect(stylesSource).toContain(".input:focus-visible,\n.button:focus-visible");
    expect(stylesSource).toContain("box-shadow: var(--focus-ring);");
    expect(stylesSource).toContain(".input:disabled {");
    expect(stylesSource).toContain("cursor: not-allowed;");
    expect(stylesSource).toContain("opacity: 0.62;");
    expect(stylesSource).not.toContain(".input:focus {");
    expect(stylesSource).toContain(".pageInfo {\n    width: 100%;");
    expect(stylesSource).toContain(".pagerActions {\n    justify-content: flex-start;");
    expect(stylesSource).toContain("width: 100%;");
    expect(stylesSource).toContain(".pagerButton {\n    flex: 0 0 auto;");
    expect(stylesSource).not.toContain("grid-template-columns: 1fr 1fr;\n    width: 100%;");
    expect(stylesSource).toContain(".userName {\n    overflow: visible;");
    expect(stylesSource).toContain("text-overflow: clip;");
    expect(stylesSource).toContain("white-space: normal;");
    expect(stylesSource).toContain("overflow-wrap: anywhere;");
    expect(source).toContain("sanitizeSensitiveText(getAdminUserDisplayName(user), 96)");
    expect(source).toContain("shortIdentifier(user.userId)");
    expect(source).toContain("sanitizeSensitiveText(role, 32)");
    expect(source).toContain("text: RoleManagementPageText;");
    expect(source).toContain("<UserRow key={user.userId} user={user} locale={locale} text={text} />");
    expect(source).toContain("<RolePager\n                text={text}");
    expect(source).toContain(
      "const isRoleDataFetching = isRoleRetryFetching || searchQuery.isFetching;"
    );
    expect(source).toContain("const isRoleActionDisabled = isSubmitting || isRoleDataFetching;");
    expect(source).toContain("disabled={!canManageRoles || isRoleActionDisabled}");
    expect(source).toContain(
      "aria-label={`${text.revokeModeratorLabel} ${userDisplayName(user)}`}"
    );
    expect(source).toContain('const isAdmin = user.roles.includes("Admin");');
    expect(source).toContain(
      "disabled={!canManageRoles || isAdmin || isModerator || isRoleActionDisabled}"
    );
    expect(source).toContain(
      "aria-label={`${text.assignModeratorLabel} ${userDisplayName(user)}`}"
    );
    expect(source).toContain("text.adminAlreadyPrivileged");
    expect(source).toContain("text.moderatorAlreadyPrivileged");
    expect(source).not.toContain('? "Moderator"');
    expect(stylesSource).toContain(".hint {");
    expect(stylesSource).toContain("line-height: 1.35;");
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
    const stylesSource = readFileSync(usersManagementStylesPath, "utf8");
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
    expect(source).toContain("const refreshSelectedUserProfileAfterAction = useCallback(");
    expect(source).toContain(
      "const [refreshResult] = await Promise.allSettled([selectedUserProfile.refresh()]);"
    );
    expect(source).toContain('clientLogger.warn("users.selected_profile_action_refresh_failed"');
    expect(source).toContain("const succeeded = await runUserAction(confirmationDialog.userId");
    expect(source).toContain("if (succeeded) {\n        confirmationDialog.afterSuccess?.();");
    expect(source).toContain(
      "if (succeeded) {\n        await refreshSelectedUserProfileAfterAction(userId);\n      }"
    );
    expect(source).toContain("[confirmationDialog, confirmationSubmitting, runUserAction]");
    expect(source).toContain("[refreshSelectedUserProfileAfterAction, runAction]");
    expect(source).not.toContain(
      "if (succeeded && selectedUserId === userId) {\n        await selectedUserProfile.refresh();\n      }"
    );
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
    expect(source).toContain(
      "aria-disabled={isUserActionLocked || busyUserId === openActionsUser.userId}"
    );
    expect(source).toContain(
      "isUserActionLocked || busyUserId === openActionsUser.userId ? -1 : undefined"
    );
    expect(source).toContain("event.preventDefault();\n                      return;");
    expect(stylesSource).toContain(".actionMenuLinkDisabled,");
    expect(stylesSource).toContain('.actionMenuLink[aria-disabled="true"]');
    expect(stylesSource).toContain("pointer-events: none;");
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
    expect(source).toContain("useCallback, useEffect, useId, useMemo, useRef, useState");
    expect(source).toContain("const walletDialogTitleId = useId();");
    expect(source).toContain("const walletDialogErrorId = useId();");
    expect(source).toContain("if (!canManageRoles || !walletDialog || walletDialogSubmitting) {");
    expect(source).toContain(
      "const reason = walletDialog.reason.trim().slice(0, USER_WALLET_REASON_MAX_LENGTH);"
    );
    expect(source).toContain('amount: event.target.value.replace(/\\D+/g, "").slice(0, 8)');
    expect(source).toContain("maxLength={8}");
    expect(source).toContain("reason: event.target.value.slice(0, USER_WALLET_REASON_MAX_LENGTH)");
    expect(source).toContain("maxLength={USER_WALLET_REASON_MAX_LENGTH}");
    expect(source).toContain("aria-labelledby={walletDialogTitleId}");
    expect(source).toContain("aria-describedby={walletDialog.error ? walletDialogErrorId : undefined}");
    expect(source).toContain('<h3 id={walletDialogTitleId} className={styles.walletDialogTitle}>');
    expect(source).toContain(
      '<p id={walletDialogErrorId} className={styles.walletError} role="alert">'
    );
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
    expect(source).not.toContain("aria-label={\n                  walletDialog.operation === \"credit\"");
    expect(source).not.toContain('<p className={styles.walletError}>{walletDialog.error}</p>');
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
    expect(hookSource).toContain("async function refreshUsersAfterAction(userId: string)");
    expect(hookSource).toContain("await Promise.allSettled([refreshUsersAfterAction(userId)]);");
    expect(hookSource).toContain("refreshUsers,");
    expect(hookSource).not.toContain(
      "const isLoading = usersQuery.isLoading || usersQuery.isFetching;"
    );
    expect(source).toContain("if (!canManageRoles) {");
    expect(source).toContain('<AdminStateCard\n          tone="info"\n          title={text.usersTitle}');
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
    expect(hookSource).toContain("await Promise.allSettled([");
    expect(hookSource).toContain(
      "queryClient.invalidateQueries({ queryKey: adminQueryKeys.userDashboardMetrics })"
    );
    expect(hookSource).not.toContain("await Promise.all([\n        queryClient.invalidateQueries({ queryKey: adminQueryKeys.userDetail(userId) })");
    expect(hookSource).toContain(
      "getAdminErrorMessage(error, options?.errorMessage ?? text.errorLoadingUsers)"
    );
    expect(pageSource).not.toContain('fetchUsers({ role: "Admin", skip: 0, take: 1 }');
  });

  it("guards logout confirmation against repeated submit", () => {
    const source = readFileSync(adminShellPath, "utf8");
    const sidebarSource = readFileSync(adminSidebarPath, "utf8");
    const topbarSource = readFileSync(adminTopbarPath, "utf8");
    const adminChromeContentSource = readFileSync(adminChromeContentPath, "utf8");
    const stylesSource = readFileSync(adminShellStylesPath, "utf8");

    expect(source).toContain("import { maskEmail, sanitizeSensitiveText }");
    expect(source).toContain("const safeSessionDisplayName = session?.user?.displayName?.trim()");
    expect(source).toContain("sanitizeSensitiveText(session.user.displayName, 96)");
    expect(source).toContain("const userName = safeSessionDisplayName || maskedSessionEmail;");
    expect(source).toContain('const userInitial = (userName || "A")[0].toUpperCase();');
    expect(source).toContain("const [isLoggingOut, setIsLoggingOut] = useState(false);");
    expect(source).toContain("const [isSidebarDrawerMode, setIsSidebarDrawerMode] = useState(false);");
    expect(source).toContain("const previousPathnameRef = useRef(pathname);");
    expect(source).toContain(
      "if (previousPathnameRef.current === pathname) {\n      return;\n    }\n\n    previousPathnameRef.current = pathname;\n    setSidebarOpen(false);"
    );
    expect(source).toContain("}, [pathname]);");
    expect(source).toContain('const media = window.matchMedia("(max-width: 860px)");');
    expect(source).toContain("setIsSidebarDrawerMode(isDrawerMode);");
    expect(source).toContain("if (!isDrawerMode) {\n        setSidebarOpen(false);\n      }");
    expect(source).toContain("media.addEventListener(\"change\", syncSidebarMode);");
    expect(source).toContain("media.removeEventListener(\"change\", syncSidebarMode);");
    expect(source).toContain(
      "if (!sidebarOpen || !isSidebarDrawerMode || typeof document === \"undefined\")"
    );
    expect(source).toContain("const previousOverflow = document.body.style.overflow;");
    expect(source).toContain('document.body.style.overflow = "hidden";');
    expect(source).toContain("document.body.style.overflow = previousOverflow;");
    expect(source).toContain("}, [isSidebarDrawerMode, sidebarOpen]);");
    expect(source).toContain("if (isLoggingOut) {\n      return;");
    expect(source).toContain("logoutDisabled={isLoggingOut}");
    expect(source).toContain("isDrawerMode={isSidebarDrawerMode}");
    expect(source).toContain("aria-hidden={isSidebarDrawerMode && sidebarOpen ? \"true\" : undefined}");
    expect(source).toContain("inert={isSidebarDrawerMode && sidebarOpen}");
    expect(topbarSource).toContain("const sidebarToggleLabel =");
    expect(topbarSource).toContain("const copy = useMemo(() => getAdminChromeCopy(locale), [locale]);");
    expect(adminChromeContentSource).toContain('sidebarToggleLabel: (sidebarOpen) =>');
    expect(adminChromeContentSource).toContain('sidebarOpen ? "Закрыть навигацию" : "Открыть навигацию"');
    expect(adminChromeContentSource).toContain('sidebarOpen ? "Close navigation" : "Open navigation"');
    expect(topbarSource).toContain("aria-label={sidebarToggleLabel}");
    expect(topbarSource).toContain("title={sidebarToggleLabel}");
    expect(source).toContain("isSubmitting={isLoggingOut}");
    expect(source).toContain("if (!isLoggingOut) {\n            setLogoutDialogOpen(false);");
    expect(sidebarSource).toContain("isDrawerMode: boolean;");
    expect(sidebarSource).toContain("const copy = useMemo(() => getAdminChromeCopy(locale), [locale]);");
    expect(adminChromeContentSource).toContain('navigationLabel: "Навигация админ-панели"');
    expect(adminChromeContentSource).toContain('navigationLabel: "Admin navigation"');
    expect(sidebarSource).toContain("aria-label={navigationLabel}");
    expect(sidebarSource).toContain("aria-hidden={isDrawerMode && !isOpen ? \"true\" : undefined}");
    expect(sidebarSource).toContain("inert={isDrawerMode && !isOpen}");
    expect(sidebarSource).toContain('<nav className={styles.nav} aria-label={navigationLabel}>');
    expect(sidebarSource).toContain("logoutDisabled?: boolean;");
    expect(sidebarSource).toContain("logoutDisabled = false,");
    expect(sidebarSource).toContain("disabled={logoutDisabled}");
    expect(sidebarSource).toContain('import { useMemo } from "react";');
    expect(sidebarSource).toContain(
      "const navItems = useMemo(() => getAdminNavItems(locale, roles), [locale, roles]);"
    );
    expect(sidebarSource).toContain(
      "const navSections = useMemo(() => buildNavSections(navItems, locale), [locale, navItems]);"
    );
    expect(stylesSource).toContain(".logoutButton:disabled");
    expect(stylesSource).toContain("cursor: not-allowed;");
    expect(stylesSource).toContain("pointer-events: none;");
    expect(stylesSource).toContain("pointer-events: auto;");
    expect(source).not.toContain(
      "const userName = session?.user?.displayName || maskedSessionEmail;"
    );
    expect(source).not.toContain("session?.user?.displayName ||\n    maskedSessionEmail");
    expect(sidebarSource).not.toContain('locale === "ru" ? "Навигация админ-панели" : "Admin navigation"');
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
    expect(profileHookSource).toContain(
      "const error = userQuery.error ?? analyticsQuery.error ?? null;"
    );
    expect(profileHookSource).toContain("error,");
    expect(source).toContain("selectedUserProfile.hasError && !selectedUser");
    expect(source).toContain(
      "title={getAdminErrorMessage(selectedUserProfile.error, text.errorLoadingUsers)}"
    );
    expect(source).toContain("disabled={selectedUserProfile.isFetching}");
    expect(source).toContain("function requestSelectedUserProfileRetry()");
    expect(source).toContain(
      "if (!selectedUserId || selectedUserProfile.isFetching) {\n      return;\n    }"
    );
    expect(source).toContain("onClick={requestSelectedUserProfileRetry}");
    expect(source).toContain("void selectedUserProfile.refresh().catch(() => undefined)");
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
