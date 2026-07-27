import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const pageSource = readFileSync(new URL("./generations-page.tsx", import.meta.url), "utf8");
const rowSource = readFileSync(new URL("./generations-page.row.tsx", import.meta.url), "utf8");
const contentSource = readFileSync(
  new URL("./generations-page.content.ts", import.meta.url),
  "utf8"
);

describe("generation refund recovery UI", () => {
  it("shows backend refund metrics, filtering, and diagnostics", () => {
    expect(pageSource).toContain("generationMetrics?.pendingRefunds");
    expect(pageSource).toContain("generationMetrics?.exhaustedRefunds");
    expect(pageSource).toContain("status,\n        refundState,");
    expect(pageSource).toContain('setOptional("refundState", refundState, "all")');
    expect(rowSource).toContain("text.refundStateOptions[item.refundState]");
    expect(rowSource).toContain("item.refundAttemptCount");
    expect(rowSource).toContain("item.refundLastErrorCode");
  });

  it("exposes refund-only recovery only when the backend allows it", () => {
    expect(rowSource).toContain("item.canRetryRefund ? (");
    expect(rowSource).toContain("onRetryRefund(item.generationId)");
    expect(pageSource).toContain("retryAdminTemplateGenerationRefund");
    expect(pageSource).toContain("generation-refund:${createAdminCorrelationId()}");
    expect(pageSource).toContain("...pendingRefundRecovery");
    expect(pageSource).toContain(
      "confirmDisabled={!pendingRefundRecovery || !refundRecoveryReason.trim()}"
    );
    expect(pageSource).toContain("maxLength={GENERATION_REFUND_RETRY_REASON_MAX_LENGTH}");
    expect(contentSource).toContain("The balance is not changed directly");
    expect(pageSource).not.toContain("adjustAdminUserWallet");
    expect(pageSource).not.toContain("creditAdminUserWallet");
  });
});
