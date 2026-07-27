"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useEffect, useMemo, useRef, useState } from "react";

import { type EconomyPageText } from "@/components/economy-page.content";
import { canCancelSubscription, canRefundPurchase } from "@/components/economy-page.helpers";
import {
  formatEconomyLogText,
  getEconomyActionErrorDetails,
} from "@/components/economy-page.shared";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  adminCancelPremiumSubscription,
  refundAdminEconomyPurchase,
  type AdminEconomyPurchase,
  type AdminEconomySubscription,
} from "@/lib/api-client";
import { ADMIN_PREMIUM_REVOKE_REASON_MAX_LENGTH } from "@/lib/api-client.economy";
import { clientLogger } from "@/lib/client-logger";

type FeedbackSetter = (feedback: { tone: "success" | "danger"; message: string } | null) => void;

type UseEconomySubscriptionPurchaseActionsParams = {
  text: EconomyPageText;
  canManageEconomy: boolean;
  purchaseItems: AdminEconomyPurchase[];
  subscriptionItems: AdminEconomySubscription[];
  setFeedback: FeedbackSetter;
};

function assertCanManage(canManageEconomy: boolean, message: string) {
  if (!canManageEconomy) {
    throw new Error(message);
  }
}

export function useEconomySubscriptionPurchaseActions({
  text,
  canManageEconomy,
  purchaseItems,
  subscriptionItems,
  setFeedback,
}: UseEconomySubscriptionPurchaseActionsParams) {
  const queryClient = useQueryClient();
  const [cancelTarget, setCancelTarget] = useState<AdminEconomySubscription | null>(null);
  const [cancelReason, setCancelReason] = useState("");
  const [cancelError, setCancelError] = useState<string | null>(null);
  const [refundTarget, setRefundTarget] = useState<AdminEconomyPurchase | null>(null);
  const [isCancelSubscriptionInFlight, setIsCancelSubscriptionInFlight] = useState(false);
  const [isRefundPurchaseInFlight, setIsRefundPurchaseInFlight] = useState(false);
  const cancelSubscriptionInFlightRef = useRef(false);
  const refundPurchaseInFlightRef = useRef(false);

  function reportEconomyAccessDenied(error: unknown) {
    setFeedback({
      tone: "danger",
      message: getAdminErrorMessage(error, text.financialActionsAdminOnly),
    });
  }

  const cancelSubscriptionMutation = useMutation({
    mutationFn: async (subscription: AdminEconomySubscription) => {
      assertCanManage(canManageEconomy, text.financialActionsAdminOnly);
      if (!canCancelSubscription(subscription)) {
        throw new Error(text.cancelSubscriptionError);
      }

      await adminCancelPremiumSubscription(
        subscription.userId,
        subscription.provider,
        cancelReason.trim()
      );
    },
    onSuccess: async (_, subscription) => {
      setFeedback({ tone: "success", message: text.cancelSubscriptionSuccess });
      setCancelError(null);
      setCancelTarget(null);
      setCancelReason("");
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: ["admin", "economy", "subscriptions"] }),
        queryClient.invalidateQueries({ queryKey: ["admin", "economy", "subscription-events"] }),
        queryClient.invalidateQueries({
          queryKey: adminQueryKeys.economyUserSubscriptionSummary(subscription.userId),
        }),
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.economyDashboardMetrics }),
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.usersRoot }),
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.userDashboardMetrics }),
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.userDetail(subscription.userId) }),
        queryClient.invalidateQueries({
          queryKey: adminQueryKeys.userAnalytics(subscription.userId),
        }),
      ]);
    },
    onError: (error, subscription) => {
      const message = getAdminErrorMessage(error, text.cancelSubscriptionError);
      clientLogger.error("economy.cancel_subscription_failed", {
        subscriptionId: formatEconomyLogText(subscription?.subscriptionId),
        userId: formatEconomyLogText(subscription?.userId),
        provider: formatEconomyLogText(subscription?.provider, 48),
        status: formatEconomyLogText(subscription?.status, 48),
        ...getEconomyActionErrorDetails(error),
      });
      setFeedback({
        tone: "danger",
        message,
      });
      setCancelError(message);
    },
    onSettled: () => {
      cancelSubscriptionInFlightRef.current = false;
      setIsCancelSubscriptionInFlight(false);
    },
  });

  const refundPurchaseMutation = useMutation({
    mutationFn: async (purchase: AdminEconomyPurchase) => {
      assertCanManage(canManageEconomy, text.financialActionsAdminOnly);
      if (!canRefundPurchase(purchase)) {
        throw new Error(text.refundPurchaseError);
      }

      await refundAdminEconomyPurchase(purchase.orderId, "admin refund");
    },
    onSuccess: async (_, purchase) => {
      setFeedback({ tone: "success", message: text.refundPurchaseSuccess });
      setRefundTarget(null);
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: ["admin", "economy", "purchases"] }),
        queryClient.invalidateQueries({ queryKey: ["admin", "economy", "ledger"] }),
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.economyDashboardMetrics }),
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.userDetail(purchase.userId) }),
        queryClient.invalidateQueries({
          queryKey: adminQueryKeys.userAnalytics(purchase.userId),
        }),
      ]);
    },
    onError: (error, purchase) => {
      clientLogger.error("economy.refund_purchase_failed", {
        orderId: formatEconomyLogText(purchase?.orderId),
        userId: formatEconomyLogText(purchase?.userId),
        provider: formatEconomyLogText(purchase?.paymentProvider, 48),
        status: formatEconomyLogText(purchase?.status, 48),
        ...getEconomyActionErrorDetails(error),
      });
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(error, text.refundPurchaseError),
      });
    },
    onSettled: () => {
      refundPurchaseInFlightRef.current = false;
      setIsRefundPurchaseInFlight(false);
    },
  });

  function requestCancelSubscription(subscription: AdminEconomySubscription) {
    try {
      assertCanManage(canManageEconomy, text.financialActionsAdminOnly);
    } catch (error) {
      reportEconomyAccessDenied(error);
      return;
    }

    if (
      cancelSubscriptionInFlightRef.current ||
      cancelSubscriptionMutation.isPending ||
      !canCancelSubscription(subscription)
    ) {
      return;
    }

    setCancelReason("");
    setCancelError(null);
    setCancelTarget(subscription);
  }

  function requestRefundPurchase(purchase: AdminEconomyPurchase) {
    try {
      assertCanManage(canManageEconomy, text.financialActionsAdminOnly);
    } catch (error) {
      reportEconomyAccessDenied(error);
      return;
    }

    if (
      refundPurchaseInFlightRef.current ||
      refundPurchaseMutation.isPending ||
      !canRefundPurchase(purchase)
    ) {
      return;
    }

    setRefundTarget(purchase);
  }

  const isCancelSubscriptionSubmitting =
    isCancelSubscriptionInFlight || cancelSubscriptionMutation.isPending;
  const isRefundPurchaseSubmitting = isRefundPurchaseInFlight || refundPurchaseMutation.isPending;

  const visiblePurchaseIds = useMemo(
    () => new Set(purchaseItems.map((purchase) => purchase.orderId)),
    [purchaseItems]
  );
  const visibleSubscriptionIds = useMemo(
    () => new Set(subscriptionItems.map((subscription) => subscription.subscriptionId)),
    [subscriptionItems]
  );

  useEffect(() => {
    let isActive = true;
    if (
      !refundTarget ||
      isRefundPurchaseSubmitting ||
      visiblePurchaseIds.has(refundTarget.orderId)
    ) {
      return;
    }

    queueMicrotask(() => {
      if (isActive) {
        setRefundTarget(null);
      }
    });

    return () => {
      isActive = false;
    };
  }, [isRefundPurchaseSubmitting, refundTarget, visiblePurchaseIds]);

  useEffect(() => {
    let isActive = true;
    if (
      !cancelTarget ||
      isCancelSubscriptionSubmitting ||
      visibleSubscriptionIds.has(cancelTarget.subscriptionId)
    ) {
      return;
    }

    queueMicrotask(() => {
      if (isActive) {
        setCancelTarget(null);
        setCancelError(null);
      }
    });

    return () => {
      isActive = false;
    };
  }, [cancelTarget, isCancelSubscriptionSubmitting, visibleSubscriptionIds]);

  function onCancelSubscriptionClose() {
    if (!cancelSubscriptionInFlightRef.current && !cancelSubscriptionMutation.isPending) {
      setCancelTarget(null);
      setCancelReason("");
      setCancelError(null);
    }
  }

  function onCancelSubscriptionConfirm() {
    if (cancelSubscriptionInFlightRef.current || cancelSubscriptionMutation.isPending) {
      return;
    }

    if (cancelTarget && canCancelSubscription(cancelTarget) && cancelReason.trim()) {
      setCancelError(null);
      cancelSubscriptionInFlightRef.current = true;
      setIsCancelSubscriptionInFlight(true);
      cancelSubscriptionMutation.mutate(cancelTarget);
    }
  }

  function onRefundPurchaseClose() {
    if (!refundPurchaseInFlightRef.current && !refundPurchaseMutation.isPending) {
      setRefundTarget(null);
    }
  }

  function onRefundPurchaseConfirm() {
    if (refundPurchaseInFlightRef.current || refundPurchaseMutation.isPending) {
      return;
    }

    if (refundTarget && canRefundPurchase(refundTarget)) {
      refundPurchaseInFlightRef.current = true;
      setIsRefundPurchaseInFlight(true);
      refundPurchaseMutation.mutate(refundTarget);
    }
  }

  return {
    cancelTarget,
    cancelReason,
    cancelError,
    setCancelReason: (value: string) =>
      setCancelReason(value.slice(0, ADMIN_PREMIUM_REVOKE_REASON_MAX_LENGTH)),
    refundTarget,
    isCancelSubscriptionSubmitting,
    isRefundPurchaseSubmitting,
    requestCancelSubscription,
    requestRefundPurchase,
    onCancelSubscriptionClose,
    onCancelSubscriptionConfirm,
    onRefundPurchaseClose,
    onRefundPurchaseConfirm,
  };
}
