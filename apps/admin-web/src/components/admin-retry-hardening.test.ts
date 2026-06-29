import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const roleManagementPath = fileURLToPath(new URL("./role-management-page.tsx", import.meta.url));
const roleManagementContentPath = fileURLToPath(
  new URL("./role-management-page.content.ts", import.meta.url)
);
const promoCodesPath = fileURLToPath(new URL("./promo-codes-view.tsx", import.meta.url));
const generationsPath = fileURLToPath(new URL("./generations-page.tsx", import.meta.url));

describe("admin retry hardening", () => {
  it("guards role management retry against repeated clicks and unhandled rejection", () => {
    const source = readFileSync(roleManagementPath, "utf8");

    expect(source).toContain(
      "const isRoleRetryFetching = adminsQuery.isFetching || moderatorsQuery.isFetching"
    );
    expect(source).toContain("function requestRoleListsRetry()");
    expect(source).toContain(
      "if (!canManageRoles || isRoleRetryFetching) {\n      return;\n    }"
    );
    expect(source).toContain("disabled={!canManageRoles || isRoleRetryFetching}");
    expect(source).toContain("onClick={requestRoleListsRetry}");
    expect(source).toContain(
      "void Promise.allSettled([adminsQuery.refetch(), moderatorsQuery.refetch()]);"
    );
    expect(source).not.toContain(
      "void Promise.all([adminsQuery.refetch(), moderatorsQuery.refetch()]).catch("
    );
  });

  it("keeps role assignment search failures distinct from empty search results", () => {
    const source = readFileSync(roleManagementPath, "utf8");
    const contentSource = readFileSync(roleManagementContentPath, "utf8");

    expect(contentSource).toContain('searchError: "Не удалось выполнить поиск пользователей"');
    expect(source).toContain("const normalizedSearch = debouncedSearch.trim();");
    expect(source).toContain("const isSearchActive = normalizedSearch.length >= 2;");
    expect(source).toContain(
      "const isSearchRefreshing = searchQuery.isFetching && searchQuery.isPlaceholderData;"
    );
    expect(source).toContain(
      "const visibleSearchResults = isSearchActive && !isSearchRefreshing ? searchResults : [];"
    );
    expect(source).toContain("isSearchActive && searchQuery.isError");
    expect(source).toContain(
      "description={getAdminErrorMessage(searchQuery.error, text.searchError)}"
    );
    expect(source).toContain("disabled={!canManageRoles || searchQuery.isFetching}");
    expect(source).toContain("void searchQuery.refetch().catch(() => undefined);");
    expect(source).toContain(
      "isSearchActive && (searchQuery.isLoading || isSearchRefreshing)"
    );
    expect(source).toContain("isSearchActive &&\n            !searchQuery.isLoading");
    expect(source).toContain("!isSearchRefreshing &&");
    expect(source).toContain("!searchQuery.isError &&\n            visibleSearchResults.length === 0");
    expect(source).toContain("visibleSearchResults.map((user) => {");
    expect(source).toContain("function requestSearchRetry()");
    expect(source).toContain(
      "if (!canManageRoles || searchQuery.isFetching) {\n      return;\n    }"
    );
    expect(source).toContain("onClick={requestSearchRetry}");
    expect(source).not.toContain("searchResults.map((user) => {");
    expect(source).not.toContain(
      "onClick={() => {\n                      if (!canManageRoles)"
    );
    expect(source).not.toContain(
      "debouncedSearch.trim().length >= 2 &&\n          !searchQuery.isLoading &&\n          searchResults.length === 0"
    );
  });

  it("keeps role list column failures local when the other role list has data", () => {
    const source = readFileSync(roleManagementPath, "utf8");
    const contentSource = readFileSync(roleManagementContentPath, "utf8");

    expect(contentSource).toContain('adminsError: "Не удалось загрузить Admin"');
    expect(contentSource).toContain('moderatorsError: "Не удалось загрузить Moderator"');
    expect(source).toContain("const hasAnyRoleData = Boolean(adminsQuery.data || moderatorsQuery.data);");
    expect(source).toContain("const hasBlockingRoleError = isError && !hasAnyRoleData;");
    expect(source).toContain(") : hasBlockingRoleError ? (");
    expect(source).toContain(
      "description={getAdminErrorMessage(adminsQuery.error ?? moderatorsQuery.error, text.error)}"
    );
    expect(source).toContain("title={text.adminsError}");
    expect(source).toContain("description={getAdminErrorMessage(adminsQuery.error, text.adminsError)}");
    expect(source).toContain("disabled={!canManageRoles || adminsQuery.isFetching}");
    expect(source).toContain("function requestAdminsRetry()");
    expect(source).toContain(
      "if (!canManageRoles || adminsQuery.isFetching) {\n      return;\n    }"
    );
    expect(source).toContain("onClick={requestAdminsRetry}");
    expect(source).toContain("void adminsQuery.refetch().catch(() => undefined);");
    expect(source).toContain("title={text.moderatorsError}");
    expect(source).toContain(
      "description={getAdminErrorMessage(moderatorsQuery.error, text.moderatorsError)}"
    );
    expect(source).toContain("disabled={!canManageRoles || moderatorsQuery.isFetching}");
    expect(source).toContain("function requestModeratorsRetry()");
    expect(source).toContain(
      "if (!canManageRoles || moderatorsQuery.isFetching) {\n      return;\n    }"
    );
    expect(source).toContain("onClick={requestModeratorsRetry}");
    expect(source).toContain("void moderatorsQuery.refetch().catch(() => undefined);");
    expect(source).not.toContain(") : isError ? (");
  });

  it("does not render stale placeholder role rows or pagers during page refreshes", () => {
    const source = readFileSync(roleManagementPath, "utf8");

    expect(source).toContain(
      "const adminsPageData = adminsQuery.isPlaceholderData ? undefined : adminsQuery.data;"
    );
    expect(source).toContain(
      "const moderatorsPageData = moderatorsQuery.isPlaceholderData ? undefined : moderatorsQuery.data;"
    );
    expect(source).toContain("const admins = adminsPageData?.items ?? [];");
    expect(source).toContain("const moderators = moderatorsPageData?.items ?? [];");
    expect(source).toContain(
      "const isAdminsRefreshing = adminsQuery.isFetching && adminsQuery.isPlaceholderData;"
    );
    expect(source).toContain(
      "const isModeratorsRefreshing = moderatorsQuery.isFetching && moderatorsQuery.isPlaceholderData;"
    );
    expect(source).toContain("isAdminsRefreshing ? (");
    expect(source).toContain("isModeratorsRefreshing ? (");
    expect(source).toContain("adminsPageData && adminsPageData.totalCount > 0");
    expect(source).toContain("moderatorsPageData && moderatorsPageData.totalCount > 0");
    expect(source).not.toContain("const admins = adminsQuery.data?.items ?? [];");
    expect(source).not.toContain("const moderators = moderatorsQuery.data?.items ?? [];");
    expect(source).not.toContain("adminsQuery.data && adminsQuery.data.totalCount > 0");
    expect(source).not.toContain("moderatorsQuery.data && moderatorsQuery.data.totalCount > 0");
  });

  it("clears pending role confirmations when search or list pages change", () => {
    const source = readFileSync(roleManagementPath, "utf8");

    expect(source).toContain("targetUserId: string;");
    expect(source).toContain("targetUserId: user.userId,");
    expect(source).toContain("function resetPendingRoleAction()");
    expect(source).toContain(
      "if (isRoleActionLocked()) {\n      return;\n    }\n\n    setPendingAction(null);"
    );
    expect(source).toContain("function setAdminsPageContext(nextPage: number)");
    expect(source).toContain("function setModeratorsPageContext(nextPage: number)");
    expect(source).toContain("resetPendingRoleAction();\n    setAdminsPage(Math.max(0, nextPage));");
    expect(source).toContain(
      "resetPendingRoleAction();\n    setModeratorsPage(Math.max(0, nextPage));"
    );
    expect(source).toContain("onPrevious={() => setAdminsPageContext(adminsPage - 1)}");
    expect(source).toContain("onNext={() => setAdminsPageContext(adminsPage + 1)}");
    expect(source).toContain("onPrevious={() => setModeratorsPageContext(moderatorsPage - 1)}");
    expect(source).toContain("onNext={() => setModeratorsPageContext(moderatorsPage + 1)}");
    expect(source).toContain(
      "onChange={(event) => {\n                  resetPendingRoleAction();\n                  setSearch(event.target.value.slice(0, USER_SEARCH_MAX_LENGTH));\n                }}"
    );
    expect(source).toContain("const visibleActionUserIdSignature = [");
    expect(source).toContain("...moderators.map((user) => user.userId)");
    expect(source).toContain("...visibleSearchResults.map((user) => user.userId)");
    expect(source).toContain(
      'visibleActionUserIdSignature.split("|").includes(pendingAction.targetUserId)'
    );
    expect(source).toContain("queueMicrotask(() => setPendingAction(null));");
  });

  it("swallows safe manual retry failures on promo and generations pages", () => {
    const promoSource = readFileSync(promoCodesPath, "utf8");
    const generationsSource = readFileSync(generationsPath, "utf8");

    expect(promoSource).toContain("function requestRefreshPromoCodes()");
    expect(promoSource).toContain(
      "const isPromoRefreshFetching = promoCodesQuery.isFetching || promoMetricsQuery.isFetching;"
    );
    expect(promoSource).toContain("disabled={!canManagePromoCodes || isPromoRefreshFetching}");
    expect(promoSource).toContain("promoCodesQueryIsFetching={isPromoRefreshFetching}");
    expect(promoSource).toContain(
      "if (!canManagePromoCodes || isPromoRefreshFetching) {\n      return;\n    }\n\n    void Promise.allSettled([promoCodesQuery.refetch(), promoMetricsQuery.refetch()]);"
    );
    expect(promoSource).toContain("function requestRefreshPromoMetrics()");
    expect(promoSource).toContain("onClick={requestRefreshPromoMetrics}");
    expect(promoSource).toContain("onRefresh={requestRefreshPromoCodes}");
    expect(promoSource).not.toContain(
      "void promoCodesQuery.refetch().catch(() => undefined);\n            void promoMetricsQuery.refetch().catch(() => undefined);"
    );
    expect(generationsSource).toContain("function requestGenerationsRetry()");
    expect(generationsSource).toContain("generationsQuery.refetch().catch(() => undefined)");
    expect(generationsSource).toContain(
      "disabled={!canViewGenerations || generationsQuery.isFetching}"
    );
    expect(generationsSource).toContain(
      "if (!canViewGenerations || generationsQuery.isFetching) {\n      return;\n    }"
    );
    expect(generationsSource).toContain("onClick={requestGenerationsRetry}");
  });
});
