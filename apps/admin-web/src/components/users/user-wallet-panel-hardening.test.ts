import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const walletPanelPath = fileURLToPath(new URL("./user-wallet-panel.tsx", import.meta.url));
const walletPanelStylesPath = fileURLToPath(
  new URL("./user-wallet-panel.module.css", import.meta.url)
);
const detailPagePath = fileURLToPath(new URL("./user-detail-page.tsx", import.meta.url));
const inlineAnalyticsPath = fileURLToPath(new URL("./user-inline-analytics.tsx", import.meta.url));

describe("user wallet panel hardening", () => {
  it("sanitizes backend errors and wallet ledger details", () => {
    const source = readFileSync(walletPanelPath, "utf8");

    expect(source).toContain("import { getAdminErrorMessage }");
    expect(source).toContain("import { sanitizeSensitiveText }");
    expect(source).toContain("getAdminErrorMessage(error, text.walletOperationError)");
    expect(source).toContain("function getWalletActionErrorDetails(error: unknown)");
    expect(source).toContain('errorName: error instanceof Error ? error.name : "UnknownError"');
    expect(source).toContain("userId: sanitizeSensitiveText(userId, 80)");
    expect(source).toContain("...getWalletActionErrorDetails(error)");
    expect(source).toContain("sanitizeSensitiveText(item.reason, 180)");
    expect(source).toContain("sanitizeSensitiveText(item.source, 80)");
    expect(source).not.toContain("userId,\n        operation: pendingAdjustment.operation");
    expect(source).not.toContain("amount: pendingAdjustment.amount,\n        error");
    expect(source).not.toContain("<p>{item.reason}</p>");
    expect(source).not.toContain("<span>{item.source}</span>");
  });

  it("requires confirmation before manual wallet adjustments", () => {
    const source = readFileSync(walletPanelPath, "utf8");

    expect(source).toContain("import { ConfirmationDialog }");
    expect(source).toContain("USER_WALLET_REASON_MAX_LENGTH,");
    expect(source).toContain("canAdjustWallet: boolean;");
    expect(source).toContain("if (!canAdjustWallet || isWalletFormLocked) {\n      return;");
    expect(source).toContain("if (!canAdjustWallet || !pendingAdjustment || isSubmitting) {");
    expect(source).toContain("type FormEvent");
    expect(source).toContain("function handleFormSubmit(event: FormEvent<HTMLFormElement>)");
    expect(source).toContain("event.preventDefault();\n    handleSubmit();");
    expect(source).toContain("type PendingWalletAdjustment");
    expect(source).toContain("const [pendingAdjustment, setPendingAdjustment]");
    expect(source).toContain("setPendingAdjustment({");
    expect(source).toContain("const isWalletConfirmationOpen = pendingAdjustment !== null;");
    expect(source).toContain(
      "const isWalletFormLocked = isSubmitting || isWalletConfirmationOpen;"
    );
    expect(source).toContain("!isWalletFormLocked");
    expect(source).toContain(
      "const normalizedReason = reason.trim().slice(0, USER_WALLET_REASON_MAX_LENGTH);"
    );
    expect(source).toContain(
      "setReason(event.target.value.slice(0, USER_WALLET_REASON_MAX_LENGTH))"
    );
    expect(source).toContain("maxLength={USER_WALLET_REASON_MAX_LENGTH}");
    expect(source).toContain("async function confirmWalletAdjustment()");
    expect(source).toContain("await adjustAdminUserWallet(");
    expect(source).toContain(
      "{canAdjustWallet ? (\n          <form className={styles.controls} onSubmit={handleFormSubmit}>"
    );
    expect(source).toContain('<Button type="submit" disabled={!canSubmit}>');
    expect(source).not.toContain('<Button type="button" onClick={() => void handleSubmit()}');
    expect(source).toContain("open={canAdjustWallet && isWalletConfirmationOpen}");
    expect(source).toContain("isSubmitting={isSubmitting}");
    expect(source).toContain("disabled={isWalletFormLocked}");
    expect(source).not.toContain("disabled={isSubmitting}");
    expect(source).not.toContain(
      "await adjustAdminUserWallet(userId, operation, parsedAmount, normalizedReason)"
    );
  });

  it("passes admin-role guard to every wallet adjustment panel usage", () => {
    const detailSource = readFileSync(detailPagePath, "utf8");
    const inlineSource = readFileSync(inlineAnalyticsPath, "utf8");

    expect(detailSource).toContain("canAdjustWallet={canViewUserProfile}");
    expect(inlineSource).toContain("canAdjustWallet={canViewUserProfile}");
  });

  it("keeps wallet controls and ledger cards usable on phone screens", () => {
    const stylesSource = readFileSync(walletPanelStylesPath, "utf8");

    expect(stylesSource).toContain("@media (max-width: 560px)");
    expect(stylesSource).toContain(".kpiGrid {\n    grid-template-columns: minmax(0, 1fr);");
    expect(stylesSource).toContain(".actions > * {\n    width: 100%;");
    expect(stylesSource).toContain(".cardHeader,\n  .meta");
    expect(stylesSource).toContain("grid-template-columns: minmax(0, 1fr);");
  });

  it("keeps wallet balance deltas readable in light and dark themes", () => {
    const stylesSource = readFileSync(walletPanelStylesPath, "utf8");

    expect(stylesSource).toContain(
      ".positive {\n  color: color-mix(in srgb, var(--success) 82%, var(--text-strong));"
    );
    expect(stylesSource).toContain(
      ".negative {\n  color: color-mix(in srgb, var(--danger) 86%, var(--text-strong));"
    );
    expect(stylesSource).not.toMatch(/#[0-9a-fA-F]{3,8}/);
  });
});
