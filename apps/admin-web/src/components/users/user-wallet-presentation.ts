import type { Dictionary } from "@/lib/i18n.types";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type UserWalletLedgerItem = {
  delta: number;
  reason: string;
  source: string;
};

export type UserWalletLedgerPresentation = {
  note?: string;
  operationLabel: string;
};

function getManualWalletNote(source: string, reason: string): string | undefined {
  const normalizedSource = source.trim().toLowerCase();
  if (normalizedSource !== "admin_grant" && normalizedSource !== "admin_debit") {
    return undefined;
  }

  const safeReason = sanitizeSensitiveText(reason, 180);
  if (!safeReason || /^[a-z][a-z0-9_]*(?::[^\s]*)?$/i.test(safeReason)) {
    return undefined;
  }

  return safeReason;
}

function getOperationLabel(
  source: string,
  text: Pick<
    Dictionary,
    | "walletLedgerBonus"
    | "walletLedgerGenerationRefund"
    | "walletLedgerGenerationSpend"
    | "walletLedgerManualAdjustment"
    | "walletLedgerOther"
    | "walletLedgerPromo"
    | "walletLedgerPurchase"
    | "walletLedgerPurchaseRefund"
    | "walletLedgerReferral"
    | "walletLedgerSubscription"
    | "walletLedgerWatermarkUnlock"
  >
) {
  switch (source.trim().toLowerCase()) {
    case "admin_grant":
    case "admin_debit":
      return text.walletLedgerManualAdjustment;
    case "generation_spend":
      return text.walletLedgerGenerationSpend;
    case "generation_refund":
      return text.walletLedgerGenerationRefund;
    case "pack_purchase":
      return text.walletLedgerPurchase;
    case "purchase_refund":
      return text.walletLedgerPurchaseRefund;
    case "ad_reward":
    case "weekly_grant":
      return text.walletLedgerBonus;
    case "premium_subscription_grant":
    case "premium_subscription_weekly_grant":
      return text.walletLedgerSubscription;
    case "redeem_code":
      return text.walletLedgerPromo;
    case "referral_bonus":
      return text.walletLedgerReferral;
    case "watermark_unlock":
      return text.walletLedgerWatermarkUnlock;
    default:
      return text.walletLedgerOther;
  }
}

export function getUserWalletLedgerPresentation(
  item: UserWalletLedgerItem,
  text: Pick<
    Dictionary,
    | "walletLedgerBonus"
    | "walletLedgerGenerationRefund"
    | "walletLedgerGenerationSpend"
    | "walletLedgerManualAdjustment"
    | "walletLedgerOther"
    | "walletLedgerPromo"
    | "walletLedgerPurchase"
    | "walletLedgerPurchaseRefund"
    | "walletLedgerReferral"
    | "walletLedgerSubscription"
    | "walletLedgerWatermarkUnlock"
  >
): UserWalletLedgerPresentation {
  return {
    operationLabel: getOperationLabel(item.source, text),
    note: getManualWalletNote(item.source, item.reason),
  };
}
