import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import {
  PROMO_CAMPAIGN_FIELD_MAX_LENGTH,
  PROMO_DESCRIPTION_MAX_LENGTH,
  buildPromoCodesCsv,
  formatCampaignMeta,
  getUserLabels,
  normalizePromoIntegerInput,
  toCreatePayload,
  toPromoForm,
  toUpdatePayload,
} from "@/components/promo-codes-view.helpers";
import type { AdminRedeemCode } from "@/lib/api-client";
import { getDictionary } from "@/lib/i18n";

const promoCodesViewPath = fileURLToPath(new URL("./promo-codes-view.tsx", import.meta.url));
const promoCodesHelpersPath = fileURLToPath(
  new URL("./promo-codes-view.helpers.ts", import.meta.url)
);
const promoCodesListCardPath = fileURLToPath(
  new URL("./promo-codes-list-card.tsx", import.meta.url)
);
const promoCodesActionsMenuPortalPath = fileURLToPath(
  new URL("./promo-codes-actions-menu-portal.tsx", import.meta.url)
);
const promoCodesActionsMenuHookPath = fileURLToPath(
  new URL("./use-promo-actions-menu.ts", import.meta.url)
);
const promoCodeActivationsCardPath = fileURLToPath(
  new URL("./promo-code-activations-card.tsx", import.meta.url)
);
const promoCodesStylesPath = fileURLToPath(
  new URL("./promo-codes-view.module.css", import.meta.url)
);

function createRedeemCode(patch: Partial<AdminRedeemCode> = {}): AdminRedeemCode {
  return {
    redeemCodeId: "code-1",
    code: "PM-SAFE",
    codePrefix: "PM",
    description: "",
    campaignName: null,
    campaignChannel: null,
    minimumSuccessfulPurchases: 0,
    createdBy: null,
    rewardKind: "spark",
    rewardValue: 100,
    maxRedemptions: 100,
    maxRedemptionsPerUser: 1,
    redeemedCount: 0,
    isActive: true,
    startsAtUtc: null,
    expiresAtUtc: null,
    createdAtUtc: "2026-06-06T12:00:00Z",
    updatedAtUtc: "2026-06-06T12:00:00Z",
    lastRedeemedAtUtc: null,
    usesLast7d: 0,
    grantedLast7d: 0,
    maxRedeemedBySingleUser: 0,
    redemptions: [],
    ...patch,
  };
}

describe("promo code CSV export", () => {
  it("uses the current timestamp for status instead of forcing expiring codes to expired", () => {
    const text = getDictionary("en");
    const csv = buildPromoCodesCsv(
      [
        createRedeemCode({
          startsAtUtc: "2026-06-07T12:00:00Z",
          expiresAtUtc: "2026-06-30T12:00:00Z",
        }),
      ],
      "en",
      text,
      new Date("2026-06-06T12:00:00Z").getTime()
    );

    expect(csv).toContain(text.promoCodesStatusScheduled);
    expect(csv).not.toContain(text.promoCodesStatusExpired);
  });

  it("prefixes formula-like cells and includes a UTF-8 BOM for spreadsheet import", () => {
    const text = getDictionary("en");
    const csv = buildPromoCodesCsv(
      [
        createRedeemCode({
          code: '=IMPORTXML("https://example.com")',
        }),
      ],
      "en",
      text,
      new Date("2026-06-06T12:00:00Z").getTime()
    );

    expect(csv.startsWith("\uFEFF")).toBe(true);
    expect(csv).toContain(`'=${"IMPORTXML"}`);
    expect(csv).not.toContain('\n=IMPORTXML("https://example.com")');
  });

  it("redacts sensitive values from exported cells before writing CSV", () => {
    const text = getDictionary("en");
    const csv = buildPromoCodesCsv(
      [
        createRedeemCode({
          code: "PM-token=raw-secret receipt=ios-secret card_number=4242424242424242 https://cdn.example.com/a.png?X-Amz-Signature=secret",
        }),
      ],
      "en",
      text,
      new Date("2026-06-06T12:00:00Z").getTime()
    );

    expect(csv).toContain("token=[redacted]");
    expect(csv).toContain("receipt=[redacted]");
    expect(csv).toContain("card_number=[redacted]");
    expect(csv).toContain("https://cdn.example.com/a.png?***");
    expect(csv).not.toContain("raw-secret");
    expect(csv).not.toContain("ios-secret");
    expect(csv).not.toContain("4242424242424242");
    expect(csv).not.toContain("X-Amz-Signature=secret");
  });
});

describe("promo codes editor drawer hardening", () => {
  it("does not close the editor with Escape or close actions while a mutation is running", () => {
    const source = readFileSync(promoCodesViewPath, "utf8");

    expect(source).toContain("if (event.key !== \"Escape\")");
    expect(source).toContain("if (isMutating) {\n        event.preventDefault();\n        return;\n      }");
    expect(source).toContain("}, [isEditorOpen, isMutating]);");
    expect(source).toContain("function handleCloseEditor() {");
    expect(source).toContain("if (isMutating) {\n      return;\n    }");
    expect(source).toContain("onClose={handleCloseEditor}");
    expect(source).not.toContain(
      'if (event.key === "Escape") {\n        setIsEditorOpen(false);\n      }'
    );
  });
});

