import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import { readUsersManagementPageLibrarySource } from "@/components/users-management-page.test-source";

const roleManagementPagePath = fileURLToPath(
  new URL("./role-management-page.tsx", import.meta.url)
);
const roleManagementContentPath = fileURLToPath(
  new URL("./role-management-page.content.ts", import.meta.url)
);
const roleManagementStylesPath = fileURLToPath(
  new URL("./role-management-page.module.css", import.meta.url)
);
const userDetailPagePath = fileURLToPath(new URL("./users/user-detail-page.tsx", import.meta.url));
const userAccessControlPanelPath = fileURLToPath(
  new URL("./users/user-access-control-panel.tsx", import.meta.url)
);
const userWalletPanelPath = fileURLToPath(
  new URL("./users/user-wallet-panel.tsx", import.meta.url)
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
const adminShellStylesPath = fileURLToPath(
  new URL("./admin/admin-shell.module.css", import.meta.url)
);
const localeErrorPagePath = fileURLToPath(new URL("../app/[locale]/error.tsx", import.meta.url));

describe("admin action hardening", () => {
  it("guards role management actions and surfaces sanitized backend errors", () => {
    const source = readFileSync(roleManagementPagePath, "utf8");
    const contentSource = readFileSync(roleManagementContentPath, "utf8");
    const stylesSource = readFileSync(roleManagementStylesPath, "utf8");

    expect(source).toContain(
      'import {\n  getRoleManagementPageText,\n  type RoleManagementPageText,\n} from "@/components/role-management-page.content";'
    );
    expect(source).toContain("const text = getRoleManagementPageText(locale);");
    expect(source).not.toContain("function getCopy(locale: Locale)");
    expect(source).not.toContain('const isRu = locale === "ru";');
    expect(source).toContain("import { getAdminErrorMessage }");
    expect(source).toContain("useAuthSession,");
    expect(source).toContain("const session = useAuthSession();");
    expect(source).toContain("const sessionRoles = session?.user.roles ?? [];");
    expect(source).toContain('const canManageRoles = sessionRoles.includes("Admin");');
    expect(source).toContain('ensureAdminSession(locale, router, { requiredRole: "Admin" });');
    expect(source).toContain("{!canManageRoles || isLoading ? (");
    expect(source).toContain("className={styles.commandArea}");
    expect(source).toContain("className={styles.directory}");
    expect(source).toContain("function focusSearch()");
    expect(source).toContain("searchInputRef.current?.focus();");
    expect(source).toContain("className={styles.roleGroup}");
    expect(source).toContain("enabled: canManageRoles");
    expect(source).toContain("const normalizedSearch = debouncedSearch.trim();");
    expect(source).toContain(
      "enabled: canManageRoles && isSearchActive && !isSearchPending && normalizedSearch.length >= 2"
    );
    expect(contentSource).toContain(
      'roleActionsAdminOnly: "Изменять роли может только администратор."'
    );
    expect(contentSource).toContain('assignModeratorLabel: "Назначить модератора пользователю"');
    expect(contentSource).toContain('revokeModeratorLabel: "Снять модератора у пользователя"');
    expect(contentSource).toContain('searchMinimumCharacters: "Введите минимум 2 символа."');
    expect(contentSource).toContain('clearSearch: "Очистить поиск"');
    expect(contentSource).toContain('searchPlaceholder: "Email, ID или имя пользователя"');
    expect(contentSource).toContain(
      'confirmAssignDescription: "Пользователь получит доступ к разрешенным разделам модерации."'
    );
    expect(contentSource).toContain(
      '"Пользователь потеряет доступ модератора. Действие будет записано в журнал аудита."'
    );
    expect(contentSource.slice(0, contentSource.indexOf("  en: {"))).not.toContain("audit log");
    expect(contentSource.slice(0, contentSource.indexOf("  en: {"))).not.toContain(
      "moderator доступ"
    );
    expect(contentSource.slice(0, contentSource.indexOf("  en: {"))).not.toMatch(
      /:\s*"[^"]*Moderator/
    );
    expect(contentSource).toContain('adminsTitle: "Администраторы"');
    expect(contentSource).toContain('adminRole: "Администратор"');
    expect(contentSource).toContain('moderatorsTitle: "Модераторы"');
    expect(contentSource).toContain('moderatorRole: "Модератор"');
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
    expect(source).toContain(
      "function getRoleActionErrorDetails(error: unknown, targetUserId: string)"
    );
    expect(source).toContain("targetUserId: shortIdentifier(targetUserId)");
    expect(source).toContain('errorName: error instanceof Error ? error.name : "UnknownError"');
    expect(source).toContain('"digest" in error');
    expect(source).toContain(
      'sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)'
    );
    expect(source).not.toContain("sanitizeSensitiveText(error.message, 160)");
    expect(source).toContain('clientLogger.warn(\n        "roles.action_failed",');
    expect(source).not.toContain('clientLogger.warn("roles.action_failed", { error');
    expect(source).toContain("USER_SEARCH_MAX_LENGTH");
    expect(source).toContain("function setSearchContext(nextSearch: string)");
    expect(source).toContain("setSearch(nextSearch.slice(0, USER_SEARCH_MAX_LENGTH));");
    expect(source).toContain('type="search"');
    expect(source).toContain('autoComplete="off"');
    expect(source).toContain(
      '<label className={styles.visuallyHidden} htmlFor="role-user-search">'
    );
    expect(source).toContain('id="role-user-search"');
    expect(source).toContain(
      'aria-describedby={searchStatusMessage ? "role-search-status" : undefined}'
    );
    expect(source).toContain('id="role-search-status"');
    expect(source).toContain("text.searchMinimumCharacters");
    expect(source).toContain("const searchStatusMessage =");
    expect(source).toContain("const isSearchLoading =");
    expect(source).toContain('role="status"');
    expect(source).toContain('aria-busy={isSearchLoading ? "true" : undefined}');
    expect(source).toContain("maxLength={USER_SEARCH_MAX_LENGTH}");
    expect(source).toContain("const [adminsPage, setAdminsPage] = useState(0);");
    expect(source).toContain("skip: adminsPage * PAGE_SIZE");
    expect(source).toContain("skip: moderatorsPage * PAGE_SIZE");
    expect(source).toContain("queryKey: adminQueryKeys.usersRoot");
    expect(source).toContain("function RolePager(");
    expect(source).toContain("if (pageIndex === 0 && !hasMore && totalCount <= pageSize) {");
    expect(contentSource).toContain('previousPageLabel: "Предыдущая страница"');
    expect(contentSource).toContain('nextPageLabel: "Следующая страница"');
    expect(source).toContain("CaretDownIcon,");
    expect(source).toContain("aria-label={text.previousPageLabel}");
    expect(source).toContain("aria-label={text.nextPageLabel}");
    expect(source).toContain("label: string;");
    expect(source).toContain("<nav className={styles.pager} aria-label={label}>");
    expect(source).toContain(
      "<CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconPrevious}`} />"
    );
    expect(source).toContain(
      "<CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconNext}`} />"
    );
    expect(source).not.toContain("{text.previous}\n        </button>");
    expect(source).not.toContain("{text.next}\n        </button>");
    expect(stylesSource).toContain(".pagerButton {");
    expect(stylesSource).toContain(".pageIconPrevious {\n  transform: rotate(90deg);");
    expect(stylesSource).toContain(".pageIconNext {\n  transform: rotate(-90deg);");
    expect(stylesSource).toContain("container-type: inline-size;");
    expect(stylesSource).toContain("@container (max-width: 56rem)");
    expect(stylesSource).toContain(".commandArea {");
    expect(stylesSource).toContain(".searchControl {");
    expect(stylesSource).toContain(".input:focus-visible,\n.userMain:focus-visible");
    expect(stylesSource).toContain("box-shadow: var(--focus-ring);");
    expect(stylesSource).toContain(".input:disabled {");
    expect(stylesSource).toContain("cursor: not-allowed;");
    expect(stylesSource).toContain("opacity: 0.62;");
    expect(stylesSource).not.toContain(".input:focus {");
    expect(stylesSource).toContain(".userName {\n    overflow: visible;");
    expect(stylesSource).toContain("text-overflow: clip;");
    expect(stylesSource).toContain("white-space: normal;");
    expect(stylesSource).toContain("overflow-wrap: anywhere;");
    expect(source).toContain("sanitizeSensitiveText(getAdminUserDisplayName(user), 96)");
    expect(source).toContain("shortIdentifier(user.userId)");
    expect(source).toContain("text: RoleManagementPageText;");
    expect(source).toContain(
      "<UserRow key={user.userId} user={user} locale={locale} text={text} />"
    );
    expect(source).toContain("<RolePager");
    expect(source).toContain("const isRoleActionDisabled = isSubmitting;");
    expect(source).not.toContain("const isRoleDataFetching");
    expect(source).toContain("disabled={!canManageRoles || isRoleActionDisabled}");
    expect(source).toContain(
      "aria-label={`${text.revokeModeratorLabel} ${userDisplayName(user)}`}"
    );
    expect(source).toContain(
      "function getExistingManagedRole(user: UserListItem, text: RoleManagementPageText)"
    );
    expect(source).toContain('if (user.roles.includes("Admin"))');
    expect(source).toContain('if (user.roles.includes("Moderator"))');
    expect(source).toContain("const existingManagedRole = getExistingManagedRole(user, text);");
    expect(source).toContain("<span className={styles.existingRole}>{existingManagedRole}</span>");
    expect(source).not.toContain("showSearchDetails");
    expect(source).not.toContain("function UserRoles");
    expect(source).not.toContain("formatDateTime(user.createdAtUtc, locale)");
    expect(source).not.toContain("sanitizeSensitiveText(role, 32)");
    expect(stylesSource).toContain(".existingRole {");
    expect(stylesSource).toContain("text-align: end;");
    expect(source).toContain(
      "aria-label={`${text.assignModeratorLabel} ${userDisplayName(user)}`}"
    );
    expect(source).not.toContain("className={styles.profileAction}");
    expect(source).toContain("text.openUserProfile");
    expect(source).not.toContain(
      "function getRoleLabel(role: string, text: RoleManagementPageText)"
    );
    expect(source).toContain("return text.adminRole;");
    expect(source).toContain("return text.moderatorRole;");
    expect(source).not.toContain('? "Moderator"');
    expect(stylesSource).toContain(".searchStatus {");
    expect(stylesSource).toContain("line-height: 1.4;");
    expect(stylesSource).toContain("overflow-wrap: anywhere;");
    expect(stylesSource).toContain(".userAction button {\n    width: 100%;");
    expect(source).not.toContain("{user.userId} / {text.created}");
    expect(source).not.toContain("{role}\n        </AdminBadge>");
    expect(source).not.toContain("setSearch(event.target.value)");
    expect(source).not.toContain("maxLength={100}");
    expect(source).not.toContain(
      '} catch {\n      setToast({ type: "error", message: text.failed });'
    );
  });

  it("guards users confirmation actions against repeated submit", () => {
    const accessSource = readFileSync(userAccessControlPanelPath, "utf8");
    const walletSource = readFileSync(userWalletPanelPath, "utf8");

    expect(accessSource).toContain("if (isSubmitting) {\n      return;");
    expect(accessSource).toContain("if (!pendingAction || isSubmitting) {\n      return;");
    expect(accessSource).toContain("setIsSubmitting(true);");
    expect(accessSource).toContain("} finally {\n      setIsSubmitting(false);");
    expect(accessSource).toContain("<ConfirmationDialog");
    expect(accessSource).toContain("isSubmitting={isSubmitting}");
    expect(accessSource).toContain(
      "{feedback ? <AdminStateCard tone={feedback.tone} title={feedback.message} /> : null}"
    );
    expect(accessSource).toContain("if (!isSubmitting) {\n            setPendingAction(null);");
    expect(walletSource).toContain(
      "if (!canAdjustWallet || !pendingAdjustment || isSubmitting) {\n      return;"
    );
    expect(walletSource).toContain(
      "const isWalletFormLocked = isSubmitting || isWalletConfirmationOpen;"
    );
    expect(walletSource).toContain("<ConfirmationDialog");
    expect(walletSource).toContain("isSubmitting={isSubmitting}");
    expect(walletSource).toContain("if (!isSubmitting) {\n            setPendingAdjustment(null);");
  });

  it("keeps users financial and destructive controls admin-only in the UI layer", () => {
    const listSource = readUsersManagementPageLibrarySource();
    const detailSource = readFileSync(userDetailPagePath, "utf8");
    const accessSource = readFileSync(userAccessControlPanelPath, "utf8");
    const walletSource = readFileSync(userWalletPanelPath, "utf8");

    expect(detailSource).toContain(
      'const canViewUserProfile = session?.user.roles.includes("Admin") ?? false;'
    );
    expect(detailSource).toContain("enabled: canViewUserProfile,");
    expect(detailSource).toContain("if (!canViewUserProfile || isLoading) {");
    expect(detailSource).toContain("canAdjustWallet={canViewUserProfile}");
    expect(detailSource).toContain('{activeTab === "access" ? (');
    expect(accessSource).toContain("await setActive(user.userId, !user.isActive);");
    expect(accessSource).toContain("const updatedSummary = await revokePremium(");
    expect(accessSource).toContain("normalizedPremiumRevokeReason");
    expect(accessSource).toContain('latestEligibility.kind !== "recovery-pending"');
    expect(accessSource).toContain("fetchAdminEconomyUserSubscriptionSummary(user.userId, signal)");
    expect(accessSource).toContain('premiumEligibility.kind === "cancellable"');
    expect(accessSource).toContain('premiumEligibility.kind === "recovery-pending"');
    expect(accessSource).toContain("await deleteAdminUser(user.userId);");
    expect(accessSource).toContain("<ConfirmationDialog");
    expect(walletSource).toContain("canAdjustWallet &&");
    expect(walletSource).toContain("{canAdjustWallet ? (");
    expect(listSource).not.toContain("adjustAdminUserWallet");
    expect(listSource).not.toContain("deleteAdminUser");
    expect(listSource).not.toContain("revokePremium");
    expect(listSource).not.toContain("setActive(");
  });

  it("keeps wallet adjustment dialog recoverable after backend failures", () => {
    const source = readFileSync(userWalletPanelPath, "utf8");

    expect(source).toContain("USER_WALLET_REASON_MAX_LENGTH,");
    expect(source).toContain(
      "const normalizedReason = reason.trim().slice(0, USER_WALLET_REASON_MAX_LENGTH);"
    );
    expect(source).toContain('event.target.value.replace(/\\D+/g, "").slice(0, 8)');
    expect(source).toContain("maxLength={8}");
    expect(source).toContain("event.target.value.slice(0, USER_WALLET_REASON_MAX_LENGTH)");
    expect(source).toContain("maxLength={USER_WALLET_REASON_MAX_LENGTH}");
    expect(source).toContain("const isWalletConfirmationOpen = pendingAdjustment !== null;");
    expect(source).toContain(
      "const isWalletFormLocked = isSubmitting || isWalletConfirmationOpen;"
    );
    expect(source).toContain("setPendingAdjustment({");
    expect(source).toContain("setIsSubmitting(true);");
    expect(source).toContain("await adjustAdminUserWallet(");
    expect(source).toContain("setPendingAdjustment(null);");
    expect(source).toContain('setReason("");');
    expect(source).toContain("message: getAdminErrorMessage(error, text.walletOperationError)");
    expect(source).toContain("} finally {\n      setIsSubmitting(false);");
    expect(source).toContain("<ConfirmationDialog");
    expect(source).toContain("open={canAdjustWallet && isWalletConfirmationOpen}");
    expect(source).not.toContain("reason: event.target.value,");
    expect(source).not.toContain("const normalizedReason = reason.trim();");
  });

  it("keeps previous users page visible during background refetches", () => {
    const source = readUsersManagementPageLibrarySource();
    const hookSource = readFileSync(useUsersAdminPath, "utf8");

    expect(source).toContain("USER_SEARCH_MAX_LENGTH");
    expect(source).toContain("setSearch(event.target.value.slice(0, USER_SEARCH_MAX_LENGTH));");
    expect(source).toContain("maxLength={USER_SEARCH_MAX_LENGTH}");
    expect(hookSource).toContain("const isLoading = usersQuery.isLoading;");
    expect(hookSource).toContain("const isFetching = usersQuery.isFetching;");
    expect(hookSource).toContain("isFetching,");
    expect(hookSource).toContain("async function refreshUsers()");
    expect(hookSource).toContain(
      "if (!canManageRoles) {\n      return usersQuery;\n    }\n\n    const refreshedUsers = await usersQuery.refetch();"
    );
    expect(hookSource).toContain("refreshUsers,");
    expect(hookSource).not.toContain(
      "const isLoading = usersQuery.isLoading || usersQuery.isFetching;"
    );
    expect(source).toContain("if (!canManageRoles) {");
    expect(source).toContain("<UsersManagementAccessState ui={ui} />");
    expect(source).toContain("<UsersManagementLoadingState ui={ui} />");
    expect(source).toContain("isFetching: isUsersFetching,");
    expect(source).toContain("refreshUsers,");
    expect(source).toContain("onClick={() => void refreshUsers().catch(() => undefined)}");
    expect(source).toContain("disabled={isUsersFetching}");
    expect(source).toContain('aria-busy={isUsersFetching ? "true" : undefined}');
    expect(source).toContain("disabled={currentPage <= 1 || isUsersFetching}");
    expect(source).toContain("disabled={currentPage >= totalPages || isUsersFetching}");
    expect(source).not.toContain("setSearch(event.target.value);");
  });

  it("routes users sorting through backend query params", () => {
    const listSource = readUsersManagementPageLibrarySource();
    const hookSource = readFileSync(useUsersAdminPath, "utf8");

    expect(listSource).toContain("const PAGE_SIZE = 24;");
    expect(listSource).toContain(
      'const [sortMode, setSortMode] = useState<UserSortMode>("created_desc");'
    );
    expect(listSource).toContain("sort: sortMode,");
    expect(listSource).toContain("setSortMode={setSortMode}");
    expect(listSource).toContain("sortMode={sortMode}");
    expect(hookSource).toContain("queryKey: adminQueryKeys.users(usersQueryParams)");
    expect(hookSource).toContain("fetchUsers(usersQueryParams, signal)");
    expect(listSource).not.toContain("fetchUserRowEnrichment");
    expect(listSource).not.toContain("userRowAnalytics");
    expect(listSource).not.toContain("economyUserSubscriptionSummaries");
    expect(listSource).not.toContain("fetchAdminUserAnalytics");
  });

  it("sources users page summary cards from backend aggregate metrics", () => {
    const source = readUsersManagementPageLibrarySource();

    expect(source).toContain("fetchAdminUserDashboardMetrics(signal)");
    expect(source).toContain("AdminUserDashboardMetrics");
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
    const listSource = readUsersManagementPageLibrarySource();
    const accessSource = readFileSync(userAccessControlPanelPath, "utf8");

    expect(accessSource).toContain("queryKey: adminQueryKeys.userDashboardMetrics");
    expect(accessSource).toContain(
      "queryFn: ({ signal }) => fetchAdminUserDashboardMetrics(signal)"
    );
    expect(accessSource).toContain("const isLastAdmin =");
    expect(accessSource).toContain("const isAdminCountCheckPending =");
    expect(accessSource).toContain("const isAdminCountCheckFailed =");
    expect(accessSource).toContain("dashboardMetricsQuery.data?.adminUsers !== undefined");
    expect(accessSource).toContain("dashboardMetricsQuery.data.adminUsers <= 1");
    expect(accessSource).toContain(
      "(isLastAdmin || isAdminCountCheckPending || isAdminCountCheckFailed);"
    );
    expect(accessSource).toContain("disabled={isSubmitting || isProtected}");
    expect(accessSource).toContain("title={isProtected ? adminProtectionHint : undefined}");
    expect(listSource).not.toContain('fetchUsers({ role: "Admin", skip: 0, take: 1 }');
    expect(listSource).not.toContain("cannotRevokeLastAdmin");
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
    expect(source).toContain(
      "const [isSidebarDrawerMode, setIsSidebarDrawerMode] = useState(false);"
    );
    expect(source).toContain("const previousPathnameRef = useRef(pathname);");
    expect(source).toContain(
      "if (previousPathnameRef.current === pathname) {\n      return;\n    }\n\n    previousPathnameRef.current = pathname;\n    setSidebarOpen(false);"
    );
    expect(source).toContain("}, [pathname]);");
    expect(source).toContain('const media = window.matchMedia("(max-width: 860px)");');
    expect(source).toContain("setIsSidebarDrawerMode(isDrawerMode);");
    expect(source).toContain("if (!isDrawerMode) {\n        setSidebarOpen(false);\n      }");
    expect(source).toContain('media.addEventListener("change", syncSidebarMode);');
    expect(source).toContain('media.removeEventListener("change", syncSidebarMode);');
    expect(source).toContain(
      'if (!sidebarOpen || !isSidebarDrawerMode || typeof document === "undefined")'
    );
    expect(source).toContain("const previousOverflow = document.body.style.overflow;");
    expect(source).toContain('document.body.style.overflow = "hidden";');
    expect(source).toContain("document.body.style.overflow = previousOverflow;");
    expect(source).toContain("}, [isSidebarDrawerMode, sidebarOpen]);");
    expect(source).toContain("if (isLoggingOut) {\n      return;");
    expect(source).toContain("logoutDisabled={isLoggingOut}");
    expect(source).toContain("isDrawerMode={isSidebarDrawerMode}");
    expect(source).toContain(
      'aria-hidden={isSidebarDrawerMode && sidebarOpen ? "true" : undefined}'
    );
    expect(source).toContain("inert={isSidebarDrawerMode && sidebarOpen}");
    expect(topbarSource).toContain("const sidebarToggleLabel =");
    expect(topbarSource).toContain(
      "const copy = useMemo(() => getAdminChromeCopy(locale), [locale]);"
    );
    expect(adminChromeContentSource).toContain("sidebarToggleLabel: (sidebarOpen) =>");
    expect(adminChromeContentSource).toContain(
      'sidebarOpen ? "Закрыть навигацию" : "Открыть навигацию"'
    );
    expect(adminChromeContentSource).toContain(
      'sidebarOpen ? "Close navigation" : "Open navigation"'
    );
    expect(topbarSource).toContain("aria-label={sidebarToggleLabel}");
    expect(topbarSource).toContain("title={sidebarToggleLabel}");
    expect(source).toContain("isSubmitting={isLoggingOut}");
    expect(source).toContain("if (!isLoggingOut) {\n            setLogoutDialogOpen(false);");
    expect(sidebarSource).toContain("isDrawerMode: boolean;");
    expect(sidebarSource).toContain(
      "const copy = useMemo(() => getAdminChromeCopy(locale), [locale]);"
    );
    expect(adminChromeContentSource).toContain('navigationLabel: "Навигация админ-панели"');
    expect(adminChromeContentSource).toContain('navigationLabel: "Admin navigation"');
    expect(adminChromeContentSource).toContain('brandTitle: "PetMagic Admin"');
    expect(sidebarSource).toContain("const brandTitle = copy.sidebar.brandTitle;");
    expect(sidebarSource).toContain("<span className={styles.brandName}>{brandTitle}</span>");
    expect(sidebarSource).not.toContain(">PetMagic Admin</span>");
    expect(sidebarSource).toContain("aria-label={navigationLabel}");
    expect(sidebarSource).toContain('aria-hidden={isDrawerMode && !isOpen ? "true" : undefined}');
    expect(sidebarSource).toContain("inert={isDrawerMode && !isOpen}");
    expect(sidebarSource).toContain("<nav className={styles.nav} aria-label={navigationLabel}>");
    expect(sidebarSource).toContain("logoutDisabled?: boolean;");
    expect(sidebarSource).toContain("logoutDisabled = false,");
    expect(sidebarSource).toContain("disabled={logoutDisabled}");
    expect(sidebarSource).toContain('import { useMemo, useState, type RefObject } from "react";');
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
    expect(sidebarSource).not.toContain(
      'locale === "ru" ? "Навигация админ-панели" : "Admin navigation"'
    );
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
    const listSource = readUsersManagementPageLibrarySource();
    const hookSource = readFileSync(useUsersAdminPath, "utf8");
    const profileHookSource = readFileSync(useAdminUserProfilePath, "utf8");
    const detailSource = readFileSync(userDetailPagePath, "utf8");

    expect(hookSource).toContain(
      'const canManageRoles = session?.user.roles.includes("Admin") ?? false;'
    );
    expect(hookSource).toContain("enabled: canManageRoles,");
    expect(hookSource).toContain("hasSession: canManageRoles");
    expect(listSource).toContain("hasSession,");
    expect(listSource).toContain("enabled: hasSession,");
    expect(listSource).not.toContain("useAdminUserProfile");
    expect(listSource).not.toContain("fetchAdminUserAnalytics");
    expect(listSource).not.toContain("fetchAdminUserPet");

    expect(profileHookSource).toContain("enabled?: boolean;");
    expect(profileHookSource).toContain("const canLoadUser = enabled && Boolean(userId);");
    expect(profileHookSource).toContain("enabled: canLoadUser");
    expect(profileHookSource).toContain(
      "const error = userQuery.error ?? analyticsQuery.error ?? null;"
    );
    expect(profileHookSource).toContain("error,");
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
    expect(detailSource).toContain(
      'enabled: canViewUserProfile && activeTab === "content" && Boolean(userId),'
    );
    expect(detailSource).toContain('{activeTab === "support" ? (');
    expect(detailSource).toContain("<UserSupportTicketsPanel");
    expect(detailSource).not.toContain("UserInlineAnalytics");
  });
});
