"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from "react";

import { useSyncFeedbackToAdminNotifications } from "@/components/admin/admin-notifications";
import {
  AdminCard,
  AdminKpiCard,
  AdminMetricStrip,
  AdminPage,
  AdminPageGrid,
  AdminPageHero,
  AdminSelectField,
  AdminStateCard,
  AdminStatusBadge,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import { EconomyPageProviderConfigsSection } from "@/components/economy-page-provider-configs-section";
import { EconomyPageSubscriptionPlansSection } from "@/components/economy-page-subscription-plans-section";
import { EconomyPageSubscriptionsSection } from "@/components/economy-page-subscriptions-section";
import {
  getEconomyText,
  ledgerSourceOptions,
  purchaseStatusOptions,
  subscriptionProviderOptions,
} from "@/components/economy-page.content";
import {
  ECONOMY_PACK_DISPLAY_NAME_MAX_LENGTH,
  ECONOMY_PACK_INTEGER_MAX_LENGTH,
  ECONOMY_PACK_PRICE_MAX_LENGTH,
  canCancelSubscription,
  canRefundPurchase,
  createDefaultProviderConfigDraft,
  normalizeEconomyIntegerInput,
  normalizeEconomyPackDisplayNameInput,
  normalizeEconomyPriceInput,
  toDraft,
  toCurrencyPackPayload,
  toProviderConfigCreatePayload,
  toProviderConfigDraft,
  toProviderConfigMatchPayload,
  toProviderConfigPayload,
  toSubscriptionPlanDraft,
  toSubscriptionPlanPayload,
  updateDraft,
  type PackDraft,
  type ProviderConfigCreateDraft,
  type ProviderConfigDraft,
  type ProviderConfigMatchDraft,
  type SubscriptionPlanDraft,
} from "@/components/economy-page.helpers";
import styles from "@/components/economy-page.module.css";
import { Button } from "@/components/ui/button";
import { useEconomyPageController } from "@/components/use-economy-page-controller";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  adminCancelPremiumSubscription,
  cloneAdminPaymentProviderConfig,
  createAdminPaymentProviderConfig,
  deleteAdminPaymentProviderConfig,
  ECONOMY_QUERY_FILTER_MAX_LENGTH,
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
import { formatDateTime } from "@/lib/format-date-time";
import { type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type EconomyPageProps = {
  locale: Locale;
};

const watermarkPositionOptions = ["bottom-right", "bottom-left", "top-right", "top-left"] as const;
const watermarkSizeOptions = ["small", "medium", "large"] as const;
const WATERMARK_TEXT_MAX_LENGTH = 80;
const WATERMARK_COST_MAX_LENGTH = 6;
const WATERMARK_OPACITY_MAX_LENGTH = 4;
const WATERMARK_LOGO_URL_MAX_LENGTH = 2_048;

type TableOrEmptyProps = {
  hasItems: boolean;
  emptyTitle: string;
  children: ReactNode;
};

function TableOrEmpty({ hasItems, emptyTitle, children }: TableOrEmptyProps) {
  if (!hasItems) {
    return <AdminStateCard tone="info" title={emptyTitle} />;
  }

  return <>{children}</>;
}

function WatermarkPreviewPanel({
  locale,
  settings,
}: {
  locale: Locale;
  settings: AdminWatermarkSettings;
}) {
  const isRu = locale === "ru";
  const previewStyle = {
    "--watermark-preview-opacity": String(settings.opacity),
  } as CSSProperties;
  const badgeText = settings.text.trim() || "PetMagic";
  const position = normalizeWatermarkPosition(settings.position);
  const size = normalizeWatermarkSize(settings.size);

  function renderFrame(kind: "image" | "video", sourceUrl: string) {
    const title =
      kind === "image"
        ? isRu
          ? "Preview image"
          : "Preview image"
        : isRu
        ? "Preview video frame"
        : "Preview video frame";
    const applies = kind === "image" ? settings.applyToImages : settings.applyToVideos;

    return (
      <div className={styles.watermarkPreviewCard}>
        <div className={styles.watermarkPreviewHeader}>
          <strong>{title}</strong>
          <span>{applies ? (isRu ? "Включён" : "Enabled") : isRu ? "Отключён" : "Disabled"}</span>
        </div>
        <div
          className={styles.watermarkPreviewFrame}
          data-kind={kind}
          style={previewStyle}
        >
          {sourceUrl ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={sourceUrl} alt={title} className={styles.watermarkPreviewMedia} />
          ) : (
            <div className={styles.watermarkPreviewPlaceholder}>
              {kind === "image"
                ? isRu
                  ? "Тестовое изображение"
                  : "Test image"
                : isRu
                ? "Тестовый кадр видео"
                : "Test video frame"}
            </div>
          )}
          {settings.enabled && applies ? (
            <div
              className={styles.watermarkPreviewBadge}
              data-position={position}
              data-size={size}
            >
              {settings.logoUrl ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={settings.logoUrl} alt="" className={styles.watermarkPreviewLogo} />
              ) : null}
              <span>{badgeText}</span>
            </div>
          ) : null}
        </div>
      </div>
    );
  }

  return (
    <div className={styles.watermarkPreviewGrid}>
      {renderFrame("image", settings.previewImageUrl)}
      {renderFrame("video", settings.previewVideoFrameUrl)}
    </div>
  );
}