describe("promo code numeric form validation", () => {
  it("normalizes numeric input to bounded digits only", () => {
    expect(normalizePromoIntegerInput("1e6+250.5abc999999")).toBe("16250599");
  });

  it("rejects exponent, decimal and oversized numeric payload values", () => {
    const text = getDictionary("en");
    const baseForm = {
      code: "PM-SAFE",
      description: "",
      campaignName: "",
      campaignChannel: "",
      minimumSuccessfulPurchases: "0",
      rewardKind: "spark" as const,
      rewardValue: "100",
      maxRedemptions: "100",
      maxRedemptionsPerUser: "1",
      isActive: true,
      startsAtUtc: "",
      expiresAtUtc: "",
    };

    expect(() => toCreatePayload({ ...baseForm, rewardValue: "1e6" }, text)).toThrow(
      text.promoCodesInvalidNumbers
    );
    expect(() => toCreatePayload({ ...baseForm, maxRedemptions: "100.5" }, text)).toThrow(
      text.promoCodesInvalidNumbers
    );
    expect(() =>
      toCreatePayload({ ...baseForm, maxRedemptionsPerUser: "123456789" }, text)
    ).toThrow(text.promoCodesInvalidNumbers);
  });

  it("trims and bounds free-text values restored from backend and sent to mutations", () => {
    const text = getDictionary("en");
    const longDescription = ` ${"d".repeat(PROMO_DESCRIPTION_MAX_LENGTH + 20)} `;
    const longCampaignName = ` ${"n".repeat(PROMO_CAMPAIGN_FIELD_MAX_LENGTH + 20)} `;
    const longCampaignChannel = ` ${"c".repeat(PROMO_CAMPAIGN_FIELD_MAX_LENGTH + 20)} `;
    const baseForm = {
      code: "PM-SAFE",
      description: longDescription,
      campaignName: longCampaignName,
      campaignChannel: longCampaignChannel,
      minimumSuccessfulPurchases: "0",
      rewardKind: "spark" as const,
      rewardValue: "100",
      maxRedemptions: "100",
      maxRedemptionsPerUser: "1",
      isActive: true,
      startsAtUtc: "",
      expiresAtUtc: "",
    };

    const createPayload = toCreatePayload(baseForm, text);
    const updatePayload = toUpdatePayload(baseForm, createRedeemCode(), text);
    const restoredForm = toPromoForm(
      createRedeemCode({
        description: longDescription,
        campaignName: longCampaignName,
        campaignChannel: longCampaignChannel,
      })
    );

    expect(createPayload.description).toHaveLength(PROMO_DESCRIPTION_MAX_LENGTH);
    expect(createPayload.campaignName).toHaveLength(PROMO_CAMPAIGN_FIELD_MAX_LENGTH);
    expect(createPayload.campaignChannel).toHaveLength(PROMO_CAMPAIGN_FIELD_MAX_LENGTH);
    expect(updatePayload.description).toHaveLength(PROMO_DESCRIPTION_MAX_LENGTH);
    expect(updatePayload.campaignName).toHaveLength(PROMO_CAMPAIGN_FIELD_MAX_LENGTH);
    expect(updatePayload.campaignChannel).toHaveLength(PROMO_CAMPAIGN_FIELD_MAX_LENGTH);
    expect(restoredForm.description).toHaveLength(PROMO_DESCRIPTION_MAX_LENGTH);
    expect(restoredForm.campaignName).toHaveLength(PROMO_CAMPAIGN_FIELD_MAX_LENGTH);
    expect(restoredForm.campaignChannel).toHaveLength(PROMO_CAMPAIGN_FIELD_MAX_LENGTH);
    expect(createPayload.description).not.toMatch(/^\s|\s$/);
    expect(updatePayload.campaignName).not.toMatch(/^\s|\s$/);
    expect(restoredForm.campaignChannel).not.toMatch(/^\s|\s$/);
  });
});

