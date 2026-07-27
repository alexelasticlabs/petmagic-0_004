import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const walletPanelPath = fileURLToPath(new URL("./user-wallet-panel.tsx", import.meta.url));
const walletPanelStylesPath = fileURLToPath(
  new URL("./user-wallet-panel.module.css", import.meta.url)
);
const walletPresentationPath = fileURLToPath(
  new URL("./user-wallet-presentation.ts", import.meta.url)
);
const detailPagePath = fileURLToPath(new URL("./user-detail-page.tsx", import.meta.url));
const inlineAnalyticsPath = fileURLToPath(new URL("./user-inline-analytics.tsx", import.meta.url));

describe("user wallet panel hardening", () => {
  it("sanitizes backend errors and keeps technical wallet details out of the panel", () => {
    const source = readFileSync(walletPanelPath, "utf8");
    const presentationSource = readFileSync(walletPresentationPath, "utf8");

    expect(source).toContain("import { getAdminErrorMessage }");
    expect(source).toContain("import { sanitizeSensitiveText }");
    expect(source).toContain("getAdminErrorMessage(error, text.walletOperationError)");
    expect(source).toContain("function getWalletActionErrorDetails(error: unknown)");
    expect(source).toContain('errorName: error instanceof Error ? error.name : "UnknownError"');
    expect(source).toContain("userId: sanitizeSensitiveText(userId, 80)");
    expect(source).toContain("...getWalletActionErrorDetails(error)");
    expect(source).toContain("import { getUserWalletLedgerPresentation }");
    expect(source).toContain("getUserWalletLedgerPresentation(item, text)");
    expect(presentationSource).toContain("sanitizeSensitiveText(reason, 180)");
    expect(presentationSource).toContain('normalizedSource !== "admin_grant"');
    expect(presentationSource).toContain('normalizedSource !== "admin_debit"');
    expect(presentationSource).toContain("/^[a-z][a-z0-9_]*(?::[^\\s]*)?$/i.test(safeReason)");
    expect(source).not.toContain("userId,\n        operation: pendingAdjustment.operation");
    expect(source).not.toContain("amount: pendingAdjustment.amount,\n        error");
    expect(source).not.toContain("<p>{item.reason}</p>");
    expect(source).not.toContain("<span>{item.source}</span>");
    expect(source).not.toContain("{item.reason}");
    expect(source).not.toContain("{item.source}");
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
    expect(source).toContain("const [retryableAdjustment, setRetryableAdjustment]");
    expect(source).toContain("setPendingAdjustment({");
    expect(source).toContain("idempotencyKey: `wallet-adjustment:${createAdminCorrelationId()}`");
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
    expect(source).toContain(
      "async function submitWalletAdjustment(adjustment: PendingWalletAdjustment)"
    );
    expect(source).toContain("await adjustAdminUserWallet(");
    expect(source).toContain("adjustment.idempotencyKey");
    expect(source).toContain(
      '{canAdjustWallet ? (\n          <form id="wallet-adjustment" className={styles.controls} onSubmit={handleFormSubmit}>'
    );
    expect(source).toContain('<Button type="submit" disabled={!canSubmit}>');
    expect(source).not.toContain('<Button type="button" onClick={() => void handleSubmit()}');
    expect(source).toContain("open={canAdjustWallet && isWalletConfirmationOpen}");
    expect(source).toContain("isSubmitting={isSubmitting}");
    expect(source).toContain("disabled={isWalletFormLocked}");
    expect(source).toContain(
      "disabled={isSubmitting}\n                      onClick={() => void retryWalletRefresh()}"
    );
    expect(source).not.toContain(
      "await adjustAdminUserWallet(userId, operation, parsedAmount, normalizedReason)"
    );
  });

  it("validates the adjustment before confirmation and does not repeat a successful mutation when refresh fails", () => {
    const source = readFileSync(walletPanelPath, "utf8");

    expect(source).toContain("const hasSufficientBalance =");
    expect(source).toContain("const projectedBalance = hasValidAmount");
    expect(source).toContain("const walletValidationMessage = !hasValidAmount");
    expect(source).toContain("text.walletDebitBalanceHint");
    expect(source).toContain("text.walletBalanceBeforeLabel");
    expect(source).toContain("text.walletBalanceAfterLabel");
    expect(source).toContain("function retryWalletRefresh()");
    expect(source).toContain("function retryWalletAdjustment()");
    expect(source).toContain("void submitWalletAdjustment(retryableAdjustment);");
    expect(source).toContain('const WALLET_ADJUSTMENT_STORAGE_VERSION = "v2";');
    expect(source).toContain(
      "function getPendingWalletAdjustmentStorageKey(actorId: string, userId: string)"
    );
    expect(source).toContain("function persistPendingWalletAdjustment(\n  actorId: string,");
    expect(source).toContain(
      "function readPendingWalletAdjustment(actorId: string, userId: string)"
    );
    expect(source).toContain("persistPendingWalletAdjustment(actorId, userId, adjustment);");
    expect(source).toContain("clearPendingWalletAdjustment(actorId, userId);");
    expect(source).toContain("const recoveryScope = `${actorId}:${userId}`;");
    expect(source).toContain("function handleAdjustmentDraftChange()");
    expect(source).toContain("!retryableAdjustment &&");
    expect(source).toContain("setHasAttemptedAdjustment(false);");
    expect(source).toContain("text.walletPendingRecoveryWarning");
    expect(source).toContain('clientLogger.warn("users.wallet_adjust_refresh_failed"');
    expect(source).toContain('clientLogger.warn("users.wallet_refresh_failed"');
    expect(source).toContain("canRetryRefresh: Boolean(onUpdated)");
    expect(source).toContain("onClick={() => void retryWalletRefresh()}");
    expect(source).toContain("await adjustAdminUserWallet(");
    expect(source).toContain("try {\n      await onUpdated?.();");
    expect(source).toContain("canRetryAdjustment: true,");
    expect(source).toContain("setRetryableAdjustment(adjustment);");
    expect(source).toContain("onClick={retryWalletAdjustment}");
  });

  it("passes admin-role guard to every wallet adjustment panel usage", () => {
    const detailSource = readFileSync(detailPagePath, "utf8");
    const inlineSource = readFileSync(inlineAnalyticsPath, "utf8");

    expect(detailSource).toContain('actorId={session?.user.userId ?? ""}');
    expect(inlineSource).toContain('actorId={session?.user.userId ?? ""}');
    expect(detailSource).toContain("canAdjustWallet={canViewUserProfile}");
    expect(inlineSource).toContain("canAdjustWallet={canViewUserProfile}");
  });

  it("keeps wallet controls compact and usable on phone screens without duplicate KPI grids", () => {
    const walletSource = readFileSync(walletPanelPath, "utf8");
    const stylesSource = readFileSync(walletPanelStylesPath, "utf8");

    expect(walletSource).toContain("className={styles.walletSummary}");
    expect(walletSource).toContain("className={styles.currentBalance}");
    expect(walletSource).toContain("className={styles.balanceTotals}");
    expect(walletSource).not.toContain("AdminMetricStrip");
    expect(walletSource).not.toContain("kpiGrid");
    expect(stylesSource).toContain(".walletSummary {");
    expect(stylesSource).toContain(".gridLedgerOnly {");
    expect(stylesSource).not.toContain(".kpiGrid");
    expect(stylesSource).toContain("align-items: start;");
    expect(stylesSource).toContain("@media (max-width: 1080px)");
    expect(stylesSource).toContain(".controls {\n    order: -1;");
    expect(stylesSource).toContain(".adjustmentFields[hidden] {\n  display: none;");
    expect(stylesSource).toContain("@media (max-width: 560px)");
    expect(stylesSource).toContain("min-height: 2.75rem;");
    expect(stylesSource).toContain(".actions > * {\n    width: 100%;");
    expect(stylesSource).toContain(".cardHeader,\n  .meta");
    expect(stylesSource).toContain("grid-template-columns: minmax(0, 1fr);");
  });

  it("keeps the initial audit hint neutral and can focus the adjustment form from a quick action", () => {
    const source = readFileSync(walletPanelPath, "utf8");

    expect(source).toContain("autoFocusAdjustment?: boolean;");
    expect(source).toContain("onAdjustmentIntentDismissed?: () => void;");
    expect(source).toContain("const amountInputRef = useRef<HTMLInputElement>(null);");
    expect(source).toContain("const [adjustmentOpenOverride, setAdjustmentOpenOverride]");
    expect(source).toContain("adjustmentOpenOverride ?? (autoFocusAdjustment && canAdjustWallet)");
    expect(source).not.toContain("setIsAdjustmentOpen(true);");
    expect(source).toContain("amountInputRef.current?.focus();");
    expect(source).toContain('<form id="wallet-adjustment"');
    expect(source).toContain("const visibleWalletValidationMessage = shouldShowWalletValidation");
    expect(source).toContain('data-tone={visibleWalletValidationMessage ? "warning" : undefined}');
    expect(source).toContain("{visibleWalletValidationMessage ?? text.walletAdjustmentHint}");
    expect(source).toContain("onBlur={() => setHasTouchedReason(true)}");
    expect(source).toContain("setHasAttemptedAdjustment(true);");
    expect(source).toContain("setHasTouchedAmount(false);");
    expect(source).toContain("setHasTouchedReason(false);");
    expect(source).toContain("function toggleAdjustmentFields()");
    expect(source).toContain("onAdjustmentIntentDismissed?.();");
    expect(source).not.toContain('className={styles.balancePreview} aria-live="polite"');
  });

  it("uses an inline empty ledger state instead of nesting a second state card", () => {
    const source = readFileSync(walletPanelPath, "utf8");
    const stylesSource = readFileSync(walletPanelStylesPath, "utf8");

    expect(source).toContain('className={styles.emptyLedger} role="status"');
    expect(source).not.toContain('tone="info" title={text.userNoWalletActivity}');
    expect(stylesSource).toContain(".emptyLedger {");
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
