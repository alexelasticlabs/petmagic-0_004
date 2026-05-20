"use client";

import { AdminCard, AdminKpiCard, AdminMetricStrip, AdminPage, AdminPageGrid, AdminPageHero, AdminSelectField, AdminStateCard, AdminStatusBadge, adminTableStyles } from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { Button } from "@/components/ui/button";
import styles from "@/components/economy-page.module.css";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
    createAdminRedeemCode,
    fetchAdminCurrencyPacks,
    fetchAdminEconomyLedger,
    fetchAdminEconomyPurchases,
    fetchAdminRedeemCodes,
    updateAdminCurrencyPack,
    useAuthSession,
    type AdminCurrencyPack,
} from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";

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

const ledgerSourceOptions = {
    ru: [
        { value: "", label: "Все источники" },
        { value: "pack_purchase", label: "Покупка пакета" },
        { value: "generation_spend", label: "Списание за генерацию" },
        { value: "weekly_grant", label: "Недельная награда" },
        { value: "ad_reward", label: "Награда за рекламу" },
        { value: "admin_grant", label: "Ручное начисление" },
        { value: "admin_debit", label: "Ручное списание" },
    ],
    en: [
        { value: "", label: "All sources" },
        { value: "pack_purchase", label: "Pack purchase" },
        { value: "generation_spend", label: "Generation spend" },
        { value: "weekly_grant", label: "Weekly reward" },
        { value: "ad_reward", label: "Ad reward" },
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

export function EconomyPage({ locale }: EconomyPageProps) {
    const text = getText(locale);
    const router = useRouter();
    const queryClient = useQueryClient();
    const session = useAuthSession();
    const [ledgerSource, setLedgerSource] = useState("");
    const [purchaseStatus, setPurchaseStatus] = useState("");
    const [drafts, setDrafts] = useState<Record<string, PackDraft>>({});
    const [redeemForm, setRedeemForm] = useState({
        code: "",
        description: "",
        rewardSpark: "100",
        maxRedemptions: "100",
        isActive: true,
        expiresAtUtc: "",
    });
    const [feedback, setFeedback] = useState<{ tone: "success" | "danger"; message: string } | null>(null);

    useEffect(() => {
        if (!session) {
            ensureAdminSession(locale, router);
        }
    }, [locale, router, session]);

    const ledgerQuery = useQuery({
        queryKey: adminQueryKeys.economyLedger(ledgerSource || "all", "all"),
        queryFn: () => fetchAdminEconomyLedger({ take: 20, source: ledgerSource || undefined }),
    });

    const purchasesQuery = useQuery({
        queryKey: adminQueryKeys.economyPurchases(purchaseStatus || "all"),
        queryFn: () => fetchAdminEconomyPurchases({ take: 20, status: purchaseStatus || undefined }),
    });

    const packsQuery = useQuery({
        queryKey: adminQueryKeys.economyPacks,
        queryFn: fetchAdminCurrencyPacks,
    });

    const redeemCodesQuery = useQuery({
        queryKey: adminQueryKeys.economyRedeemCodes,
        queryFn: fetchAdminRedeemCodes,
    });

    useEffect(() => {
        if (!packsQuery.data) {
            return;
        }

        setDrafts((current) => {
            const next = { ...current };
            for (const pack of packsQuery.data) {
                next[pack.packId] ??= toDraft(pack);
            }
            return next;
        });
    }, [packsQuery.data]);

    const savePackMutation = useMutation({
        mutationFn: async (packId: string) => {
            const draft = drafts[packId];
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

    const createRedeemMutation = useMutation({
        mutationFn: () => createAdminRedeemCode({
            code: redeemForm.code.trim(),
            description: redeemForm.description.trim(),
            rewardSpark: Number(redeemForm.rewardSpark),
            maxRedemptions: Number(redeemForm.maxRedemptions),
            isActive: redeemForm.isActive,
            startsAtUtc: null,
            expiresAtUtc: redeemForm.expiresAtUtc ? new Date(redeemForm.expiresAtUtc).toISOString() : null,
        }),
        onSuccess: async () => {
            setFeedback({ tone: "success", message: text.redeemCreated });
            setRedeemForm({ code: "", description: "", rewardSpark: "100", maxRedemptions: "100", isActive: true, expiresAtUtc: "" });
            await queryClient.invalidateQueries({ queryKey: adminQueryKeys.economyRedeemCodes });
        },
        onError: () => {
            setFeedback({ tone: "danger", message: text.redeemCreateError });
        },
    });

    const ledgerItems = ledgerQuery.data?.items ?? [];
    const purchaseItems = purchasesQuery.data?.items ?? [];
    const packs = packsQuery.data ?? [];
    const redeemCodes = redeemCodesQuery.data ?? [];

    const metrics = useMemo(() => {
        const credited = ledgerItems.filter((item) => item.delta > 0).reduce((sum, item) => sum + item.delta, 0);
        const debited = ledgerItems.filter((item) => item.delta < 0).reduce((sum, item) => sum + Math.abs(item.delta), 0);
        const grossRevenue = purchaseItems.reduce((sum, item) => sum + item.priceAmount, 0);
        const activePacks = packs.filter((pack) => pack.isActive).length;

        return { credited, debited, grossRevenue, activePacks };
    }, [ledgerItems, packs, purchaseItems]);

    const isLoading = ledgerQuery.isLoading || purchasesQuery.isLoading || packsQuery.isLoading || redeemCodesQuery.isLoading;
    const hasError = ledgerQuery.isError || purchasesQuery.isError || packsQuery.isError || redeemCodesQuery.isError;

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
                    `${text.metaRedeem}: ${redeemCodes.length}`,
                    `${text.metaLedger}: ${ledgerItems.length}`,
                    `${text.metaPurchases}: ${purchaseItems.length}`,
                ]}
            />

            <AdminPageGrid columns="four">
                <AdminKpiCard label={text.activePacksLabel} value={String(metrics.activePacks)} tone="primary" />
                <AdminKpiCard label={text.creditFlowLabel} value={formatTokens(metrics.credited, locale)} tone="success" />
                <AdminKpiCard label={text.debitFlowLabel} value={formatTokens(metrics.debited, locale)} tone="warning" />
                <AdminKpiCard label={text.revenueLabel} value={formatCurrency(metrics.grossRevenue, locale, purchaseItems[0]?.currencyCode ?? "USD")} tone="info" />
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

                {packs.length ? (
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
                ) : (
                    <AdminStateCard tone="info" title={text.noPacks} />
                )}
            </AdminCard>

            <AdminCard title={text.redeemTitle} description={text.redeemDescription}>
                <div className={styles.redeemGrid}>
                    <section className={styles.redeemForm}>
                        <label className={styles.field}>
                            <span>{text.redeemCodeLabel}</span>
                            <input
                                value={redeemForm.code}
                                onChange={(event) => setRedeemForm((current) => ({ ...current, code: event.target.value }))}
                                className={styles.input}
                                placeholder="WELCOME-100"
                            />
                        </label>
                        <label className={styles.field}>
                            <span>{text.redeemDescriptionLabel}</span>
                            <input
                                value={redeemForm.description}
                                onChange={(event) => setRedeemForm((current) => ({ ...current, description: event.target.value }))}
                                className={styles.input}
                            />
                        </label>
                        <div className={styles.formRow}>
                            <label className={styles.field}>
                                <span>{text.redeemRewardLabel}</span>
                                <input
                                    value={redeemForm.rewardSpark}
                                    onChange={(event) => setRedeemForm((current) => ({ ...current, rewardSpark: event.target.value }))}
                                    inputMode="numeric"
                                    className={styles.input}
                                />
                            </label>
                            <label className={styles.field}>
                                <span>{text.redeemLimitLabel}</span>
                                <input
                                    value={redeemForm.maxRedemptions}
                                    onChange={(event) => setRedeemForm((current) => ({ ...current, maxRedemptions: event.target.value }))}
                                    inputMode="numeric"
                                    className={styles.input}
                                />
                            </label>
                        </div>
                        <label className={styles.field}>
                            <span>{text.redeemExpiresLabel}</span>
                            <input
                                type="datetime-local"
                                value={redeemForm.expiresAtUtc}
                                onChange={(event) => setRedeemForm((current) => ({ ...current, expiresAtUtc: event.target.value }))}
                                className={styles.input}
                            />
                        </label>
                        <label className={styles.checkboxField}>
                            <input
                                type="checkbox"
                                checked={redeemForm.isActive}
                                onChange={(event) => setRedeemForm((current) => ({ ...current, isActive: event.target.checked }))}
                            />
                            <span>{text.activeState}</span>
                        </label>
                        <Button onClick={() => createRedeemMutation.mutate()} disabled={createRedeemMutation.isPending || !redeemForm.code.trim()}>
                            {createRedeemMutation.isPending ? text.savingAction : text.redeemCreateAction}
                        </Button>
                    </section>

                    <section>
                        {redeemCodes.length ? (
                            <div className={adminTableStyles.tableWrap}>
                                <table className={adminTableStyles.table}>
                                    <thead>
                                        <tr>
                                            <th>{text.redeemCodeColumn}</th>
                                            <th>{text.redeemRewardLabel}</th>
                                            <th>{text.redeemUsageColumn}</th>
                                            <th>{text.activeColumn}</th>
                                            <th>{text.redeemExpiresLabel}</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {redeemCodes.map((code) => (
                                            <tr key={code.redeemCodeId}>
                                                <td>
                                                    <div className={styles.packMeta}>
                                                        <strong>{code.codePrefix}...</strong>
                                                        <span>{code.description || text.noDescription}</span>
                                                    </div>
                                                </td>
                                                <td>{code.rewardSpark} {text.tokensShort}</td>
                                                <td>{code.redeemedCount} / {code.maxRedemptions}</td>
                                                <td>
                                                    <AdminStatusBadge color={code.isActive ? "#22c55e" : "#8da1ba"}>
                                                        {code.isActive ? text.activeState : text.inactiveState}
                                                    </AdminStatusBadge>
                                                </td>
                                                <td>{formatDateTime(code.expiresAtUtc, locale)}</td>
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>
                        ) : (
                            <AdminStateCard tone="info" title={text.noRedeemCodes} />
                        )}
                    </section>
                </div>
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
                    {ledgerItems.length ? (
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
                    ) : (
                        <AdminStateCard tone="info" title={text.noLedger} />
                    )}
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
                    {purchaseItems.length ? (
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
                    ) : (
                        <AdminStateCard tone="info" title={text.noPurchases} />
                    )}
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
            metaRedeem: "Промокодов",
            metaLedger: "Операций",
            metaPurchases: "Покупок",
            activePacksLabel: "Активные паки",
            creditFlowLabel: "Начисления",
            debitFlowLabel: "Списания",
            revenueLabel: "Выручка",
            packsTitle: "Паки пополнения",
            packsDescription: "Редактирование цен, бонуса и видимости пакетов без затрагивания истории покупок.",
            tokensShort: "spark",
            packSaved: "Пакет обновлен.",
            packSaveError: "Не удалось сохранить пакет.",
            packColumn: "Пакет",
            priceColumn: "Цена",
            grantedColumn: "База",
            bonusColumn: "Бонус",
            sortColumn: "Порядок",
            activeColumn: "Активен",
            actionsColumn: "Действие",
            activeState: "Включен",
            inactiveState: "Скрыт",
            savingAction: "Сохраняем...",
            saveAction: "Сохранить",
            noPacks: "Паки пополнения пока не настроены.",
            redeemTitle: "Промокоды",
            redeemDescription: "Создание и контроль redeem-кодов для начисления PawSpark через кошелек пользователя.",
            redeemCreated: "Промокод создан.",
            redeemCreateError: "Не удалось создать промокод.",
            redeemCodeLabel: "Код",
            redeemDescriptionLabel: "Описание",
            redeemRewardLabel: "Награда",
            redeemLimitLabel: "Лимит",
            redeemExpiresLabel: "Истекает",
            redeemCreateAction: "Создать промокод",
            redeemCodeColumn: "Код",
            redeemUsageColumn: "Использовано",
            noDescription: "Без описания",
            noRedeemCodes: "Промокодов пока нет.",
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
        metaRedeem: "Redeem codes",
        metaLedger: "Ledger rows",
        metaPurchases: "Purchases",
        activePacksLabel: "Active packs",
        creditFlowLabel: "Credits",
        debitFlowLabel: "Debits",
        revenueLabel: "Revenue",
        packsTitle: "Top-up packs",
        packsDescription: "Update pricing, bonus, and visibility without touching historical purchases.",
        tokensShort: "spark",
        packSaved: "Pack updated.",
        packSaveError: "Failed to save pack.",
        packColumn: "Pack",
        priceColumn: "Price",
        grantedColumn: "Base",
        bonusColumn: "Bonus",
        sortColumn: "Sort",
        activeColumn: "Active",
        actionsColumn: "Action",
        activeState: "On",
        inactiveState: "Hidden",
        savingAction: "Saving...",
        saveAction: "Save",
        noPacks: "No top-up packs configured yet.",
        redeemTitle: "Redeem codes",
        redeemDescription: "Create and monitor wallet redeem codes that grant PawSpark to users.",
        redeemCreated: "Redeem code created.",
        redeemCreateError: "Failed to create redeem code.",
        redeemCodeLabel: "Code",
        redeemDescriptionLabel: "Description",
        redeemRewardLabel: "Reward",
        redeemLimitLabel: "Limit",
        redeemExpiresLabel: "Expires",
        redeemCreateAction: "Create redeem code",
        redeemCodeColumn: "Code",
        redeemUsageColumn: "Used",
        noDescription: "No description",
        noRedeemCodes: "No redeem codes yet.",
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

function formatDateTime(value: string | null | undefined, locale: Locale) {
    if (!value) {
        return "—";
    }

    return new Intl.DateTimeFormat(locale === "ru" ? "ru-RU" : "en-US", {
        dateStyle: "medium",
        timeStyle: "short",
    }).format(new Date(value));
}

function humanizeSource(value: string, locale: Locale) {
    const labels: Record<string, { ru: string; en: string }> = {
        weekly_grant: { ru: "Недельная награда", en: "Weekly reward" },
        ad_reward: { ru: "Награда за рекламу", en: "Ad reward" },
        generation_spend: { ru: "Списание за генерацию", en: "Generation spend" },
        generation_refund: { ru: "Возврат за генерацию", en: "Generation refund" },
        pack_purchase: { ru: "Покупка пакета", en: "Pack purchase" },
        admin_grant: { ru: "Ручное начисление", en: "Manual grant" },
        admin_debit: { ru: "Ручное списание", en: "Manual debit" },
    };

    return labels[value]?.[locale] ?? value;
}

function humanizeStatus(value: string, locale: Locale) {
    const labels: Record<string, { ru: string; en: string }> = {
        pending: { ru: "Ожидает", en: "Pending" },
        succeeded: { ru: "Успешно", en: "Succeeded" },
        failed: { ru: "Ошибка", en: "Failed" },
    };

    return labels[value]?.[locale] ?? value;
}

function statusColor(value: string) {
    switch (value) {
        case "succeeded":
            return "#22c55e";
        case "failed":
            return "#f87171";
        default:
            return "#f59e0b";
    }
}