describe("promo code dangerous action hardening", () => {
  it("keeps archive confirmation open until the backend action succeeds", () => {
    const source = readFileSync(promoCodesViewPath, "utf8");

    expect(source).toContain("const sessionRoles = session?.user.roles ?? [];");
    expect(source).toContain('const canManagePromoCodes = sessionRoles.includes("Admin");');
    expect(source).toContain("if (!canManagePromoCodes || promoCodesQuery.isLoading)");
    expect(source).not.toContain(
      "if (!canManagePromoCodes || promoCodesQuery.isLoading || promoMetricsQuery.isLoading)"
    );
    expect(source).toContain("function assertCanManagePromoCodes(): boolean");
    expect(source).toContain(
      'setFeedback({ tone: "danger", message: promoCodesAdminOnlyMessage });'
    );
    expect(source).toContain("if (!assertCanManagePromoCodes()) {\n      return;");
    expect(source).toContain("if (!assertCanManagePromoCodes()) {\n      return false;");
    expect(source).toContain(
      "async function handleArchive(code: AdminRedeemCode): Promise<boolean>"
    );
    expect(source).toContain("await archiveMutation.mutateAsync");
    expect(source).toContain("handleArchive(codePendingArchive).then((succeeded)");
    expect(source).toContain("function requestArchiveCode(code: AdminRedeemCode)");
    expect(source).toContain("onArchive={requestArchiveCode}");
    expect(source).not.toContain("setCodePendingArchive(code);\n        }}");
    expect(source).toContain(
      "const isPromoRefreshFetching = promoCodesQuery.isFetching || promoMetricsQuery.isFetching;"
    );
    expect(source).toContain("if (promoCodesQuery.isError)");
    expect(source).not.toContain("if (promoCodesQuery.isError || promoMetricsQuery.isError)");
    expect(source).toContain("promoMetricsQuery.isError ? (");
    expect(source).toContain("title={text.promoCodesMetricsErrorDescription}");
    expect(source).toContain(
      "description={getAdminErrorMessage(\n            promoMetricsQuery.error,\n            text.promoCodesMetricsErrorDescription\n          )}"
    );
    expect(source).toContain("disabled={!canManagePromoCodes || isPromoRefreshFetching}");
    expect(source).toContain("promoCodesQueryIsFetching={isPromoRefreshFetching}");
    expect(source).toContain("function requestRefreshPromoCodes()");
    expect(source).toContain(
      "if (!canManagePromoCodes || isPromoRefreshFetching) {\n      return;\n    }\n\n    void Promise.allSettled([promoCodesQuery.refetch(), promoMetricsQuery.refetch()]);"
    );
    expect(source).toContain("function requestRefreshPromoMetrics()");
    expect(source).toContain("onClick={requestRefreshPromoMetrics}");
    expect(source).toContain("onClick={requestRefreshPromoCodes}");
    expect(source).toContain("onRefresh={requestRefreshPromoCodes}");
    expect(source).toContain("promoCodesQuery.refetch()");
    expect(source).toContain("promoMetricsQuery.refetch().catch(() => undefined)");
    expect(source).not.toContain(
      "void promoCodesQuery.refetch().catch(() => undefined);\n            void promoMetricsQuery.refetch().catch(() => undefined);"
    );
    expect(source).not.toContain(
      "handleArchive(codePendingArchive);\n          setCodePendingArchive(null);"
    );
  });

  it("clears stale promo dangerous actions after real list refreshes", () => {
    const source = readFileSync(promoCodesViewPath, "utf8");

    expect(source).toContain(
      "const visiblePromoCodeIds = useMemo(\n    () => new Set(promoCodes.map((code) => code.redeemCodeId))"
    );
    expect(source).toContain(
      "if (!promoCodesPage || isPromoCodesRefreshing || isMutating) {\n      return;\n    }"
    );
    expect(source).toContain(
      "actionsMenuCodeId !== null && !visiblePromoCodeIds.has(actionsMenuCodeId)"
    );
    expect(source).toContain(
      "codePendingArchive !== null && !visiblePromoCodeIds.has(codePendingArchive.redeemCodeId)"
    );
    expect(source).toContain("queueMicrotask(() => {");
    expect(source).toContain("closeActionsMenu();");
    expect(source).toContain("setCodePendingArchive(null);");
  });

  it("gates promo code export and copy actions behind Admin role checks", () => {
    const viewSource = readFileSync(promoCodesViewPath, "utf8");
    const listCardSource = readFileSync(promoCodesListCardPath, "utf8");
    const helpersSource = readFileSync(promoCodesHelpersPath, "utf8");

    expect(viewSource).toContain(
      "async function handleCopyCode(code: string) {\n    if (!assertCanManagePromoCodes())"
    );
    expect(helpersSource).toContain("try {\n      await navigator.clipboard.writeText(value);");
    expect(helpersSource).toContain("} catch {\n      // Fall back to the legacy path below;");
    expect(helpersSource).toContain('const copied = document.execCommand("copy");');
    expect(helpersSource).toContain('throw new Error("Clipboard fallback copy failed");');
    expect(helpersSource).toContain("} finally {\n    input.remove();");
    expect(viewSource).toContain("function getPromoClientErrorDetails(error: unknown)");
    expect(viewSource).toContain('errorName: error instanceof Error ? error.name : "UnknownError"');
    expect(viewSource).toContain('"digest" in error');
    expect(viewSource).toContain(
      'sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)'
    );
    expect(viewSource).toContain(
      'clientLogger.warn("promo.copy_failed", getPromoClientErrorDetails(error));'
    );
    expect(viewSource).not.toContain("sanitizeSensitiveText(error.message, 160)");
    expect(viewSource).not.toContain('clientLogger.warn("promo.copy_failed", { error });');
    expect(viewSource).toContain('setFeedback({ tone: "danger", message: text.promoCodesUpdateError });');
    expect(viewSource).toContain(
      "function handleExport() {\n    if (!assertCanManagePromoCodes())"
    );
    expect(viewSource).toContain("document.body.append(link);");
    expect(viewSource).toContain("link.remove();");
    expect(viewSource).toContain("window.setTimeout(() => URL.revokeObjectURL(url), 1000);");
    expect(viewSource).not.toContain("link.click();\n    URL.revokeObjectURL(url);");
    expect(viewSource).toContain("canManagePromoCodes={canManagePromoCodes}");
    expect(viewSource).toContain("promoCodesActionLocked={isMutating}");
    expect(listCardSource).toContain("canManagePromoCodes: boolean;");
    expect(listCardSource).toContain("promoCodesActionLocked: boolean;");
    expect(listCardSource).toContain(
      "disabled={!hasFilteredCodes || !canManagePromoCodes || promoCodesQueryIsFetching}"
    );
    expect(listCardSource).toContain("disabled={!canManagePromoCodes || promoCodesQueryIsFetching}");
    expect(listCardSource).toContain(
      "disabled={!canManagePromoCodes || promoCodesActionLocked}"
    );
    expect(listCardSource).toContain("disabled={promoCodesQueryIsFetching}");
    expect(listCardSource.match(/disabled=\{promoCodesQueryIsFetching\}/g) ?? []).toHaveLength(7);
    expect(viewSource).toContain("function handleOpenCreatePanel()");
    expect(viewSource).toContain("if (isMutating) {\n      return;\n    }");
  });

  it("disables every promo code action menu item while mutations are pending", () => {
    const actionsMenuSource = readFileSync(promoCodesActionsMenuPortalPath, "utf8");
    const actionButtons = [...actionsMenuSource.matchAll(/<button[\s\S]*?<\/button>/g)].map(
      (match) => match[0]
    );

    expect(actionButtons).toHaveLength(7);
    expect(actionButtons).toEqual(
      expect.arrayContaining([
        expect.stringContaining("disabled={isActionsMenuBusy}"),
        expect.stringContaining("disabled={!actionsMenuCode.isActive || isActionsMenuBusy}"),
      ])
    );
    expect(actionButtons.every((button) => button.includes("isActionsMenuBusy"))).toBe(true);
    expect(actionsMenuSource).toContain(
      'const actionCodeLabel = actionsMenuCode.code || `${actionsMenuCode.codePrefix}...`;'
    );
    expect(actionsMenuSource).toContain("aria-label={copyActionLabel}");
    expect(actionsMenuSource).toContain("aria-label={editActionLabel}");
    expect(actionsMenuSource).toContain("aria-label={viewActivationsLabel}");
    expect(actionsMenuSource).toContain("aria-label={restoreActionLabel}");
    expect(actionsMenuSource).toContain("aria-label={toggleStateActionLabel}");
    expect(actionsMenuSource).toContain("aria-label={archiveActionLabel}");
    expect(actionsMenuSource).toContain("title={archiveActionLabel}");
  });
});

