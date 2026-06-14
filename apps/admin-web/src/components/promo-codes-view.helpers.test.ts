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
    expect(source).toContain(
      "if (!canManagePromoCodes) {\n                  return;\n                }\n\n                void promoCodesQuery.refetch().catch(() => undefined);"
    );
    expect(source).toContain(
      "void promoCodesQuery.refetch().catch(() => undefined);\n            void promoMetricsQuery.refetch().catch(() => undefined);"
    );
    expect(source).toContain("promoCodesQuery.refetch().catch(() => undefined)");
    expect(source).toContain("promoMetricsQuery.refetch().catch(() => undefined)");
    expect(source).not.toContain(
      "handleArchive(codePendingArchive);\n          setCodePendingArchive(null);"
    );
  });

  it("gates promo code export and copy actions behind Admin role checks", () => {
    const viewSource = readFileSync(promoCodesViewPath, "utf8");
    const listCardSource = readFileSync(promoCodesListCardPath, "utf8");

    expect(viewSource).toContain(
      "async function handleCopyCode(code: string) {\n    if (!assertCanManagePromoCodes())"
    );
    expect(viewSource).toContain(
      "function handleExport() {\n    if (!assertCanManagePromoCodes())"
    );
    expect(viewSource).toContain("canManagePromoCodes={canManagePromoCodes}");
    expect(listCardSource).toContain("canManagePromoCodes: boolean;");
    expect(listCardSource).toContain("disabled={!hasFilteredCodes || !canManagePromoCodes}");
    expect(listCardSource).toContain(
      '<Button variant="primary" onClick={onOpenCreatePanel} disabled={!canManagePromoCodes}>'
    );
  });
});

describe("promo code activation data sourcing", () => {
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
      "const redemptionsForView = activationsQuery.isError ? EMPTY_REDEMPTIONS : visibleRedemptions;"
    );
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
    expect(queryKeysSource).toContain("economyRedeemCodesRoot");
    expect(queryKeysSource).toContain("economyRedeemCodes: (query: unknown)");
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
    const stylesSource = readFileSync(promoCodesStylesPath, "utf8");

    expect(listSource).toContain("CaretDownIcon");
    expect(listSource).toContain("title={text.promoCodesPreviousAction}");
    expect(listSource).toContain("title={text.promoCodesNextAction}");
    expect(listSource).toContain("className={`${styles.pageIcon} ${styles.pageIconPrevious}`}");
    expect(listSource).toContain("className={`${styles.pageIcon} ${styles.pageIconNext}`}");
    expect(listSource).not.toContain('{"<"}');
    expect(listSource).not.toContain('{">"}');
    expect(listSource).toContain('aria-current={pageNumber === currentPage ? "page" : undefined}');
    expect(listSource).toContain("`Page ${formatNumber(pageNumber, locale)}`");
    expect(listSource).toContain("`Страница ${formatNumber(pageNumber, locale)}`");
    expect(stylesSource).toContain(".tableTopBar {\n  display: flex;\n  flex-wrap: wrap;");
    expect(stylesSource).toContain(".statusTabs {\n  min-width: 0;\n  max-width: 100%;");
    expect(stylesSource).toContain("overflow-x: auto;");
    expect(stylesSource).toContain(".paginationActions {\n  min-width: 0;\n  max-width: 100%;");
    expect(stylesSource).toContain("@media (max-width: 1080px)");
    expect(stylesSource).toContain(
      ".filterBar {\n    grid-template-columns: repeat(2, minmax(0, 1fr));"
    );
    expect(stylesSource).toContain(".searchField {\n    grid-column: 1 / -1;");
    expect(stylesSource).toContain("@media (max-width: 860px)");
    expect(stylesSource).toContain(".statusTabs {\n    width: 100%;\n    flex-wrap: nowrap;");
    expect(stylesSource).toContain(".paginationActions {\n    justify-content: flex-start;");
  });

  it("keeps promo code status colors and overlays on semantic theme tokens", () => {
    const helperSource = readFileSync(promoCodesHelpersPath, "utf8");
    const listSource = readFileSync(promoCodesListCardPath, "utf8");
    const activationsSource = readFileSync(promoCodeActivationsCardPath, "utf8");
    const stylesSource = readFileSync(promoCodesStylesPath, "utf8");

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
    expect(stylesSource).not.toContain("rgba(");
    expect(stylesSource).not.toMatch(/#[0-9a-fA-F]{3,8}/);
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
    expect(activationsSource).not.toContain(
      '`${selectedCode.code || `${selectedCode.codePrefix}...`} · ${selectedStatusLabel ?? ""}`'
    );
  });
});
