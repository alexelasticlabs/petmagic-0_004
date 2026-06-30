"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";

import { useSyncFeedbackToAdminNotifications } from "@/components/admin/admin-notifications";
import {
  AdminKpiCard,
  AdminPage,
  AdminPageGrid,
  AdminPageHero,
  AdminStateCard,
} from "@/components/admin/admin-primitives";
import { EconomyPageConfirmationDialogs } from "@/components/economy-page-confirmation-dialogs";
import { EconomyPageLedgerPurchasesSection } from "@/components/economy-page-ledger-purchases-section";
import { EconomyPagePacksSection } from "@/components/economy-page-packs-section";
import { EconomyPageProviderConfigsSection } from "@/components/economy-page-provider-configs-section";
import { EconomyPageSubscriptionPlansSection } from "@/components/economy-page-subscription-plans-section";
import { EconomyPageSubscriptionsSection } from "@/components/economy-page-subscriptions-section";
import { EconomyPageWatermarkSection } from "@/components/economy-page-watermark-section";
import { getEconomyText } from "@/components/economy-page.content";
import {
  canCancelSubscription,
  canRefundPurchase,
  createDefaultProviderConfigDraft,
  isPackDraftDirty,
  isProviderConfigDraftDirty,
  isSubscriptionPlanDraftDirty,
  toDraft,
  toCurrencyPackPayload,
  toProviderConfigCreatePayload,
  toProviderConfigDraft,
  toProviderConfigMatchPayload,
  toProviderConfigPayload,
  toSubscriptionPlanDraft,
  toSubscriptionPlanPayload,
  type PackDraft,
  type ProviderConfigCreateDraft,
  type ProviderConfigDraft,
  type ProviderConfigMatchDraft,
  type SubscriptionPlanDraft,
} from "@/components/economy-page.helpers";
import styles from "@/components/economy-page.module.css";
import {
  formatCurrency,
  formatEconomyLogText,
  formatTokens,
  getEconomyActionErrorDetails,
  humanizeBillingPeriod,
  humanizeProvider,
  humanizeStatus,
  shortGuid,
  statusColor,
  useTimedFeedbackReset,
} from "@/components/economy-page.shared";
import { Button } from "@/components/ui/button";
import { useEconomyPageController } from "@/components/use-economy-page-controller";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  adminCancelPremiumSubscription,
  cloneAdminPaymentProviderConfig,
  createAdminPaymentProviderConfig,
  deleteAdminPaymentProviderConfig,
  refundAdminEconomyPurchase,
  testAdminPaymentProviderConfigMatch,
  updateAdminCurrencyPack,
  fetchAdminWatermarkSettings,
  updateAdminPaymentProviderConfig,
  updateAdminWatermarkSettings,
  updateAdminSubscriptionPlan,
  useAuthSession,
  type AdminEconomyPurchase,
  type AdminPaymentProviderConfigurationMatch,
  type AdminEconomySubscription,
  type AdminWatermarkSettings,
} from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { type Locale } from "@/lib/i18n";

type EconomyPageProps = {
  locale: Locale;
};

