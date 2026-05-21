"use client";

import {
    CalendarIcon,
    DownloadIcon,
    PencilIcon,
    PlusIcon,
    PromoCodeIcon,
    RefreshIcon,
    TrendUpIcon,
    UsersIcon,
} from "@/components/admin/admin-icons";
import { AdminBadge, AdminCard, AdminFilterBar, AdminKpiCard, AdminPage, AdminPageHero, AdminStateCard, AdminStatusBadge, AdminToolbar, adminTableStyles } from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import styles from "@/components/promo-codes-view.module.css";
import { Button } from "@/components/ui/button";
import { Select, type SelectOption } from "@/components/ui/select";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import { createAdminRedeemCode, fetchAdminRedeemCodes, fetchAdminUser, updateAdminRedeemCode, useAuthSession, type AdminRedeemCode, type AdminUserDetail } from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";
import { useMutation, useQueries, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { type FormEvent, useDeferredValue, useEffect, useMemo, useState } from "react";

const PAGE_SIZE = 8;
const EMPTY_PROMO_CODES: AdminRedeemCode[] = [];

type PromoStatusFilter = "all" | "active" | "scheduled" | "exhausted" | "expired" | "archived";
type PromoSortMode = "updated" | "usage" | "reward" | "code" | "expiry";
type PromoFormMode = "create" | "edit" | "duplicate";
type PromoFeedback = {
    tone: "success" | "danger" | "info";
    message: string;
};
type PromoForm = {
    code: string;
    description: string;
    rewardValue: string;
    maxRedemptions: string;
    maxRedemptionsPerUser: string;
    isActive: boolean;
    startsAtUtc: string;
    expiresAtUtc: string;
};

export function PromoCodesView({ locale }: { locale: Locale }) {
    const text = getDictionary(locale);
    const tokenUnit = "spark";
    const router = useRouter();
    const queryClient = useQueryClient();
    const session = useAuthSession();
    const [search, setSearch] = useState("");
    const deferredSearch = useDeferredValue(search);
    const [statusFilter, setStatusFilter] = useState<PromoStatusFilter>("all");
    const [sortMode, setSortMode] = useState<PromoSortMode>("updated");
    const [page, setPage] = useState(1);
    const [panelMode, setPanelMode] = useState<PromoFormMode>("create");
    const [selectedCodeId, setSelectedCodeId] = useState<string | null>(null);
    const [form, setForm] = useState<PromoForm>(() => createDefaultPromoForm());
    const [feedback, setFeedback] = useState<PromoFeedback | null>(null);
    const [busyCodeId, setBusyCodeId] = useState<string | null>(null);

    useEffect(() => {
        if (!session) {
            ensureAdminSession(locale, router);
        }
    }, [locale, router, session]);

    const promoCodesQuery = useQuery({
        queryKey: adminQueryKeys.economyRedeemCodes,
        queryFn: fetchAdminRedeemCodes,
    });

    const promoCodes = promoCodesQuery.data ?? EMPTY_PROMO_CODES;
    const selectedCode = useMemo(
        () => promoCodes.find((code) => code.redeemCodeId === selectedCodeId) ?? null,
        [promoCodes, selectedCodeId],
    );

    const createMutation = useMutation({
        mutationFn: (payload: ReturnType<typeof toCreatePayload>) => createAdminRedeemCode(payload),
        onSuccess: async (code) => {
            setFeedback({ tone: "success", message: text.promoCodesCreateSuccess });
            setPanelMode("edit");
            setSelectedCodeId(code.redeemCodeId);
            setForm(toPromoForm(code));
            await queryClient.invalidateQueries({ queryKey: adminQueryKeys.economyRedeemCodes });
        },
        onError: (error) => {
            setFeedback({ tone: "danger", message: error instanceof Error ? error.message : text.promoCodesCreateError });
        },
    });

    const updateMutation = useMutation({
        mutationFn: ({ redeemCodeId, payload }: { redeemCodeId: string; payload: ReturnType<typeof toUpdatePayload> }) => updateAdminRedeemCode(redeemCodeId, payload),
        onSuccess: async (code) => {
            setFeedback({ tone: "success", message: text.promoCodesUpdateSuccess });
            setPanelMode("edit");
            setSelectedCodeId(code.redeemCodeId);
            setForm(toPromoForm(code));
            await queryClient.invalidateQueries({ queryKey: adminQueryKeys.economyRedeemCodes });
        },
        onError: (error) => {
            setFeedback({ tone: "danger", message: error instanceof Error ? error.message : text.promoCodesUpdateError });
        },
    });

    const archiveMutation = useMutation({
        mutationFn: ({ redeemCodeId, payload }: { redeemCodeId: string; payload: ReturnType<typeof toUpdatePayload> }) => updateAdminRedeemCode(redeemCodeId, payload),
        onSuccess: async (code) => {
            setFeedback({ tone: "success", message: text.promoCodesArchiveSuccess });
            if (selectedCodeId === code.redeemCodeId) {
                setForm(toPromoForm(code));
            }
            await queryClient.invalidateQueries({ queryKey: adminQueryKeys.economyRedeemCodes });
        },
        onError: (error) => {
            setFeedback({ tone: "danger", message: error instanceof Error ? error.message : text.promoCodesArchiveError });
        },
        onSettled: () => {
            setBusyCodeId(null);
        },
    });

    const selectedUserIds = useMemo(() => {
        if (!selectedCode) {
            return [];
        }

        return [...new Set(
            [...selectedCode.redemptions]
                .sort((firstItem, secondItem) => new Date(secondItem.redeemedAtUtc).getTime() - new Date(firstItem.redeemedAtUtc).getTime())
                .slice(0, 5)
                .map((item) => item.userId),
        )];
    }, [selectedCode]);

    const selectedUsersQueries = useQueries({
        queries: selectedUserIds.map((userId) => ({
            queryKey: adminQueryKeys.userDetail(userId),
            queryFn: () => fetchAdminUser(userId),
            staleTime: 60_000,
        })),
    });

    const selectedUsersById = useMemo(() => {
        const entries: Array<[string, AdminUserDetail]> = [];

        for (const [index, userId] of selectedUserIds.entries()) {
            const user = selectedUsersQueries[index]?.data;
            if (user) {
                entries.push([userId, user]);
            }
        }

        return new Map(entries);
    }, [selectedUserIds, selectedUsersQueries]);

    const metrics = useMemo(() => {
        const totalUses = promoCodes.reduce((sum, code) => sum + code.redeemedCount, 0);
        const totalGranted = promoCodes.reduce((sum, code) => sum + (code.rewardKind === "spark" ? code.rewardValue * code.redeemedCount : 0), 0);
        const activeCodes = promoCodes.filter((code) => getPromoStatus(code, text).key === "active").length;

        return {
            totalCodes: promoCodes.length,
            activeCodes,
            totalUses,
            totalGranted,
        };
    }, [promoCodes, text]);

    const filteredCodes = useMemo(() => {
        const normalizedSearch = deferredSearch.trim().toLowerCase();

        return promoCodes
            .filter((code) => {
                const status = getPromoStatus(code, text).key;
                const matchesStatus = statusFilter === "all" || status === statusFilter;
                const matchesSearch = !normalizedSearch
                    || code.code.toLowerCase().includes(normalizedSearch)
                    || code.codePrefix.toLowerCase().includes(normalizedSearch)
                    || code.description.toLowerCase().includes(normalizedSearch);

                return matchesStatus && matchesSearch;
            })
            .sort((firstItem, secondItem) => comparePromoCodes(firstItem, secondItem, sortMode));
    }, [deferredSearch, promoCodes, sortMode, statusFilter, text]);

    const totalPages = Math.max(1, Math.ceil(filteredCodes.length / PAGE_SIZE));
    const currentPage = Math.min(page, totalPages);
    const pagedCodes = filteredCodes.slice((currentPage - 1) * PAGE_SIZE, currentPage * PAGE_SIZE);
    const hasCodes = promoCodes.length > 0;
    const hasFilteredCodes = filteredCodes.length > 0;
    const isMutating = createMutation.isPending || updateMutation.isPending || archiveMutation.isPending;

    function handleResetPanel() {
        setFeedback(null);

        if (panelMode === "edit" && selectedCode) {
            setForm(toPromoForm(selectedCode));
            return;
        }

        if (panelMode === "duplicate" && selectedCode) {
            setForm({
                ...toPromoForm(selectedCode),
                code: createGeneratedPromoCode(),
            });
            return;
        }

        setForm(createDefaultPromoForm());
    }

    function handleOpenCreatePanel() {
        setPanelMode("create");
        setSelectedCodeId(null);
        setForm(createDefaultPromoForm());
        setFeedback(null);
    }

    function handleOpenEditPanel(code: AdminRedeemCode) {
        setPanelMode("edit");
        setSelectedCodeId(code.redeemCodeId);
        setForm(toPromoForm(code));
        setFeedback(null);
    }

    function handleOpenDuplicatePanel(code: AdminRedeemCode) {
        setPanelMode("duplicate");
        setSelectedCodeId(code.redeemCodeId);
        setForm({
            ...toPromoForm(code),
            code: createGeneratedPromoCode(),
        });
        setFeedback(null);
    }

    async function handleCopyCode(code: string) {
        try {
            await copyTextToClipboard(code);
            setFeedback({ tone: "info", message: text.promoCodesCopied });
        } catch {
            setFeedback({ tone: "danger", message: text.promoCodesCopyAction });
        }
    }

    function handleGenerateCode() {
        setForm((current) => ({ ...current, code: createGeneratedPromoCode() }));
    }

    function handleExport() {
        if (!filteredCodes.length) {
            return;
        }

        const csv = buildPromoCodesCsv(filteredCodes, locale, text);
        const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
        const url = URL.createObjectURL(blob);
        const link = document.createElement("a");
        link.href = url;
        link.download = `promo-codes-${new Date().toISOString().slice(0, 10)}.csv`;
        link.click();
        URL.revokeObjectURL(url);
        setFeedback({ tone: "info", message: text.promoCodesExported });
    }

    function handleArchive(code: AdminRedeemCode) {
        if (!window.confirm(text.promoCodesArchiveConfirm)) {
            return;
        }

        try {
            const payload = toUpdatePayload({ ...toPromoForm(code), isActive: false }, code, text);
            setBusyCodeId(code.redeemCodeId);
            archiveMutation.mutate({ redeemCodeId: code.redeemCodeId, payload });
        } catch (error) {
            setFeedback({ tone: "danger", message: error instanceof Error ? error.message : text.promoCodesArchiveError });
        }
    }

    function handleSubmit(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();
        setFeedback(null);

        try {
            if (panelMode === "edit") {
                if (!selectedCode) {
                    throw new Error(text.promoCodesUpdateError);
                }

                updateMutation.mutate({
                    redeemCodeId: selectedCode.redeemCodeId,
                    payload: toUpdatePayload(form, selectedCode, text),
                });
                return;
            }

            createMutation.mutate(toCreatePayload(form, text));
        } catch (error) {
            setFeedback({ tone: "danger", message: error instanceof Error ? error.message : text.promoCodesCreateError });
        }
    }

    const statusOptions: SelectOption[] = [
        { value: "all", label: text.promoCodesStatusAll, tone: "neutral" },
        { value: "active", label: text.activeLabel, tone: "recommended" },
        { value: "scheduled", label: text.promoCodesStatusScheduled, tone: "fast" },
        { value: "exhausted", label: text.promoCodesStatusExhausted, tone: "premium" },
        { value: "expired", label: text.promoCodesStatusExpired, tone: "neutral" },
        { value: "archived", label: text.promoCodesStatusArchived, tone: "neutral" },
    ];
    const sortOptions: SelectOption[] = [
        { value: "updated", label: text.promoCodesSortUpdated, tone: "recommended" },
        { value: "usage", label: text.promoCodesSortUsage, tone: "premium" },
        { value: "reward", label: text.promoCodesSortReward, tone: "fast" },
        { value: "code", label: text.promoCodesSortCode, tone: "neutral" },
        { value: "expiry", label: text.promoCodesSortExpiry, tone: "neutral" },
    ];

    if (promoCodesQuery.isLoading) {
        return (
            <AdminPage className={styles.page}>
                <AdminStateCard tone="info" title={text.navPromoCodes} description={text.promoCodesLoadingDescription} />
            </AdminPage>
        );
    }

    if (promoCodesQuery.isError) {
        return (
            <AdminPage className={styles.page}>
                <AdminStateCard tone="danger" title={text.navPromoCodes} description={text.promoCodesErrorDescription} action={<Button variant="secondary" onClick={() => void promoCodesQuery.refetch()}>{text.promoCodesRefreshAction}</Button>} />
            </AdminPage>
        );
    }

    return (
        <AdminPage className={styles.page}>
            <AdminPageHero
                eyebrow={text.promoCodesHeroEyebrow}
                title={text.navPromoCodes}
                description={text.promoCodesHeroDescription}
                badge={<AdminBadge tone="success">{text.promoCodesTokenOnlyBadge}</AdminBadge>}
                actions={(
                    <div className={styles.heroActions}>
                        <Button variant="secondary" onClick={() => void promoCodesQuery.refetch()}><RefreshIcon className={styles.actionIcon} /> {text.promoCodesRefreshAction}</Button>
                        <Button variant="secondary" onClick={handleExport} disabled={!hasFilteredCodes}><DownloadIcon className={styles.actionIcon} /> {text.promoCodesExportAction}</Button>
                        <Button variant="primary" onClick={handleOpenCreatePanel}><PlusIcon className={styles.actionIcon} /> {text.promoCodesCreateAction}</Button>
                    </div>
                )}
                metaItems={[
                    `${text.promoCodesTotalLabel}: ${formatNumber(metrics.totalCodes, locale)}`,
                    `${text.promoCodesActiveLabel}: ${formatNumber(metrics.activeCodes, locale)}`,
                    `${text.promoCodesUsesLabel}: ${formatNumber(metrics.totalUses, locale)}`,
                    `${text.promoCodesGrantedLabel}: ${formatNumber(metrics.totalGranted, locale)} ${tokenUnit}`,
                ]}
            />

            {feedback ? <div className={`${styles.feedback} ${feedback.tone === "success" ? styles.feedbackSuccess : feedback.tone === "danger" ? styles.feedbackDanger : styles.feedbackInfo}`}>{feedback.message}</div> : null}

            <div className={styles.kpiGrid}>
                <AdminKpiCard label={text.promoCodesTotalLabel} value={formatNumber(metrics.totalCodes, locale)} hint={text.promoCodesTableDescription} tone="primary" icon={<PromoCodeIcon className={styles.kpiIcon} />} />
                <AdminKpiCard label={text.promoCodesActiveLabel} value={formatNumber(metrics.activeCodes, locale)} hint={text.activeLabel} tone="success" icon={<TrendUpIcon className={styles.kpiIcon} />} />
                <AdminKpiCard label={text.promoCodesUsesLabel} value={formatNumber(metrics.totalUses, locale)} hint={text.promoCodesRecentUsageTitle} tone="info" icon={<UsersIcon className={styles.kpiIcon} />} />
                <AdminKpiCard label={text.promoCodesGrantedLabel} value={`${formatNumber(metrics.totalGranted, locale)} ${tokenUnit}`} hint={text.promoCodesRewardFixedLabel} tone="warning" icon={<CalendarIcon className={styles.kpiIcon} />} />
            </div>

            <div className={styles.workspace}>
                <AdminCard title={text.navPromoCodes} description={text.promoCodesTableDescription} className={styles.tableCard}>
                    <AdminToolbar className={styles.toolbar}>
                        <span className={styles.toolbarCaption}>{hasFilteredCodes ? `${formatNumber(filteredCodes.length, locale)} / ${formatNumber(promoCodes.length, locale)}` : formatNumber(promoCodes.length, locale)}</span>
                    </AdminToolbar>
                    <AdminFilterBar className={styles.filterBar}>
                        <label className={styles.searchField}>
                            <span className={styles.fieldLabel}>{text.promoCodesSearchPlaceholder}</span>
                            <input className={styles.searchInput} value={search} onChange={(event) => {
                                setSearch(event.target.value);
                                setPage(1);
                            }} placeholder={text.promoCodesSearchPlaceholder} />
                        </label>
                        <div className={styles.selectField}>
                            <span className={styles.fieldLabel}>{text.promoCodesStatusFilterLabel}</span>
                            <Select value={statusFilter} options={statusOptions} onChange={(value) => {
                                setStatusFilter(value as PromoStatusFilter);
                                setPage(1);
                            }} ariaLabel={text.promoCodesStatusFilterLabel} showSelectedDescription={false} />
                        </div>
                        <div className={styles.selectField}>
                            <span className={styles.fieldLabel}>{text.promoCodesSortLabel}</span>
                            <Select value={sortMode} options={sortOptions} onChange={(value) => {
                                setSortMode(value as PromoSortMode);
                                setPage(1);
                            }} ariaLabel={text.promoCodesSortLabel} showSelectedDescription={false} />
                        </div>
                    </AdminFilterBar>

                    {!hasCodes ? (
                        <AdminStateCard tone="info" title={text.navPromoCodes} description={text.promoCodesEmptyDescription} action={<Button variant="primary" onClick={handleOpenCreatePanel}>{text.promoCodesCreateAction}</Button>} />
                    ) : !hasFilteredCodes ? (
                        <AdminStateCard tone="neutral" title={text.navPromoCodes} description={text.promoCodesNoResults} />
                    ) : (
                        <>
                            <div className={adminTableStyles.tableWrap}>
                                <table className={adminTableStyles.table}>
                                    <thead>
                                        <tr>
                                            <th>{text.promoCodesCodeLabel}</th>
                                            <th>{text.promoCodesDescriptionLabel}</th>
                                            <th>{text.promoCodesRewardLabel}</th>
                                            <th>{text.promoCodesUsageLabel}</th>
                                            <th>{text.statusLabel}</th>
                                            <th>{text.promoCodesWindowLabel}</th>
                                            <th>{text.promoCodesUpdatedColumn}</th>
                                            <th>{text.actionsLabel}</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {pagedCodes.map((code) => {
                                            const status = getPromoStatus(code, text);
                                            const isSelected = selectedCodeId === code.redeemCodeId && panelMode === "edit";

                                            return (
                                                <tr key={code.redeemCodeId} className={isSelected ? styles.rowSelected : undefined} onClick={() => handleOpenEditPanel(code)}>
                                                    <td>
                                                        <div className={styles.codeCell}>
                                                            <strong className={styles.codeValue}>{code.code || `${code.codePrefix}...`}</strong>
                                                            <span className={styles.codeMeta}>{shortGuid(code.redeemCodeId)}</span>
                                                        </div>
                                                    </td>
                                                    <td>
                                                        <div className={styles.descriptionCell}>
                                                            <strong>{code.description.trim() || "-"}</strong>
                                                            <span className={styles.descriptionMeta}>{formatDateTime(code.createdAtUtc, locale)}</span>
                                                        </div>
                                                    </td>
                                                    <td>
                                                        <AdminStatusBadge color="#22c55e">{formatRewardValue(code.rewardValue)}</AdminStatusBadge>
                                                    </td>
                                                    <td>
                                                        <div className={styles.usageCell}>
                                                            <strong>{formatNumber(code.redeemedCount, locale)} / {formatNumber(code.maxRedemptions, locale)}</strong>
                                                            <span>{text.promoCodesPerUserLimitLabel}: {formatNumber(code.maxRedemptionsPerUser, locale)}</span>
                                                        </div>
                                                    </td>
                                                    <td>
                                                        <AdminStatusBadge color={status.color}>{status.label}</AdminStatusBadge>
                                                    </td>
                                                    <td className={styles.windowCell}>{formatWindow(code, locale, text)}</td>
                                                    <td>{formatDateTime(code.updatedAtUtc, locale)}</td>
                                                    <td>
                                                        <div className={styles.tableActions} onClick={(event) => event.stopPropagation()}>
                                                            <Button variant="ghost" size="sm" className={styles.actionButton} onClick={() => handleCopyCode(code.code || `${code.codePrefix}...`)}>{text.promoCodesCopyAction}</Button>
                                                            <Button variant="ghost" size="sm" className={styles.actionButton} onClick={() => handleOpenDuplicatePanel(code)}>{text.promoCodesDuplicateAction}</Button>
                                                            <Button variant="ghost" size="sm" className={styles.actionButton} onClick={() => handleOpenEditPanel(code)}><PencilIcon className={styles.inlineIcon} /> {text.editTemplate}</Button>
                                                            <Button variant="danger" size="sm" className={styles.actionButton} onClick={() => handleArchive(code)} disabled={!code.isActive || busyCodeId === code.redeemCodeId}>{text.archive}</Button>
                                                        </div>
                                                    </td>
                                                </tr>
                                            );
                                        })}
                                    </tbody>
                                </table>
                            </div>

                            <div className={styles.pagination}>
                                <span className={styles.paginationInfo}>{formatNumber(currentPage, locale)} / {formatNumber(totalPages, locale)}</span>
                                <div className={styles.paginationActions}>
                                    <Button variant="secondary" size="sm" onClick={() => setPage((current) => Math.max(1, current - 1))} disabled={currentPage <= 1}>{text.promoCodesPreviousAction}</Button>
                                    <Button variant="secondary" size="sm" onClick={() => setPage((current) => Math.min(totalPages, current + 1))} disabled={currentPage >= totalPages}>{text.promoCodesNextAction}</Button>
                                </div>
                            </div>
                        </>
                    )}
                </AdminCard>

                <div className={styles.sidebarColumn}>
                    <AdminCard
                        title={panelMode === "edit" ? text.promoCodesEditPanelTitle : panelMode === "duplicate" ? text.promoCodesDuplicatePanelTitle : text.promoCodesCreatePanelTitle}
                        description={text.promoCodesRewardFixedLabel}
                        action={panelMode !== "create" ? <Button variant="ghost" size="sm" onClick={handleOpenCreatePanel}>{text.promoCodesNewDraftAction}</Button> : null}
                        className={styles.formCard}
                    >
                        <form className={styles.form} onSubmit={handleSubmit}>
                            <label className={styles.formField}>
                                <span className={styles.fieldLabel}>{text.promoCodesCodeLabel}</span>
                                <div className={styles.inlineField}>
                                    <input
                                        className={styles.input}
                                        value={form.code}
                                        onChange={(event) => setForm((current) => ({ ...current, code: event.target.value.toUpperCase() }))}
                                        readOnly={panelMode === "edit"}
                                    />
                                    <Button variant="secondary" size="sm" onClick={handleGenerateCode} disabled={panelMode === "edit"}>{text.promoCodesGenerateCodeAction}</Button>
                                </div>
                                <span className={styles.helperText}>{text.promoCodesCodeHelp}</span>
                            </label>

                            <label className={styles.formField}>
                                <span className={styles.fieldLabel}>{text.promoCodesDescriptionLabel}</span>
                                <input className={styles.input} value={form.description} onChange={(event) => setForm((current) => ({ ...current, description: event.target.value }))} />
                            </label>

                            <div className={styles.rewardCard}>
                                <span className={styles.fieldLabel}>{text.promoCodesRewardLabel}</span>
                                <div className={styles.rewardValue}>
                                    <AdminStatusBadge color="#22c55e">{text.promoCodesRewardFixedLabel}</AdminStatusBadge>
                                    <input className={styles.input} inputMode="numeric" value={form.rewardValue} onChange={(event) => setForm((current) => ({ ...current, rewardValue: event.target.value }))} />
                                </div>
                            </div>

                            <div className={styles.formGrid}>
                                <label className={styles.formField}>
                                    <span className={styles.fieldLabel}>{text.promoCodesLimitLabel}</span>
                                    <input className={styles.input} inputMode="numeric" value={form.maxRedemptions} onChange={(event) => setForm((current) => ({ ...current, maxRedemptions: event.target.value }))} />
                                </label>
                                <label className={styles.formField}>
                                    <span className={styles.fieldLabel}>{text.promoCodesPerUserLimitLabel}</span>
                                    <input className={styles.input} inputMode="numeric" value={form.maxRedemptionsPerUser} onChange={(event) => setForm((current) => ({ ...current, maxRedemptionsPerUser: event.target.value }))} />
                                </label>
                            </div>

                            <div className={styles.formGrid}>
                                <label className={styles.formField}>
                                    <span className={styles.fieldLabel}>{text.promoCodesStartsLabel}</span>
                                    <input className={styles.input} type="datetime-local" value={form.startsAtUtc} onChange={(event) => setForm((current) => ({ ...current, startsAtUtc: event.target.value }))} />
                                </label>
                                <label className={styles.formField}>
                                    <span className={styles.fieldLabel}>{text.promoCodesExpiresLabel}</span>
                                    <input className={styles.input} type="datetime-local" value={form.expiresAtUtc} onChange={(event) => setForm((current) => ({ ...current, expiresAtUtc: event.target.value }))} />
                                </label>
                            </div>

                            <label className={styles.checkboxField}>
                                <input type="checkbox" checked={form.isActive} onChange={(event) => setForm((current) => ({ ...current, isActive: event.target.checked }))} />
                                <span>{text.activeLabel}</span>
                            </label>

                            <div className={styles.formActions}>
                                <Button variant="secondary" onClick={handleResetPanel} disabled={isMutating}>{text.resetForm}</Button>
                                <Button variant="primary" type="submit" disabled={isMutating}>{panelMode === "edit" ? text.promoCodesSaveUpdateAction : text.promoCodesSaveCreateAction}</Button>
                            </div>
                        </form>
                    </AdminCard>

                    <AdminCard title={text.promoCodesRecentUsageTitle} description={selectedCode ? selectedCode.code || `${selectedCode.codePrefix}...` : text.promoCodesSelectForUsage} className={styles.usageCard}>
                        {!selectedCode ? (
                            <p className={styles.placeholderText}>{text.promoCodesSelectForUsage}</p>
                        ) : !selectedCode.redemptions.length ? (
                            <p className={styles.placeholderText}>{text.promoCodesRecentUsageEmpty}</p>
                        ) : (
                            <ul className={styles.usageList}>
                                {[...selectedCode.redemptions]
                                    .sort((firstItem, secondItem) => new Date(secondItem.redeemedAtUtc).getTime() - new Date(firstItem.redeemedAtUtc).getTime())
                                    .slice(0, 5)
                                    .map((redemption) => {
                                        const labels = getUserLabels(redemption.userId, selectedUsersById.get(redemption.userId));

                                        return (
                                            <li key={redemption.redemptionId} className={styles.usageItem}>
                                                <div>
                                                    <strong>{labels.primary}</strong>
                                                    <span>{labels.secondary}</span>
                                                </div>
                                                <div className={styles.usageMeta}>
                                                    <AdminStatusBadge color="#22c55e">{formatRewardValue(redemption.rewardValue)}</AdminStatusBadge>
                                                    <span>{formatDateTime(redemption.redeemedAtUtc, locale)}</span>
                                                </div>
                                            </li>
                                        );
                                    })}
                            </ul>
                        )}
                    </AdminCard>
                </div>
            </div>
        </AdminPage>
    );
}

function createDefaultPromoForm(): PromoForm {
    return {
        code: createGeneratedPromoCode(),
        description: "",
        rewardValue: "100",
        maxRedemptions: "100",
        maxRedemptionsPerUser: "1",
        isActive: true,
        startsAtUtc: "",
        expiresAtUtc: "",
    };
}

function toPromoForm(code: AdminRedeemCode): PromoForm {
    return {
        code: code.code || `${code.codePrefix}...`,
        description: code.description,
        rewardValue: code.rewardValue.toString(),
        maxRedemptions: code.maxRedemptions.toString(),
        maxRedemptionsPerUser: code.maxRedemptionsPerUser.toString(),
        isActive: code.isActive,
        startsAtUtc: toDateTimeLocalValue(code.startsAtUtc),
        expiresAtUtc: toDateTimeLocalValue(code.expiresAtUtc),
    };
}

function toCreatePayload(form: PromoForm, text: ReturnType<typeof getDictionary>) {
    validatePromoForm(form, 0, 0, text);

    return {
        code: form.code.trim(),
        description: form.description.trim(),
        rewardKind: "spark" as const,
        rewardValue: Number(form.rewardValue),
        maxRedemptions: Number(form.maxRedemptions),
        maxRedemptionsPerUser: Number(form.maxRedemptionsPerUser),
        isActive: form.isActive,
        startsAtUtc: toIsoOrNull(form.startsAtUtc),
        expiresAtUtc: toIsoOrNull(form.expiresAtUtc),
    };
}

function toUpdatePayload(form: PromoForm, code: AdminRedeemCode, text: ReturnType<typeof getDictionary>) {
    validatePromoForm(form, code.redeemedCount, getMaxUserRedemptions(code), text);

    return {
        description: form.description.trim(),
        rewardKind: "spark" as const,
        rewardValue: Number(form.rewardValue),
        maxRedemptions: Number(form.maxRedemptions),
        maxRedemptionsPerUser: Number(form.maxRedemptionsPerUser),
        isActive: form.isActive,
        startsAtUtc: toIsoOrNull(form.startsAtUtc),
        expiresAtUtc: toIsoOrNull(form.expiresAtUtc),
    };
}

function validatePromoForm(form: PromoForm, redeemedCount: number, maxRedeemedBySingleUser: number, text: ReturnType<typeof getDictionary>) {
    const normalizedCode = form.code.trim();
    const rewardValue = Number(form.rewardValue);
    const maxRedemptions = Number(form.maxRedemptions);
    const maxRedemptionsPerUser = Number(form.maxRedemptionsPerUser);

    if (!normalizedCode || normalizedCode.length < 4 || normalizedCode.length > 48) {
        throw new Error(text.promoCodesInvalidCode);
    }

    if (!Number.isFinite(rewardValue) || rewardValue <= 0 || !Number.isFinite(maxRedemptions) || maxRedemptions <= 0 || !Number.isFinite(maxRedemptionsPerUser) || maxRedemptionsPerUser <= 0) {
        throw new Error(text.promoCodesInvalidNumbers);
    }

    if (maxRedemptions < redeemedCount) {
        throw new Error(text.promoCodesLimitTooLow);
    }

    if (maxRedemptionsPerUser < maxRedeemedBySingleUser) {
        throw new Error(text.promoCodesPerUserLimitTooLow);
    }

    if (form.startsAtUtc && form.expiresAtUtc && new Date(form.startsAtUtc).getTime() > new Date(form.expiresAtUtc).getTime()) {
        throw new Error(text.promoCodesInvalidWindow);
    }
}

function getPromoStatus(code: AdminRedeemCode, text: ReturnType<typeof getDictionary>) {
    const now = Date.now();
    const startsAt = code.startsAtUtc ? new Date(code.startsAtUtc).getTime() : null;
    const expiresAt = code.expiresAtUtc ? new Date(code.expiresAtUtc).getTime() : null;

    if (!code.isActive) {
        return { key: "archived" as const, label: text.promoCodesStatusArchived, color: "#8da1ba" };
    }

    if (code.redeemedCount >= code.maxRedemptions) {
        return { key: "exhausted" as const, label: text.promoCodesStatusExhausted, color: "#f59e0b" };
    }

    if (startsAt !== null && startsAt > now) {
        return { key: "scheduled" as const, label: text.promoCodesStatusScheduled, color: "#38bdf8" };
    }

    if (expiresAt !== null && expiresAt <= now) {
        return { key: "expired" as const, label: text.promoCodesStatusExpired, color: "#f87171" };
    }

    return { key: "active" as const, label: text.activeLabel, color: "#22c55e" };
}

function comparePromoCodes(firstItem: AdminRedeemCode, secondItem: AdminRedeemCode, sortMode: PromoSortMode) {
    switch (sortMode) {
        case "usage":
            return secondItem.redeemedCount - firstItem.redeemedCount || secondItem.rewardValue - firstItem.rewardValue;
        case "reward":
            return secondItem.rewardValue - firstItem.rewardValue || secondItem.redeemedCount - firstItem.redeemedCount;
        case "code":
            return firstItem.code.localeCompare(secondItem.code);
        case "expiry": {
            const firstExpiry = firstItem.expiresAtUtc ? new Date(firstItem.expiresAtUtc).getTime() : Number.MAX_SAFE_INTEGER;
            const secondExpiry = secondItem.expiresAtUtc ? new Date(secondItem.expiresAtUtc).getTime() : Number.MAX_SAFE_INTEGER;
            return firstExpiry - secondExpiry;
        }
        default:
            return new Date(secondItem.updatedAtUtc).getTime() - new Date(firstItem.updatedAtUtc).getTime();
    }
}

function formatRewardValue(value: number) {
    return `${value} spark`;
}

function formatWindow(code: AdminRedeemCode, locale: Locale, text: ReturnType<typeof getDictionary>) {
    if (!code.startsAtUtc && !code.expiresAtUtc) {
        return text.promoCodesWindowAlways;
    }

    return `${formatDateTime(code.startsAtUtc, locale)} • ${formatDateTime(code.expiresAtUtc, locale)}`;
}

function formatDateTime(value: string | null | undefined, locale: Locale) {
    if (!value) {
        return "-";
    }

    const date = new Date(value);
    if (Number.isNaN(date.getTime())) {
        return "-";
    }

    return new Intl.DateTimeFormat(locale === "ru" ? "ru-RU" : "en-US", {
        day: "2-digit",
        month: "short",
        hour: "2-digit",
        minute: "2-digit",
    }).format(date);
}

function formatNumber(value: number, locale: Locale) {
    return new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US").format(value);
}

function toDateTimeLocalValue(value: string | null | undefined) {
    if (!value) {
        return "";
    }

    const date = new Date(value);
    if (Number.isNaN(date.getTime())) {
        return "";
    }

    const localDate = new Date(date.getTime() - date.getTimezoneOffset() * 60_000);
    return localDate.toISOString().slice(0, 16);
}

function toIsoOrNull(value: string) {
    return value ? new Date(value).toISOString() : null;
}

function getMaxUserRedemptions(code: AdminRedeemCode) {
    const usageByUser = new Map<string, number>();

    for (const redemption of code.redemptions) {
        usageByUser.set(redemption.userId, (usageByUser.get(redemption.userId) ?? 0) + 1);
    }

    return Math.max(0, ...usageByUser.values());
}

function createGeneratedPromoCode() {
    const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    const segments = Array.from({ length: 3 }, () => Array.from({ length: 4 }, () => alphabet[Math.floor(Math.random() * alphabet.length)]).join(""));
    return `PM-${segments.join("-")}`;
}

function shortGuid(value: string) {
    return value.slice(0, 8);
}

function getUserLabels(userId: string, user?: AdminUserDetail) {
    if (!user) {
        return {
            primary: shortGuid(userId),
            secondary: userId,
        };
    }

    if (user.displayName?.trim()) {
        return {
            primary: user.displayName.trim(),
            secondary: user.email,
        };
    }

    return {
        primary: user.email,
        secondary: userId,
    };
}

async function copyTextToClipboard(value: string) {
    if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(value);
        return;
    }

    const input = document.createElement("textarea");
    input.value = value;
    input.setAttribute("readonly", "true");
    input.style.position = "absolute";
    input.style.left = "-9999px";
    document.body.append(input);
    input.select();
    document.execCommand("copy");
    input.remove();
}

function buildPromoCodesCsv(codes: AdminRedeemCode[], locale: Locale, text: ReturnType<typeof getDictionary>) {
    const rows = [
        [text.promoCodesCodeLabel, text.promoCodesDescriptionLabel, text.promoCodesRewardLabel, text.promoCodesUsageLabel, text.statusLabel, text.promoCodesWindowLabel, text.promoCodesUpdatedColumn],
        ...codes.map((code) => [
            code.code,
            code.description,
            formatRewardValue(code.rewardValue),
            `${code.redeemedCount}/${code.maxRedemptions}`,
            getPromoStatus(code, text).label,
            formatWindow(code, locale, text),
            formatDateTime(code.updatedAtUtc, locale),
        ]),
    ];

    return rows.map((row) => row.map(escapeCsvCell).join(",")).join("\n");
}

function escapeCsvCell(value: string) {
    if (value.includes(",") || value.includes("\"") || value.includes("\n")) {
        return `"${value.replaceAll("\"", "\"\"")}"`;
    }

    return value;
}