"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useState, type ReactNode } from "react";

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
import { EconomyPageProviderConfigsSection } from "@/components/economy-page-provider-configs-section";
import { EconomyPageSubscriptionPlansSection } from "@/components/economy-page-subscription-plans-section";
import { EconomyPageSubscriptionsSection } from "@/components/economy-page-subscriptions-section";
import {
  getEconomyText,
  ledgerSourceOptions,
  purchaseStatusOptions,
} from "@/components/economy-page.content";
import {
  createDefaultProviderConfigDraft,
  toDraft,
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
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  cloneAdminPaymentProviderConfig,
  createAdminPaymentProviderConfig,
  deleteAdminPaymentProviderConfig,
  testAdminPaymentProviderConfigMatch,
  updateAdminCurrencyPack,
  updateAdminPaymentProviderConfig,
  updateAdminSubscriptionPlan,
  type AdminPaymentProviderConfigurationMatch,
} from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import { type Locale } from "@/lib/i18n";

type EconomyPageProps = {
  locale: Locale;
};

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

export function EconomyPage({ locale }: EconomyPageProps) {
  const text = getEconomyText(locale);
  const queryClient = useQueryClient();
  const {
    eventProvider,
    eventStatus,
    hasError,
    isLoading,
    ledgerItems,
    ledgerSource,
    metrics,
    packs,
    providerConfigs,
    purchaseItems,
    purchaseStatus,
    premiumMetrics,
    setEventProvider,
    setEventStatus,
    setLedgerSource,
    setPurchaseStatus,
    setSubscriptionProvider,
    setSubscriptionStatus,
    subscriptionEvents,
    subscriptionItems,
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

  const savePackMutation = useMutation({
    mutationFn: async (packId: string) => {
      const pack = packs.find((item) => item.packId === packId);
      const draft = drafts[packId] ?? (pack ? toDraft(pack) : null);
      if (!draft) {
        throw new Error("Missing draft");
      }

      return updateAdminCurrencyPack(packId, {
        displayName: draft.displayName.trim(),
        priceAmount: Number(draft.priceAmount),
        grantedSpark: Number(draft.grantedSpark),
        bonusSpark: Number(draft.bonusSpark),
        isActive: draft.isActive,
        sortOrder: Number(draft.sortOrder),
      });
    },
    onSuccess: async (pack) => {
      setFeedback({ tone: "success", message: text.packSaved });
      setDrafts((current) => ({ ...current, [pack.packId]: toDraft(pack) }));
      await queryClient.invalidateQueries({ queryKey: adminQueryKeys.economyPacks });
    },
    onError: () => {
      setFeedback({ tone: "danger", message: text.packSaveError });
    },
  });

  const savePlanMutation = useMutation({
    mutationFn: async (planId: string) => {
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
      await queryClient.invalidateQueries({ queryKey: adminQueryKeys.economySubscriptionPlans });
    },
    onError: (error) => {
      setFeedback({
        tone: "danger",
        message: error instanceof Error ? error.message : text.planSaveError,
      });
    },
  });

  const saveProviderConfigMutation = useMutation({
    mutationFn: async (configurationId: string) => {
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
      await queryClient.invalidateQueries({
        queryKey: adminQueryKeys.economyPaymentProviderConfigs,
      });
    },
    onError: (error) => {
      setFeedback({
        tone: "danger",
        message: error instanceof Error ? error.message : text.providerConfigSaveError,
      });
    },
  });

  const createProviderConfigMutation = useMutation({
    mutationFn: async () =>
      createAdminPaymentProviderConfig(toProviderConfigCreatePayload(createProviderDraft, text)),
    onSuccess: async () => {
      setFeedback({ tone: "success", message: text.providerConfigCreated });
      setCreateProviderDraft(createDefaultProviderConfigDraft());
      await queryClient.invalidateQueries({
        queryKey: adminQueryKeys.economyPaymentProviderConfigs,
      });
    },
    onError: (error) => {
      setFeedback({
        tone: "danger",
        message: error instanceof Error ? error.message : text.providerConfigCreateError,
      });
    },
  });

  const cloneProviderConfigMutation = useMutation({
    mutationFn: async (payload: { configurationId: string; region: string }) => {
      return cloneAdminPaymentProviderConfig(payload.configurationId, { region: payload.region });
    },
    onSuccess: async (_, variables) => {
      setFeedback({ tone: "success", message: text.providerConfigCloned });
      setCloneRegionDrafts((current) => ({ ...current, [variables.configurationId]: "" }));
      await queryClient.invalidateQueries({
        queryKey: adminQueryKeys.economyPaymentProviderConfigs,
      });
    },
    onError: (error) => {
      setFeedback({
        tone: "danger",
        message: error instanceof Error ? error.message : text.providerConfigCloneError,
      });
    },
  });

  const deleteProviderConfigMutation = useMutation({
    mutationFn: async (configurationId: string) => {
      await deleteAdminPaymentProviderConfig(configurationId);
    },
    onSuccess: async () => {
      setFeedback({ tone: "success", message: text.providerConfigDeleted });
      await queryClient.invalidateQueries({
        queryKey: adminQueryKeys.economyPaymentProviderConfigs,
      });
    },
    onError: (error) => {
      setFeedback({
        tone: "danger",
        message: error instanceof Error ? error.message : text.providerConfigDeleteError,
      });
    },
  });

  const testProviderConfigMutation = useMutation({
    mutationFn: async () => {
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
        message: error instanceof Error ? error.message : text.providerConfigTestError,
      });
    },
  });

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

  if (hasError) {
    return (
      <AdminPage className={styles.page}>
        <AdminPageHero eyebrow={text.eyebrow} title={text.title} description={text.description} />
        <AdminStateCard tone="danger" title={text.errorTitle} description={text.errorDescription} />
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
          value={formatCurrency(
            metrics.grossRevenue,
            locale,
            purchaseItems[0]?.currencyCode ?? "USD"
          )}
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

      <AdminCard title={text.packsTitle} description={text.packsDescription}>
        <AdminMetricStrip
          items={packs.slice(0, 4).map((pack) => ({
            label: `${pack.code.toUpperCase()} • ${pack.currencyCode}`,
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
                  return (
                    <tr key={pack.packId}>
                      <td>
                        <div className={styles.packMeta}>
                          <strong>{pack.code.toUpperCase()}</strong>
                          <span>{pack.currencyCode}</span>
                        </div>
                        <input
                          value={draft.displayName}
                          onChange={(event) =>
                            updateDraft(setDrafts, pack.packId, { displayName: event.target.value })
                          }
                          className={styles.input}
                        />
                      </td>
                      <td>
                        <input
                          value={draft.priceAmount}
                          onChange={(event) =>
                            updateDraft(setDrafts, pack.packId, { priceAmount: event.target.value })
                          }
                          inputMode="decimal"
                          className={styles.input}
                        />
                      </td>
                      <td>
                        <input
                          value={draft.grantedSpark}
                          onChange={(event) =>
                            updateDraft(setDrafts, pack.packId, {
                              grantedSpark: event.target.value,
                            })
                          }
                          inputMode="numeric"
                          className={styles.input}
                        />
                      </td>
                      <td>
                        <input
                          value={draft.bonusSpark}
                          onChange={(event) =>
                            updateDraft(setDrafts, pack.packId, { bonusSpark: event.target.value })
                          }
                          inputMode="numeric"
                          className={styles.input}
                        />
                      </td>
                      <td>
                        <input
                          value={draft.sortOrder}
                          onChange={(event) =>
                            updateDraft(setDrafts, pack.packId, { sortOrder: event.target.value })
                          }
                          inputMode="numeric"
                          className={styles.input}
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
                          />
                          <span>{draft.isActive ? text.activeState : text.inactiveState}</span>
                        </label>
                      </td>
                      <td>
                        <Button
                          onClick={() => savePackMutation.mutate(pack.packId)}
                          disabled={isSavingRow}
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
                      <td>{item.reason}</td>
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
            <AdminSelectField
              label={text.purchaseFilterLabel}
              value={purchaseStatus}
              onChange={setPurchaseStatus}
              options={purchaseStatusOptions[locale]}
              className={styles.compactSelect}
            />
          }
        >
          <TableOrEmpty hasItems={purchaseItems.length > 0} emptyTitle={text.noPurchases}>
            <div className={adminTableStyles.tableWrap}>
              <table className={adminTableStyles.table}>
                <thead>
                  <tr>
                    <th>{text.timeColumn}</th>
                    <th>{text.userColumn}</th>
                    <th>{text.packColumn}</th>
                    <th>{text.amountColumn}</th>
                    <th>{text.statusColumn}</th>
                  </tr>
                </thead>
                <tbody>
                  {purchaseItems.map((item) => (
                    <tr key={item.orderId}>
                      <td>{formatDateTime(item.confirmedAtUtc ?? item.createdAtUtc, locale)}</td>
                      <td className={adminTableStyles.mono}>{shortGuid(item.userId)}</td>
                      <td>
                        <div className={styles.packMeta}>
                          <strong>{item.packDisplayName}</strong>
                          <span>
                            {item.sparkToGrant} {text.tokensShort}
                          </span>
                        </div>
                      </td>
                      <td>{formatCurrency(item.priceAmount, locale, item.currencyCode)}</td>
                      <td>
                        <AdminStatusBadge color={statusColor(item.status)}>
                          {humanizeStatus(item.status, locale)}
                        </AdminStatusBadge>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </TableOrEmpty>
        </AdminCard>
      </AdminPageGrid>

      <AdminPageGrid columns="two">
        <EconomyPageSubscriptionPlansSection
          locale={locale}
          text={text}
          subscriptionPlans={subscriptionPlans}
          planDrafts={planDrafts}
          setPlanDrafts={setPlanDrafts}
          savePlanPending={savePlanMutation.isPending}
          savePlanId={savePlanMutation.variables}
          onSavePlan={(planId) => savePlanMutation.mutate(planId)}
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
          onSaveProviderConfig={(configurationId) =>
            saveProviderConfigMutation.mutate(configurationId)
          }
          onCreateProviderConfig={() => createProviderConfigMutation.mutate()}
          onTestProviderConfig={() => testProviderConfigMutation.mutate()}
          onCloneProviderConfig={(payload) => cloneProviderConfigMutation.mutate(payload)}
          onDeleteProviderConfig={(configurationId) =>
            deleteProviderConfigMutation.mutate(configurationId)
          }
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
          subscriptionItems={subscriptionItems}
          subscriptionEvents={subscriptionEvents}
          setSubscriptionProvider={setSubscriptionProvider}
          setSubscriptionStatus={setSubscriptionStatus}
          setEventProvider={setEventProvider}
          setEventStatus={setEventStatus}
          shortGuid={shortGuid}
          humanizeProvider={humanizeProvider}
          humanizeStatus={humanizeStatus}
          statusColor={statusColor}
        />
      </AdminPageGrid>
    </AdminPage>
  );
}

function shortGuid(value: string) {
  return value.slice(0, 8);
}

function formatTokens(value: number, locale: Locale) {
  return `${new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US").format(value)} spark`;
}

function formatCurrency(value: number, locale: Locale, currencyCode: string) {
  return new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US", {
    style: "currency",
    currency: currencyCode,
    maximumFractionDigits: 2,
  }).format(value);
}

function humanizeSource(value: string, locale: Locale) {
  const labels: Record<string, { ru: string; en: string }> = {
    weekly_grant: { ru: "Недельная награда", en: "Weekly reward" },
    ad_reward: { ru: "Награда за рекламу", en: "Ad reward" },
    redeem_code: { ru: "Промокод", en: "Redeem code" },
    premium_subscription_grant: { ru: "Выдача Premium токенов", en: "Premium token grant" },
    generation_spend: { ru: "Списание за генерацию", en: "Generation spend" },
    generation_refund: { ru: "Возврат за генерацию", en: "Generation refund" },
    pack_purchase: { ru: "Покупка пакета", en: "Pack purchase" },
    admin_grant: { ru: "Ручное начисление", en: "Manual grant" },
    admin_debit: { ru: "Ручное списание", en: "Manual debit" },
  };

  return labels[value]?.[locale] ?? value;
}

function humanizeProvider(value: string, locale: Locale) {
  const labels: Record<string, { ru: string; en: string }> = {
    app_store: { ru: "Apple App Store", en: "Apple App Store" },
    google_play: { ru: "Google Play", en: "Google Play" },
    stripe: { ru: "Stripe", en: "Stripe" },
  };

  return labels[value]?.[locale] ?? value;
}

function humanizeBillingPeriod(value: string, locale: Locale) {
  const labels: Record<string, { ru: string; en: string }> = {
    monthly: { ru: "Месяц", en: "Monthly" },
    yearly: { ru: "Год", en: "Yearly" },
  };

  return labels[value]?.[locale] ?? value;
}

function humanizeStatus(value: string, locale: Locale) {
  const labels: Record<string, { ru: string; en: string }> = {
    pending: { ru: "Ожидает", en: "Pending" },
    succeeded: { ru: "Успешно", en: "Succeeded" },
    failed: { ru: "Ошибка", en: "Failed" },
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
      return "#22c55e";
    case "trialing":
      return "#38bdf8";
    case "past_due":
    case "failed":
      return "#f87171";
    case "canceled":
    case "expired":
      return "#64748b";
    default:
      return "#f59e0b";
  }
}