describe("promo code activation data sourcing", () => {
  it("clears the selected promo code when list filters or pages change", () => {
    const viewSource = readFileSync(promoCodesViewPath, "utf8");

    expect(viewSource).toContain("function resetSelectedPromoCode(nextPage = 1) {");
    expect(viewSource).toContain(
      "setSelectedCodeId(null);\n    setSelectedCodeSnapshot(null);\n    setShowAllActivations(false);\n    setActivationsPage(1);\n    setPage(nextPage);\n    closeActionsMenu();"
    );
    expect(viewSource).toContain("onStatusTabChange={(value) => {");
    expect(viewSource).toContain("onSearchChange={(value) => {");
    expect(viewSource).toContain("onStatusFilterChange={(value) => {");
    expect(viewSource).toContain("onRewardFilterChange={(value) => {");
    expect(viewSource).toContain("onSortModeChange={(value) => {");
    expect(viewSource).toContain("onPageSizeChange={(value) => {");
    expect(viewSource).toContain("onResetFilters={() => {");
    expect(viewSource).toContain("onPreviousPage={() => resetSelectedPromoCode(Math.max(1, currentPage - 1))}");
    expect(viewSource).toContain("onNextPage={() => resetSelectedPromoCode(Math.min(totalPages, currentPage + 1))}");
    expect(viewSource).toContain("onSelectPage={resetSelectedPromoCode}");
  });

  it("keeps the selected promo code context stable across filtered page refetches", () => {
    const viewSource = readFileSync(promoCodesViewPath, "utf8");

    expect(viewSource).toContain(
      "const [selectedCodeSnapshot, setSelectedCodeSnapshot] = useState<AdminRedeemCode | null>(null);"
    );
    expect(viewSource).toContain(
      "promoCodes.find((code) => code.redeemCodeId === selectedCodeId) ??\n      (selectedCodeSnapshot?.redeemCodeId === selectedCodeId ? selectedCodeSnapshot : null)"
    );
    expect(viewSource).toContain("setSelectedCodeSnapshot(code);");
    expect(viewSource).toContain("setSelectedCodeSnapshot(null);");
    expect(viewSource).toContain("placeholderData: keepPreviousData");
  });

  it("does not substitute embedded redemption history when backend activations fail", () => {
    const viewSource = readFileSync(promoCodesViewPath, "utf8");
    const cardSource = readFileSync(
      fileURLToPath(new URL("./promo-code-activations-card.tsx", import.meta.url)),
      "utf8"
    );

    expect(viewSource).toContain(
      "const activationsPageData = activationsQuery.isPlaceholderData ? undefined : activationsQuery.data;"
    );
    expect(viewSource).toContain(
      "const redemptionsForView = activationsQuery.isError ? EMPTY_REDEMPTIONS : visibleRedemptions;"
    );
    expect(viewSource).toContain("const hasMoreRedemptions = Boolean(activationsPageData?.hasMore);");
    expect(viewSource).toContain(
      "const isActivationsRefreshing = activationsQuery.isFetching && activationsQuery.isPlaceholderData;"
    );
    expect(viewSource).toContain(
      "activationsIsLoading={activationsQuery.isLoading || isActivationsRefreshing}"
    );
    expect(viewSource).not.toContain("activationsQuery.data?.items ?? EMPTY_REDEMPTIONS");
    expect(viewSource).not.toContain("Boolean(activationsQuery.data?.hasMore)");
    expect(viewSource).not.toContain("fallbackRedemptions");
    expect(viewSource).not.toContain("localRedemptions");
    expect(viewSource).toContain(
      "const canGoToNextActivationsPage = !activationsQuery.isError && hasMoreRedemptions;"
    );
    expect(cardSource).toContain(") : activationsIsError ? (");
    expect(cardSource.indexOf(") : activationsIsError ? (")).toBeLessThan(
      cardSource.indexOf("<div className={styles.usageTableWrap}>")
    );
  });

  it("uses backend pagination, search, filters, and query invalidation for promo code lists", () => {
    const viewSource = readFileSync(promoCodesViewPath, "utf8");
    const listSource = readFileSync(promoCodesListCardPath, "utf8");
    const queryKeysSource = readFileSync(
      fileURLToPath(new URL("../lib/admin-query-keys.ts", import.meta.url)),
      "utf8"
    );

    expect(viewSource).toContain("const debouncedSearch = useDebouncedValue(search, 350);");
    expect(viewSource).toContain('const canManagePromoCodes = sessionRoles.includes("Admin");');
    expect(viewSource).toContain("const sessionRoles = session?.user.roles ?? [];");
    expect(viewSource).toContain("if (!canManagePromoCodes || promoCodesQuery.isLoading)");
    expect(viewSource).not.toContain(
      "if (!canManagePromoCodes || promoCodesQuery.isLoading || promoMetricsQuery.isLoading)"
    );
    expect(viewSource).toContain('ensureAdminSession(locale, router, { requiredRole: "Admin" });');
    expect(viewSource).toContain("normalizeAdminRedeemCodesQuery({");
    expect(viewSource).toContain("skip: (page - 1) * pageSize");
    expect(viewSource).toContain("const promoCodesTotalCount =");
    expect(viewSource).toContain("promoCodesPage?.totalCount");
    expect(viewSource).toContain("Math.ceil(promoCodesTotalCount / pageSize)");
    expect(viewSource).toContain("totalCount={promoCodesTotalCount}");
    expect(readFileSync(promoCodesListCardPath, "utf8")).toContain(
      "of ${formatNumber(totalCount, locale)}"
    );
    expect(viewSource).toContain(
      "queryKey: adminQueryKeys.economyRedeemCodes(promoCodesQueryParams)"
    );
    expect(viewSource).toContain("fetchAdminRedeemCodes(promoCodesQueryParams, signal)");
    expect(viewSource).toContain("enabled: canManagePromoCodes");
    expect(viewSource).toContain("!canManagePromoCodes || hasActivePromoFilters || isEditorOpen");
    expect(viewSource).toContain(
      "queryClient.invalidateQueries({ queryKey: adminQueryKeys.economyRedeemCodesRoot })"
    );
    expect(viewSource).not.toContain(
      "const totalPages = hasMorePromoCodes ? currentPage + 1 : currentPage;"
    );
    expect(viewSource).not.toContain("hasMorePromoCodes");
    expect(viewSource).not.toContain("promoCodesTotalCount === null");
    expect(readFileSync(promoCodesListCardPath, "utf8")).not.toContain("totalCount === null");
    expect(viewSource).not.toContain("useDeferredValue(search)");
    expect(viewSource).not.toContain("return promoCodes\n      .filter((code) => {");
    expect(viewSource).toContain(
      "const promoCodesPage = promoCodesQuery.isPlaceholderData ? undefined : promoCodesQuery.data;"
    );
    expect(viewSource).toContain(
      "const isPromoCodesRefreshing = promoCodesQuery.isFetching && promoCodesQuery.isPlaceholderData;"
    );
    expect(viewSource).toContain("promoCodesQueryIsRefreshing={isPromoCodesRefreshing}");
    expect(listSource).toContain("promoCodesQueryIsRefreshing: boolean;");
    expect(listSource).toContain("promoCodesQueryIsRefreshing,");
    expect(listSource).toContain("promoCodesQueryIsRefreshing ? (");
    expect(listSource).toContain("description={text.promoCodesLoadingDescription}");
    expect(listSource).toContain(
      "disabled={!hasFilteredCodes || !canManagePromoCodes || promoCodesQueryIsFetching}"
    );
    expect(listSource).toContain("disabled={actionBusy || promoCodesQueryIsFetching}");
    expect(listSource).toContain("disabled={currentPage <= 1 || promoCodesQueryIsFetching}");
    expect(listSource).toContain("disabled={currentPage >= totalPages || promoCodesQueryIsFetching}");
    expect(listSource).toContain("disabled={promoCodesQueryIsFetching}");
    expect(listSource.match(/disabled=\{promoCodesQueryIsFetching\}/g) ?? []).toHaveLength(7);
    expect(queryKeysSource).toContain("economyRedeemCodesRoot");
    expect(queryKeysSource).toContain("economyRedeemCodes: (query: unknown)");
  });

  it("keeps promo code mutation cache refreshes non-blocking after success", () => {
    const viewSource = readFileSync(promoCodesViewPath, "utf8");
    const rootRefreshes = viewSource.match(
      /Promise\.allSettled\(\[\n\s+queryClient\.invalidateQueries\(\{ queryKey: adminQueryKeys\.economyRedeemCodesRoot \}\),\n\s+\]\)/g
    ) ?? [];

    expect(rootRefreshes).toHaveLength(4);
    expect(viewSource).not.toContain(
      "await queryClient.invalidateQueries({ queryKey: adminQueryKeys.economyRedeemCodesRoot })"
    );
  });

  it("sources promo code KPI cards from backend aggregate metrics", () => {
    const viewSource = readFileSync(promoCodesViewPath, "utf8");
    const queryKeysSource = readFileSync(
      fileURLToPath(new URL("../lib/admin-query-keys.ts", import.meta.url)),
      "utf8"
    );

    expect(viewSource).toContain(
      "queryKey: adminQueryKeys.economyRedeemCodeMetrics(promoCodeMetricsQueryParams)"
    );
    expect(viewSource).toContain(
      "fetchAdminRedeemCodeMetrics(promoCodeMetricsQueryParams, signal)"
    );
    expect(viewSource).toContain("enabled: canManagePromoCodes");
    expect(viewSource).toContain("value={formatNumber(metrics.totalCodes, locale)}");
    expect(viewSource).toContain("value={formatNumber(metrics.activeCodes, locale)}");
    expect(viewSource).toContain("value={formatNumber(metrics.totalUses, locale)}");
    expect(viewSource).toContain(
      "value={`${formatNumber(metrics.totalGranted, locale)} ${tokenUnit}`}"
    );
    expect(viewSource).not.toContain("pageCodes: promoCodes.length");
    expect(viewSource).not.toContain("activeCodes: promoCodes.filter");
    expect(viewSource).not.toContain("totalUses: promoCodes.reduce");
    expect(viewSource).not.toContain("totalGranted: promoCodes.reduce");
    expect(viewSource).not.toContain("Codes on page");
    expect(viewSource).not.toContain("Exact global totals need a backend aggregate endpoint.");
    expect(queryKeysSource).toContain("economyRedeemCodeMetrics: (query: unknown)");
  });
});