function normalizeWatermarkPosition(value: string) {
  return watermarkPositionOptions.includes(value as (typeof watermarkPositionOptions)[number])
    ? value
    : "bottom-right";
}

function normalizeWatermarkSize(value: string) {
  return watermarkSizeOptions.includes(value as (typeof watermarkSizeOptions)[number]) ? value : "small";
}

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
    ledgerItems,
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
    title: locale === "ru" ? "Экономика" : "Economy",
    href: `/${locale}/economy`,
  });

  useEffect(() => {
    if (!feedback) {
      return;
    }

    const timer = window.setTimeout(() => setFeedback(null), 3200);
    return () => window.clearTimeout(timer);
  }, [feedback]);

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
        throw new Error(locale === "ru" ? "Настройки watermark не загружены" : "Watermark settings are not loaded");
      }

      return updateAdminWatermarkSettings(draft);
    },
    onSuccess: async (settings) => {
      setFeedback({
        tone: "success",
        message: locale === "ru" ? "Настройки watermark сохранены" : "Watermark settings saved",
      });
      setWatermarkDraft(settings);
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateWatermarkSettings }),
      ]);
    },
    onError: (error) => {
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(
          error,
          locale === "ru" ? "Не удалось сохранить watermark" : "Could not save watermark settings"
        ),
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

    savePackMutation.mutate(packId);
  }

  function requestSavePlan(planId: string) {
    if (savePlanMutation.isPending) {
      return;
    }

    savePlanMutation.mutate(planId);
  }

  function requestSaveProviderConfig(configurationId: string) {
    if (saveProviderConfigMutation.isPending) {
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
    onError: (error) => {
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
    onError: (error) => {
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
              onClick={() => {
                if (!canManageEconomy) {
                  return;
                }

                void refetchAll().catch(() => undefined);
              }}
            >
              {locale === "ru" ? "Повторить" : "Retry"}
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
              onClick={() => {
                if (!canManageEconomy) {
                  return;
                }

                void refetchAll().catch(() => undefined);
              }}
            >
              {locale === "ru" ? "Повторить" : "Retry"}
            </Button>
          }
        />
      ) : null}

      <AdminCard title={text.packsTitle} description={text.packsDescription}>
        <AdminMetricStrip
          items={packs.slice(0, 4).map((pack) => ({
            label: `${safeText(pack.code.toUpperCase(), 32)} • ${safeText(
              pack.currencyCode.toUpperCase(),
              12
            )}`,
            value: `${pack.totalSpark} ${text.tokensShort}`,
          }))}
          className={styles.metricStrip}
        />

        <TableOrEmpty hasItems={packs.length > 0} emptyTitle={text.noPacks}>
          <div className={adminTableStyles.tableWrap}>
            <table className={adminTableStyles.table}>
              <thead>
                <tr>
                  <th>{text.packColumn}</th>
                  <th>{text.priceColumn}</th>
                  <th>{text.grantedColumn}</th>
                  <th>{text.bonusColumn}</th>
                  <th>{text.sortColumn}</th>
                  <th>{text.activeColumn}</th>
                  <th>{text.actionsColumn}</th>
                </tr>
              </thead>
              <tbody>
                {packs.map((pack) => {
                  const draft = drafts[pack.packId] ?? toDraft(pack);
                  const isSavingRow =
                    savePackMutation.isPending && savePackMutation.variables === pack.packId;
                  const isPackDraftLocked = savePackMutation.isPending;
                  return (
                    <tr key={pack.packId}>
                      <td>
                        <div className={styles.packMeta}>
                          <strong>{safeText(pack.code.toUpperCase(), 32)}</strong>
                          <span>{safeText(pack.currencyCode.toUpperCase(), 12)}</span>
                        </div>
                        <input
                          value={draft.displayName}
                          onChange={(event) =>
                            updateDraft(setDrafts, pack.packId, {
                              displayName: normalizeEconomyPackDisplayNameInput(
                                event.target.value
                              ),
                            })
                          }
                          maxLength={ECONOMY_PACK_DISPLAY_NAME_MAX_LENGTH}
                          className={styles.input}
                          disabled={isPackDraftLocked}
                        />
                      </td>
                      <td>
                        <input
                          value={draft.priceAmount}
                          onChange={(event) =>
                            updateDraft(setDrafts, pack.packId, {
                              priceAmount: normalizeEconomyPriceInput(event.target.value),
                            })
                          }
                          maxLength={ECONOMY_PACK_PRICE_MAX_LENGTH}
                          inputMode="decimal"
                          className={styles.input}
                          disabled={isPackDraftLocked}
                        />
                      </td>
                      <td>
                        <input
                          value={draft.grantedSpark}
                          onChange={(event) =>
                            updateDraft(setDrafts, pack.packId, {
                              grantedSpark: normalizeEconomyIntegerInput(event.target.value),
                            })
                          }
                          maxLength={ECONOMY_PACK_INTEGER_MAX_LENGTH}
                          inputMode="numeric"
                          className={styles.input}
                          disabled={isPackDraftLocked}
                        />
                      </td>
                      <td>
                        <input
                          value={draft.bonusSpark}
                          onChange={(event) =>
                            updateDraft(setDrafts, pack.packId, {
                              bonusSpark: normalizeEconomyIntegerInput(event.target.value),
                            })
                          }
                          maxLength={ECONOMY_PACK_INTEGER_MAX_LENGTH}
                          inputMode="numeric"
                          className={styles.input}
                          disabled={isPackDraftLocked}
                        />
                      </td>
                      <td>
                        <input
                          value={draft.sortOrder}
                          onChange={(event) =>
                            updateDraft(setDrafts, pack.packId, {
                              sortOrder: normalizeEconomyIntegerInput(event.target.value),
                            })
                          }
                          maxLength={ECONOMY_PACK_INTEGER_MAX_LENGTH}
                          inputMode="numeric"
                          className={styles.input}
                          disabled={isPackDraftLocked}
                        />
                      </td>
                      <td>
                        <label className={styles.checkboxField}>
                          <input
                            type="checkbox"
                            checked={draft.isActive}
                            onChange={(event) =>
                              updateDraft(setDrafts, pack.packId, {
                                isActive: event.target.checked,
                              })
                            }
                            disabled={isPackDraftLocked}
                          />
                          <span>{draft.isActive ? text.activeState : text.inactiveState}</span>
                        </label>
                      </td>
                      <td>
                        <Button
                          onClick={() => requestSavePack(pack.packId)}
                          disabled={isPackDraftLocked}
                        >
                          {isSavingRow ? text.savingAction : text.saveAction}
                        </Button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </TableOrEmpty>
      </AdminCard>

      <AdminPageGrid columns="two">
        <AdminCard
          title={text.ledgerTitle}
          description={text.ledgerDescription}
          action={
            <AdminSelectField
              label={text.ledgerFilterLabel}
              value={ledgerSource}
              onChange={setLedgerSource}
              options={ledgerSourceOptions[locale]}
              className={styles.compactSelect}
            />
          }
        >
          <TableOrEmpty hasItems={ledgerItems.length > 0} emptyTitle={text.noLedger}>
            <div className={adminTableStyles.tableWrap}>
              <table className={adminTableStyles.table}>
                <thead>
                  <tr>
                    <th>{text.timeColumn}</th>
                    <th>{text.userColumn}</th>
                    <th>{text.deltaColumn}</th>
                    <th>{text.balanceColumn}</th>
                    <th>{text.sourceColumn}</th>
                    <th>{text.reasonColumn}</th>
                  </tr>
                </thead>
                <tbody>
                  {ledgerItems.map((item) => (
                    <tr key={item.entryId}>
                      <td>{formatDateTime(item.createdAtUtc, locale)}</td>
                      <td className={adminTableStyles.mono}>{shortGuid(item.userId)}</td>
                      <td>
                        <span className={item.delta >= 0 ? styles.positive : styles.negative}>
                          {item.delta >= 0 ? "+" : ""}
                          {item.delta}
                        </span>
                      </td>
                      <td>{item.balanceAfter}</td>
                      <td>{humanizeSource(item.source, locale)}</td>
                      <td>{safeText(item.reason)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </TableOrEmpty>
        </AdminCard>

        <AdminCard
          title={text.purchasesTitle}
          description={text.purchasesDescription}
          action={
            <div className={styles.filterRow}>
              <AdminSelectField
                label={text.purchaseFilterLabel}
                value={purchaseStatus}
                onChange={setPurchaseStatus}
                options={purchaseStatusOptions[locale]}
                className={styles.compactSelect}
              />
              <AdminSelectField
                label={text.purchaseProviderFilterLabel}
                value={purchaseProvider}
                onChange={setPurchaseProvider}
                options={subscriptionProviderOptions[locale]}
                className={styles.compactSelect}
              />
              <label className={styles.filterField}>
                <span>{text.searchFilterLabel}</span>
                <input
                  className={styles.input}
                  value={purchaseSearch}
                  onChange={(event) =>
                    setPurchaseSearch(event.target.value.slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH))
                  }
                  maxLength={ECONOMY_QUERY_FILTER_MAX_LENGTH}
                  placeholder={text.purchaseSearchPlaceholder}
                />
              </label>
            </div>
          }
        >
          {purchasesIsRefreshing ? (
            <AdminStateCard tone="info" title={text.loadingTitle} />
          ) : (
            <TableOrEmpty hasItems={purchaseItems.length > 0} emptyTitle={text.noPurchases}>
              <div className={adminTableStyles.tableWrap}>
                <table className={adminTableStyles.table}>
                  <thead>
                    <tr>
                      <th>{text.timeColumn}</th>
                      <th>{text.userColumn}</th>
                      <th>{text.productTypeColumn}</th>
                      <th>{text.packColumn}</th>
                      <th>{text.providerColumn}</th>
                      <th>{text.amountColumn}</th>
                      <th>{text.statusColumn}</th>
                      <th>{text.refundStatusColumn}</th>
                      <th>{text.actionsColumn}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {purchaseItems.map((item) => {
                      const canRefund = canRefundPurchase(item);

                      return (
                        <tr key={item.orderId}>
                          <td>
                            {formatDateTime(item.confirmedAtUtc ?? item.createdAtUtc, locale)}
                          </td>
                          <td className={adminTableStyles.mono}>{shortGuid(item.userId)}</td>
                          <td>{safeText(item.productType ?? "TokenPack")}</td>
                          <td>
                            <div className={styles.packMeta}>
                              <strong>{safeText(item.packDisplayName)}</strong>
                              <span>
                                {item.tokenAmount ?? item.sparkToGrant} {text.tokensShort}
                              </span>
                            </div>
                          </td>
                          <td>{humanizeProvider(item.paymentProvider, locale)}</td>
                          <td>{formatCurrency(item.priceAmount, locale, item.currencyCode)}</td>
                          <td>
                            <AdminStatusBadge color={statusColor(item.status)}>
                              {humanizeStatus(item.status, locale)}
                            </AdminStatusBadge>
                          </td>
                          <td>
                            {safeText(
                              item.refundStatus ??
                                (item.status === "refunded" ? "refunded" : "none")
                            )}
                          </td>
                          <td>
                            {canRefund ? (
                              <Button
                                type="button"
                                size="sm"
                                variant="danger"
                                disabled={isRefundPurchaseSubmitting}
                                onClick={() => requestRefundPurchase(item)}
                              >
                                {text.refundPurchaseAction}
                              </Button>
                            ) : (
                              <span className={styles.mutedText}>-</span>
                            )}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
              <div className={styles.pager}>
                <button
                  type="button"
                  className={styles.pagerButton}
                  disabled={purchasePage === 0 || purchasesIsFetching}
                  aria-label={text.previousPurchasesPageLabel}
                  onClick={() => setPurchasePage((current) => Math.max(0, current - 1))}
                >
                  {text.previousPage}
                </button>
                <button
                  type="button"
                  className={styles.pagerButton}
                  disabled={!purchasesHasMore || purchasesIsFetching}
                  aria-label={text.nextPurchasesPageLabel}
                  onClick={() => setPurchasePage((current) => current + 1)}
                >
                  {text.nextPage}
                </button>
              </div>
            </TableOrEmpty>
          )}
        </AdminCard>
      </AdminPageGrid>

      <AdminCard
        title={locale === "ru" ? "Watermark" : "Watermark"}
        description={
          locale === "ru"
            ? "Настройки мягкого продвижения для бесплатных результатов и разового clean unlock."
            : "Free-result promotion and one-time clean unlock settings."
        }
        action={
          <Button
            type="button"
            disabled={isSaveWatermarkDisabled}
            onClick={requestSaveWatermark}
          >
            {saveWatermarkMutation.isPending
              ? text.savingAction
              : locale === "ru"
              ? "Сохранить watermark"
              : "Save watermark"}
          </Button>
        }
      >
        {watermarkQuery.isLoading || !effectiveWatermarkDraft ? (
          <AdminStateCard
            tone="info"
            title={locale === "ru" ? "Загружаем watermark" : "Loading watermark settings"}
          />
        ) : (
          <div className={styles.rewardFields}>
            <div className={styles.formRow}>
              <label className={styles.checkboxField}>
                <input
                  type="checkbox"
                  checked={effectiveWatermarkDraft.enabled}
                  onChange={(event) => updateWatermarkDraft({ enabled: event.target.checked })}
                />
                <span>{locale === "ru" ? "Включён" : "Enabled"}</span>
              </label>
              <label className={styles.checkboxField}>
                <input
                  type="checkbox"
                  checked={effectiveWatermarkDraft.applyToImages}
                  onChange={(event) =>
                    updateWatermarkDraft({ applyToImages: event.target.checked })
                  }
                />
                <span>{locale === "ru" ? "Images" : "Images"}</span>
              </label>
              <label className={styles.checkboxField}>
                <input
                  type="checkbox"
                  checked={effectiveWatermarkDraft.applyToVideos}
                  onChange={(event) =>
                    updateWatermarkDraft({ applyToVideos: event.target.checked })
                  }
                />
                <span>{locale === "ru" ? "Videos" : "Videos"}</span>
              </label>
            </div>
            <div className={styles.formRow}>
              <label className={styles.field}>
                <span>{locale === "ru" ? "Текст" : "Text"}</span>
                <input
                  className={styles.input}
                  value={effectiveWatermarkDraft.text}
                  maxLength={WATERMARK_TEXT_MAX_LENGTH}
                  onChange={(event) =>
                    updateWatermarkDraft({
                      text: event.target.value.slice(0, WATERMARK_TEXT_MAX_LENGTH),
                    })
                  }
                />
              </label>
              <label className={styles.field}>
                <span>{locale === "ru" ? "Cost in credits" : "Cost in credits"}</span>
                <input
                  className={styles.input}
                  type="text"
                  inputMode="numeric"
                  pattern="[0-9]*"
                  maxLength={WATERMARK_COST_MAX_LENGTH}
                  value={String(effectiveWatermarkDraft.costCredits)}
                  onChange={(event) => {
                    const value = event.target.value
                      .replace(/\D+/g, "")
                      .slice(0, WATERMARK_COST_MAX_LENGTH);
                    updateWatermarkDraft({
                      costCredits: Math.max(1, Number.parseInt(value, 10) || 1),
                    });
                  }}
                />
              </label>
            </div>
            <div className={styles.formRow}>
              <label className={styles.field}>
                <span>{locale === "ru" ? "Opacity" : "Opacity"}</span>
                <input
                  className={styles.input}
                  type="text"
                  inputMode="decimal"
                  maxLength={WATERMARK_OPACITY_MAX_LENGTH}
                  value={String(effectiveWatermarkDraft.opacity)}
                  onChange={(event) => {
                    const value = event.target.value
                      .replace(/[^\d.]+/g, "")
                      .replace(/(\..*)\./g, "$1")
                      .slice(0, WATERMARK_OPACITY_MAX_LENGTH);
                    updateWatermarkDraft({
                      opacity: Math.min(
                        0.65,
                        Math.max(0.45, Number.parseFloat(value) || 0.55)
                      ),
                    });
                  }}
                />
              </label>
              <label className={styles.field}>
                <span>{locale === "ru" ? "Logo URL" : "Logo URL"}</span>
                <input
                  className={styles.input}
                  value={effectiveWatermarkDraft.logoUrl ?? ""}
                  maxLength={WATERMARK_LOGO_URL_MAX_LENGTH}
                  onChange={(event) =>
                    updateWatermarkDraft({
                      logoUrl: event.target.value.slice(0, WATERMARK_LOGO_URL_MAX_LENGTH),
                    })
                  }
                />
              </label>
            </div>
            <div className={styles.formRow}>
              <label className={styles.field}>
                <span>{locale === "ru" ? "Position" : "Position"}</span>
                <select
                  className={styles.input}
                  value={normalizeWatermarkPosition(effectiveWatermarkDraft.position)}
                  onChange={(event) => updateWatermarkDraft({ position: event.target.value })}
                >
                  {watermarkPositionOptions.map((position) => (
                    <option key={position} value={position}>
                      {position}
                    </option>
                  ))}
                </select>
              </label>
              <label className={styles.field}>
                <span>{locale === "ru" ? "Size" : "Size"}</span>
                <select
                  className={styles.input}
                  value={normalizeWatermarkSize(effectiveWatermarkDraft.size)}
                  onChange={(event) => updateWatermarkDraft({ size: event.target.value })}
                >
                  {watermarkSizeOptions.map((size) => (
                    <option key={size} value={size}>
                      {size}
                    </option>
                  ))}
                </select>
              </label>
            </div>
            <WatermarkPreviewPanel locale={locale} settings={effectiveWatermarkDraft} />
          </div>
        )}
      </AdminCard>

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
        onCancel={() => {
          if (!cancelSubscriptionInFlightRef.current && !cancelSubscriptionMutation.isPending) {
            setCancelTarget(null);
          }
        }}
        onConfirm={() => {
          if (cancelSubscriptionInFlightRef.current || cancelSubscriptionMutation.isPending) {
            return;
          }

          if (cancelTarget && canCancelSubscription(cancelTarget)) {
            cancelSubscriptionInFlightRef.current = true;
            setIsCancelSubscriptionInFlight(true);
            cancelSubscriptionMutation.mutate(cancelTarget);
          }
        }}
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
        onCancel={() => {
          if (!refundPurchaseInFlightRef.current && !refundPurchaseMutation.isPending) {
            setRefundTarget(null);
          }
        }}
        onConfirm={() => {
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

function shortGuid(value: string) {
  return safeText(value, 32).slice(0, 8);
}

function safeText(value: string | null | undefined, maxLength = 120) {
  const trimmed = value?.trim();
  return trimmed ? sanitizeSensitiveText(trimmed, maxLength) : "-";
}

function formatTokens(value: number, locale: Locale) {
  return `${new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US").format(value)} spark`;
}

function formatCurrency(value: number, locale: Locale, currencyCode: string) {
  const amount = Number.isFinite(value) ? value : 0;
  const safeCurrencyCode = safeText(currencyCode.toUpperCase(), 12);
  if (/^[A-Z]{3}$/.test(safeCurrencyCode)) {
    try {
      return new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US", {
        style: "currency",
        currency: safeCurrencyCode,
        maximumFractionDigits: 2,
      }).format(amount);
    } catch {
      // Fall through to a non-throwing display for unexpected currency codes.
    }
  }

  return `${new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US", {
    maximumFractionDigits: 2,
  }).format(amount)} ${safeCurrencyCode}`;
}

function humanizeSource(value: string, locale: Locale) {
  const labels: Record<string, { ru: string; en: string }> = {
    weekly_grant: { ru: "Недельная награда", en: "Weekly reward" },
    ad_reward: { ru: "Награда за рекламу", en: "Ad reward" },
    redeem_code: { ru: "Промокод", en: "Redeem code" },
    premium_subscription_grant: { ru: "Выдача Premium PawSpark", en: "Premium PawSpark grant" },
    generation_spend: { ru: "Списание за генерацию", en: "Generation spend" },
    generation_refund: { ru: "Возврат за генерацию", en: "Generation refund" },
    pack_purchase: { ru: "Покупка пакета", en: "Pack purchase" },
    admin_grant: { ru: "Ручное начисление", en: "Manual grant" },
    admin_debit: { ru: "Ручное списание", en: "Manual debit" },
  };

  return labels[value]?.[locale] ?? safeText(value, 80);
}

function humanizeProvider(value: string, locale: Locale) {
  const labels: Record<string, { ru: string; en: string }> = {
    app_store: { ru: "Apple App Store", en: "Apple App Store" },
    google_play: { ru: "Google Play", en: "Google Play" },
    stripe: { ru: "Stripe", en: "Stripe" },
  };

  return labels[value]?.[locale] ?? safeText(value, 80);
}

function humanizeBillingPeriod(value: string, locale: Locale) {
  const labels: Record<string, { ru: string; en: string }> = {
    monthly: { ru: "Месяц", en: "Monthly" },
    yearly: { ru: "Год", en: "Yearly" },
  };

  return labels[value]?.[locale] ?? safeText(value, 48);
}

function humanizeStatus(value: string, locale: Locale) {
  const labels: Record<string, { ru: string; en: string }> = {
    pending: { ru: "Ожидает", en: "Pending" },
    succeeded: { ru: "Успешно", en: "Succeeded" },
    failed: { ru: "Ошибка", en: "Failed" },
    refunded: { ru: "Возврат", en: "Refunded" },
    active: { ru: "Активна", en: "Active" },
    trialing: { ru: "Пробный период", en: "Trialing" },
    past_due: { ru: "Просрочка", en: "Past due" },
    canceled: { ru: "Отменена", en: "Canceled" },
    expired: { ru: "Истекла", en: "Expired" },
    processed: { ru: "Обработано", en: "Processed" },
  };

  return labels[value]?.[locale] ?? value;
}

function statusColor(value: string) {
  switch (value) {
    case "active":
    case "succeeded":
    case "processed":
      return "var(--success)";
    case "trialing":
      return "var(--info)";
    case "past_due":
    case "failed":
      return "var(--danger)";
    case "canceled":
    case "expired":
    case "refunded":
      return "var(--neutral)";
    default:
      return "var(--warning)";
  }
}
