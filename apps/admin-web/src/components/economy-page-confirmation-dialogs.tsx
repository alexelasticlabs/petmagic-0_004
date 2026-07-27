"use client";

import { useRef } from "react";

import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import { type EconomyPageText } from "@/components/economy-page.content";
import styles from "@/components/economy-page.module.css";
import { formatCurrency, safeText, shortGuid } from "@/components/economy-page.shared";
import { type AdminEconomyPurchase, type AdminEconomySubscription } from "@/lib/api-client";
import { ADMIN_PREMIUM_REVOKE_REASON_MAX_LENGTH } from "@/lib/api-client.economy";
import { type Locale } from "@/lib/i18n";

type EconomyPageConfirmationDialogsProps = {
  text: EconomyPageText;
  locale: Locale;
  cancelTarget: AdminEconomySubscription | null;
  cancelReason: string;
  cancelError: string | null;
  refundTarget: AdminEconomyPurchase | null;
  isCancelSubscriptionSubmitting: boolean;
  isRefundPurchaseSubmitting: boolean;
  onCancelSubscriptionClose: () => void;
  onCancelSubscriptionConfirm: () => void;
  onCancelReasonChange: (value: string) => void;
  onRefundPurchaseClose: () => void;
  onRefundPurchaseConfirm: () => void;
};

export function EconomyPageConfirmationDialogs({
  text,
  locale,
  cancelTarget,
  cancelReason,
  cancelError,
  refundTarget,
  isCancelSubscriptionSubmitting,
  isRefundPurchaseSubmitting,
  onCancelSubscriptionClose,
  onCancelSubscriptionConfirm,
  onCancelReasonChange,
  onRefundPurchaseClose,
  onRefundPurchaseConfirm,
}: EconomyPageConfirmationDialogsProps) {
  const cancelReasonRef = useRef<HTMLTextAreaElement>(null);

  return (
    <>
      <ConfirmationDialog
        open={Boolean(cancelTarget)}
        title={text.cancelSubscriptionTitle}
        description={
          cancelTarget
            ? `${text.cancelSubscriptionDescription} ${shortGuid(cancelTarget.userId)} / ${safeText(
                cancelTarget.planName ?? cancelTarget.planId,
                120
              )}`
            : text.cancelSubscriptionDescription
        }
        confirmLabel={text.cancelSubscriptionAction}
        cancelLabel={text.confirmationCancel}
        tone="danger"
        isSubmitting={isCancelSubscriptionSubmitting}
        confirmDisabled={!cancelReason.trim()}
        initialFocusRef={cancelReasonRef}
        onCancel={onCancelSubscriptionClose}
        onConfirm={onCancelSubscriptionConfirm}
      >
        <div className={styles.confirmationContent}>
          {cancelError ? (
            <p className={styles.confirmationError} role="alert">
              {cancelError}
            </p>
          ) : null}
          <label className={styles.confirmationReason}>
            <span>{text.cancelSubscriptionReasonLabel}</span>
            <textarea
              ref={cancelReasonRef}
              value={cancelReason}
              maxLength={ADMIN_PREMIUM_REVOKE_REASON_MAX_LENGTH}
              required
              onChange={(event) => onCancelReasonChange(event.target.value)}
              placeholder={text.cancelSubscriptionReasonPlaceholder}
            />
            <small>
              {text.cancelSubscriptionReasonHint} {cancelReason.length}/
              {ADMIN_PREMIUM_REVOKE_REASON_MAX_LENGTH}
            </small>
          </label>
        </div>
      </ConfirmationDialog>
      <ConfirmationDialog
        open={Boolean(refundTarget)}
        title={text.refundPurchaseTitle}
        description={
          refundTarget
            ? `${text.refundPurchaseDescription} ${shortGuid(refundTarget.orderId)} / ${formatCurrency(
                refundTarget.priceAmount,
                locale,
                refundTarget.currencyCode
              )}`
            : text.refundPurchaseDescription
        }
        confirmLabel={text.refundPurchaseAction}
        cancelLabel={text.confirmationCancel}
        tone="danger"
        isSubmitting={isRefundPurchaseSubmitting}
        onCancel={onRefundPurchaseClose}
        onConfirm={onRefundPurchaseConfirm}
      />
    </>
  );
}
