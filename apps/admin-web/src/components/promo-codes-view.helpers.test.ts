import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import {
  buildPromoCodesCsv,
  formatCampaignMeta,
  getUserLabels,
  normalizePromoIntegerInput,
  toCreatePayload,
} from "@/components/promo-codes-view.helpers";
import type { AdminRedeemCode } from "@/lib/api-client";
import { getDictionary } from "@/lib/i18n";

const promoCodesViewPath = fileURLToPath(new URL("./promo-codes-view.tsx", import.meta.url));
const promoCodesListCardPath = fileURLToPath(
  new URL("./promo-codes-list-card.tsx", import.meta.url)
);
const promoCodeActivationsCardPath = fileURLToPath(
  new URL("./promo-code-activations-card.tsx", import.meta.url)
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
});

describe("promo code dangerous action hardening", () => {
  it("keeps archive confirmation open until the backend action succeeds", () => {
    const source = readFileSync(promoCodesViewPath, "utf8");

    expect(source).toContain('const canManagePromoCodes = session?.user.roles.includes("Admin") ?? false;');
    expect(source).toContain("function assertCanManagePromoCodes(): boolean");
    expect(source).toContain("setFeedback({ tone: \"danger\", message: promoCodesAdminOnlyMessage });");
    expect(source).toContain("if (!assertCanManagePromoCodes()) {\n      return;");
    expect(source).toContain("if (!assertCanManagePromoCodes()) {\n      return false;");
    expect(source).toContain("async function handleArchive(code: AdminRedeemCode): Promise<boolean>");
    expect(source).toContain("await archiveMutation.mutateAsync");
    expect(source).toContain("handleArchive(codePendingArchive).then((succeeded)");
    expect(source).toContain("function requestArchiveCode(code: AdminRedeemCode)");
    expect(source).toContain("onArchive={requestArchiveCode}");
    expect(source).not.toContain("setCodePendingArchive(code);\n        }}");
    expect(source).toContain("disabled={promoCodesQuery.isFetching}");
    expect(source).toContain("promoCodesQuery.refetch().catch(() => undefined)");
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
    expect(viewSource).toContain("function handleExport() {\n    if (!assertCanManagePromoCodes())");
    expect(viewSource).toContain("canManagePromoCodes={canManagePromoCodes}");
    expect(listCardSource).toContain("canManagePromoCodes: boolean;");
    expect(listCardSource).toContain("disabled={!hasFilteredCodes || !canManagePromoCodes}");
    expect(listCardSource).toContain(
      '<Button variant="primary" onClick={onOpenCreatePanel} disabled={!canManagePromoCodes}>'
    );
  });
});

describe("promo code activation data sourcing", () => {
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
    expect(source).not.toContain("code.description.trim() || \"-\"");
    expect(source).not.toContain("code.createdBy?.trim() || \"-\"");
  });

  it("sanitizes selected promo code labels and disables repeated activation retries", () => {
    const viewSource = readFileSync(promoCodesViewPath, "utf8");
    const activationsSource = readFileSync(promoCodeActivationsCardPath, "utf8");

    expect(viewSource).toContain("formatPromoDisplayText(\n                codePendingArchive.code || `${codePendingArchive.codePrefix}...`,\n                80");
    expect(viewSource).not.toContain("`${codePendingArchive.code}: ${text.promoCodesArchiveConfirm}`");
    expect(activationsSource).toContain("formatPromoDisplayText(selectedCode.code || `${selectedCode.codePrefix}...`, 80)");
    expect(activationsSource).toContain("disabled={activationsIsFetching}");
    expect(activationsSource).not.toContain(
      "`${selectedCode.code || `${selectedCode.codePrefix}...`} · ${selectedStatusLabel ?? \"\"}`"
    );
  });
});
