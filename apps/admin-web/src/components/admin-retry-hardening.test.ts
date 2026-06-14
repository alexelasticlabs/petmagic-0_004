import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const roleManagementPath = fileURLToPath(new URL("./role-management-page.tsx", import.meta.url));
const promoCodesPath = fileURLToPath(new URL("./promo-codes-view.tsx", import.meta.url));
const generationsPath = fileURLToPath(new URL("./generations-page.tsx", import.meta.url));

describe("admin retry hardening", () => {
  it("guards role management retry against repeated clicks and unhandled rejection", () => {
    const source = readFileSync(roleManagementPath, "utf8");

    expect(source).toContain(
      "const isRoleRetryFetching = adminsQuery.isFetching || moderatorsQuery.isFetching"
    );
    expect(source).toContain("disabled={!canManageRoles || isRoleRetryFetching}");
    expect(source).toContain(
      "if (!canManageRoles) {\n                  return;\n                }\n\n                void Promise.all([adminsQuery.refetch(), moderatorsQuery.refetch()]).catch("
    );
    expect(source).toContain(
      "void Promise.all([adminsQuery.refetch(), moderatorsQuery.refetch()]).catch("
    );
  });

  it("keeps role assignment search failures distinct from empty search results", () => {
    const source = readFileSync(roleManagementPath, "utf8");

    expect(source).toContain(
      'searchError: isRu ? "Не удалось выполнить поиск пользователей" : "Failed to search users"'
    );
    expect(source).toContain("const isSearchActive = debouncedSearch.trim().length >= 2;");
    expect(source).toContain("isSearchActive && searchQuery.isError");
    expect(source).toContain(
      "description={getAdminErrorMessage(searchQuery.error, text.searchError)}"
    );
    expect(source).toContain("disabled={!canManageRoles || searchQuery.isFetching}");
    expect(source).toContain("void searchQuery.refetch().catch(() => undefined);");
    expect(source).toContain("isSearchActive &&\n            !searchQuery.isLoading");
    expect(source).toContain("!searchQuery.isError &&\n            searchResults.length === 0");
    expect(source).not.toContain(
      "debouncedSearch.trim().length >= 2 &&\n          !searchQuery.isLoading &&\n          searchResults.length === 0"
    );
  });

  it("swallows safe manual retry failures on promo and generations pages", () => {
    const promoSource = readFileSync(promoCodesPath, "utf8");
    const generationsSource = readFileSync(generationsPath, "utf8");

    expect(promoSource).toContain("promoCodesQuery.refetch().catch(() => undefined)");
    expect(promoSource).toContain(
      "const isPromoRefreshFetching = promoCodesQuery.isFetching || promoMetricsQuery.isFetching;"
    );
    expect(promoSource).toContain("disabled={!canManagePromoCodes || isPromoRefreshFetching}");
    expect(promoSource).toContain("promoCodesQueryIsFetching={isPromoRefreshFetching}");
    expect(promoSource).toContain(
      "if (!canManagePromoCodes) {\n                  return;\n                }\n\n                void promoCodesQuery.refetch().catch(() => undefined);"
    );
    expect(promoSource).toContain(
      "void promoCodesQuery.refetch().catch(() => undefined);\n            void promoMetricsQuery.refetch().catch(() => undefined);"
    );
    expect(generationsSource).toContain("generationsQuery.refetch().catch(() => undefined)");
    expect(generationsSource).toContain(
      "disabled={!canViewGenerations || generationsQuery.isFetching}"
    );
    expect(generationsSource).toContain(
      "if (!canViewGenerations) {\n                  return;\n                }\n\n                void generationsQuery.refetch().catch(() => undefined);"
    );
  });
});
