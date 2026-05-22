"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { type ReactNode, useState } from "react";

import { AdminCard, AdminKpiCard, AdminMetricStrip, AdminPage, AdminPageGrid, AdminPageHero, AdminSelectField, AdminStateCard, AdminStatusBadge, adminTableStyles } from "@/components/admin/admin-primitives";
import styles from "@/components/economy-page.module.css";
import { Button } from "@/components/ui/button";
import { useEconomyPageController } from "@/components/use-economy-page-controller";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
    updateAdminPaymentProviderConfig,
    updateAdminCurrencyPack,
    updateAdminSubscriptionPlan,
    type AdminCurrencyPack,
    type AdminPaymentProviderConfiguration,
    type AdminSubscriptionPlan,
} from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import { type Locale } from "@/lib/i18n";

type EconomyPageProps = {
    locale: Locale;
};

type PackDraft = {
    displayName: string;
    priceAmount: string;
    grantedSpark: string;
    bonusSpark: string;
    sortOrder: string;
    isActive: boolean;
};

type SubscriptionPlanDraft = {
    name: string;
    priceAmount: string;
    currencyCode: string;
    monthlyTokenLimit: string;
    isRecommended: boolean;
    isActive: boolean;
    appleProductId: string;
    googleProductId: string;
    stripePriceId: string;
    displayOrder: string;
};

type ProviderConfigDraft = {
    region: string;
    isEnabled: boolean;
    isRecommended: boolean;
    isSelectedByDefault: boolean;
    requiresExternalWarning: boolean;
    requiresStoreDisclosure: boolean;
    allowedFromAppVersion: string;
    externalCheckoutAllowed: boolean;
    bonusTokensPercent: string;
    displayLabel: string;
    displaySubtitle: string;
    warningTitle: string;
    warningMessage: string;
    mode: string;
    notes: string;
};

type TableOrEmptyProps = {
    hasItems: boolean;
    emptyTitle: string;
    children: ReactNode;
};

const ledgerSourceOptions = {
    ru: [
        { value: "", label: "Все источники" },
        { value: "pack_purchase", label: "Покупка пакета" },
        { value: "generation_spend", label: "Списание за генерацию" },
        { value: "weekly_grant", label: "Недельная награда" },
        { value: "ad_reward", label: "Награда за рекламу" },
        { value: "redeem_code", label: "Промокод" },
        { value: "premium_subscription_grant", label: "Выдача Premium токенов" },
        { value: "admin_grant", label: "Ручное начисление" },
        { value: "admin_debit", label: "Ручное списание" },
    ],
    en: [
        { value: "", label: "All sources" },
        { value: "pack_purchase", label: "Pack purchase" },
        { value: "generation_spend", label: "Generation spend" },
        { value: "weekly_grant", label: "Weekly reward" },
        { value: "ad_reward", label: "Ad reward" },
        { value: "redeem_code", label: "Redeem code" },
        { value: "premium_subscription_grant", label: "Premium token grant" },
        { value: "admin_grant", label: "Manual grant" },
        { value: "admin_debit", label: "Manual debit" },
    ],
} as const;

const purchaseStatusOptions = {
    ru: [
        { value: "", label: "Все статусы" },
        { value: "pending", label: "Ожидает" },
        { value: "succeeded", label: "Успешно" },
        { value: "failed", label: "Ошибка" },
    ],
    en: [
        { value: "", label: "All statuses" },
        { value: "pending", label: "Pending" },
        { value: "succeeded", label: "Succeeded" },
        { value: "failed", label: "Failed" },
    ],
} as const;

const subscriptionProviderOptions = {
    ru: [
        { value: "", label: "Все провайдеры" },
        { value: "app_store", label: "Apple App Store" },
        { value: "google_play", label: "Google Play" },
        { value: "stripe", label: "Stripe" },
    ],
    en: [
        { value: "", label: "All providers" },
        { value: "app_store", label: "Apple App Store" },
        { value: "google_play", label: "Google Play" },
        { value: "stripe", label: "Stripe" },
    ],
} as const;

const subscriptionStatusOptions = {
    ru: [
        { value: "", label: "Все статусы" },
        { value: "active", label: "Активна" },
        { value: "trialing", label: "Пробный период" },
        { value: "past_due", label: "Просрочка" },
        { value: "canceled", label: "Отменена" },
        { value: "expired", label: "Истекла" },
    ],
    en: [
        { value: "", label: "All statuses" },
        { value: "active", label: "Active" },
        { value: "trialing", label: "Trialing" },
        { value: "past_due", label: "Past due" },
        { value: "canceled", label: "Canceled" },
        { value: "expired", label: "Expired" },
    ],
} as const;

const eventStatusOptions = {
    ru: [
        { value: "", label: "Все статусы" },
        { value: "active", label: "Активна" },
        { value: "canceled", label: "Отменена" },
        { value: "expired", label: "Истекла" },
        { value: "processed", label: "Обработано" },
        { value: "failed", label: "Ошибка" },
    ],
    en: [
        { value: "", label: "All statuses" },
        { value: "active", label: "Active" },
        { value: "canceled", label: "Canceled" },
        { value: "expired", label: "Expired" },
        { value: "processed", label: "Processed" },
        { value: "failed", label: "Failed" },
    ],
} as const;

function TableOrEmpty({ hasItems, emptyTitle, children }: TableOrEmptyProps) {
    if (!hasItems) {
        return <AdminStateCard tone="info" title={emptyTitle} />;
    }

    return <>{children}</>;
}

