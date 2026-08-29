import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import { readUsersManagementPageLibrarySource } from "@/components/users-management-page.test-source";

const usersAdminHookPath = fileURLToPath(new URL("./use-users-admin.ts", import.meta.url));
const usersChromePath = fileURLToPath(
  new URL("../users-management-page.chrome.tsx", import.meta.url)
);
const usersFiltersPath = fileURLToPath(
  new URL("../users-management-users-card.filters.tsx", import.meta.url)
);
const userAccessPanelPath = fileURLToPath(
  new URL("./user-access-control-panel.tsx", import.meta.url)
);
const userDetailContentPath = fileURLToPath(
  new URL("./user-detail-page.content.ts", import.meta.url)
);
const userWalletPanelPath = fileURLToPath(new URL("./user-wallet-panel.tsx", import.meta.url));
const userWalletStylesPath = fileURLToPath(
  new URL("./user-wallet-panel.module.css", import.meta.url)
);
const userSupportTicketsPanelPath = fileURLToPath(
  new URL("./user-support-tickets-panel.tsx", import.meta.url)
);
const apiClientPath = fileURLToPath(
  new URL("../../lib/api-client.admin-users.ts", import.meta.url)
);

describe("users admin action hardening", () => {
  it("keeps the registry hook lightweight and free of mutation actions", () => {
    const source = readFileSync(usersAdminHookPath, "utf8");

    expect(source).toContain('import { keepPreviousData, useQuery } from "@tanstack/react-query";');
    expect(source).toContain("queryKey: adminQueryKeys.users(usersQueryParams),");
    expect(source).toContain("queryFn: ({ signal }) => fetchUsers(usersQueryParams, signal),");
    expect(source).toContain("enabled: canManageRoles,");
    expect(source).toContain("placeholderData: keepPreviousData,");
    expect(source).toContain('ensureAdminSession(locale, router, { requiredRole: "Admin" });');

    for (const mutationConcern of [
      "useQueryClient",
      "useRef",
      "useState",
      "runAction",
      "busyUserId",
      "actionInFlightUserIdRef",
      "refreshUsersAfterAction",
      "clientLogger",
      "assignRole",
      "revokeRole",
      "revokePremium",
      "setActive",
      "deleteAdminUser",
      "adjustAdminUserWallet",
    ]) {
      expect(source).not.toContain(mutationConcern);
    }
  });

  it("keeps manual users retry strict so retry errors still surface in the page state", () => {
    const source = readFileSync(usersAdminHookPath, "utf8");

    expect(source).toContain("async function refreshUsers()");
    expect(source).toContain("const refreshedUsers = await usersQuery.refetch();");
    expect(source).toContain(
      "if (refreshedUsers.isError) {\n      throw refreshedUsers.error;\n    }"
    );
  });

  it("keeps the previous registry visible while filters or pages refresh", () => {
    const source = readFileSync(usersAdminHookPath, "utf8");
    const pageSource = readUsersManagementPageLibrarySource();

    expect(source).toContain(
      "const isRefreshing = usersQuery.isFetching && usersQuery.isPlaceholderData;"
    );
    expect(source).toContain("const visibleUsersPage = usersQuery.data;");
    expect(source).not.toContain(
      "const visibleUsersPage = usersQuery.isPlaceholderData ? undefined : usersQuery.data;"
    );
    expect(source).toContain("users: visibleUsersPage?.items ?? []");
    expect(source).toContain("usersPage: visibleUsersPage ?? {");
    expect(pageSource).toContain("isRefreshing: isUsersRefreshing,");
    expect(pageSource).toContain("users={users}");
    expect(pageSource).toContain(
      "const isInitialRefresh = isUsersRefreshing && !hasUsers && !error;"
    );
    expect(pageSource).toContain("{isUsersRefreshing && hasUsers ? (");
    expect(pageSource).toContain("{!error && !isUsersRefreshing && !hasUsers ? (");
    expect(pageSource).toContain("{hasUsers || hasRecoverablePagination ? (");
    expect(pageSource).not.toContain("pageUsers");
  });

  it("resets only the registry page for search and list filters, while the period stays in KPIs", () => {
    const filtersSource = readFileSync(usersFiltersPath, "utf8");
    const chromeSource = readFileSync(usersChromePath, "utf8");

    expect(filtersSource.match(/resetUsersPage\(\);/g) ?? []).toHaveLength(11);
    expect(filtersSource).toContain("setStatusFilter(value as StatusFilter);");
    expect(filtersSource).toContain("const hasResettableControls =");
    expect(filtersSource).toContain("const activeFilters: Array<{");
    expect(filtersSource).toContain("className={styles.clearSearchButton}");
    expect(filtersSource).toContain("aria-label={ui.clearSearch}");
    expect(filtersSource).not.toContain("ActivityFilter");
    expect(filtersSource).not.toContain("RangeDays");
    expect(filtersSource).not.toContain("setRangeDays");
    expect(chromeSource).toContain("setRangeDays(Number.parseInt(value, 10) as RangeDays)");
    expect(chromeSource).toContain("ariaLabel={ui.periodLabel}");
  });

  it("keeps access mutations behind a confirmation and protects the last administrator", () => {
    const accessSource = readFileSync(userAccessPanelPath, "utf8");
    const detailContentSource = readFileSync(userDetailContentPath, "utf8");

    expect(accessSource).toContain("type AccessAction =");
    expect(accessSource).toContain("const [pendingAction, setPendingAction]");
    expect(accessSource).toContain("if (isSubmitting) {");
    expect(accessSource).toContain("if (!pendingAction || isSubmitting) {");
    expect(accessSource).toContain("<ConfirmationDialog");
    expect(accessSource).toContain("open={pendingAction !== null}");
    expect(accessSource).toContain("isSubmitting={isSubmitting}");
    expect(accessSource).toContain('enabled: user.roles.includes("Admin"),');
    expect(accessSource).toContain("dashboardMetricsQuery.data.adminUsers <= 1");
    expect(accessSource).toContain("const isAdminCountCheckPending =");
    expect(accessSource).toContain("const isAdminCountCheckFailed =");
    expect(accessSource).toContain(
      "const isBlockProtected = user.isActive && isAdminRoleMutationProtected;"
    );
    expect(accessSource).toContain("const isDeleteProtected = isAdminRoleMutationProtected;");
    expect(accessSource).toContain("disabled={isSubmitting || isBlockProtected}");
    expect(accessSource).toContain("disabled={isSubmitting || isDeleteProtected}");
    expect(accessSource).toContain("disabled={isSubmitting || isProtected}");
    expect(accessSource).toContain("title={isProtected ? adminProtectionHint : undefined}");
    expect(accessSource).toContain("function retryProfileRefresh()");
    expect(accessSource).toContain('clientLogger.warn("users.access_refresh_failed"');
    expect(accessSource).toContain("workspaceText.actionRefreshWarning");
    expect(accessSource).toContain('if (pendingAction.kind !== "premium") {');
    expect(accessSource).toContain(
      "message: getAdminErrorMessage(error, workspaceText.actionError),"
    );
    expect(accessSource).toContain('clientLogger.error("users.access_action_failed"');
    expect(accessSource).toContain("title={pendingAction?.label ?? workspaceText.confirmTitle}");
    expect(accessSource).toContain(
      "description={pendingAction?.description ?? workspaceText.confirmDescription}"
    );
    expect(detailContentSource).toContain(
      'lastAdminProtected: "Последнего администратора нельзя лишить роли."'
    );
    expect(detailContentSource).toContain(
      "Изменение будет применено сразу и записано в журнал аудита."
    );
    expect(detailContentSource).toContain(
      "Необратимое действие. Используйте его только после проверки юридических оснований и политики хранения данных."
    );
    expect(detailContentSource).toContain(
      'confirmBlockDescription: "Пользователь потеряет доступ к сервису до разблокировки."'
    );
    expect(detailContentSource).toContain("confirmDeleteDescription:");
    expect(detailContentSource).toContain(
      "Аккаунт и связанные данные будут удалены без возможности восстановления."
    );
  });

  it("keeps user support navigation direct and avoids a reset effect", () => {
    const supportSource = readFileSync(userSupportTicketsPanelPath, "utf8");

    expect(supportSource).toContain(
      "const [pageState, setPageState] = useState({ page: 1, userId });"
    );
    expect(supportSource).toContain(
      "const page = pageState.userId === userId ? pageState.page : 1;"
    );
    expect(supportSource).toContain(
      "function updatePage(nextPage: (currentPage: number) => number)"
    );
    expect(supportSource).not.toContain("useEffect");
    expect(supportSource).toContain(
      "title={totalCount ? `${text.supportTitle} · ${totalCount}` : text.supportTitle}"
    );
    expect(supportSource).toContain("const ticketAccessibleLabel = [");
    expect(supportSource).toContain("text.supportOpenTicket,");
    expect(supportSource).toContain("ticketStatusLabel,");
    expect(supportSource).toContain("assignmentLabel,");
    expect(supportSource).toContain("unreadLabel,");
    expect(supportSource).toContain("aria-label={ticketAccessibleLabel}");
    expect(supportSource).toContain(
      'const preview = sanitizeSensitiveText(ticket.lastMessagePreview, 220) || "—";'
    );
    expect(supportSource).not.toContain("supportOpenAction");
    expect(supportSource).toContain("<time dateTime={ticket.updatedAtUtc}>");
    expect(supportSource).toContain('<span aria-live="polite">');
    expect(supportSource).toContain("{text.supportPreviousAction}");
    expect(supportSource).toContain("{text.supportNextAction}");
  });

  it("keeps premium grant out of the UI and retains a confirmed, reasoned wallet adjustment", () => {
    const apiSource = readFileSync(apiClientPath, "utf8");
    const accessSource = readFileSync(userAccessPanelPath, "utf8");
    const detailContentSource = readFileSync(userDetailContentPath, "utf8");
    const walletSource = readFileSync(userWalletPanelPath, "utf8");
    const walletStylesSource = readFileSync(userWalletStylesPath, "utf8");

    expect(apiSource).not.toContain("export async function setPremium");
    expect(apiSource).toContain(
      "await adminCancelPremiumSubscription(userId, normalizedPaymentProvider, reason)"
    );
    expect(apiSource).toContain('if (normalizedPaymentProvider !== "stripe") {');
    expect(apiSource).not.toContain('paymentProvider: "stripe"');
    expect(accessSource).toContain("fetchAdminEconomyUserSubscriptionSummary(user.userId, signal)");
    expect(accessSource).toContain(
      "const latestSubscriptionResult = await subscriptionSummaryQuery.refetch();"
    );
    expect(accessSource).toContain(
      "latestSubscriptionResult.isError || !latestSubscriptionResult.data"
    );
    expect(accessSource).toContain("const updatedSummary = await revokePremium(");
    expect(accessSource).toContain("normalizedPremiumRevokeReason");
    expect(accessSource).toContain('latestEligibility.kind !== "recovery-pending"');
    expect(accessSource).toContain('premiumEligibility.kind === "cancellable"');
    expect(accessSource).toContain('premiumEligibility.kind === "recovery-pending"');
    expect(accessSource).toContain("PREMIUM_REVOKE_REASON_MAX_LENGTH");
    expect(accessSource).toContain("{canRevokePremium ? (");
    expect(accessSource).toContain("workspaceText.accessPremiumStoreManaged");
    expect(accessSource).not.toContain("{user.isPremium ? (");
    expect(accessSource).not.toContain("makePremium");
    expect(detailContentSource).toContain(
      "Подписка управляется через {provider}. Отмена выполняется в аккаунте магазина пользователя"
    );
    expect(detailContentSource).toContain(
      "This subscription is managed through {provider}. It must be cancelled from the user's store account"
    );
    expect(walletSource).toContain("USER_WALLET_REASON_MAX_LENGTH");
    expect(walletSource).toContain(
      "const isWalletFormLocked = isSubmitting || isWalletConfirmationOpen;"
    );
    expect(walletSource).toContain("if (!canAdjustWallet || !pendingAdjustment || isSubmitting) {");
    expect(walletSource).toContain("<ConfirmationDialog");
    expect(walletSource).toContain("open={canAdjustWallet && isWalletConfirmationOpen}");
    expect(walletSource).toContain("await adjustAdminUserWallet(");
    expect(walletSource).toContain("disabled={isWalletFormLocked}");
    expect(walletStylesSource).toContain(".operationField :global(button");
    expect(walletStylesSource).toContain("@media (max-width: 560px)");
  });
});