describe("promo code sensitive display", () => {
  it("sanitizes campaign metadata and user labels shown in admin promo surfaces", () => {
    const campaignMeta = formatCampaignMeta(
      createRedeemCode({
        campaignName: "email alice@example.com",
        campaignChannel: "receipt=ios-secret",
      })
    );
    const userLabels = getUserLabels("user-123456789", {
      userId: "user-123456789",
      email: "alice@example.com",
      displayName: "Alice token=raw-secret",
      roles: [],
      isActive: true,
      isPremium: false,
      emailConfirmed: true,
      createdAtUtc: "2026-06-06T12:00:00Z",
      avatar: null,
    });
    const unknownUserLabels = getUserLabels("user-123456789");

    expect(campaignMeta).toContain("al***@e***.com");
    expect(campaignMeta).toContain("receipt=[redacted]");
    expect(campaignMeta).not.toContain("alice@example.com");
    expect(campaignMeta).not.toContain("ios-secret");
    expect(userLabels.primary).toContain("token=[redacted]");
    expect(userLabels.primary).not.toContain("raw-secret");
    expect(userLabels.secondary).toBe("al***@e***.com");
    expect(unknownUserLabels.secondary).toBe("user-123");
  });

  it("uses sanitized promo display helpers in the list card", () => {
    const source = readFileSync(promoCodesListCardPath, "utf8");

    expect(source).toContain("const codeValue = formatPromoDisplayText(");
    expect(source).toContain("formatPromoDisplayText(code.description, 160)");
    expect(source).toContain("formatPromoDisplayText(code.createdBy, 80)");
    expect(source).not.toContain("const codeValue = code.code || `${code.codePrefix}...`");
    expect(source).not.toContain('code.description.trim() || "-"');
    expect(source).not.toContain('code.createdBy?.trim() || "-"');
  });

  it("keeps promo code filters and pagination usable on tablet and mobile widths", () => {
    const listSource = readFileSync(promoCodesListCardPath, "utf8");
    const activationsSource = readFileSync(promoCodeActivationsCardPath, "utf8");
    const stylesSource = readFileSync(promoCodesStylesPath, "utf8");

    expect(listSource).toContain("CaretDownIcon");
    expect(listSource).toContain("title={text.promoCodesPreviousAction}");
    expect(listSource).toContain("title={text.promoCodesNextAction}");
    expect(listSource).toContain(
      "const actionsMenuLabel = `${text.promoCodesActionsMenuLabel}: ${codeValue}`;"
    );
    expect(listSource).toContain("aria-label={actionsMenuLabel}");
    expect(listSource).toContain("title={actionsMenuLabel}");
    expect(listSource).toContain("className={`${styles.pageIcon} ${styles.pageIconPrevious}`}");
    expect(listSource).toContain("className={`${styles.pageIcon} ${styles.pageIconNext}`}");
    expect(listSource).toContain(
      "const isStatusTabDisabled = isActiveTab || promoCodesQueryIsFetching;"
    );
    expect(listSource).toContain("disabled={isStatusTabDisabled}");
    expect(listSource).toContain(
      "if (isStatusTabDisabled) {\n                    return;\n                  }"
    );
    expect(listSource).not.toContain('{"<"}');
    expect(listSource).not.toContain('{">"}');
    expect(listSource).toContain('aria-current={pageNumber === currentPage ? "page" : undefined}');
    expect(listSource).toContain("`Page ${formatNumber(pageNumber, locale)}`");
    expect(listSource).toContain("`Страница ${formatNumber(pageNumber, locale)}`");
    expect(activationsSource).toContain("CaretDownIcon");
    expect(activationsSource).toContain("aria-label={text.promoCodesPreviousAction}");
    expect(activationsSource).toContain("aria-label={text.promoCodesNextAction}");
    expect(activationsSource).toContain("title={text.promoCodesPreviousAction}");
    expect(activationsSource).toContain("title={text.promoCodesNextAction}");
    expect(activationsSource).toContain(
      "className={`${styles.pageIcon} ${styles.pageIconPrevious}`}"
    );
    expect(activationsSource).toContain("className={`${styles.pageIcon} ${styles.pageIconNext}`}");
    expect(activationsSource).not.toContain(">\n                  {text.promoCodesPreviousAction}\n");
    expect(activationsSource).not.toContain(">\n                  {text.promoCodesNextAction}\n");
    expect(stylesSource).toContain(".tableTopBar {\n  display: flex;\n  flex-wrap: wrap;");
    expect(stylesSource).toContain(".statusTabs {\n  min-width: 0;\n  max-width: 100%;");
    expect(stylesSource).toContain("overflow-x: auto;");
    expect(stylesSource).toContain(".usageTableWrap {\n  position: relative;");
    expect(stylesSource).toContain("width: 100%;\n  min-width: 0;");
    expect(stylesSource).toContain("overscroll-behavior-inline: contain;");
    expect(stylesSource).toContain(".usageTableWrap::-webkit-scrollbar");
    expect(stylesSource).toContain(
      ".usageTable {\n  width: 100%;\n  min-width: clamp(24rem, 82vw, 30rem);"
    );
    expect(stylesSource).toContain(".paginationActions {\n  min-width: 0;\n  max-width: 100%;");
    expect(stylesSource).toContain("@media (max-width: 1080px)");
    expect(stylesSource).toContain(
      ".filterBar {\n    grid-template-columns: repeat(2, minmax(0, 1fr));"
    );
    expect(stylesSource).toContain(".searchField {\n    grid-column: 1 / -1;");
    expect(stylesSource).toContain("@media (max-width: 860px)");
    expect(stylesSource).toContain(".statusTabs {\n    width: 100%;\n    flex-wrap: nowrap;");
    expect(stylesSource).toContain(".paginationActions {\n    justify-content: flex-start;");
    const editorDrawerBlock = stylesSource.match(/\.editorDrawer \{[\s\S]*?\n\}/)?.[0] ?? "";
    expect(editorDrawerBlock).toContain("height: min(100%, calc(100dvh - 1.8rem));");
    expect(editorDrawerBlock).toContain("border-radius: var(--radius);");
    expect(stylesSource).toContain("max-height: calc(100dvh - 8rem);");
    expect(stylesSource).toContain("height: min(100%, calc(100dvh - 1.12rem));");
    expect(stylesSource).not.toContain("100vh");
    expect(editorDrawerBlock).not.toContain("border-radius: 1.05rem;");
  });

  it("shows promo activation load errors before empty states so retry stays available", () => {
    const activationsSource = readFileSync(promoCodeActivationsCardPath, "utf8");

    const errorStateIndex = activationsSource.indexOf(") : activationsIsError ? (");
    const emptyStateIndex = activationsSource.indexOf(") : !hasAnyRedemptions ? (");

    expect(errorStateIndex).toBeGreaterThan(-1);
    expect(emptyStateIndex).toBeGreaterThan(-1);
    expect(errorStateIndex).toBeLessThan(emptyStateIndex);
    expect(activationsSource).toContain("disabled={activationsIsFetching}");
    expect(activationsSource).toContain("function requestActivationsRetry()");
    expect(activationsSource).toContain(
      "if (activationsIsFetching) {\n      return;\n    }"
    );
    expect(activationsSource).toContain("void onRefetchActivations();");
    expect(activationsSource).toContain("onClick={requestActivationsRetry}");
  });

  it("keeps promo code status colors and overlays on semantic theme tokens", () => {
    const helperSource = readFileSync(promoCodesHelpersPath, "utf8");
    const listSource = readFileSync(promoCodesListCardPath, "utf8");
    const activationsSource = readFileSync(promoCodeActivationsCardPath, "utf8");
    const actionsMenuSource = readFileSync(promoCodesActionsMenuPortalPath, "utf8");
    const actionsMenuHookSource = readFileSync(promoCodesActionsMenuHookPath, "utf8");
    const stylesSource = readFileSync(promoCodesStylesPath, "utf8");
    const nonZeroLetterSpacingRules = [...stylesSource.matchAll(/letter-spacing:\s*([^;]+);/g)]
      .map((match) => match[1]?.trim())
      .filter((value) => value !== "0");

    expect(helperSource).toContain('color: "var(--success)"');
    expect(helperSource).toContain('color: "var(--warning)"');
    expect(helperSource).toContain('color: "var(--danger)"');
    expect(helperSource).toContain('color: "var(--info)"');
    expect(helperSource).toContain('color: "var(--text-muted)"');
    expect(listSource).toContain("const rewardKindColors: Record<AdminRedeemRewardKind, string>");
    expect(listSource).toContain('spark: "var(--success)"');
    expect(listSource).toContain('premium_days: "var(--info)"');
    expect(listSource).toContain("color={rewardKindColors[code.rewardKind]}");
    expect(activationsSource).toContain('AdminStatusBadge color="var(--success)"');
    expect(stylesSource).toContain(
      "background: color-mix(in srgb, var(--surface-0) 74%, transparent);"
    );
    expect(stylesSource).toContain("box-shadow: var(--shadow-strong);");
    expect(stylesSource).toContain(".tableRow:focus-visible td");
    expect(stylesSource).toContain("outline: 2px solid var(--border-accent);");
    expect(stylesSource).toContain(".actionsMenuItem:focus-visible");
    expect(stylesSource).toContain("box-shadow: var(--focus-ring);");
    expect(stylesSource).toContain("max-width: calc(100vw - 1rem);");
    expect(stylesSource).toContain("max-height: calc(100dvh - 1rem);");
    expect(stylesSource).toContain(".actionsMenuListPortal {\n  position: static;");
    expect(stylesSource).toContain("max-width: inherit;");
    expect(stylesSource).toContain("max-height: inherit;");
    expect(stylesSource).toContain("overflow-y: auto;");
    expect(stylesSource).toContain(".actionsMenuItem {\n  appearance: none;\n  width: 100%;\n  min-width: 0;");
    expect(stylesSource).toContain("white-space: normal;");
    expect(stylesSource).toContain("overflow-wrap: anywhere;");
    expect(stylesSource).not.toContain("rgba(");
    expect(actionsMenuSource).toContain('minWidth: `min(${minWidthPx}px, calc(100vw - 1rem))`');
    expect(actionsMenuSource).not.toContain("minWidth: minWidthPx");
    expect(actionsMenuHookSource).toContain("const menuWidth = Math.min(");
    expect(actionsMenuHookSource).toContain(
      "Math.max(0, window.innerWidth - ACTIONS_MENU_GAP_PX * 2)"
    );
    expect(actionsMenuHookSource).toContain("rect.right - menuWidth");
    expect(actionsMenuHookSource).not.toContain("rect.right - ACTIONS_MENU_WIDTH_PX");
    expect(stylesSource).not.toContain("outline: 1px solid color-mix(in srgb, var(--success) 42%, transparent);");
    expect(stylesSource).not.toContain("radial-gradient");
    expect(stylesSource).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(stylesSource).not.toMatch(/font-size:\s*[^;]*vw/);
    expect(nonZeroLetterSpacingRules).toEqual([]);
    expect(listSource).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(activationsSource).not.toMatch(/#[0-9a-fA-F]{3,8}/);
  });

  it("sanitizes selected promo code labels and disables repeated activation retries", () => {
    const viewSource = readFileSync(promoCodesViewPath, "utf8");
    const activationsSource = readFileSync(promoCodeActivationsCardPath, "utf8");

    expect(viewSource).toContain(
      "formatPromoDisplayText(\n                codePendingArchive.code || `${codePendingArchive.codePrefix}...`,\n                80"
    );
    expect(viewSource).toContain("enabled: canManagePromoCodes && Boolean(selectedCodeId)");
    expect(viewSource).toContain("selectedUsersQueries = useQueries({");
    expect(viewSource).toContain("enabled: canManagePromoCodes");
    expect(viewSource).not.toContain(
      "`${codePendingArchive.code}: ${text.promoCodesArchiveConfirm}`"
    );
    expect(activationsSource).toContain(
      "formatPromoDisplayText(selectedCode.code || `${selectedCode.codePrefix}...`, 80)"
    );
    expect(activationsSource).toContain("disabled={activationsIsFetching}");
    expect(activationsSource).toContain(
      "<Button\n                variant=\"secondary\"\n                size=\"sm\"\n                onClick={onShowAllActivations}\n                disabled={activationsIsFetching}"
    );
    expect(activationsSource).toContain(
      "<Button\n                variant=\"ghost\"\n                size=\"sm\"\n                onClick={onShowLatestActivations}\n                disabled={activationsIsFetching}"
    );
    expect(activationsSource).not.toContain(
      '`${selectedCode.code || `${selectedCode.codePrefix}...`} · ${selectedStatusLabel ?? ""}`'
    );
  });
});