export function EconomyPage({ locale }: EconomyPageProps) {
    const text = getText(locale);
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
    const [providerConfigDrafts, setProviderConfigDrafts] = useState<Record<string, ProviderConfigDraft>>({});
    const [feedback, setFeedback] = useState<{ tone: "success" | "danger"; message: string } | null>(null);

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
            setFeedback({ tone: "danger", message: error instanceof Error ? error.message : text.planSaveError });
        },
    });

    const saveProviderConfigMutation = useMutation({
        mutationFn: async (configurationId: string) => {
            const config = providerConfigs.find((item) => item.configurationId === configurationId);
            const draft = providerConfigDrafts[configurationId] ?? (config ? toProviderConfigDraft(config) : null);
            if (!draft) {
                throw new Error(text.providerConfigMissingDraft);
            }

            return updateAdminPaymentProviderConfig(configurationId, toProviderConfigPayload(draft, text));
        },
        onSuccess: async (config) => {
            setFeedback({ tone: "success", message: text.providerConfigSaved });
            setProviderConfigDrafts((current) => ({ ...current, [config.configurationId]: toProviderConfigDraft(config) }));
            await queryClient.invalidateQueries({ queryKey: adminQueryKeys.economyPaymentProviderConfigs });
        },
        onError: (error) => {
            setFeedback({ tone: "danger", message: error instanceof Error ? error.message : text.providerConfigSaveError });
        },
    });

    if (isLoading) {
        return (
            <AdminPage className={styles.page}>
                <AdminPageHero eyebrow={text.eyebrow} title={text.title} description={text.description} />
                <AdminStateCard tone="info" title={text.loadingTitle} description={text.loadingDescription} />
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
            <AdminPageHero
                eyebrow={text.eyebrow}
                title={text.title}
                description={text.description}
                metaItems={[
                    `${text.metaPacks}: ${packs.length}`,
                    `${text.metaLedger}: ${ledgerItems.length}`,
                    `${text.metaPurchases}: ${purchaseItems.length}`,
                    `${text.metaSubscriptions}: ${subscriptionItems.length}`,
                    `${text.metaRoutes}: ${providerConfigs.length}`,
                ]}
            />

            <AdminPageGrid columns="four">
                <AdminKpiCard label={text.activePacksLabel} value={String(metrics.activePacks)} tone="primary" />
                <AdminKpiCard label={text.creditFlowLabel} value={formatTokens(metrics.credited, locale)} tone="success" />
                <AdminKpiCard label={text.debitFlowLabel} value={formatTokens(metrics.debited, locale)} tone="warning" />
                <AdminKpiCard label={text.revenueLabel} value={formatCurrency(metrics.grossRevenue, locale, purchaseItems[0]?.currencyCode ?? "USD")} tone="info" />
            </AdminPageGrid>

            <AdminPageGrid columns="four">
                <AdminKpiCard label={text.activeSubscriptionsLabel} value={String(premiumMetrics.activeSubscriptions)} tone="primary" />
                <AdminKpiCard label={text.renewalStopsLabel} value={String(premiumMetrics.renewalStops)} tone="warning" />
                <AdminKpiCard label={text.activePlansCountLabel} value={String(premiumMetrics.activePlans)} tone="success" />
                <AdminKpiCard label={text.enabledRoutesLabel} value={String(premiumMetrics.enabledRoutes)} tone="info" />
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
                                    const isSavingRow = savePackMutation.isPending && savePackMutation.variables === pack.packId;
                                    return (
                                        <tr key={pack.packId}>
                                            <td>
                                                <div className={styles.packMeta}>
                                                    <strong>{pack.code.toUpperCase()}</strong>
                                                    <span>{pack.currencyCode}</span>
                                                </div>
                                                <input
                                                    value={draft.displayName}
                                                    onChange={(event) => updateDraft(setDrafts, pack.packId, { displayName: event.target.value })}
                                                    className={styles.input}
                                                />
                                            </td>
                                            <td>
                                                <input
                                                    value={draft.priceAmount}
                                                    onChange={(event) => updateDraft(setDrafts, pack.packId, { priceAmount: event.target.value })}
                                                    inputMode="decimal"
                                                    className={styles.input}
                                                />
                                            </td>
                                            <td>
                                                <input
                                                    value={draft.grantedSpark}
                                                    onChange={(event) => updateDraft(setDrafts, pack.packId, { grantedSpark: event.target.value })}
                                                    inputMode="numeric"
                                                    className={styles.input}
                                                />
                                            </td>
                                            <td>
                                                <input
                                                    value={draft.bonusSpark}
                                                    onChange={(event) => updateDraft(setDrafts, pack.packId, { bonusSpark: event.target.value })}
                                                    inputMode="numeric"
                                                    className={styles.input}
                                                />
                                            </td>
                                            <td>
                                                <input
                                                    value={draft.sortOrder}
                                                    onChange={(event) => updateDraft(setDrafts, pack.packId, { sortOrder: event.target.value })}
                                                    inputMode="numeric"
                                                    className={styles.input}
                                                />
                                            </td>
                                            <td>
                                                <label className={styles.checkboxField}>
                                                    <input
                                                        type="checkbox"
                                                        checked={draft.isActive}
                                                        onChange={(event) => updateDraft(setDrafts, pack.packId, { isActive: event.target.checked })}
                                                    />
                                                    <span>{draft.isActive ? text.activeState : text.inactiveState}</span>
                                                </label>
                                            </td>
                                            <td>
                                                <Button onClick={() => savePackMutation.mutate(pack.packId)} disabled={isSavingRow}>
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
                                                    {item.delta >= 0 ? "+" : ""}{item.delta}
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
                                                    <span>{item.sparkToGrant} {text.tokensShort}</span>
                                                </div>
                                            </td>
                                            <td>{formatCurrency(item.priceAmount, locale, item.currencyCode)}</td>
                                            <td>
                                                <AdminStatusBadge color={statusColor(item.status)}>{humanizeStatus(item.status, locale)}</AdminStatusBadge>
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
                <AdminCard title={text.subscriptionPlansTitle} description={text.subscriptionPlansDescription}>
                    <AdminMetricStrip
                        items={subscriptionPlans.slice(0, 4).map((plan) => ({
                            label: `${plan.name} • ${humanizeBillingPeriod(plan.billingPeriod, locale)}`,
                            value: `${plan.monthlyTokenLimit} ${text.tokensShort}`,
                        }))}
                        className={styles.metricStrip}
                    />

                    <TableOrEmpty hasItems={subscriptionPlans.length > 0} emptyTitle={text.noSubscriptionPlans}>
                        <div className={adminTableStyles.tableWrap}>
                            <table className={adminTableStyles.table}>
                                <thead>
                                    <tr>
                                        <th>{text.planColumn}</th>
                                        <th>{text.priceColumn}</th>
                                        <th>{text.billingColumn}</th>
                                        <th>{text.tokensColumn}</th>
                                        <th>{text.productIdsColumn}</th>
                                        <th>{text.statusColumn}</th>
                                        <th>{text.actionsColumn}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {subscriptionPlans.map((plan) => {
                                        const draft = planDrafts[plan.planId] ?? toSubscriptionPlanDraft(plan);
                                        const isSavingPlan = savePlanMutation.isPending && savePlanMutation.variables === plan.planId;

                                        return (
                                            <tr key={plan.planId}>
                                                <td>
                                                    <div className={styles.packMeta}>
                                                        <strong>{plan.planId}</strong>
                                                        <span>{humanizeBillingPeriod(plan.billingPeriod, locale)}</span>
                                                    </div>
                                                    <input
                                                        value={draft.name}
                                                        onChange={(event) => updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, { name: event.target.value })}
                                                        className={styles.input}
                                                    />
                                                </td>
                                                <td>
                                                    <div className={styles.windowFields}>
                                                        <input
                                                            value={draft.priceAmount}
                                                            onChange={(event) => updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, { priceAmount: event.target.value })}
                                                            inputMode="decimal"
                                                            className={styles.input}
                                                        />
                                                        <input
                                                            value={draft.currencyCode}
                                                            onChange={(event) => updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, { currencyCode: event.target.value.toUpperCase() })}
                                                            className={styles.input}
                                                            maxLength={3}
                                                        />
                                                    </div>
                                                </td>
                                                <td>
                                                    <div className={styles.windowFields}>
                                                        <span>{humanizeBillingPeriod(plan.billingPeriod, locale)}</span>
                                                        <label className={styles.field}>
                                                            <span>{text.sortColumn}</span>
                                                            <input
                                                                value={draft.displayOrder}
                                                                onChange={(event) => updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, { displayOrder: event.target.value })}
                                                                inputMode="numeric"
                                                                className={styles.input}
                                                            />
                                                        </label>
                                                    </div>
                                                </td>
                                                <td>
                                                    <input
                                                        value={draft.monthlyTokenLimit}
                                                        onChange={(event) => updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, { monthlyTokenLimit: event.target.value })}
                                                        inputMode="numeric"
                                                        className={styles.input}
                                                    />
                                                </td>
                                                <td>
                                                    <div className={styles.windowFields}>
                                                        <label className={styles.field}>
                                                            <span>{text.appleProductLabel}</span>
                                                            <input
                                                                value={draft.appleProductId}
                                                                onChange={(event) => updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, { appleProductId: event.target.value })}
                                                                className={styles.input}
                                                            />
                                                        </label>
                                                        <label className={styles.field}>
                                                            <span>{text.googleProductLabel}</span>
                                                            <input
                                                                value={draft.googleProductId}
                                                                onChange={(event) => updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, { googleProductId: event.target.value })}
                                                                className={styles.input}
                                                            />
                                                        </label>
                                                        <label className={styles.field}>
                                                            <span>{text.stripePriceLabel}</span>
                                                            <input
                                                                value={draft.stripePriceId}
                                                                onChange={(event) => updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, { stripePriceId: event.target.value })}
                                                                className={styles.input}
                                                            />
                                                        </label>
                                                    </div>
                                                </td>
                                                <td>
                                                    <div className={styles.statusStack}>
                                                        <label className={styles.checkboxField}>
                                                            <input
                                                                type="checkbox"
                                                                checked={draft.isActive}
                                                                onChange={(event) => updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, { isActive: event.target.checked })}
                                                            />
                                                            <span>{draft.isActive ? text.activeState : text.inactiveState}</span>
                                                        </label>
                                                        <label className={styles.checkboxField}>
                                                            <input
                                                                type="checkbox"
                                                                checked={draft.isRecommended}
                                                                onChange={(event) => updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, { isRecommended: event.target.checked })}
                                                            />
                                                            <span>{text.recommendedState}</span>
                                                        </label>
                                                    </div>
                                                </td>
                                                <td>
                                                    <Button onClick={() => savePlanMutation.mutate(plan.planId)} disabled={isSavingPlan}>
                                                        {isSavingPlan ? text.savingAction : text.saveAction}
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

                <AdminCard title={text.providerConfigsTitle} description={text.providerConfigsDescription}>
                    <TableOrEmpty hasItems={providerConfigs.length > 0} emptyTitle={text.noProviderConfigs}>
                        <div className={adminTableStyles.tableWrap}>
                            <table className={adminTableStyles.table}>
                                <thead>
                                    <tr>
                                        <th>{text.providerColumn}</th>
                                        <th>{text.platformColumn}</th>
                                        <th>{text.regionColumn}</th>
                                        <th>{text.statusColumn}</th>
                                        <th>{text.flagsColumn}</th>
                                        <th>{text.modeColumn}</th>
                                        <th>{text.actionsColumn}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {providerConfigs.map((config) => {
                                        const draft = providerConfigDrafts[config.configurationId] ?? toProviderConfigDraft(config);
                                        const isSavingConfig = saveProviderConfigMutation.isPending && saveProviderConfigMutation.variables === config.configurationId;

                                        return (
                                            <tr key={config.configurationId}>
                                                <td>{humanizeProvider(config.provider, locale)}</td>
                                                <td>{config.platform}</td>
                                                <td>
                                                    <input
                                                        value={draft.region}
                                                        onChange={(event) => updateProviderConfigDraft(setProviderConfigDrafts, config.configurationId, { region: event.target.value.toUpperCase() })}
                                                        className={styles.input}
                                                    />
                                                </td>
                                                <td>
                                                    <label className={styles.checkboxField}>
                                                        <input
                                                            type="checkbox"
                                                            checked={draft.isEnabled}
                                                            onChange={(event) => updateProviderConfigDraft(setProviderConfigDrafts, config.configurationId, { isEnabled: event.target.checked })}
                                                        />
                                                        <span>{draft.isEnabled ? text.activeState : text.inactiveState}</span>
                                                    </label>
                                                </td>
                                                <td>
                                                    <div className={styles.windowFields}>
                                                        <label className={styles.checkboxField}>
                                                            <input
                                                                type="checkbox"
                                                                checked={draft.externalCheckoutAllowed}
                                                                onChange={(event) => updateProviderConfigDraft(setProviderConfigDrafts, config.configurationId, { externalCheckoutAllowed: event.target.checked })}
                                                            />
                                                            <span>{text.externalCheckoutFlag}</span>
                                                        </label>
                                                        <label className={styles.checkboxField}>
                                                            <input
                                                                type="checkbox"
                                                                checked={draft.isRecommended}
                                                                onChange={(event) => updateProviderConfigDraft(setProviderConfigDrafts, config.configurationId, { isRecommended: event.target.checked })}
                                                            />
                                                            <span>{text.recommendedFlag}</span>
                                                        </label>
                                                        <label className={styles.checkboxField}>
                                                            <input
                                                                type="checkbox"
                                                                checked={draft.isSelectedByDefault}
                                                                onChange={(event) => updateProviderConfigDraft(setProviderConfigDrafts, config.configurationId, { isSelectedByDefault: event.target.checked })}
                                                            />
                                                            <span>{text.defaultFlag}</span>
                                                        </label>
                                                        <label className={styles.checkboxField}>
                                                            <input
                                                                type="checkbox"
                                                                checked={draft.requiresExternalWarning}
                                                                onChange={(event) => updateProviderConfigDraft(setProviderConfigDrafts, config.configurationId, { requiresExternalWarning: event.target.checked })}
                                                            />
                                                            <span>{text.externalWarningFlag}</span>
                                                        </label>
                                                        <label className={styles.checkboxField}>
                                                            <input
                                                                type="checkbox"
                                                                checked={draft.requiresStoreDisclosure}
                                                                onChange={(event) => updateProviderConfigDraft(setProviderConfigDrafts, config.configurationId, { requiresStoreDisclosure: event.target.checked })}
                                                            />
                                                            <span>{text.storeDisclosureFlag}</span>
                                                        </label>
                                                        <label className={styles.field}>
                                                            <span>{text.minVersionLabel}</span>
                                                            <input
                                                                value={draft.allowedFromAppVersion}
                                                                onChange={(event) => updateProviderConfigDraft(setProviderConfigDrafts, config.configurationId, { allowedFromAppVersion: event.target.value })}
                                                                className={styles.input}
                                                            />
                                                        </label>
                                                        <label className={styles.field}>
                                                            <span>{text.bonusPercentLabel}</span>
                                                            <input
                                                                type="number"
                                                                min="0"
                                                                max="100"
                                                                value={draft.bonusTokensPercent}
                                                                onChange={(event) => updateProviderConfigDraft(setProviderConfigDrafts, config.configurationId, { bonusTokensPercent: event.target.value })}
                                                                className={styles.input}
                                                            />
                                                        </label>
                                                    </div>
                                                </td>
                                                <td>
                                                    <div className={styles.windowFields}>
                                                        <label className={styles.field}>
                                                            <span>{text.modeColumn}</span>
                                                            <input
                                                                value={draft.mode}
                                                                onChange={(event) => updateProviderConfigDraft(setProviderConfigDrafts, config.configurationId, { mode: event.target.value })}
                                                                className={styles.input}
                                                            />
                                                        </label>
                                                        <label className={styles.field}>
                                                            <span>{text.displayLabelLabel}</span>
                                                            <input
                                                                value={draft.displayLabel}
                                                                onChange={(event) => updateProviderConfigDraft(setProviderConfigDrafts, config.configurationId, { displayLabel: event.target.value })}
                                                                className={styles.input}
                                                                placeholder={humanizeProvider(config.provider, locale)}
                                                            />
                                                        </label>
                                                        <label className={styles.field}>
                                                            <span>{text.displaySubtitleLabel}</span>
                                                            <input
                                                                value={draft.displaySubtitle}
                                                                onChange={(event) => updateProviderConfigDraft(setProviderConfigDrafts, config.configurationId, { displaySubtitle: event.target.value })}
                                                                className={styles.input}
                                                                placeholder={text.noDescription}
                                                            />
                                                        </label>
                                                        <label className={styles.field}>
                                                            <span>{text.warningTitleLabel}</span>
                                                            <input
                                                                value={draft.warningTitle}
                                                                onChange={(event) => updateProviderConfigDraft(setProviderConfigDrafts, config.configurationId, { warningTitle: event.target.value })}
                                                                className={styles.input}
                                                                placeholder={text.noDescription}
                                                            />
                                                        </label>
                                                        <label className={styles.field}>
                                                            <span>{text.warningMessageLabel}</span>
                                                            <input
                                                                value={draft.warningMessage}
                                                                onChange={(event) => updateProviderConfigDraft(setProviderConfigDrafts, config.configurationId, { warningMessage: event.target.value })}
                                                                className={styles.input}
                                                                placeholder={text.noDescription}
                                                            />
                                                        </label>
                                                        <label className={styles.field}>
                                                            <span>{text.notesLabel}</span>
                                                            <input
                                                                value={draft.notes}
                                                                onChange={(event) => updateProviderConfigDraft(setProviderConfigDrafts, config.configurationId, { notes: event.target.value })}
                                                                className={styles.input}
                                                                placeholder={text.noDescription}
                                                            />
                                                        </label>
                                                    </div>
                                                </td>
                                                <td>
                                                    <Button onClick={() => saveProviderConfigMutation.mutate(config.configurationId)} disabled={isSavingConfig}>
                                                        {isSavingConfig ? text.savingAction : text.saveAction}
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
            </AdminPageGrid>

            <AdminPageGrid columns="two">
                <AdminCard
                    title={text.subscriptionsTitle}
                    description={text.subscriptionsDescription}
                    action={
                        <div className={styles.filterRow}>
                            <AdminSelectField
                                label={text.providerColumn}
                                value={subscriptionProvider}
                                onChange={setSubscriptionProvider}
                                options={subscriptionProviderOptions[locale]}
                                className={styles.compactSelect}
                            />
                            <AdminSelectField
                                label={text.statusColumn}
                                value={subscriptionStatus}
                                onChange={setSubscriptionStatus}
                                options={subscriptionStatusOptions[locale]}
                                className={styles.compactSelect}
                            />
                        </div>
                    }
                >
                    <TableOrEmpty hasItems={subscriptionItems.length > 0} emptyTitle={text.noSubscriptions}>
                        <div className={adminTableStyles.tableWrap}>
                            <table className={adminTableStyles.table}>
                                <thead>
                                    <tr>
                                        <th>{text.userColumn}</th>
                                        <th>{text.planColumn}</th>
                                        <th>{text.providerColumn}</th>
                                        <th>{text.statusColumn}</th>
                                        <th>{text.renewalColumn}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {subscriptionItems.map((item) => (
                                        <tr key={item.subscriptionId}>
                                            <td className={adminTableStyles.mono}>{shortGuid(item.userId)}</td>
                                            <td>
                                                <div className={styles.packMeta}>
                                                    <strong>{item.planName || item.planId}</strong>
                                                    <span>{`${item.monthlyTokensGranted}/${item.monthlyTokenLimit} ${text.tokensShort}`}</span>
                                                </div>
                                            </td>
                                            <td>
                                                <div className={styles.packMeta}>
                                                    <strong>{humanizeProvider(item.provider, locale)}</strong>
                                                    <span>{`${item.purchaseChannel} • ${item.region}`}</span>
                                                </div>
                                            </td>
                                            <td>
                                                <div className={styles.statusStack}>
                                                    <AdminStatusBadge color={statusColor(item.status)}>{humanizeStatus(item.status, locale)}</AdminStatusBadge>
                                                    {item.cancelAtPeriodEnd ? <AdminStatusBadge color="#f59e0b">{text.cancelAtPeriodEndLabel}</AdminStatusBadge> : null}
                                                </div>
                                            </td>
                                            <td>{formatDateTime(item.currentPeriodEndUtc ?? item.updatedAtUtc, locale)}</td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                    </TableOrEmpty>
                </AdminCard>

                <AdminCard
                    title={text.subscriptionEventsTitle}
                    description={text.subscriptionEventsDescription}
                    action={
                        <div className={styles.filterRow}>
                            <AdminSelectField
                                label={text.providerColumn}
                                value={eventProvider}
                                onChange={setEventProvider}
                                options={subscriptionProviderOptions[locale]}
                                className={styles.compactSelect}
                            />
                            <AdminSelectField
                                label={text.statusColumn}
                                value={eventStatus}
                                onChange={setEventStatus}
                                options={eventStatusOptions[locale]}
                                className={styles.compactSelect}
                            />
                        </div>
                    }
                >
                    <TableOrEmpty hasItems={subscriptionEvents.length > 0} emptyTitle={text.noSubscriptionEvents}>
                        <div className={adminTableStyles.tableWrap}>
                            <table className={adminTableStyles.table}>
                                <thead>
                                    <tr>
                                        <th>{text.timeColumn}</th>
                                        <th>{text.providerColumn}</th>
                                        <th>{text.eventTypeColumn}</th>
                                        <th>{text.statusColumn}</th>
                                        <th>{text.processedColumn}</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {subscriptionEvents.map((item) => (
                                        <tr key={item.eventId}>
                                            <td>{formatDateTime(item.createdAtUtc, locale)}</td>
                                            <td>{humanizeProvider(item.provider, locale)}</td>
                                            <td>
                                                <div className={styles.packMeta}>
                                                    <strong>{item.eventType}</strong>
                                                    <span>{item.externalSubscriptionId || item.externalEventId || text.noDescription}</span>
                                                </div>
                                            </td>
                                            <td>
                                                <AdminStatusBadge color={statusColor(item.status)}>{humanizeStatus(item.status, locale)}</AdminStatusBadge>
                                            </td>
                                            <td>{item.processedAtUtc ? formatDateTime(item.processedAtUtc, locale) : text.notProcessedLabel}</td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                    </TableOrEmpty>
                </AdminCard>
            </AdminPageGrid>
        </AdminPage>
    );
}

function getText(locale: Locale) {
    if (locale === "ru") {
        return {
            eyebrow: "Экономика и кошелек",
            title: "Экономика",
            description: "Общий обзор движения валюты, платежных статусов и пакетов пополнения без ухода в карточки пользователей.",
            loadingTitle: "Загружаем экономику",
            loadingDescription: "Подтягиваем историю операций, покупки и конфигурацию пакетов.",
            errorTitle: "Не удалось загрузить экономику",
            errorDescription: "Проверьте доступ к backend и повторите запрос.",
            metaPacks: "Пакетов",
            metaLedger: "Операций",
            metaPurchases: "Покупок",
            metaSubscriptions: "Подписок",
            metaRoutes: "Маршрутов",
            activePacksLabel: "Активные паки",
            creditFlowLabel: "Начисления",
            debitFlowLabel: "Списания",
            revenueLabel: "Выручка",
            activeSubscriptionsLabel: "Активные подписки",
            renewalStopsLabel: "Остановки продления",
            activePlansCountLabel: "Активные планы",
            enabledRoutesLabel: "Включенные маршруты",
            packsTitle: "Паки пополнения",
            packsDescription: "Редактирование цен, бонуса и видимости пакетов без затрагивания истории покупок.",
            subscriptionPlansTitle: "Premium планы",
            subscriptionPlansDescription: "Текущая конфигурация месячных и годовых планов, которую видят мобильный клиент и checkout flow.",
            providerConfigsTitle: "Маршрутизация платежей",
            providerConfigsDescription: "Backend-controlled правила выбора App Store, Google Play и Stripe по платформе и региону.",
            subscriptionsTitle: "Активные и недавние подписки",
            subscriptionsDescription: "Снимок последних premium подписок по пользователям с провайдером, токенами и датой продления.",
            subscriptionEventsTitle: "Лог событий подписок",
            subscriptionEventsDescription: "Последние lifecycle события из store/Stripe flows для диагностики интеграции.",
            tokensShort: "spark",
            packSaved: "Пакет обновлен.",
            packSaveError: "Не удалось сохранить пакет.",
            planSaved: "Premium план обновлен.",
            planSaveError: "Не удалось сохранить Premium план.",
            providerConfigSaved: "Маршрут оплаты обновлен.",
            providerConfigSaveError: "Не удалось сохранить маршрут оплаты.",
            planMissingDraft: "План не найден в текущем списке.",
            providerConfigMissingDraft: "Маршрут оплаты не найден в текущем списке.",
            invalidPlanNumbers: "Укажите корректные цену, валюту и лимит токенов для плана.",
            invalidProviderConfig: "Заполните регион, минимальную версию приложения, режим маршрута и бонус от 0 до 100%.",
            packColumn: "Пакет",
            planColumn: "План",
            priceColumn: "Цена",
            grantedColumn: "База",
            bonusColumn: "Бонус",
            sortColumn: "Порядок",
            activeColumn: "Активен",
            actionsColumn: "Действие",
            activeState: "Включен",
            inactiveState: "Скрыт",
            recommendedState: "Рекомендуем",
            savingAction: "Сохраняем...",
            saveAction: "Сохранить",
            noPacks: "Паки пополнения пока не настроены.",
            noSubscriptionPlans: "Premium планы пока не настроены.",
            noProviderConfigs: "Правила маршрутизации платежей пока не настроены.",
            noSubscriptions: "Подписки пока не найдены.",
            noSubscriptionEvents: "События подписок пока не записаны.",
            noDescription: "Без описания",
            ledgerTitle: "Ledger операций",
            ledgerDescription: "Последние движения баланса по всем пользователям с источником и причиной.",
            ledgerFilterLabel: "Источник",
            purchaseFilterLabel: "Статус",
            noLedger: "Операций пока нет.",
            purchasesTitle: "Покупки и статусы",
            purchasesDescription: "Последние заказы с итоговым статусом оплаты и начислением spark.",
            noPurchases: "Покупок пока нет.",
            timeColumn: "Время",
            userColumn: "Пользователь",
            deltaColumn: "Delta",
            balanceColumn: "Баланс",
            sourceColumn: "Источник",
            reasonColumn: "Причина",
            amountColumn: "Сумма",
            statusColumn: "Статус",
            billingColumn: "Период",
            tokensColumn: "Лимит токенов",
            providerColumn: "Провайдер",
            platformColumn: "Платформа",
            regionColumn: "Регион",
            productIdsColumn: "Store IDs",
            appleProductLabel: "Apple product ID",
            googleProductLabel: "Google product ID",
            stripePriceLabel: "Stripe price ID",
            flagsColumn: "Флаги",
            modeColumn: "Режим",
            notesLabel: "Заметки",
            renewalColumn: "Следующее списание",
            eventTypeColumn: "Событие",
            processedColumn: "Обработано",
            cancelAtPeriodEndLabel: "Без автопродления",
            externalCheckoutFlag: "External checkout",
            recommendedFlag: "Recommended",
            defaultFlag: "Default",
            externalWarningFlag: "External warning",
            storeDisclosureFlag: "Store disclosure",
            minVersionLabel: "Минимум",
            bonusPercentLabel: "Бонус, %",
            displayLabelLabel: "Название",
            displaySubtitleLabel: "Подзаголовок",
            warningTitleLabel: "Заголовок warning",
            warningMessageLabel: "Текст warning",
            notProcessedLabel: "Еще не обработано",
        };
    }

    return {
        eyebrow: "Economy and wallet",
        title: "Economy",
        description: "System-wide view of balance movement, payment statuses, and top-up packs without opening each user profile.",
        loadingTitle: "Loading economy",
        loadingDescription: "Fetching ledger, purchases, and pack configuration.",
        errorTitle: "Failed to load economy",
        errorDescription: "Check backend availability and try again.",
        metaPacks: "Packs",
        metaLedger: "Ledger rows",
        metaPurchases: "Purchases",
        metaSubscriptions: "Subscriptions",
        metaRoutes: "Routes",
        activePacksLabel: "Active packs",
        creditFlowLabel: "Credits",
        debitFlowLabel: "Debits",
        revenueLabel: "Revenue",
        activeSubscriptionsLabel: "Active subscriptions",
        renewalStopsLabel: "Renewal stops",
        activePlansCountLabel: "Active plans",
        enabledRoutesLabel: "Enabled routes",
        packsTitle: "Top-up packs",
        packsDescription: "Update pricing, bonus, and visibility without touching historical purchases.",
        subscriptionPlansTitle: "Premium plans",
        subscriptionPlansDescription: "Current monthly and yearly plan configuration used by mobile clients and checkout flows.",
        providerConfigsTitle: "Payment routing",
        providerConfigsDescription: "Backend-controlled rules that choose App Store, Google Play, and Stripe by platform and region.",
        subscriptionsTitle: "Active and recent subscriptions",
        subscriptionsDescription: "Snapshot of recent premium subscriptions with provider, token usage, and renewal date.",
        subscriptionEventsTitle: "Subscription event log",
        subscriptionEventsDescription: "Recent lifecycle events from store and Stripe flows for integration diagnostics.",
        tokensShort: "spark",
        packSaved: "Pack updated.",
        packSaveError: "Failed to save pack.",
        planSaved: "Premium plan updated.",
        planSaveError: "Failed to save premium plan.",
        providerConfigSaved: "Payment route updated.",
        providerConfigSaveError: "Failed to save payment route.",
        planMissingDraft: "Premium plan was not found in the current list.",
        providerConfigMissingDraft: "Payment route was not found in the current list.",
        invalidPlanNumbers: "Enter a valid price, currency, and token limit for the plan.",
        invalidProviderConfig: "Enter a valid region, minimum app version, routing mode, and 0-100% bonus.",
        packColumn: "Pack",
        planColumn: "Plan",
        priceColumn: "Price",
        grantedColumn: "Base",
        bonusColumn: "Bonus",
        sortColumn: "Sort",
        activeColumn: "Active",
        actionsColumn: "Action",
        activeState: "On",
        inactiveState: "Hidden",
        recommendedState: "Recommended",
        savingAction: "Saving...",
        saveAction: "Save",
        noPacks: "No top-up packs configured yet.",
        noSubscriptionPlans: "No premium plans configured yet.",
        noProviderConfigs: "No payment routing rules configured yet.",
        noSubscriptions: "No subscriptions found yet.",
        noSubscriptionEvents: "No subscription events recorded yet.",
        noDescription: "No description",
        ledgerTitle: "Wallet ledger",
        ledgerDescription: "Recent balance movements across users with source and reason.",
        ledgerFilterLabel: "Source",
        purchaseFilterLabel: "Status",
        noLedger: "No wallet operations yet.",
        purchasesTitle: "Purchases and statuses",
        purchasesDescription: "Recent orders with payment outcome and spark grant value.",
        noPurchases: "No purchases yet.",
        timeColumn: "Time",
        userColumn: "User",
        deltaColumn: "Delta",
        balanceColumn: "Balance",
        sourceColumn: "Source",
        reasonColumn: "Reason",
        amountColumn: "Amount",
        statusColumn: "Status",
        billingColumn: "Period",
        tokensColumn: "Token limit",
        providerColumn: "Provider",
        platformColumn: "Platform",
        regionColumn: "Region",
        productIdsColumn: "Store IDs",
        appleProductLabel: "Apple product ID",
        googleProductLabel: "Google product ID",
        stripePriceLabel: "Stripe price ID",
        flagsColumn: "Flags",
        modeColumn: "Mode",
        notesLabel: "Notes",
        renewalColumn: "Next renewal",
        eventTypeColumn: "Event",
        processedColumn: "Processed",
        cancelAtPeriodEndLabel: "No auto-renew",
        externalCheckoutFlag: "External checkout",
        recommendedFlag: "Recommended",
        defaultFlag: "Default",
        externalWarningFlag: "External warning",
        storeDisclosureFlag: "Store disclosure",
        minVersionLabel: "Min",
        bonusPercentLabel: "Bonus, %",
        displayLabelLabel: "Label",
        displaySubtitleLabel: "Subtitle",
        warningTitleLabel: "Warning title",
        warningMessageLabel: "Warning message",
        notProcessedLabel: "Not processed yet",
    };
}

function toDraft(pack: AdminCurrencyPack): PackDraft {
    return {
        displayName: pack.displayName,
        priceAmount: pack.priceAmount.toString(),
        grantedSpark: pack.grantedSpark.toString(),
        bonusSpark: pack.bonusSpark.toString(),
        sortOrder: pack.sortOrder.toString(),
        isActive: pack.isActive,
    };
}

function updateDraft(
    setDrafts: React.Dispatch<React.SetStateAction<Record<string, PackDraft>>>,
    packId: string,
    patch: Partial<PackDraft>,
) {
    setDrafts((current) => ({
        ...current,
        [packId]: {
            ...(current[packId] ?? {
                displayName: "",
                priceAmount: "0",
                grantedSpark: "0",
                bonusSpark: "0",
                sortOrder: "0",
                isActive: false,
            }),
            ...patch,
        },
    }));
}

function toSubscriptionPlanDraft(plan: AdminSubscriptionPlan): SubscriptionPlanDraft {
    return {
        name: plan.name,
        priceAmount: plan.priceAmount.toString(),
        currencyCode: plan.currencyCode,
        monthlyTokenLimit: plan.monthlyTokenLimit.toString(),
        isRecommended: plan.isRecommended,
        isActive: plan.isActive,
        appleProductId: plan.appleProductId ?? "",
        googleProductId: plan.googleProductId ?? "",
        stripePriceId: plan.stripePriceId ?? "",
        displayOrder: plan.displayOrder.toString(),
    };
}

function updateSubscriptionPlanDraft(
    setPlanDrafts: React.Dispatch<React.SetStateAction<Record<string, SubscriptionPlanDraft>>>,
    planId: string,
    patch: Partial<SubscriptionPlanDraft>,
) {
    setPlanDrafts((current) => ({
        ...current,
        [planId]: {
            ...(current[planId] ?? {
                name: "",
                priceAmount: "0",
                currencyCode: "USD",
                monthlyTokenLimit: "0",
                isRecommended: false,
                isActive: false,
                appleProductId: "",
                googleProductId: "",
                stripePriceId: "",
                displayOrder: "0",
            }),
            ...patch,
        },
    }));
}

function toSubscriptionPlanPayload(draft: SubscriptionPlanDraft, text: ReturnType<typeof getText>) {
    const priceAmount = Number(draft.priceAmount);
    const monthlyTokenLimit = Number(draft.monthlyTokenLimit);
    const displayOrder = Number(draft.displayOrder);
    const currencyCode = draft.currencyCode.trim().toUpperCase();

    if (!draft.name.trim() || !Number.isFinite(priceAmount) || priceAmount <= 0 || !Number.isFinite(monthlyTokenLimit) || monthlyTokenLimit <= 0 || !Number.isFinite(displayOrder) || displayOrder < 0 || currencyCode.length !== 3) {
        throw new Error(text.invalidPlanNumbers);
    }

    return {
        name: draft.name.trim(),
        priceAmount,
        currencyCode,
        monthlyTokenLimit,
        isRecommended: draft.isRecommended,
        isActive: draft.isActive,
        appleProductId: optionalText(draft.appleProductId),
        googleProductId: optionalText(draft.googleProductId),
        stripePriceId: optionalText(draft.stripePriceId),
        displayOrder,
    };
}

function toProviderConfigDraft(config: AdminPaymentProviderConfiguration): ProviderConfigDraft {
    return {
        region: config.region,
        isEnabled: config.isEnabled,
        isRecommended: config.isRecommended,
        isSelectedByDefault: config.isSelectedByDefault,
        requiresExternalWarning: config.requiresExternalWarning,
        requiresStoreDisclosure: config.requiresStoreDisclosure,
        allowedFromAppVersion: config.allowedFromAppVersion,
        externalCheckoutAllowed: config.externalCheckoutAllowed,
        bonusTokensPercent: config.bonusTokensPercent.toString(),
        displayLabel: config.displayLabel ?? "",
        displaySubtitle: config.displaySubtitle ?? "",
        warningTitle: config.warningTitle ?? "",
        warningMessage: config.warningMessage ?? "",
        mode: config.mode,
        notes: config.notes ?? "",
    };
}

function updateProviderConfigDraft(
    setProviderConfigDrafts: React.Dispatch<React.SetStateAction<Record<string, ProviderConfigDraft>>>,
    configurationId: string,
    patch: Partial<ProviderConfigDraft>,
) {
    setProviderConfigDrafts((current) => ({
        ...current,
        [configurationId]: {
            ...(current[configurationId] ?? {
                region: "*",
                isEnabled: false,
                isRecommended: false,
                isSelectedByDefault: false,
                requiresExternalWarning: false,
                requiresStoreDisclosure: false,
                allowedFromAppVersion: "0.0.0",
                externalCheckoutAllowed: false,
                bonusTokensPercent: "0",
                displayLabel: "",
                displaySubtitle: "",
                warningTitle: "",
                warningMessage: "",
                mode: "test",
                notes: "",
            }),
            ...patch,
        },
    }));
}

function toProviderConfigPayload(draft: ProviderConfigDraft, text: ReturnType<typeof getText>) {
    const region = draft.region.trim().toUpperCase();
    const allowedFromAppVersion = draft.allowedFromAppVersion.trim();
    const mode = draft.mode.trim().toLowerCase();
    const bonusTokensPercent = Number(draft.bonusTokensPercent);

    if (!region || !allowedFromAppVersion || !mode || !Number.isFinite(bonusTokensPercent) || bonusTokensPercent < 0 || bonusTokensPercent > 100) {
        throw new Error(text.invalidProviderConfig);
    }

    return {
        region,
        isEnabled: draft.isEnabled,
        isRecommended: draft.isRecommended,
        isSelectedByDefault: draft.isSelectedByDefault,
        requiresExternalWarning: draft.requiresExternalWarning,
        requiresStoreDisclosure: draft.requiresStoreDisclosure,
        allowedFromAppVersion,
        externalCheckoutAllowed: draft.externalCheckoutAllowed,
        bonusTokensPercent,
        displayLabel: optionalText(draft.displayLabel),
        displaySubtitle: optionalText(draft.displaySubtitle),
        warningTitle: optionalText(draft.warningTitle),
        warningMessage: optionalText(draft.warningMessage),
        mode,
        notes: optionalText(draft.notes),
    };
}

function optionalText(value: string) {
    const normalized = value.trim();
    return normalized ? normalized : null;
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
