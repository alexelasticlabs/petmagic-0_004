"use client";

import { useEffect, useRef, useState, type FormEvent } from "react";

import { AdminCard, AdminStateCard } from "@/components/admin/admin-primitives";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import { Button } from "@/components/ui/button";
import { Select } from "@/components/ui/select";
import styles from "@/components/users/user-wallet-panel.module.css";
import { getUserWalletLedgerPresentation } from "@/components/users/user-wallet-presentation";
import { createAdminCorrelationId } from "@/lib/admin-correlation-id";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import {
  adjustAdminUserWallet,
  USER_WALLET_REASON_MAX_LENGTH,
  type AdminUserAnalytics,
} from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { formatDateTime } from "@/lib/format-date-time";
import { getDictionary, type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type UserWalletPanelProps = {
  actorId: string;
  locale: Locale;
  userId: string;
  analytics: AdminUserAnalytics;
  canAdjustWallet: boolean;
  autoFocusAdjustment?: boolean;
  onAdjustmentIntentDismissed?: () => void;
  onUpdated?: () => Promise<void> | void;
};

const LEDGER_ITEMS_LIMIT = 20;
const WALLET_ADJUSTMENT_STORAGE_VERSION = "v2";
const WALLET_ADJUSTMENT_STORAGE_TTL_MS = 30 * 60_000;

type PendingWalletAdjustment = {
  operation: "credit" | "debit";
  amount: number;
  reason: string;
  idempotencyKey: string;
};

type StoredPendingWalletAdjustment = PendingWalletAdjustment & {
  createdAtEpochMs: number;
};

type WalletAdjustmentRecovery = PendingWalletAdjustment | null;

type WalletFeedback = {
  canRetryAdjustment?: boolean;
  canRetryRefresh?: boolean;
  message: string;
  tone: "danger" | "success" | "warning";
};

function getWalletActionErrorDetails(error: unknown) {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorDigest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

function getPendingWalletAdjustmentStorageKey(actorId: string, userId: string): string | null {
  const normalizedActorId = actorId.trim();
  if (!normalizedActorId) {
    return null;
  }

  return `petmagic.admin.wallet.adjustment:${WALLET_ADJUSTMENT_STORAGE_VERSION}:${encodeURIComponent(normalizedActorId)}:${encodeURIComponent(userId)}`;
}

function isStoredPendingWalletAdjustment(value: unknown): value is StoredPendingWalletAdjustment {
  if (!value || typeof value !== "object") {
    return false;
  }

  const candidate = value as Partial<StoredPendingWalletAdjustment>;
  return (
    (candidate.operation === "credit" || candidate.operation === "debit") &&
    typeof candidate.amount === "number" &&
    Number.isInteger(candidate.amount) &&
    candidate.amount > 0 &&
    typeof candidate.reason === "string" &&
    candidate.reason.trim().length > 0 &&
    candidate.reason.length <= USER_WALLET_REASON_MAX_LENGTH &&
    typeof candidate.idempotencyKey === "string" &&
    candidate.idempotencyKey.length > 0 &&
    typeof candidate.createdAtEpochMs === "number" &&
    Number.isFinite(candidate.createdAtEpochMs)
  );
}

function readPendingWalletAdjustment(actorId: string, userId: string): WalletAdjustmentRecovery {
  if (typeof window === "undefined") {
    return null;
  }

  const storageKey = getPendingWalletAdjustmentStorageKey(actorId, userId);
  if (!storageKey) {
    return null;
  }

  try {
    const rawValue = window.sessionStorage.getItem(storageKey);
    if (!rawValue) {
      return null;
    }

    const storedAdjustment: unknown = JSON.parse(rawValue);
    const isExpired =
      isStoredPendingWalletAdjustment(storedAdjustment) &&
      Date.now() - storedAdjustment.createdAtEpochMs > WALLET_ADJUSTMENT_STORAGE_TTL_MS;

    if (!isStoredPendingWalletAdjustment(storedAdjustment) || isExpired) {
      window.sessionStorage.removeItem(storageKey);
      return null;
    }

    return {
      operation: storedAdjustment.operation,
      amount: storedAdjustment.amount,
      reason: storedAdjustment.reason,
      idempotencyKey: storedAdjustment.idempotencyKey,
    };
  } catch {
    return null;
  }
}

function persistPendingWalletAdjustment(
  actorId: string,
  userId: string,
  adjustment: PendingWalletAdjustment
): void {
  if (typeof window === "undefined") {
    return;
  }

  const storageKey = getPendingWalletAdjustmentStorageKey(actorId, userId);
  if (!storageKey) {
    return;
  }

  try {
    const storedAdjustment: StoredPendingWalletAdjustment = {
      ...adjustment,
      createdAtEpochMs: Date.now(),
    };
    window.sessionStorage.setItem(storageKey, JSON.stringify(storedAdjustment));
  } catch {
    // Browser storage can be unavailable in private or restricted contexts.
  }
}

function clearPendingWalletAdjustment(actorId: string, userId: string): void {
  if (typeof window === "undefined") {
    return;
  }

  const storageKey = getPendingWalletAdjustmentStorageKey(actorId, userId);
  if (!storageKey) {
    return;
  }

  try {
    window.sessionStorage.removeItem(storageKey);
  } catch {
    // Browser storage can be unavailable in private or restricted contexts.
  }
}

export function UserWalletPanel({
  actorId,
  locale,
  userId,
  analytics,
  canAdjustWallet,
  autoFocusAdjustment = false,
  onAdjustmentIntentDismissed,
  onUpdated,
}: UserWalletPanelProps) {
  const text = getDictionary(locale);
  const [operation, setOperation] = useState<"credit" | "debit">("credit");
  const [amount, setAmount] = useState("50");
  const [reason, setReason] = useState("");
  const [adjustmentOpenOverride, setAdjustmentOpenOverride] = useState<boolean | null>(null);
  const [pendingAdjustment, setPendingAdjustment] = useState<PendingWalletAdjustment | null>(null);
  const [retryableAdjustment, setRetryableAdjustment] = useState<PendingWalletAdjustment | null>(
    null
  );
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [feedback, setFeedback] = useState<WalletFeedback | null>(null);
  const [hasAttemptedAdjustment, setHasAttemptedAdjustment] = useState(false);
  const [hasTouchedAmount, setHasTouchedAmount] = useState(false);
  const [hasTouchedReason, setHasTouchedReason] = useState(false);
  const amountInputRef = useRef<HTMLInputElement>(null);
  const recoveredWalletScopeRef = useRef<string | null>(null);
  const parsedAmount = Number(amount);
  const normalizedReason = reason.trim().slice(0, USER_WALLET_REASON_MAX_LENGTH);
  const isWalletConfirmationOpen = pendingAdjustment !== null;
  const isWalletFormLocked = isSubmitting || isWalletConfirmationOpen;
  const hasValidAmount = Number.isInteger(parsedAmount) && parsedAmount > 0;
  const hasSufficientBalance =
    operation !== "debit" || (hasValidAmount && parsedAmount <= analytics.summary.walletBalance);
  const projectedBalance = hasValidAmount
    ? analytics.summary.walletBalance + (operation === "credit" ? parsedAmount : -parsedAmount)
    : analytics.summary.walletBalance;
  const walletValidationMessage = !hasValidAmount
    ? text.walletAmountInvalidHint
    : !hasSufficientBalance
      ? text.walletDebitBalanceHint
      : normalizedReason.length === 0
        ? text.walletReasonRequiredHint
        : null;
  const shouldShowWalletValidation =
    hasAttemptedAdjustment ||
    ((!hasValidAmount || !hasSufficientBalance) && hasTouchedAmount) ||
    (normalizedReason.length === 0 && hasTouchedReason);
  const visibleWalletValidationMessage = shouldShowWalletValidation
    ? walletValidationMessage
    : null;
  const canSubmit =
    canAdjustWallet &&
    hasValidAmount &&
    hasSufficientBalance &&
    normalizedReason.length > 0 &&
    !retryableAdjustment &&
    !isWalletFormLocked;
  const isAdjustmentOpen = adjustmentOpenOverride ?? (autoFocusAdjustment && canAdjustWallet);

  useEffect(() => {
    if (autoFocusAdjustment && canAdjustWallet && isAdjustmentOpen) {
      amountInputRef.current?.focus();
    }
  }, [autoFocusAdjustment, canAdjustWallet, isAdjustmentOpen]);

  useEffect(() => {
    const recoveryScope = `${actorId}:${userId}`;
    if (!canAdjustWallet || !actorId.trim() || recoveredWalletScopeRef.current === recoveryScope) {
      return;
    }

    recoveredWalletScopeRef.current = recoveryScope;
    const recoveredAdjustment = readPendingWalletAdjustment(actorId, userId);
    if (!recoveredAdjustment) {
      return;
    }

    const recoveryTimer = window.setTimeout(() => {
      if (recoveredWalletScopeRef.current !== recoveryScope) {
        return;
      }

      setOperation(recoveredAdjustment.operation);
      setAmount(String(recoveredAdjustment.amount));
      setReason(recoveredAdjustment.reason);
      setRetryableAdjustment(recoveredAdjustment);
      setAdjustmentOpenOverride(true);
      setFeedback({
        tone: "warning",
        message: text.walletPendingRecoveryWarning,
        canRetryAdjustment: true,
      });
    }, 0);

    return () => window.clearTimeout(recoveryTimer);
  }, [actorId, canAdjustWallet, text.walletPendingRecoveryWarning, userId]);

  function discardRetryableAdjustment() {
    setRetryableAdjustment(null);
    clearPendingWalletAdjustment(actorId, userId);
  }

  function handleAdjustmentDraftChange() {
    setFeedback(null);
    discardRetryableAdjustment();
  }

  function handleSubmit() {
    if (!canAdjustWallet || isWalletFormLocked) {
      return;
    }

    if (retryableAdjustment) {
      setFeedback({
        tone: "warning",
        message: text.walletPendingRecoveryWarning,
        canRetryAdjustment: true,
      });
      return;
    }

    setHasAttemptedAdjustment(true);

    if (!canSubmit) {
      setFeedback({
        tone: "danger",
        message: walletValidationMessage ?? text.walletOperationError,
      });
      return;
    }

    setPendingAdjustment({
      operation,
      amount: parsedAmount,
      reason: normalizedReason,
      idempotencyKey: `wallet-adjustment:${createAdminCorrelationId()}`,
    });
    discardRetryableAdjustment();
  }

  function handleFormSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    handleSubmit();
  }

  function toggleAdjustmentFields() {
    const nextIsOpen = !isAdjustmentOpen;
    setAdjustmentOpenOverride(nextIsOpen);

    if (!nextIsOpen && autoFocusAdjustment) {
      onAdjustmentIntentDismissed?.();
    }
  }

  async function confirmWalletAdjustment() {
    if (!canAdjustWallet || !pendingAdjustment || isSubmitting) {
      return;
    }

    await submitWalletAdjustment(pendingAdjustment);
  }

  async function submitWalletAdjustment(adjustment: PendingWalletAdjustment) {
    setIsSubmitting(true);
    setFeedback(null);
    persistPendingWalletAdjustment(actorId, userId, adjustment);

    try {
      await adjustAdminUserWallet(
        userId,
        adjustment.operation,
        adjustment.amount,
        adjustment.reason,
        adjustment.idempotencyKey
      );
    } catch (error) {
      clientLogger.error("users.wallet_adjust_failed", {
        userId: sanitizeSensitiveText(userId, 80),
        operation: adjustment.operation,
        amount: adjustment.amount,
        ...getWalletActionErrorDetails(error),
      });
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(error, text.walletOperationError),
        canRetryAdjustment: true,
      });
      setRetryableAdjustment(adjustment);
      setPendingAdjustment(null);
      setIsSubmitting(false);
      return;
    }

    setPendingAdjustment(null);
    setRetryableAdjustment(null);
    clearPendingWalletAdjustment(actorId, userId);
    setReason("");
    setHasAttemptedAdjustment(false);
    setHasTouchedAmount(false);
    setHasTouchedReason(false);

    try {
      await onUpdated?.();
      setFeedback({ tone: "success", message: text.walletOperationSaved });
    } catch (error) {
      clientLogger.warn("users.wallet_adjust_refresh_failed", {
        userId: sanitizeSensitiveText(userId, 80),
        operation: adjustment.operation,
        amount: adjustment.amount,
        ...getWalletActionErrorDetails(error),
      });
      setFeedback({
        tone: "warning",
        message: text.walletRefreshWarning,
        canRetryRefresh: Boolean(onUpdated),
      });
    } finally {
      setIsSubmitting(false);
    }
  }

  function retryWalletAdjustment() {
    if (!retryableAdjustment || isSubmitting) {
      return;
    }

    void submitWalletAdjustment(retryableAdjustment);
  }

  async function retryWalletRefresh() {
    if (!onUpdated || isSubmitting) {
      return;
    }

    setIsSubmitting(true);
    setFeedback(null);

    try {
      await onUpdated();
      setFeedback({ tone: "success", message: text.walletOperationSaved });
    } catch (error) {
      clientLogger.warn("users.wallet_refresh_failed", {
        userId: sanitizeSensitiveText(userId, 80),
        ...getWalletActionErrorDetails(error),
      });
      setFeedback({ tone: "warning", message: text.walletRefreshWarning, canRetryRefresh: true });
    } finally {
      setIsSubmitting(false);
    }
  }

  const pendingOperationLabel =
    pendingAdjustment?.operation === "debit"
      ? text.walletOperationDebit
      : text.walletOperationCredit;
  const pendingDescription = pendingAdjustment
    ? text.walletConfirmDescription
        .replace("{operation}", pendingOperationLabel)
        .replace("{amount}", String(pendingAdjustment.amount))
        .replace("{reason}", sanitizeSensitiveText(pendingAdjustment.reason, 120))
    : "";
  const pendingBalanceAfter = pendingAdjustment
    ? analytics.summary.walletBalance +
      (pendingAdjustment.operation === "credit"
        ? pendingAdjustment.amount
        : -pendingAdjustment.amount)
    : analytics.summary.walletBalance;

  return (
    <AdminCard title={text.userWalletTitle} description={text.userWalletDescription}>
      <section className={styles.walletSummary} aria-label={text.userWalletTitle}>
        <div className={styles.currentBalance}>
          <span>{text.walletBalanceLabel}</span>
          <strong>
            {analytics.summary.walletBalance} <small>PawSpark</small>
          </strong>
        </div>
        <dl className={styles.balanceTotals}>
          <div>
            <dt>{text.tokensGrantedLabel}</dt>
            <dd>{analytics.summary.totalTokensCredited}</dd>
          </div>
          <div>
            <dt>{text.tokensSpentLabel}</dt>
            <dd>{analytics.summary.totalTokensSpent}</dd>
          </div>
        </dl>
      </section>

      <div className={`${styles.grid} ${!canAdjustWallet ? styles.gridLedgerOnly : ""}`}>
        <section className={styles.ledger}>
          <div className={styles.sectionHeader}>
            <h3>{text.walletRecentActivityTitle}</h3>
            <p>{text.walletRecentActivityDescription}</p>
          </div>

          {analytics.recentWalletLedger.length ? (
            <div className={styles.list}>
              {analytics.recentWalletLedger.slice(0, LEDGER_ITEMS_LIMIT).map((item) => {
                const presentation = getUserWalletLedgerPresentation(item, text);

                return (
                  <article key={item.entryId} className={styles.card}>
                    <div className={styles.cardHeader}>
                      <strong className={item.delta >= 0 ? styles.positive : styles.negative}>
                        {item.delta >= 0 ? "+" : ""}
                        {item.delta}
                      </strong>
                      <span>{formatDateTime(item.createdAtUtc, locale)}</span>
                    </div>
                    <p className={styles.operationLabel}>{presentation.operationLabel}</p>
                    {presentation.note ? <p className={styles.note}>{presentation.note}</p> : null}
                    <div className={styles.meta}>
                      <span>
                        {text.walletBalanceLabel}: {item.balanceAfter}
                      </span>
                    </div>
                  </article>
                );
              })}
            </div>
          ) : (
            <div className={styles.emptyLedger} role="status">
              <strong>{text.userNoWalletActivity}</strong>
            </div>
          )}
        </section>

        {canAdjustWallet ? (
          <form id="wallet-adjustment" className={styles.controls} onSubmit={handleFormSubmit}>
            <div className={styles.adjustmentHeader}>
              <div className={styles.sectionHeader}>
                <h3>{text.walletAdjustmentTitle}</h3>
                <p>{text.walletAdjustmentHint}</p>
              </div>
              <Button
                type="button"
                variant={isAdjustmentOpen ? "secondary" : "primary"}
                size="sm"
                className={styles.adjustmentToggle}
                aria-controls="wallet-adjustment-fields"
                aria-expanded={isAdjustmentOpen}
                disabled={isWalletFormLocked}
                onClick={toggleAdjustmentFields}
              >
                {isAdjustmentOpen
                  ? text.walletAdjustmentCloseAction
                  : text.walletAdjustmentOpenAction}
              </Button>
            </div>

            <div
              id="wallet-adjustment-fields"
              className={styles.adjustmentFields}
              hidden={!isAdjustmentOpen}
            >
              <div className={styles.formGrid}>
                <div className={`${styles.field} ${styles.operationField}`}>
                  <span>{text.walletOperationLabel}</span>
                  <Select
                    value={operation}
                    options={[
                      { value: "credit", label: text.walletOperationCredit },
                      { value: "debit", label: text.walletOperationDebit },
                    ]}
                    onChange={(value) => {
                      setOperation(value as "credit" | "debit");
                      handleAdjustmentDraftChange();
                    }}
                    ariaLabel={text.walletOperationLabel}
                    showSelectedDescription={false}
                    disabled={isWalletFormLocked}
                  />
                </div>

                <label className={styles.field}>
                  <span>{text.walletAmountLabel}</span>
                  <input
                    ref={amountInputRef}
                    value={amount}
                    onChange={(event) => {
                      setAmount(event.target.value.replace(/\D+/g, "").slice(0, 8));
                      handleAdjustmentDraftChange();
                    }}
                    onBlur={() => setHasTouchedAmount(true)}
                    inputMode="numeric"
                    maxLength={8}
                    className={styles.input}
                    aria-describedby="wallet-adjustment-feedback"
                    aria-invalid={
                      (hasAttemptedAdjustment || hasTouchedAmount) &&
                      (!hasValidAmount || !hasSufficientBalance)
                    }
                    disabled={isWalletFormLocked}
                  />
                </label>
              </div>

              <label className={styles.field}>
                <span>{text.walletReasonLabel}</span>
                <textarea
                  value={reason}
                  onChange={(event) => {
                    setReason(event.target.value.slice(0, USER_WALLET_REASON_MAX_LENGTH));
                    handleAdjustmentDraftChange();
                  }}
                  onBlur={() => setHasTouchedReason(true)}
                  rows={3}
                  maxLength={USER_WALLET_REASON_MAX_LENGTH}
                  className={styles.textarea}
                  placeholder={text.walletReasonPlaceholder}
                  aria-describedby="wallet-adjustment-feedback"
                  aria-invalid={
                    (hasAttemptedAdjustment || hasTouchedReason) && normalizedReason.length === 0
                  }
                  disabled={isWalletFormLocked}
                />
              </label>

              <div className={styles.balancePreview}>
                <span>
                  {text.walletBalanceBeforeLabel}: {analytics.summary.walletBalance} PawSpark
                </span>
                <strong>
                  {text.walletBalanceAfterLabel}: {projectedBalance} PawSpark
                </strong>
              </div>

              <p
                id="wallet-adjustment-feedback"
                className={styles.validationHint}
                aria-live="polite"
                data-tone={visibleWalletValidationMessage ? "warning" : undefined}
              >
                {visibleWalletValidationMessage ?? text.walletAdjustmentHint}
              </p>

              <div className={styles.actions}>
                <Button type="submit" disabled={!canSubmit}>
                  <span>{isSubmitting ? text.walletSaving : text.walletApplyAction}</span>
                </Button>
              </div>
            </div>

            {feedback ? (
              <AdminStateCard
                tone={feedback.tone}
                title={feedback.message}
                className={styles.feedback}
                action={
                  feedback.canRetryAdjustment ? (
                    <Button
                      variant="secondary"
                      size="sm"
                      disabled={isSubmitting}
                      onClick={retryWalletAdjustment}
                    >
                      {text.supportRetryAction}
                    </Button>
                  ) : feedback.canRetryRefresh ? (
                    <Button
                      variant="secondary"
                      size="sm"
                      disabled={isSubmitting}
                      onClick={() => void retryWalletRefresh()}
                    >
                      {text.supportRetryAction}
                    </Button>
                  ) : undefined
                }
              />
            ) : null}
          </form>
        ) : null}
      </div>
      <ConfirmationDialog
        open={canAdjustWallet && isWalletConfirmationOpen}
        title={text.walletConfirmTitle}
        description={
          pendingAdjustment
            ? `${pendingDescription} ${text.walletBalanceAfterLabel}: ${pendingBalanceAfter} PawSpark.`
            : pendingDescription
        }
        confirmLabel={isSubmitting ? text.walletSaving : text.walletApplyAction}
        cancelLabel={text.walletConfirmCancel}
        isSubmitting={isSubmitting}
        tone={pendingAdjustment?.operation === "debit" ? "danger" : "primary"}
        onCancel={() => {
          if (!isSubmitting) {
            setPendingAdjustment(null);
          }
        }}
        onConfirm={() => void confirmWalletAdjustment()}
      />
    </AdminCard>
  );
}
