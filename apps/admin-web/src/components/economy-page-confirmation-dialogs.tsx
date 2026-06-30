"use client";

import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import { type EconomyPageText } from "@/components/economy-page.content";
import {
  formatCurrency,
  safeText,
  shortGuid,
} from "@/components/economy-page.shared";
import {
  type AdminEconomyPurchase,
  type AdminEconomySubscription,
} from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";

type EconomyPageConfirmationDialogsProps = {
  text: EconomyPageText;
  locale: Locale;
  cancelTarget: AdminEconomySubscription | null;
  refundTarget: AdminEconomyPurchase | null;
  isCancelSubscriptionSubmitting: boolean;
  isRefundPurchaseSubmitting: boolean;
  onCancelSubscriptionClose: () => void;
  onCancelSubscriptionConfirm: () => void;
  onRefundPurchaseClose: () => void;
  onRefundPurchaseConfirm: () => void;
};

export function EconomyPageConfirmationDialogs({
  text,
  locale,
  cancelTarget,
  refundTarget,
  isCancelSubscriptionSubmitting,
  isRefundPurchaseSubmitting,
  onCancelSubscriptionClose,
  onCancelSubscriptionConfirm,
  onRefundPurchaseClose,
  onRefundPurchaseConfirm,
}: EconomyPageConfirmationDialogsProps) {
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
        onCancel={onCancelSubscriptionClose}
        onConfirm={onCancelSubscriptionConfirm}
      />
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
