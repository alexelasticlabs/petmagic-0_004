"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";

import { useSyncFeedbackToAdminNotifications } from "@/components/admin/admin-notifications";
import {
  AdminKpiCard,
  AdminPage,
  AdminPageGrid,
  AdminPageHero,
  AdminStateCard,
} from "@/components/admin/admin-primitives";
import { EconomyPageConfirmationDialogs } from "@/components/economy-page-confirmation-dialogs";
import { EconomyPageIncidentsSection } from "@/components/economy-page-incidents-section";
import { EconomyPageLedgerPurchasesSection } from "@/components/economy-page-ledger-purchases-section";
import { EconomyPagePacksSection } from "@/components/economy-page-packs-section";
import { EconomyPageProviderConfigsSection } from "@/components/economy-page-provider-configs-section";
import { EconomyPageSubscriptionPlansSection } from "@/components/economy-page-subscription-plans-section";
import { EconomyPageSubscriptionsSection } from "@/components/economy-page-subscriptions-section";
import { EconomyPageWatermarkSection } from "@/components/economy-page-watermark-section";
import { getEconomyText } from "@/components/economy-page.content";
import styles from "@/components/economy-page.module.css";
import {
  formatCurrency,
  formatTokens,
  humanizeBillingPeriod,
  humanizeProvider,
  humanizeStatus,
  shortGuid,
  statusColor,
  useTimedFeedbackReset,
} from "@/components/economy-page.shared";
import { Button } from "@/components/ui/button";
import { useEconomyCatalogMutations } from "@/components/use-economy-catalog-mutations";
import { useEconomyPageController } from "@/components/use-economy-page-controller";
import { useEconomySubscriptionPurchaseActions } from "@/components/use-economy-subscription-purchase-actions";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  applyAdminEconomyIncidentAction,
  fetchAdminEconomyIncidentDetail,
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

export function EconomyPage({ locale }: EconomyPageProps) {
  const text = getEconomyText(locale);
  const session = useAuthSession();
  const queryClient = useQueryClient();
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
    incidentCategory,
    incidentItems,
    incidentPage,
    incidentStatus,
    incidentType,
    incidentsHasMore,
    incidentsIsFetching,
    incidentsIsRefreshing,
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
    openIncidents,
    purchasesHasMore,
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
  const [feedback, setFeedback] = useState<{ tone: "success" | "danger"; message: string } | null>(
    null
  );
  const [selectedIncidentId, setSelectedIncidentId] = useState<string | null>(null);

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
    onSuccess: async () => {
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
      await queryClient.invalidateQueries({ queryKey: adminQueryKeys.economyIncidents({}) });
      await invalidateEconomyQueries();
    },
    onError: () => setFeedback({ tone: "danger", message: text.incidentResolveError }),
  });

  const selectedIncidentDetailQuery = useQuery({
    queryKey: selectedIncidentId
      ? adminQueryKeys.economyIncident(selectedIncidentId)
      : adminQueryKeys.economyIncident("disabled"),
    queryFn: ({ signal }) => fetchAdminEconomyIncidentDetail(selectedIncidentId ?? "", signal),
    enabled: canManageEconomy && Boolean(selectedIncidentId),
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
        <AdminKpiCard
          label={text.openIncidentsLabel}
          value={String(openIncidents)}
          tone={openIncidents > 0 ? "warning" : "success"}
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
        drafts={catalog.drafts}
        setDrafts={catalog.setDrafts}
        savePackPending={catalog.savePackPending}
        savePackId={catalog.savePackId}
        onSavePack={catalog.requestSavePack}
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
        isRefundPurchaseSubmitting={subscriptionPurchaseActions.isRefundPurchaseSubmitting}
        onRefundPurchase={subscriptionPurchaseActions.requestRefundPurchase}
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

      <EconomyPageIncidentsSection
        locale={locale}
        text={text}
        selectedIncidentId={selectedIncidentId}
        selectedIncidentDetail={selectedIncidentDetailQuery.data ?? null}
        selectedIncidentLoading={selectedIncidentDetailQuery.isFetching}
        incidentItems={incidentItems}
        incidentCategory={incidentCategory}
        incidentStatus={incidentStatus}
        incidentType={incidentType}
        incidentPage={incidentPage}
        incidentsHasMore={incidentsHasMore}
        incidentsIsFetching={incidentsIsFetching}
        incidentsIsRefreshing={incidentsIsRefreshing}
        runReconciliationPending={reconciliationMutation.isPending}
        actionPending={resolveIncidentMutation.isPending || incidentActionMutation.isPending}
        setIncidentCategory={setIncidentCategory}
        setIncidentStatus={setIncidentStatus}
        setIncidentType={setIncidentType}
        setIncidentPage={setIncidentPage}
        onSelectIncident={(incident) => setSelectedIncidentId(incident.incidentId)}
        onRunReconciliation={() => reconciliationMutation.mutate()}
        onResolveIncident={(incident) => resolveIncidentMutation.mutate(incident)}
        onApplyIncidentAction={(payload) => incidentActionMutation.mutate(payload)}
      />

      <AdminPageGrid columns="two">
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
          cancelSubscriptionPending={subscriptionPurchaseActions.isCancelSubscriptionSubmitting}
          subscriptionEvents={subscriptionEvents}
          setSubscriptionProvider={setSubscriptionProvider}
          setSubscriptionStatus={setSubscriptionStatus}
          setSubscriptionSearch={setSubscriptionSearch}
          setSubscriptionPage={setSubscriptionPage}
          setEventProvider={setEventProvider}
          setEventStatus={setEventStatus}
          onCancelSubscription={subscriptionPurchaseActions.requestCancelSubscription}
          shortGuid={shortGuid}
          humanizeProvider={humanizeProvider}
          humanizeStatus={humanizeStatus}
          statusColor={statusColor}
        />
      </AdminPageGrid>

      <EconomyPageConfirmationDialogs
        text={text}
        locale={locale}
        cancelTarget={subscriptionPurchaseActions.cancelTarget}
        refundTarget={subscriptionPurchaseActions.refundTarget}
        isCancelSubscriptionSubmitting={subscriptionPurchaseActions.isCancelSubscriptionSubmitting}
        isRefundPurchaseSubmitting={subscriptionPurchaseActions.isRefundPurchaseSubmitting}
        onCancelSubscriptionClose={subscriptionPurchaseActions.onCancelSubscriptionClose}
        onCancelSubscriptionConfirm={subscriptionPurchaseActions.onCancelSubscriptionConfirm}
        onRefundPurchaseClose={subscriptionPurchaseActions.onRefundPurchaseClose}
        onRefundPurchaseConfirm={subscriptionPurchaseActions.onRefundPurchaseConfirm}
      />
    </AdminPage>
  );
}
