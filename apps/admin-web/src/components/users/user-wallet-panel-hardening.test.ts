import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const walletPanelPath = fileURLToPath(new URL("./user-wallet-panel.tsx", import.meta.url));
const detailPagePath = fileURLToPath(new URL("./user-detail-page.tsx", import.meta.url));
const inlineAnalyticsPath = fileURLToPath(new URL("./user-inline-analytics.tsx", import.meta.url));

describe("user wallet panel hardening", () => {
  it("sanitizes backend errors and wallet ledger details", () => {
    const source = readFileSync(walletPanelPath, "utf8");

    expect(source).toContain("import { getAdminErrorMessage }");
    expect(source).toContain("import { sanitizeSensitiveText }");
    expect(source).toContain("getAdminErrorMessage(error, text.walletOperationError)");
    expect(source).toContain("sanitizeSensitiveText(item.reason, 180)");
    expect(source).toContain("sanitizeSensitiveText(item.source, 80)");
    expect(source).not.toContain("<p>{item.reason}</p>");
    expect(source).not.toContain("<span>{item.source}</span>");
  });

  it("requires confirmation before manual wallet adjustments", () => {
    const source = readFileSync(walletPanelPath, "utf8");

    expect(source).toContain("import { ConfirmationDialog }");
    expect(source).toContain("USER_WALLET_REASON_MAX_LENGTH,");
    expect(source).toContain("canAdjustWallet: boolean;");
    expect(source).toContain("if (!canAdjustWallet || isSubmitting) {\n      return;");
    expect(source).toContain("if (!canAdjustWallet || !pendingAdjustment || isSubmitting) {");
    expect(source).toContain("type PendingWalletAdjustment");
    expect(source).toContain("const [pendingAdjustment, setPendingAdjustment]");
    expect(source).toContain("setPendingAdjustment({");
    expect(source).toContain(
      "const normalizedReason = reason.trim().slice(0, USER_WALLET_REASON_MAX_LENGTH);"
    );
    expect(source).toContain(
      "setReason(event.target.value.slice(0, USER_WALLET_REASON_MAX_LENGTH))"
    );
    expect(source).toContain("maxLength={USER_WALLET_REASON_MAX_LENGTH}");
    expect(source).toContain("async function confirmWalletAdjustment()");
    expect(source).toContain("await adjustAdminUserWallet(");
    expect(source).toContain("{canAdjustWallet ? (\n          <section");
    expect(source).toContain("open={canAdjustWallet && pendingAdjustment !== null}");
    expect(source).toContain("isSubmitting={isSubmitting}");
    expect(source).toContain("disabled={isSubmitting}");
    expect(source).not.toContain("await adjustAdminUserWallet(userId, operation, parsedAmount, normalizedReason)");
  });

  it("passes admin-role guard to every wallet adjustment panel usage", () => {
    const detailSource = readFileSync(detailPagePath, "utf8");
    const inlineSource = readFileSync(inlineAnalyticsPath, "utf8");

    expect(detailSource).toContain("canAdjustWallet={canViewUserProfile}");
    expect(inlineSource).toContain("canAdjustWallet={canViewUserProfile}");
  });
});
