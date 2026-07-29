"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { type KeyboardEvent, useEffect, useRef, useState } from "react";

import { useSyncFeedbackToAdminNotifications } from "@/components/admin/admin-notifications";
import {
  AdminMetricStrip,
  AdminPage,
  AdminSectionHeader,
  AdminStateCard,
  AdminSummaryChips,
} from "@/components/admin/admin-primitives";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import { useAdminUrlStateSyncGuard } from "@/components/admin/use-admin-url-state-sync-guard";
import { EconomyPageConfirmationDialogs } from "@/components/economy-page-confirmation-dialogs";
import { EconomyPageIncidentsSection } from "@/components/economy-page-incidents-section";
import { EconomyPageLedgerPurchasesSection } from "@/components/economy-page-ledger-purchases-section";
import { EconomyPageOverviewActions } from "@/components/economy-page-overview-actions";
import { EconomyPagePacksSection } from "@/components/economy-page-packs-section";
import { EconomyPageProviderConfigsSection } from "@/components/economy-page-provider-configs-section";
import { EconomyPageSubscriptionPlansSection } from "@/components/economy-page-subscription-plans-section";
import { EconomyPageSubscriptionsSection } from "@/components/economy-page-subscriptions-section";
import { EconomyPageWatermarkSection } from "@/components/economy-page-watermark-section";
import { type EconomyWorkspace } from "@/components/economy-page-workspace";
import { getEconomyText, type EconomyPageText } from "@/components/economy-page.content";
import styles from "@/components/economy-page.module.css";
import {
  formatCurrency,
  humanizeBillingPeriod,
  humanizeProvider,
  humanizeStatus,
  shortGuid,
  statusColor,
  useTimedFeedbackReset,
} from "@/components/economy-page.shared";
import { EconomyPurchaseInspector } from "@/components/economy-purchase-inspector";
import { Button } from "@/components/ui/button";
import { useEconomyCatalogMutations } from "@/components/use-economy-catalog-mutations";
import { useEconomyPageController } from "@/components/use-economy-page-controller";
import { useEconomySubscriptionPurchaseActions } from "@/components/use-economy-subscription-purchase-actions";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  applyAdminEconomyIncidentAction,
  fetchAdminEconomyIncidentDetail,
  fetchAdminEconomyPurchase,
  resolveAdminEconomyIncident,
  runAdminEconomyReconciliation,
  type AdminEconomyIncident,
  type AdminEconomyIncidentAction,
  type EconomyReconciliationRun,
  useAuthSession,
} from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";

type EconomyPageProps = {
  locale: Locale;
};

const economyWorkspaces = [
  {
    value: "overview",
    labelKey: "overviewWorkspaceLabel",
    descriptionKey: "overviewWorkspaceDescription",
  },
  {
    value: "catalog",
    labelKey: "catalogWorkspaceLabel",
    descriptionKey: "catalogWorkspaceDescription",
  },
  {
    value: "subscriptions",
    labelKey: "subscriptionsWorkspaceLabel",
    descriptionKey: "subscriptionsWorkspaceDescription",
  },
  {
    value: "payments",
    labelKey: "paymentsWorkspaceLabel",
    descriptionKey: "paymentsWorkspaceDescription",
  },
] as const satisfies ReadonlyArray<{
  value: EconomyWorkspace;
  labelKey: keyof EconomyPageText;
  descriptionKey: keyof EconomyPageText;
}>;

function readEconomyWorkspace(value: string | null): EconomyWorkspace {
  return economyWorkspaces.some((item) => item.value === value)
    ? (value as EconomyWorkspace)
    : "overview";
}

function formatWeekDelta(current: number, previous: number, text: EconomyPageText) {
  if (previous <= 0) {
    return text.noPreviousWeekLabel;
  }

  const delta = Math.round(((current - previous) / previous) * 100);
  return `${delta > 0 ? "+" : ""}${delta}% ${text.previousWeekLabel}`;
}

function formatOptionalWeekDelta(current: number, previous: number, text: EconomyPageText) {
  return previous > 0 ? formatWeekDelta(current, previous, text) : "—";
}

