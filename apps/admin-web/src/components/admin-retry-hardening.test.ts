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

  it("swallows safe manual retry failures on promo and generations pages", () => {
    const promoSource = readFileSync(promoCodesPath, "utf8");
    const generationsSource = readFileSync(generationsPath, "utf8");

    expect(promoSource).toContain("promoCodesQuery.refetch().catch(() => undefined)");
    expect(promoSource).toContain(
      "!canManagePromoCodes || promoCodesQuery.isFetching || promoMetricsQuery.isFetching"
    );
    expect(promoSource).toContain(
      "if (!canManagePromoCodes) {\n                  return;\n                }\n\n                void promoCodesQuery.refetch().catch(() => undefined);"
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
