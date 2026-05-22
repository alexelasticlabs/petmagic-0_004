"use client";

import { useState } from "react";

import { AdminCard, AdminKpiCard, AdminMetricStrip, AdminStateCard } from "@/components/admin/admin-primitives";
import { Button } from "@/components/ui/button";
import styles from "@/components/users/user-wallet-panel.module.css";
import {
  adjustAdminUserWallet,
  type AdminUserAnalytics,
} from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import { getDictionary, type Locale } from "@/lib/i18n";

type UserWalletPanelProps = {
  locale: Locale;
  userId: string;
  analytics: AdminUserAnalytics;
  onUpdated?: () => Promise<void> | void;
};

export function UserWalletPanel({ locale, userId, analytics, onUpdated }: UserWalletPanelProps) {
  const text = getDictionary(locale);
  const [operation, setOperation] = useState<"credit" | "debit">("credit");
  const [amount, setAmount] = useState("50");
  const [reason, setReason] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [feedback, setFeedback] = useState<{ tone: "success" | "danger"; message: string } | null>(null);

  async function handleSubmit() {
    const parsedAmount = Number(amount);
    if (!Number.isInteger(parsedAmount) || parsedAmount <= 0 || !reason.trim()) {
      setFeedback({ tone: "danger", message: text.walletOperationError });
      return;
    }

    setIsSubmitting(true);
    setFeedback(null);

    try {
      await adjustAdminUserWallet(userId, operation, parsedAmount, reason.trim());
      setReason("");
      setFeedback({ tone: "success", message: text.walletOperationSaved });
      await onUpdated?.();
    } catch {
      setFeedback({ tone: "danger", message: text.walletOperationError });
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <AdminCard title={text.userWalletTitle} description={text.userWalletDescription}>
      <div className={styles.kpiGrid}>
        <AdminKpiCard label={text.tokenBalanceLabel} value={String(analytics.summary.walletBalance)} tone="primary" />
        <AdminKpiCard label={text.tokensGrantedLabel} value={String(analytics.summary.totalTokensCredited)} tone="success" />
        <AdminKpiCard label={text.tokensSpentLabel} value={String(analytics.summary.totalTokensSpent)} tone="warning" />
        <AdminKpiCard label={text.viewsLabel} value={String(analytics.summary.totalViews)} hint={`${text.videoViewsLabel}: ${analytics.summary.totalVideoViews}`} tone="info" />
        <AdminKpiCard label={text.loginsLabel} value={String(analytics.summary.successfulLogins)} hint={`${text.failedLoginsLabel}: ${analytics.summary.failedLogins}`} tone="magenta" />
        <AdminKpiCard label={text.lastLoginLabel} value={formatDateTime(analytics.summary.lastLoginAtUtc, locale)} tone="neutral" />
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
        <section className={styles.controls}>
          <div className={styles.sectionHeader}>
            <h4>{text.walletAdjustmentTitle}</h4>
            <p>{text.walletAdjustmentHint}</p>
          </div>

          <div className={styles.formGrid}>
            <label className={styles.field}>
              <span>{text.walletOperationLabel}</span>
              <select value={operation} onChange={(event) => setOperation(event.target.value as "credit" | "debit")} className={styles.select}>
                <option value="credit">{text.walletOperationCredit}</option>
                <option value="debit">{text.walletOperationDebit}</option>
              </select>
            </label>

            <label className={styles.field}>
              <span>{text.walletAmountLabel}</span>
              <input value={amount} onChange={(event) => setAmount(event.target.value)} inputMode="numeric" className={styles.input} />
            </label>
          </div>

          <label className={styles.field}>
            <span>{text.walletReasonLabel}</span>
            <textarea value={reason} onChange={(event) => setReason(event.target.value)} rows={3} className={styles.textarea} placeholder={text.walletReasonPlaceholder} />
          </label>

          <div className={styles.actions}>
            <Button type="button" onClick={() => void handleSubmit()} disabled={isSubmitting}>
              <span>{isSubmitting ? text.walletSaving : text.walletApplyAction}</span>
            </Button>
          </div>

          {feedback ? <AdminStateCard tone={feedback.tone} title={feedback.message} className={styles.feedback} /> : null}
        </section>

        <section className={styles.ledger}>
          <div className={styles.sectionHeader}>
            <h4>{text.userWalletTitle}</h4>
            <p>{text.userWalletDescription}</p>
          </div>

          {analytics.recentWalletLedger.length ? (
            <div className={styles.list}>
              {analytics.recentWalletLedger.map((item) => (
                <article key={item.entryId} className={styles.card}>
                  <div className={styles.cardHeader}>
                    <strong className={item.delta >= 0 ? styles.positive : styles.negative}>
                      {item.delta >= 0 ? "+" : ""}{item.delta}
                    </strong>
                    <span>{formatDateTime(item.createdAtUtc, locale)}</span>
                  </div>
                  <p>{item.reason}</p>
                  <div className={styles.meta}>
                    <span>{item.source}</span>
                    <span>{text.walletBalanceLabel}: {item.balanceAfter}</span>
                  </div>
                </article>
              ))}
            </div>
          ) : (
            <AdminStateCard tone="info" title={text.userNoWalletActivity} />
          )}
        </section>
      </div>
    </AdminCard>
  );
}