export function EconomyPage({ locale }: EconomyPageProps) {
  const text = getEconomyText(locale);
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const session = useAuthSession();
  const queryClient = useQueryClient();
  const canManageEconomy = session?.user.roles.includes("Admin") ?? false;
  const [workspace, setWorkspace] = useState<EconomyWorkspace>(() =>
    readEconomyWorkspace(searchParams.get("workspace"))
  );
  const workspaceNavRef = useRef<HTMLDivElement | null>(null);
  const workspaceTabRefs = useRef<Partial<Record<EconomyWorkspace, HTMLButtonElement | null>>>({});
  const workspacePanelRef = useRef<HTMLDivElement | null>(null);
  const shouldFocusWorkspacePanel = useRef(false);
  const [feedback, setFeedback] = useState<{ tone: "success" | "danger"; message: string } | null>(
    null
  );
  const [selectedIncidentId, setSelectedIncidentId] = useState<string | null>(() => {
    const value = (searchParams.get("incident") ?? "").trim().slice(0, 80);
    return value || null;
  });
  const [selectedPurchaseId, setSelectedPurchaseId] = useState<string | null>(() => {
    const value = (searchParams.get("purchase") ?? "").trim().slice(0, 80);
    return value || null;
  });
  const [isReconciliationDialogOpen, setIsReconciliationDialogOpen] = useState(false);
  const [lastReconciliation, setLastReconciliation] = useState<EconomyReconciliationRun | null>(
    null
  );
  const {
    applyUrlState: applyControllerUrlState,
    eventPage,
    eventProvider,
    eventStatus,
    refetchAll,
    economyError,
    hasBlockingError,
    hasPartialError,
    isFetching,
    isLoading,
    incidentCategory,
    incidentItems,
    incidentPage,
    incidentStatus,
    incidentType,
    incidentsHasMore,
    incidentsIsFetching,
    ledgerHasMore,
    ledgerItems,
    ledgerIsFetching,
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
    premiumMetrics,
    purchasesHasMore,
    setEventPage,
    setEventProvider,
    setEventStatus,
    setIncidentPage,
    setIncidentCategory,
    setIncidentStatus,
    setIncidentType,
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
    subscriptionEventsHasMore,
    subscriptionEventsIsFetching,
    subscriptionPage,
    subscriptionItems,
    subscriptionsIsFetching,
    subscriptionSearch,
    subscriptionsHasMore,
    subscriptionPlans,
    subscriptionProvider,
    subscriptionStatus,
  } = useEconomyPageController({ locale, workspace });
  const currentSearchParams = searchParams.toString();
  const { consumeUrlStateApplication, markUrlStateWritten } = useAdminUrlStateSyncGuard({
    currentSearch: currentSearchParams,
    applyUrlState: (nextSearchParams) => {
      setWorkspace(readEconomyWorkspace(nextSearchParams.get("workspace")));
      const nextIncidentId = (nextSearchParams.get("incident") ?? "").trim().slice(0, 80);
      setSelectedIncidentId(nextIncidentId || null);
      const nextPurchaseId = (nextSearchParams.get("purchase") ?? "").trim().slice(0, 80);
      setSelectedPurchaseId(nextPurchaseId || null);
      applyControllerUrlState(nextSearchParams);
    },
  });

  useEffect(() => {
    if (consumeUrlStateApplication()) {
      return;
    }

    const next = new URLSearchParams(searchParams.toString());
    const setOptional = (key: string, value: string, defaultValue = "") => {
      if (!value || value === defaultValue) next.delete(key);
      else next.set(key, value);
    };

    setOptional("workspace", workspace, "overview");
    setOptional("purchaseStatus", purchaseStatus);
    setOptional("purchaseProvider", purchaseProvider);
    setOptional("purchaseSearch", purchaseSearch);
    setOptional("purchasePage", purchasePage > 0 ? String(purchasePage + 1) : "");
    setOptional("incidentStatus", incidentStatus, "open");
    setOptional("incidentCategory", incidentCategory);
    setOptional("incidentType", incidentType);
    setOptional("incidentPage", incidentPage > 0 ? String(incidentPage + 1) : "");
    setOptional("incident", selectedIncidentId ?? "");
    setOptional("purchase", selectedPurchaseId ?? "");

    const nextSearch = next.toString();
    if (nextSearch !== searchParams.toString()) {
      markUrlStateWritten(nextSearch);
      router.replace(nextSearch ? `${pathname}?${nextSearch}` : pathname, { scroll: false });
    }
  }, [
    consumeUrlStateApplication,
    incidentCategory,
    incidentPage,
    incidentStatus,
    incidentType,
    markUrlStateWritten,
    pathname,
    purchasePage,
    purchaseProvider,
    purchaseSearch,
    purchaseStatus,
    router,
    searchParams,
    selectedIncidentId,
    selectedPurchaseId,
    workspace,
  ]);

  useSyncFeedbackToAdminNotifications(feedback, {
    category: "economy",
    source: "economy-admin",
    title: text.title,
    href: `/${locale}/economy`,
  });

  useTimedFeedbackReset(feedback, () => setFeedback(null));

  const invalidateEconomyQueries = async () => {
    await queryClient.invalidateQueries({ queryKey: ["admin", "economy"] });
  };

  const reconciliationMutation = useMutation<EconomyReconciliationRun, Error>({
    mutationFn: runAdminEconomyReconciliation,
    onSuccess: async (result) => {
      setLastReconciliation(result);
      setIsReconciliationDialogOpen(false);
      setFeedback({ tone: "success", message: text.reconciliationStarted });
      await invalidateEconomyQueries();
    },
    onError: () => setFeedback({ tone: "danger", message: text.reconciliationFailed }),
  });

  const resolveIncidentMutation = useMutation<AdminEconomyIncident, Error, AdminEconomyIncident>({
    mutationFn: async (incident) =>
      resolveAdminEconomyIncident(incident.incidentId, text.incidentAutoResolveReason),
    onSuccess: async () => {
      setFeedback({ tone: "success", message: text.incidentResolved });
      await invalidateEconomyQueries();
    },
    onError: () => setFeedback({ tone: "danger", message: text.incidentResolveError }),
  });

  const selectedIncidentDetailQuery = useQuery({
    queryKey: selectedIncidentId
      ? adminQueryKeys.economyIncident(selectedIncidentId)
      : adminQueryKeys.economyIncident("disabled"),
    queryFn: ({ signal }) => fetchAdminEconomyIncidentDetail(selectedIncidentId ?? "", signal),
    enabled: canManageEconomy && workspace === "payments" && Boolean(selectedIncidentId),
  });

  const selectedPurchaseQuery = useQuery({
    queryKey: selectedPurchaseId
      ? adminQueryKeys.economyPurchase(selectedPurchaseId)
      : adminQueryKeys.economyPurchase("disabled"),
    queryFn: ({ signal }) => fetchAdminEconomyPurchase(selectedPurchaseId ?? "", signal),
    enabled: canManageEconomy && workspace === "overview" && Boolean(selectedPurchaseId),
  });

  const incidentActionMutation = useMutation<
    AdminEconomyIncidentAction,
    Error,
    {
      incidentId: string;
      action: string;
      reason: string;
      amount?: number;
      externalReferenceId?: string;
    }
  >({
    mutationFn: ({ incidentId, ...payload }) =>
      applyAdminEconomyIncidentAction(incidentId, payload),
    onSuccess: async (result) => {
      setFeedback({ tone: "success", message: text.incidentActionSuccess });
      setSelectedIncidentId(result.incident.incidentId);
      await invalidateEconomyQueries();
    },
    onError: () => setFeedback({ tone: "danger", message: text.incidentActionError }),
  });

  const catalog = useEconomyCatalogMutations({
    text,
    canManageEconomy,
    loadWatermark: workspace === "catalog",
    packs,
    subscriptionPlans,
    providerConfigs,
    setFeedback,
  });

  const subscriptionPurchaseActions = useEconomySubscriptionPurchaseActions({
    text,
    canManageEconomy,
    purchaseItems,
    subscriptionItems,
    setFeedback,
  });

  function requestEconomyRetry() {
    if (!canManageEconomy || isFetching) {
      return;
    }

    void refetchAll().catch(() => undefined);
  }

  useEffect(() => {
    if (!shouldFocusWorkspacePanel.current) {
      return;
    }

    shouldFocusWorkspacePanel.current = false;
    workspacePanelRef.current?.focus();
  }, [workspace]);

  useEffect(() => {
    let frameId = 0;
    const keepActiveWorkspaceVisible = () => {
      cancelAnimationFrame(frameId);
      frameId = requestAnimationFrame(() => {
        const navigation = workspaceNavRef.current;
        const activeTab = workspaceTabRefs.current[workspace];
        if (!navigation || !activeTab) {
          return;
        }

        navigation.scrollTo({
          left: Math.max(
            0,
            activeTab.offsetLeft - (navigation.clientWidth - activeTab.offsetWidth) / 2
          ),
          behavior: "auto",
        });
      });
    };

    keepActiveWorkspaceVisible();
    window.addEventListener("resize", keepActiveWorkspaceVisible);
    return () => {
      window.removeEventListener("resize", keepActiveWorkspaceVisible);
      cancelAnimationFrame(frameId);
    };
  }, [workspace]);

  function selectWorkspace(nextWorkspace: EconomyWorkspace, focusWorkspacePanel = false) {
    if (nextWorkspace === workspace) {
      if (focusWorkspacePanel) {
        workspacePanelRef.current?.focus();
      }
      return;
    }

    shouldFocusWorkspacePanel.current = focusWorkspacePanel;
    setWorkspace(nextWorkspace);
    if (nextWorkspace !== "payments") {
      setSelectedIncidentId(null);
    }
    if (nextWorkspace !== "overview") {
      setSelectedPurchaseId(null);
    }
  }

  function openIncidentsWorkspace() {
    setSelectedIncidentId(null);
    setIncidentCategory("");
    setIncidentStatus("open");
    setIncidentType("");
    setIncidentPage(0);
    selectWorkspace("payments", true);
  }

  function openPaymentRoutesWorkspace() {
    setSelectedIncidentId(null);
    selectWorkspace("payments", true);
  }

  function openReconciliationDialog() {
    if (!canManageEconomy || reconciliationMutation.isPending) {
      return;
    }

    setIsReconciliationDialogOpen(true);
  }

  function confirmReconciliation() {
    if (!canManageEconomy || reconciliationMutation.isPending) {
      return;
    }

    reconciliationMutation.mutate();
  }

  function handleWorkspaceTabKeyDown(
    event: KeyboardEvent<HTMLButtonElement>,
    currentIndex: number
  ) {
    let nextIndex: number | null = null;

    switch (event.key) {
      case "ArrowRight":
      case "ArrowDown":
        nextIndex = (currentIndex + 1) % economyWorkspaces.length;
        break;
      case "ArrowLeft":
      case "ArrowUp":
        nextIndex = (currentIndex - 1 + economyWorkspaces.length) % economyWorkspaces.length;
        break;
      case "Home":
        nextIndex = 0;
        break;
      case "End":
        nextIndex = economyWorkspaces.length - 1;
        break;
      default:
        return;
    }

    event.preventDefault();
    const nextWorkspace = economyWorkspaces[nextIndex]?.value ?? "overview";
    selectWorkspace(nextWorkspace);
    queueMicrotask(() => workspaceTabRefs.current[nextWorkspace]?.focus());
  }

  const workspaceContent = (() => {
    if (!canManageEconomy || isLoading) {
      return (
        <AdminStateCard
          tone="info"
          title={text.loadingTitle}
          description={text.loadingDescription}
        />
      );
    }

    if (hasBlockingError) {
      return (
        <AdminStateCard
          tone="danger"
          title={text.errorTitle}
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
      );
    }

    if (workspace === "overview") {
      return (
        <>
          <section className={styles.workspaceSection} aria-labelledby="economy-overview-title">
            <AdminSectionHeader title={text.overviewTitle} titleId="economy-overview-title" />
            <AdminMetricStrip
              items={[
                {
                  label: text.revenueLabel,
                  value: formatCurrency(metrics.grossRevenue, locale, metrics.revenueCurrencyCode),
                  hint: formatWeekDelta(metrics.grossRevenue, metrics.revenuePreviousWeek, text),
                  tone: "primary",
                },
                {
                  label: text.successfulPaymentsLabel,
                  value: metrics.successfulPaymentsThisWeek,
                  hint: formatOptionalWeekDelta(
                    metrics.successfulPaymentsThisWeek,
                    metrics.successfulPaymentsPreviousWeek,
                    text
                  ),
                  tone: "success",
                },
                {
                  label: text.failedPaymentsLabel,
                  value: metrics.failedPaymentsThisWeek,
                  hint: formatOptionalWeekDelta(
                    metrics.failedPaymentsThisWeek,
                    metrics.failedPaymentsPreviousWeek,
                    text
                  ),
                  tone: metrics.failedPaymentsThisWeek > 0 ? "danger" : "neutral",
                },
                {
                  label: text.activeSubscriptionsLabel,
                  value: premiumMetrics.activeSubscriptions,
                  hint: `${text.renewalStopsLabel}: ${premiumMetrics.renewalStops}`,
                  tone: "info",
                },
              ]}
            />
            <AdminSummaryChips
              items={[
                `${text.purchasesThisWeekLabel}: ${metrics.purchasesThisWeek}`,
                formatOptionalWeekDelta(
                  metrics.purchasesThisWeek,
                  metrics.purchasesPreviousWeek,
                  text
                ),
              ]}
            />
          </section>

          <EconomyPageOverviewActions
            locale={locale}
            text={text}
            isRefreshing={isFetching}
            isReconciliationPending={reconciliationMutation.isPending}
            lastReconciliation={lastReconciliation}
            onRefresh={requestEconomyRetry}
            onOpenIncidents={openIncidentsWorkspace}
            onOpenPaymentRoutes={openPaymentRoutesWorkspace}
            onRunReconciliation={openReconciliationDialog}
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
            setLedgerPage={setLedgerPage}
            purchaseStatus={purchaseStatus}
            setPurchaseStatus={setPurchaseStatus}
            purchaseProvider={purchaseProvider}
            setPurchaseProvider={setPurchaseProvider}
            purchaseSearch={purchaseSearch}
            setPurchaseSearch={setPurchaseSearch}
            purchasesIsFetching={purchasesIsFetching}
            purchaseItems={purchaseItems}
            purchasePage={purchasePage}
            purchasesHasMore={purchasesHasMore}
            setPurchasePage={setPurchasePage}
            isRefundPurchaseSubmitting={subscriptionPurchaseActions.isRefundPurchaseSubmitting}
            onRefundPurchase={subscriptionPurchaseActions.requestRefundPurchase}
            onInspectPurchase={(purchase) => setSelectedPurchaseId(purchase.orderId)}
          />
        </>
      );
    }

    if (workspace === "catalog") {
      return (
        <>
          <EconomyPagePacksSection
            text={text}
            packs={packs}
            drafts={catalog.drafts}
            setDrafts={catalog.setDrafts}
            savePackPending={catalog.savePackPending}
            savePackId={catalog.savePackId}
            onSavePack={catalog.requestSavePack}
          />
          <EconomyPageWatermarkSection
            text={text}
            effectiveWatermarkDraft={catalog.effectiveWatermarkDraft}
            isLoading={catalog.watermarkQuery.isLoading}
            isSaveDisabled={catalog.isSaveWatermarkDisabled}
            isSavePending={catalog.saveWatermarkPending}
            onSubmit={catalog.requestSaveWatermark}
            onUpdateDraft={catalog.updateWatermarkDraft}
          />
        </>
      );
    }

    if (workspace === "subscriptions") {
      return (
        <>
          <EconomyPageSubscriptionPlansSection
            locale={locale}
            text={text}
            subscriptionPlans={subscriptionPlans}
            planDrafts={catalog.planDrafts}
            setPlanDrafts={catalog.setPlanDrafts}
            savePlanPending={catalog.savePlanPending}
            savePlanId={catalog.savePlanId}
            onSavePlan={catalog.requestSavePlan}
            humanizeBillingPeriod={humanizeBillingPeriod}
          />
          <EconomyPageSubscriptionsSection
            locale={locale}
            text={text}
            subscriptionProvider={subscriptionProvider}
            subscriptionStatus={subscriptionStatus}
            eventProvider={eventProvider}
            eventStatus={eventStatus}
            eventPage={eventPage}
            subscriptionSearch={subscriptionSearch}
            subscriptionPage={subscriptionPage}
            subscriptionsHasMore={subscriptionsHasMore}
            subscriptionItems={subscriptionItems}
            subscriptionsIsFetching={subscriptionsIsFetching}
            cancelSubscriptionPending={subscriptionPurchaseActions.isCancelSubscriptionSubmitting}
            subscriptionEvents={subscriptionEvents}
            subscriptionEventsHasMore={subscriptionEventsHasMore}
            subscriptionEventsIsFetching={subscriptionEventsIsFetching}
            setSubscriptionProvider={setSubscriptionProvider}
            setSubscriptionStatus={setSubscriptionStatus}
            setSubscriptionSearch={setSubscriptionSearch}
            setSubscriptionPage={setSubscriptionPage}
            setEventProvider={setEventProvider}
            setEventStatus={setEventStatus}
            setEventPage={setEventPage}
            onCancelSubscription={subscriptionPurchaseActions.requestCancelSubscription}
            shortGuid={shortGuid}
            humanizeProvider={humanizeProvider}
            humanizeStatus={humanizeStatus}
            statusColor={statusColor}
          />
        </>
      );
    }

    return (
      <>
        <EconomyPageProviderConfigsSection
          locale={locale}
          text={text}
          providerConfigs={providerConfigs}
          providerConfigDrafts={catalog.providerConfigDrafts}
          createProviderDraft={catalog.createProviderDraft}
          setCreateProviderDraft={catalog.setCreateProviderDraft}
          matchDraft={catalog.matchDraft}
          setMatchDraft={catalog.setMatchDraft}
          matchResult={catalog.matchResult}
          setProviderConfigDrafts={catalog.setProviderConfigDrafts}
          cloneRegionDrafts={catalog.cloneRegionDrafts}
          setCloneRegionDrafts={catalog.setCloneRegionDrafts}
          saveProviderConfigPending={catalog.saveProviderConfigPending}
          saveProviderConfigId={catalog.saveProviderConfigId}
          createProviderConfigPending={catalog.createProviderConfigPending}
          testProviderConfigPending={catalog.testProviderConfigPending}
          cloneProviderConfigPending={catalog.cloneProviderConfigPending}
          cloneProviderConfigId={catalog.cloneProviderConfigId}
          deleteProviderConfigPending={catalog.deleteProviderConfigPending}
          deleteProviderConfigId={catalog.deleteProviderConfigId}
          onSaveProviderConfig={catalog.requestSaveProviderConfig}
          onCreateProviderConfig={catalog.requestCreateProviderConfig}
          onTestProviderConfig={catalog.requestTestProviderConfig}
          onCloneProviderConfig={catalog.requestCloneProviderConfig}
          onDeleteProviderConfig={catalog.requestDeleteProviderConfig}
          humanizeProvider={humanizeProvider}
        />
        <EconomyPageIncidentsSection
          locale={locale}
          text={text}
          selectedIncidentId={selectedIncidentId}
          selectedIncidentDetail={selectedIncidentDetailQuery.data ?? null}
          selectedIncidentLoading={selectedIncidentDetailQuery.isFetching}
          selectedIncidentError={
            selectedIncidentDetailQuery.isError
              ? getAdminErrorMessage(
                  selectedIncidentDetailQuery.error,
                  text.incidentDetailLoadError
                )
              : null
          }
          incidentItems={incidentItems}
          incidentCategory={incidentCategory}
          incidentStatus={incidentStatus}
          incidentType={incidentType}
          incidentPage={incidentPage}
          incidentsHasMore={incidentsHasMore}
          incidentsIsFetching={incidentsIsFetching}
          runReconciliationPending={reconciliationMutation.isPending}
          actionPending={resolveIncidentMutation.isPending || incidentActionMutation.isPending}
          setIncidentCategory={(value) => {
            setSelectedIncidentId(null);
            setIncidentCategory(value);
          }}
          setIncidentStatus={(value) => {
            setSelectedIncidentId(null);
            setIncidentStatus(value);
          }}
          setIncidentType={(value) => {
            setSelectedIncidentId(null);
            setIncidentType(value);
          }}
          setIncidentPage={(value) => {
            setSelectedIncidentId(null);
            setIncidentPage(value);
          }}
          onSelectIncident={(incident) => setSelectedIncidentId(incident.incidentId)}
          onRetrySelectedIncident={() => void selectedIncidentDetailQuery.refetch()}
          onRunReconciliation={openReconciliationDialog}
          onResolveIncident={async (incident) => {
            try {
              await resolveIncidentMutation.mutateAsync(incident);
              return true;
            } catch {
              return false;
            }
          }}
          onApplyIncidentAction={(payload) => incidentActionMutation.mutate(payload)}
        />
      </>
    );
  })();

  return (
    <AdminPage className={styles.page}>
      <div
        className={styles.workspaceToolbar}
        data-has-action={workspace !== "overview" || undefined}
      >
        <div
          ref={workspaceNavRef}
          className={styles.workspaceNav}
          role="tablist"
          aria-label={text.workspaceNavigationLabel}
        >
          {economyWorkspaces.map((item, index) => {
            const isActive = item.value === workspace;

            return (
              <button
                ref={(element) => {
                  workspaceTabRefs.current[item.value] = element;
                }}
                key={item.value}
                type="button"
                id={`economy-workspace-tab-${item.value}`}
                role="tab"
                className={styles.workspaceTab}
                data-active={isActive || undefined}
                aria-controls="economy-workspace-panel"
                aria-label={`${text[item.labelKey]}: ${text[item.descriptionKey]}`}
                aria-selected={isActive}
                tabIndex={isActive ? 0 : -1}
                onClick={() => selectWorkspace(item.value)}
                onKeyDown={(event) => handleWorkspaceTabKeyDown(event, index)}
              >
                <strong>{text[item.labelKey]}</strong>
              </button>
            );
          })}
        </div>
        {workspace !== "overview" ? (
          <Button
            type="button"
            variant="secondary"
            disabled={!canManageEconomy || isFetching}
            onClick={requestEconomyRetry}
          >
            {isFetching ? text.refreshingAction : text.refreshAction}
          </Button>
        ) : null}
      </div>

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

      <div
        id="economy-workspace-panel"
        ref={workspacePanelRef}
        className={styles.workspacePanel}
        role="tabpanel"
        tabIndex={-1}
        aria-labelledby={`economy-workspace-tab-${workspace}`}
      >
        {workspaceContent}
      </div>

      <EconomyPurchaseInspector
        locale={locale}
        orderId={selectedPurchaseId}
        detail={selectedPurchaseQuery.data ?? null}
        isLoading={selectedPurchaseQuery.isFetching}
        error={
          selectedPurchaseQuery.isError
            ? getAdminErrorMessage(selectedPurchaseQuery.error, text.errorDescription)
            : null
        }
        isRefundPending={subscriptionPurchaseActions.isRefundPurchaseSubmitting}
        onClose={() => setSelectedPurchaseId(null)}
        onRetry={() => void selectedPurchaseQuery.refetch()}
        onRefund={subscriptionPurchaseActions.requestRefundPurchase}
      />

      <EconomyPageConfirmationDialogs
        text={text}
        locale={locale}
        cancelTarget={subscriptionPurchaseActions.cancelTarget}
        cancelReason={subscriptionPurchaseActions.cancelReason}
        cancelError={subscriptionPurchaseActions.cancelError}
        refundTarget={subscriptionPurchaseActions.refundTarget}
        isCancelSubscriptionSubmitting={subscriptionPurchaseActions.isCancelSubscriptionSubmitting}
        isRefundPurchaseSubmitting={subscriptionPurchaseActions.isRefundPurchaseSubmitting}
        onCancelSubscriptionClose={subscriptionPurchaseActions.onCancelSubscriptionClose}
        onCancelSubscriptionConfirm={subscriptionPurchaseActions.onCancelSubscriptionConfirm}
        onCancelReasonChange={subscriptionPurchaseActions.setCancelReason}
        onRefundPurchaseClose={subscriptionPurchaseActions.onRefundPurchaseClose}
        onRefundPurchaseConfirm={subscriptionPurchaseActions.onRefundPurchaseConfirm}
      />
      <ConfirmationDialog
        open={isReconciliationDialogOpen}
        title={text.reconciliationConfirmTitle}
        description={text.reconciliationConfirmDescription}
        confirmLabel={text.runReconciliationAction}
        cancelLabel={text.confirmationCancel}
        tone="primary"
        isSubmitting={reconciliationMutation.isPending}
        onCancel={() => {
          if (!reconciliationMutation.isPending) {
            setIsReconciliationDialogOpen(false);
          }
        }}
        onConfirm={confirmReconciliation}
      />
    </AdminPage>
  );
}