export function EconomyPage({ locale }: EconomyPageProps) {
  const text = getEconomyText(locale);
  const queryClient = useQueryClient();
  const session = useAuthSession();
  const canManageEconomy = session?.user.roles.includes("Admin") ?? false;
  const {
    eventProvider,
    eventStatus,
    refetchAll,
    economyError,
    hasBlockingError,
    hasPartialError,
    isFetching,
    isLoading,
    ledgerHasMore,
    ledgerItems,
    ledgerIsFetching,
    ledgerIsRefreshing,
    ledgerPage,
    ledgerSource,
    metrics,
    packs,
    providerConfigs,
    purchaseItems,
    purchasePage,
    purchaseProvider,
    purchaseSearch,
    purchaseStatus,
    purchasesIsFetching,
    purchasesIsRefreshing,
    premiumMetrics,
    purchasesHasMore,
    setEventProvider,
    setEventStatus,
    setLedgerPage,
    setLedgerSource,
    setPurchasePage,
    setPurchaseProvider,
    setPurchaseSearch,
    setPurchaseStatus,
    setSubscriptionPage,
    setSubscriptionProvider,
    setSubscriptionSearch,
    setSubscriptionStatus,
    subscriptionEvents,
    subscriptionPage,
    subscriptionItems,
    subscriptionsIsFetching,
    subscriptionsIsRefreshing,
    subscriptionSearch,
    subscriptionsHasMore,
    subscriptionPlans,
    subscriptionProvider,
    subscriptionStatus,
  } = useEconomyPageController({ locale });
  const [drafts, setDrafts] = useState<Record<string, PackDraft>>({});
  const [planDrafts, setPlanDrafts] = useState<Record<string, SubscriptionPlanDraft>>({});
  const [providerConfigDrafts, setProviderConfigDrafts] = useState<
    Record<string, ProviderConfigDraft>
  >({});
  const [cloneRegionDrafts, setCloneRegionDrafts] = useState<Record<string, string>>({});
  const [createProviderDraft, setCreateProviderDraft] = useState<ProviderConfigCreateDraft>(() =>
    createDefaultProviderConfigDraft()
  );
  const [matchDraft, setMatchDraft] = useState<ProviderConfigMatchDraft>({
    provider: "stripe",
    platform: "web",
    country: "US",
    appVersion: "1.0.0",
  });
  const [matchResult, setMatchResult] = useState<AdminPaymentProviderConfigurationMatch | null>(
    null
  );
  const [feedback, setFeedback] = useState<{ tone: "success" | "danger"; message: string } | null>(
    null
  );
  const [cancelTarget, setCancelTarget] = useState<AdminEconomySubscription | null>(null);
  const [refundTarget, setRefundTarget] = useState<AdminEconomyPurchase | null>(null);
  const [isCancelSubscriptionInFlight, setIsCancelSubscriptionInFlight] = useState(false);
  const [isRefundPurchaseInFlight, setIsRefundPurchaseInFlight] = useState(false);
  const [watermarkDraft, setWatermarkDraft] = useState<AdminWatermarkSettings | null>(null);
  const cancelSubscriptionInFlightRef = useRef(false);
  const refundPurchaseInFlightRef = useRef(false);

  const watermarkQuery = useQuery({
    queryKey: adminQueryKeys.templateWatermarkSettings,
    queryFn: ({ signal }) => fetchAdminWatermarkSettings(signal),
    enabled: canManageEconomy,
  });

  useSyncFeedbackToAdminNotifications(feedback, {
    category: "economy",
    source: "economy-admin",
    title: text.title,
    href: `/${locale}/economy`,
  });

  useTimedFeedbackReset(feedback, () => setFeedback(null));

  function assertCanManageEconomy() {
    if (!canManageEconomy) {
      throw new Error(text.financialActionsAdminOnly);
    }
  }

  function reportEconomyAccessDenied(error: unknown) {
    setFeedback({
      tone: "danger",
      message: getAdminErrorMessage(error, text.financialActionsAdminOnly),
    });
  }

  function updateWatermarkDraft(patch: Partial<AdminWatermarkSettings>) {
    setWatermarkDraft((current) => {
      const base = current ?? watermarkQuery.data;
      return base ? { ...base, ...patch } : current;
    });
  }

  const savePackMutation = useMutation({
    mutationFn: async (packId: string) => {
      assertCanManageEconomy();
      const pack = packs.find((item) => item.packId === packId);
      const draft = drafts[packId] ?? (pack ? toDraft(pack) : null);
      if (!draft) {
        throw new Error(text.packMissingDraft);
      }

      return updateAdminCurrencyPack(packId, toCurrencyPackPayload(draft, text));
    },
    onSuccess: async (pack) => {
      setFeedback({ tone: "success", message: text.packSaved });
      setDrafts((current) => ({ ...current, [pack.packId]: toDraft(pack) }));
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.economyPacks }),
      ]);
    },
    onError: (error) => {
      setFeedback({ tone: "danger", message: getAdminErrorMessage(error, text.packSaveError) });
    },
  });

  const saveWatermarkMutation = useMutation({
    mutationFn: async () => {
      assertCanManageEconomy();
      const draft = watermarkDraft ?? watermarkQuery.data;
      if (!draft) {
        throw new Error(text.watermarkSettingsNotLoaded);
      }

      return updateAdminWatermarkSettings(draft);
    },
    onSuccess: async (settings) => {
      setFeedback({
        tone: "success",
        message: text.watermarkSaved,
      });
      setWatermarkDraft(settings);
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateWatermarkSettings }),
      ]);
    },
    onError: (error) => {
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(error, text.watermarkSaveError),
      });
    },
  });

  const savePlanMutation = useMutation({
    mutationFn: async (planId: string) => {
      assertCanManageEconomy();
      const plan = subscriptionPlans.find((item) => item.planId === planId);
      const draft = planDrafts[planId] ?? (plan ? toSubscriptionPlanDraft(plan) : null);
      if (!draft) {
        throw new Error(text.planMissingDraft);
      }

      return updateAdminSubscriptionPlan(planId, toSubscriptionPlanPayload(draft, text));
    },
    onSuccess: async (plan) => {
      setFeedback({ tone: "success", message: text.planSaved });
      setPlanDrafts((current) => ({ ...current, [plan.planId]: toSubscriptionPlanDraft(plan) }));
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.economySubscriptionPlans }),
      ]);
    },
    onError: (error) => {
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(error, text.planSaveError),
      });
    },
  });

  const saveProviderConfigMutation = useMutation({
    mutationFn: async (configurationId: string) => {
      assertCanManageEconomy();
      const config = providerConfigs.find((item) => item.configurationId === configurationId);
      const draft =
        providerConfigDrafts[configurationId] ?? (config ? toProviderConfigDraft(config) : null);
      if (!draft) {
        throw new Error(text.providerConfigMissingDraft);
      }

      return updateAdminPaymentProviderConfig(
        configurationId,
        toProviderConfigPayload(draft, text)
      );
    },
    onSuccess: async (config) => {
      setFeedback({ tone: "success", message: text.providerConfigSaved });
      setProviderConfigDrafts((current) => ({
        ...current,
        [config.configurationId]: toProviderConfigDraft(config),
      }));
      await Promise.allSettled([
        queryClient.invalidateQueries({
          queryKey: adminQueryKeys.economyPaymentProviderConfigs,
        }),
      ]);
    },
    onError: (error) => {
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(error, text.providerConfigSaveError),
      });
    },
  });

  function requestSavePack(packId: string) {
    if (savePackMutation.isPending) {
      return;
    }

    const pack = packs.find((item) => item.packId === packId);
    const draft = drafts[packId] ?? (pack ? toDraft(pack) : null);
    if (!pack || !draft || !isPackDraftDirty(pack, draft)) {
      return;
    }

    savePackMutation.mutate(packId);
  }

  function requestSavePlan(planId: string) {
    if (savePlanMutation.isPending) {
      return;
    }

    const plan = subscriptionPlans.find((item) => item.planId === planId);
    const draft = planDrafts[planId] ?? (plan ? toSubscriptionPlanDraft(plan) : null);
    if (!plan || !draft || !isSubscriptionPlanDraftDirty(plan, draft)) {
      return;
    }

    savePlanMutation.mutate(planId);
  }

  function requestSaveProviderConfig(configurationId: string) {
    if (saveProviderConfigMutation.isPending) {
      return;
    }

    const config = providerConfigs.find((item) => item.configurationId === configurationId);
    const draft =
      providerConfigDrafts[configurationId] ?? (config ? toProviderConfigDraft(config) : null);
    if (!config || !draft || !isProviderConfigDraftDirty(config, draft)) {
      return;
    }

    saveProviderConfigMutation.mutate(configurationId);
  }

  const createProviderConfigMutation = useMutation({
    mutationFn: async () => {
      assertCanManageEconomy();
      return createAdminPaymentProviderConfig(
        toProviderConfigCreatePayload(createProviderDraft, text)
      );
    },
    onSuccess: async () => {
      setFeedback({ tone: "success", message: text.providerConfigCreated });
      setCreateProviderDraft(createDefaultProviderConfigDraft());
      await Promise.allSettled([
        queryClient.invalidateQueries({
          queryKey: adminQueryKeys.economyPaymentProviderConfigs,
        }),
      ]);
    },
    onError: (error) => {
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(error, text.providerConfigCreateError),
      });
    },
  });

  const cloneProviderConfigMutation = useMutation({
    mutationFn: async (payload: { configurationId: string; region: string }) => {
      assertCanManageEconomy();
      return cloneAdminPaymentProviderConfig(payload.configurationId, { region: payload.region });
    },
    onSuccess: async (_, variables) => {
      setFeedback({ tone: "success", message: text.providerConfigCloned });
      setCloneRegionDrafts((current) => ({ ...current, [variables.configurationId]: "" }));
      await Promise.allSettled([
        queryClient.invalidateQueries({
          queryKey: adminQueryKeys.economyPaymentProviderConfigs,
        }),
      ]);
    },
    onError: (error) => {
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(error, text.providerConfigCloneError),
      });
    },
  });

  const deleteProviderConfigMutation = useMutation({
    mutationFn: async (configurationId: string) => {
      assertCanManageEconomy();
      await deleteAdminPaymentProviderConfig(configurationId);
    },
    onSuccess: async () => {
      setFeedback({ tone: "success", message: text.providerConfigDeleted });
      await Promise.allSettled([
        queryClient.invalidateQueries({
          queryKey: adminQueryKeys.economyPaymentProviderConfigs,
        }),
      ]);
    },
    onError: (error) => {
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(error, text.providerConfigDeleteError),
      });
    },
  });

  const testProviderConfigMutation = useMutation({
    mutationFn: async () => {
      assertCanManageEconomy();
      const payload = toProviderConfigMatchPayload(matchDraft, text);
      return testAdminPaymentProviderConfigMatch(payload);
    },
    onSuccess: (result) => {
      setMatchResult(result);
    },
    onError: (error) => {
      setMatchResult(null);
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(error, text.providerConfigTestError),
      });
    },
  });

  function requestCreateProviderConfig() {
    if (createProviderConfigMutation.isPending) {
      return;
    }

    createProviderConfigMutation.mutate();
  }

  function requestTestProviderConfig() {
    if (testProviderConfigMutation.isPending) {
      return;
    }

    testProviderConfigMutation.mutate();
  }

  function requestCloneProviderConfig(payload: { configurationId: string; region: string }) {
    if (cloneProviderConfigMutation.isPending) {
      return;
    }

    cloneProviderConfigMutation.mutate(payload);
  }

  const cancelSubscriptionMutation = useMutation({
    mutationFn: async (subscription: AdminEconomySubscription) => {
      assertCanManageEconomy();
      if (!canCancelSubscription(subscription)) {
        throw new Error(text.cancelSubscriptionError);
      }

      await adminCancelPremiumSubscription(subscription.userId, subscription.provider);
    },
    onSuccess: async (_, subscription) => {
      setFeedback({ tone: "success", message: text.cancelSubscriptionSuccess });
      setCancelTarget(null);
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
      clientLogger.error("economy.cancel_subscription_failed", {
        subscriptionId: formatEconomyLogText(subscription?.subscriptionId),
        userId: formatEconomyLogText(subscription?.userId),
        provider: formatEconomyLogText(subscription?.provider, 48),
        status: formatEconomyLogText(subscription?.status, 48),
        ...getEconomyActionErrorDetails(error),
      });
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(error, text.cancelSubscriptionError),
      });
    },
    onSettled: () => {
      cancelSubscriptionInFlightRef.current = false;
      setIsCancelSubscriptionInFlight(false);
    },
  });

  const refundPurchaseMutation = useMutation({
    mutationFn: async (purchase: AdminEconomyPurchase) => {
      assertCanManageEconomy();
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
      assertCanManageEconomy();
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

    setCancelTarget(subscription);
  }

  function requestRefundPurchase(purchase: AdminEconomyPurchase) {
    try {
      assertCanManageEconomy();
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
    if (
      !refundTarget ||
      isRefundPurchaseSubmitting ||
      visiblePurchaseIds.has(refundTarget.orderId)
    ) {
      return;
    }

    queueMicrotask(() => setRefundTarget(null));
  }, [isRefundPurchaseSubmitting, refundTarget, visiblePurchaseIds]);

  useEffect(() => {
    if (
      !cancelTarget ||
      isCancelSubscriptionSubmitting ||
      visibleSubscriptionIds.has(cancelTarget.subscriptionId)
    ) {
      return;
    }

    queueMicrotask(() => setCancelTarget(null));
  }, [cancelTarget, isCancelSubscriptionSubmitting, visibleSubscriptionIds]);

  if (!canManageEconomy) {
    return (
      <AdminPage className={styles.page}>
        <AdminPageHero eyebrow={text.eyebrow} title={text.title} description={text.description} />
        <AdminStateCard
          tone="info"
          title={text.loadingTitle}
          description={text.loadingDescription}
        />
      </AdminPage>
    );
  }

  if (isLoading) {
    return (
      <AdminPage className={styles.page}>
        <AdminPageHero eyebrow={text.eyebrow} title={text.title} description={text.description} />
        <AdminStateCard
          tone="info"
          title={text.loadingTitle}
          description={text.loadingDescription}
        />
      </AdminPage>
    );
  }

  function requestEconomyRetry() {
    if (!canManageEconomy || isFetching) {
      return;
    }

    void refetchAll().catch(() => undefined);
  }

  if (hasBlockingError) {
    return (
      <AdminPage className={styles.page}>
        <AdminPageHero eyebrow={text.eyebrow} title={text.title} description={text.description} />
        <AdminStateCard
          tone="danger"
          title={text.errorTitle}
          description={text.errorDescription}
          action={
            <Button
              type="button"
              variant="secondary"
              disabled={!canManageEconomy || isFetching}
              onClick={requestEconomyRetry}
            >
              {text.retry}
            </Button>
          }
        />
      </AdminPage>
    );
  }

  const effectiveWatermarkDraft = watermarkDraft ?? watermarkQuery.data ?? null;
  const isSaveWatermarkDisabled =
    !canManageEconomy || !effectiveWatermarkDraft || saveWatermarkMutation.isPending;

  function requestSaveWatermark() {
    if (isSaveWatermarkDisabled) {
      return;
    }

    saveWatermarkMutation.mutate();
  }

  return (
    <AdminPage className={styles.page}>
      <AdminPageHero eyebrow={text.eyebrow} title={text.title} description={text.description} />

      <AdminPageGrid columns="four">
        <AdminKpiCard
          label={text.activePacksLabel}
          value={String(metrics.activePacks)}
          tone="primary"
        />
        <AdminKpiCard
          label={text.creditFlowLabel}
          value={formatTokens(metrics.credited, locale)}
          tone="success"
        />
        <AdminKpiCard
          label={text.debitFlowLabel}
          value={formatTokens(metrics.debited, locale)}
          tone="warning"
        />
        <AdminKpiCard
          label={text.revenueLabel}
          value={formatCurrency(metrics.grossRevenue, locale, metrics.revenueCurrencyCode)}
          tone="info"
        />
      </AdminPageGrid>

      <AdminPageGrid columns="four">
        <AdminKpiCard
          label={text.activeSubscriptionsLabel}
          value={String(premiumMetrics.activeSubscriptions)}
          tone="primary"
        />
        <AdminKpiCard
          label={text.renewalStopsLabel}
          value={String(premiumMetrics.renewalStops)}
          tone="warning"
        />
        <AdminKpiCard
          label={text.activePlansCountLabel}
          value={String(premiumMetrics.activePlans)}
          tone="success"
        />
        <AdminKpiCard
          label={text.enabledRoutesLabel}
          value={String(premiumMetrics.enabledRoutes)}
          tone="info"
        />
      </AdminPageGrid>

      {feedback ? <AdminStateCard tone={feedback.tone} title={feedback.message} /> : null}
      {hasPartialError ? (
        <AdminStateCard
          tone="warning"
          title={text.partialErrorTitle}
          description={getAdminErrorMessage(economyError, text.errorDescription)}
          action={
            <Button
              type="button"
              variant="secondary"
              disabled={!canManageEconomy || isFetching}
              onClick={requestEconomyRetry}
            >
              {text.retry}
            </Button>
          }
        />
      ) : null}

      <EconomyPagePacksSection
        text={text}
        packs={packs}
        drafts={drafts}
        setDrafts={setDrafts}
        savePackPending={savePackMutation.isPending}
        savePackId={savePackMutation.variables}
        onSavePack={requestSavePack}
      />

      <EconomyPageLedgerPurchasesSection
        locale={locale}
        text={text}
        ledgerSource={ledgerSource}
        setLedgerSource={setLedgerSource}
        ledgerItems={ledgerItems}
        ledgerPage={ledgerPage}
        ledgerHasMore={ledgerHasMore}
        ledgerIsFetching={ledgerIsFetching}
        ledgerIsRefreshing={ledgerIsRefreshing}
        setLedgerPage={setLedgerPage}
        purchaseStatus={purchaseStatus}
        setPurchaseStatus={setPurchaseStatus}
        purchaseProvider={purchaseProvider}
        setPurchaseProvider={setPurchaseProvider}
        purchaseSearch={purchaseSearch}
        setPurchaseSearch={setPurchaseSearch}
        purchasesIsFetching={purchasesIsFetching}
        purchasesIsRefreshing={purchasesIsRefreshing}
        purchaseItems={purchaseItems}
        purchasePage={purchasePage}
        purchasesHasMore={purchasesHasMore}
        setPurchasePage={setPurchasePage}
        isRefundPurchaseSubmitting={isRefundPurchaseSubmitting}
        onRefundPurchase={requestRefundPurchase}
      />

      <EconomyPageWatermarkSection
        text={text}
        effectiveWatermarkDraft={effectiveWatermarkDraft}
        isLoading={watermarkQuery.isLoading}
        isSaveDisabled={isSaveWatermarkDisabled}
        isSavePending={saveWatermarkMutation.isPending}
        onSubmit={requestSaveWatermark}
        onUpdateDraft={updateWatermarkDraft}
      />

      <AdminPageGrid columns="two">
        <EconomyPageSubscriptionPlansSection
          locale={locale}
          text={text}
          subscriptionPlans={subscriptionPlans}
          planDrafts={planDrafts}
          setPlanDrafts={setPlanDrafts}
          savePlanPending={savePlanMutation.isPending}
          savePlanId={savePlanMutation.variables}
          onSavePlan={requestSavePlan}
          humanizeBillingPeriod={humanizeBillingPeriod}
        />

        <EconomyPageProviderConfigsSection
          locale={locale}
          text={text}
          providerConfigs={providerConfigs}
          providerConfigDrafts={providerConfigDrafts}
          createProviderDraft={createProviderDraft}
          setCreateProviderDraft={setCreateProviderDraft}
          matchDraft={matchDraft}
          setMatchDraft={setMatchDraft}
          matchResult={matchResult}
          setProviderConfigDrafts={setProviderConfigDrafts}
          cloneRegionDrafts={cloneRegionDrafts}
          setCloneRegionDrafts={setCloneRegionDrafts}
          saveProviderConfigPending={saveProviderConfigMutation.isPending}
          saveProviderConfigId={saveProviderConfigMutation.variables}
          createProviderConfigPending={createProviderConfigMutation.isPending}
          testProviderConfigPending={testProviderConfigMutation.isPending}
          cloneProviderConfigPending={cloneProviderConfigMutation.isPending}
          cloneProviderConfigId={cloneProviderConfigMutation.variables?.configurationId}
          deleteProviderConfigPending={deleteProviderConfigMutation.isPending}
          deleteProviderConfigId={deleteProviderConfigMutation.variables}
          onSaveProviderConfig={requestSaveProviderConfig}
          onCreateProviderConfig={requestCreateProviderConfig}
          onTestProviderConfig={requestTestProviderConfig}
          onCloneProviderConfig={requestCloneProviderConfig}
          onDeleteProviderConfig={async (configurationId) => {
            try {
              await deleteProviderConfigMutation.mutateAsync(configurationId);
              return true;
            } catch {
              return false;
            }
          }}
          humanizeProvider={humanizeProvider}
        />
      </AdminPageGrid>

      <AdminPageGrid columns="two">
        <EconomyPageSubscriptionsSection
          locale={locale}
          text={text}
          subscriptionProvider={subscriptionProvider}
          subscriptionStatus={subscriptionStatus}
          eventProvider={eventProvider}
          eventStatus={eventStatus}
          subscriptionSearch={subscriptionSearch}
          subscriptionPage={subscriptionPage}
          subscriptionsHasMore={subscriptionsHasMore}
          subscriptionItems={subscriptionItems}
          subscriptionsIsFetching={subscriptionsIsFetching}
          subscriptionsIsRefreshing={subscriptionsIsRefreshing}
          cancelSubscriptionPending={isCancelSubscriptionSubmitting}
          subscriptionEvents={subscriptionEvents}
          setSubscriptionProvider={setSubscriptionProvider}
          setSubscriptionStatus={setSubscriptionStatus}
          setSubscriptionSearch={setSubscriptionSearch}
          setSubscriptionPage={setSubscriptionPage}
          setEventProvider={setEventProvider}
          setEventStatus={setEventStatus}
          onCancelSubscription={requestCancelSubscription}
          shortGuid={shortGuid}
          humanizeProvider={humanizeProvider}
          humanizeStatus={humanizeStatus}
          statusColor={statusColor}
        />
      </AdminPageGrid>

      <EconomyPageConfirmationDialogs
        text={text}
        locale={locale}
        cancelTarget={cancelTarget}
        refundTarget={refundTarget}
        isCancelSubscriptionSubmitting={isCancelSubscriptionSubmitting}
        isRefundPurchaseSubmitting={isRefundPurchaseSubmitting}
        onCancelSubscriptionClose={() => {
          if (!cancelSubscriptionInFlightRef.current && !cancelSubscriptionMutation.isPending) {
            setCancelTarget(null);
          }
        }}
        onCancelSubscriptionConfirm={() => {
          if (cancelSubscriptionInFlightRef.current || cancelSubscriptionMutation.isPending) {
            return;
          }

          if (cancelTarget && canCancelSubscription(cancelTarget)) {
            cancelSubscriptionInFlightRef.current = true;
            setIsCancelSubscriptionInFlight(true);
            cancelSubscriptionMutation.mutate(cancelTarget);
          }
        }}
        onRefundPurchaseClose={() => {
          if (!refundPurchaseInFlightRef.current && !refundPurchaseMutation.isPending) {
            setRefundTarget(null);
          }
        }}
        onRefundPurchaseConfirm={() => {
          if (refundPurchaseInFlightRef.current || refundPurchaseMutation.isPending) {
            return;
          }

          if (refundTarget && canRefundPurchase(refundTarget)) {
            refundPurchaseInFlightRef.current = true;
            setIsRefundPurchaseInFlight(true);
            refundPurchaseMutation.mutate(refundTarget);
          }
        }}
      />
    </AdminPage>
  );
}
