"use client";

import { useState } from "react";

import {
  AdminCard,
  AdminKpiCard,
  AdminMetricStrip,
  AdminStateCard,
} from "@/components/admin/admin-primitives";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import { Button } from "@/components/ui/button";
import styles from "@/components/users/user-wallet-panel.module.css";
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
  locale: Locale;
  userId: string;
  analytics: AdminUserAnalytics;
  canAdjustWallet: boolean;
  onUpdated?: () => Promise<void> | void;
};

const LEDGER_ITEMS_LIMIT = 20;

type PendingWalletAdjustment = {
  operation: "credit" | "debit";
  amount: number;
  reason: string;
};

export function UserWalletPanel({
  locale,
  userId,
  analytics,
  canAdjustWallet,
  onUpdated,
}: UserWalletPanelProps) {
  const text = getDictionary(locale);
  const [operation, setOperation] = useState<"credit" | "debit">("credit");
  const [amount, setAmount] = useState("50");
  const [reason, setReason] = useState("");
  const [pendingAdjustment, setPendingAdjustment] = useState<PendingWalletAdjustment | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [feedback, setFeedback] = useState<{ tone: "success" | "danger"; message: string } | null>(
    null
  );
  const parsedAmount = Number(amount);
  const normalizedReason = reason.trim().slice(0, USER_WALLET_REASON_MAX_LENGTH);
  const canSubmit =
    canAdjustWallet &&
    Number.isInteger(parsedAmount) &&
    parsedAmount > 0 &&
    normalizedReason.length > 0 &&
    !isSubmitting;

  function handleSubmit() {
    if (!canAdjustWallet || isSubmitting) {
      return;
    }

    if (!Number.isInteger(parsedAmount) || parsedAmount <= 0 || normalizedReason.length === 0) {
      setFeedback({ tone: "danger", message: text.walletOperationError });
      return;
    }

    setPendingAdjustment({
      operation,
      amount: parsedAmount,
      reason: normalizedReason,
    });
  }

  async function confirmWalletAdjustment() {
    if (!canAdjustWallet || !pendingAdjustment || isSubmitting) {
      return;
    }

    setIsSubmitting(true);
    setFeedback(null);

    try {
      await adjustAdminUserWallet(
        userId,
        pendingAdjustment.operation,
        pendingAdjustment.amount,
        pendingAdjustment.reason
      );
      setPendingAdjustment(null);
      setReason("");
      setFeedback({ tone: "success", message: text.walletOperationSaved });
      await onUpdated?.();
    } catch (error) {
      clientLogger.error("users.wallet_adjust_failed", {
        userId,
        operation: pendingAdjustment.operation,
        amount: pendingAdjustment.amount,
        error,
      });
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(error, text.walletOperationError),
      });
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

  return (
    <AdminCard title={text.userWalletTitle} description={text.userWalletDescription}>
      <div className={styles.kpiGrid}>
        <AdminKpiCard
          label={text.tokenBalanceLabel}
          value={String(analytics.summary.walletBalance)}
          tone="primary"
        />
        <AdminKpiCard
          label={text.tokensGrantedLabel}
          value={String(analytics.summary.totalTokensCredited)}
          tone="success"
        />
        <AdminKpiCard
          label={text.tokensSpentLabel}
          value={String(analytics.summary.totalTokensSpent)}
          tone="warning"
        />
        <AdminKpiCard
          label={text.viewsLabel}
          value={String(analytics.summary.totalViews)}
          hint={`${text.videoViewsLabel}: ${analytics.summary.totalVideoViews}`}
          tone="info"
        />
        <AdminKpiCard
          label={text.loginsLabel}
          value={String(analytics.summary.successfulLogins)}
          hint={`${text.failedLoginsLabel}: ${analytics.summary.failedLogins}`}
          tone="magenta"
        />
        <AdminKpiCard
          label={text.lastLoginLabel}
          value={formatDateTime(analytics.summary.lastLoginAtUtc, locale)}
          tone="neutral"
        />
      </div>

      <AdminMetricStrip
        className={styles.metrics}
        items={[
          { label: text.manualGrantLabel, value: analytics.summary.manualTokensGranted },
          { label: text.manualDebitLabel, value: analytics.summary.manualTokensDebited },
          { label: text.walletBalanceLabel, value: analytics.summary.walletBalance },
        ]}
      />

      <div className={styles.grid}>
        {canAdjustWallet ? (
          <section className={styles.controls}>
            <div className={styles.sectionHeader}>
              <h4>{text.walletAdjustmentTitle}</h4>
              <p>{text.walletAdjustmentHint}</p>
            </div>

            <div className={styles.formGrid}>
              <label className={styles.field}>
                <span>{text.walletOperationLabel}</span>
                <select
                  value={operation}
                  onChange={(event) => setOperation(event.target.value as "credit" | "debit")}
                  className={styles.select}
                  disabled={isSubmitting}
                >
                  <option value="credit">{text.walletOperationCredit}</option>
                  <option value="debit">{text.walletOperationDebit}</option>
                </select>
              </label>

              <label className={styles.field}>
                <span>{text.walletAmountLabel}</span>
                <input
                  value={amount}
                  onChange={(event) =>
                    setAmount(event.target.value.replace(/\D+/g, "").slice(0, 8))
                  }
                  inputMode="numeric"
                  maxLength={8}
                  className={styles.input}
                  disabled={isSubmitting}
                />
              </label>
            </div>

            <label className={styles.field}>
              <span>{text.walletReasonLabel}</span>
              <textarea
                value={reason}
                onChange={(event) =>
                  setReason(event.target.value.slice(0, USER_WALLET_REASON_MAX_LENGTH))
                }
                rows={3}
                maxLength={USER_WALLET_REASON_MAX_LENGTH}
                className={styles.textarea}
                placeholder={text.walletReasonPlaceholder}
                disabled={isSubmitting}
              />
            </label>

            <div className={styles.actions}>
              <Button type="button" onClick={() => void handleSubmit()} disabled={!canSubmit}>
                <span>{isSubmitting ? text.walletSaving : text.walletApplyAction}</span>
              </Button>
            </div>

            {feedback ? (
              <AdminStateCard
                tone={feedback.tone}
                title={feedback.message}
                className={styles.feedback}
              />
            ) : null}
          </section>
        ) : null}

        <section className={styles.ledger}>
          <div className={styles.sectionHeader}>
            <h4>{text.userWalletTitle}</h4>
            <p>{text.userWalletDescription}</p>
          </div>

          {analytics.recentWalletLedger.length ? (
            <div className={styles.list}>
              {analytics.recentWalletLedger.slice(0, LEDGER_ITEMS_LIMIT).map((item) => (
                <article key={item.entryId} className={styles.card}>
                  <div className={styles.cardHeader}>
                    <strong className={item.delta >= 0 ? styles.positive : styles.negative}>
                      {item.delta >= 0 ? "+" : ""}
                      {item.delta}
                    </strong>
                    <span>{formatDateTime(item.createdAtUtc, locale)}</span>
                  </div>
                  <p>{sanitizeSensitiveText(item.reason, 180)}</p>
                  <div className={styles.meta}>
                    <span>{sanitizeSensitiveText(item.source, 80)}</span>
                    <span>
                      {text.walletBalanceLabel}: {item.balanceAfter}
                    </span>
                  </div>
                </article>
              ))}
            </div>
          ) : (
            <AdminStateCard tone="info" title={text.userNoWalletActivity} />
          )}
        </section>
      </div>
      <ConfirmationDialog
        open={canAdjustWallet && pendingAdjustment !== null}
        title={text.walletConfirmTitle}
        description={pendingDescription}
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
