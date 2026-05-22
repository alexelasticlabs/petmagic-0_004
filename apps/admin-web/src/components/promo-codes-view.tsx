"use client";

import { useMutation, useQueries, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useDeferredValue, useEffect, useMemo, useState, type FormEvent } from "react";

import {
    CalendarIcon,
    DownloadIcon,
    MoreHorizontalIcon,
    PromoCodeIcon,
    RefreshIcon,
    TrendUpIcon,
    UsersIcon,
} from "@/components/admin/admin-icons";
import { AdminCard, AdminFilterBar, AdminKpiCard, AdminPage, AdminStateCard, AdminStatusBadge, AdminToolbar, adminTableStyles } from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import {
    buildPromoCodesCsv,
    comparePromoCodes,
    copyTextToClipboard,
    createDefaultPromoForm,
    createGeneratedPromoCode,
    formatCampaignMeta,
    formatDateTime,
    formatNumber,
    formatRewardValue,
    formatSevenDayDelta,
    formatWindow,
    getLastUsedAt,
    getPromoStatus,
    getRewardKindLabel,
    getUserLabels,
    toCreatePayload,
    toPromoForm,
    toUpdatePayload,
    type PromoFeedback,
    type PromoForm,
    type PromoFormMode,
    type PromoSortMode,
    type PromoStatusFilter,
} from "@/components/promo-codes-view.helpers";
import styles from "@/components/promo-codes-view.module.css";
import { Button } from "@/components/ui/button";
import { Select, type SelectOption } from "@/components/ui/select";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
    createAdminRedeemCode,
    fetchAdminRedeemCodeActivations,
    fetchAdminRedeemCodes,
    fetchAdminUser,
    updateAdminRedeemCode,
    useAuthSession,
    type AdminRedeemCode,
    type AdminRedeemCodeRedemption,
    type AdminRedeemRewardKind,
    type AdminUserDetail,
} from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";

const PAGE_SIZE = 8;
const PROMO_CODES_AUTO_REFRESH_MS = 30_000;
const EMPTY_PROMO_CODES: AdminRedeemCode[] = [];
const EMPTY_REDEMPTIONS: AdminRedeemCodeRedemption[] = [];
const ACTIVATIONS_PREVIEW_LIMIT = 5;
const ACTIVATIONS_EXPANDED_LIMIT = 20;

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
    const [actionsMenuCodeId, setActionsMenuCodeId] = useState<string | null>(null);
    const [showAllActivations, setShowAllActivations] = useState(false);
    const [activationsPage, setActivationsPage] = useState(1);

    useEffect(() => {
        if (!session) {
            ensureAdminSession(locale, router);
        }
    }, [locale, router, session]);

    useEffect(() => {
        if (!actionsMenuCodeId) {
            return;
        }

        function handlePointerDown(event: PointerEvent) {
            const target = event.target as HTMLElement | null;
            if (target?.closest("[data-promo-actions-root]")) {
                return;
            }

            setActionsMenuCodeId(null);
        }

        window.addEventListener("pointerdown", handlePointerDown);
        return () => {
            window.removeEventListener("pointerdown", handlePointerDown);
        };
    }, [actionsMenuCodeId]);

    const promoCodesQuery = useQuery({
        queryKey: adminQueryKeys.economyRedeemCodes,
        queryFn: fetchAdminRedeemCodes,
        refetchInterval: PROMO_CODES_AUTO_REFRESH_MS,
        refetchIntervalInBackground: false,
    });

    const promoCodes = promoCodesQuery.data ?? EMPTY_PROMO_CODES;
    const nowMs = promoCodesQuery.dataUpdatedAt || 0;
    const selectedCode = useMemo(
        () => promoCodes.find((code) => code.redeemCodeId === selectedCodeId) ?? null,
        [promoCodes, selectedCodeId],
    );

    const activationsTake = showAllActivations ? ACTIVATIONS_EXPANDED_LIMIT : ACTIVATIONS_PREVIEW_LIMIT;
    const activationsSkip = showAllActivations ? (activationsPage - 1) * activationsTake : 0;

    const activationsQuery = useQuery({
        queryKey: adminQueryKeys.economyRedeemCodeActivations(selectedCodeId ?? "none", activationsSkip, activationsTake),
        queryFn: () => fetchAdminRedeemCodeActivations(selectedCodeId!, {
            skip: activationsSkip,
            take: activationsTake,
        }),
        enabled: Boolean(selectedCodeId),
        staleTime: 20_000,
    });

    const visibleRedemptions = useMemo(
        () => activationsQuery.data?.items ?? EMPTY_REDEMPTIONS,
        [activationsQuery.data?.items],
    );
    const hasMoreRedemptions = Boolean(activationsQuery.data?.hasMore);
    const hasAnyRedemptions = (selectedCode?.redeemedCount ?? 0) > 0;
    const canGoToPreviousActivationsPage = showAllActivations && activationsPage > 1;

    const selectedUserIds = useMemo(
        () => [...new Set(visibleRedemptions.map((item) => item.userId))],
        [visibleRedemptions],
    );

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

    const createMutation = useMutation({
        mutationFn: (payload: ReturnType<typeof toCreatePayload>) => createAdminRedeemCode(payload),
        onSuccess: async (code) => {
            setFeedback({ tone: "success", message: text.promoCodesCreateSuccess });
            setPanelMode("edit");
            setSelectedCodeId(code.redeemCodeId);
            setShowAllActivations(false);
            setActivationsPage(1);
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
            setShowAllActivations(false);
            setActivationsPage(1);
            setForm(toPromoForm(code));
            await queryClient.invalidateQueries({ queryKey: adminQueryKeys.economyRedeemCodes });
        },
        onError: (error) => {
            setFeedback({ tone: "danger", message: error instanceof Error ? error.message : text.promoCodesUpdateError });
        },
    });

    const statusMutation = useMutation({
        mutationFn: ({ redeemCodeId, payload }: { redeemCodeId: string; payload: ReturnType<typeof toUpdatePayload> }) => updateAdminRedeemCode(redeemCodeId, payload),
        onSuccess: async (code, variables) => {
            setFeedback({
                tone: "success",
                message: variables.payload.isActive ? text.promoCodesResumeSuccess : text.promoCodesPauseSuccess,
            });
            if (selectedCodeId === code.redeemCodeId) {
                setForm(toPromoForm(code));
            }
            await queryClient.invalidateQueries({ queryKey: adminQueryKeys.economyRedeemCodes });
        },
        onError: (error, variables) => {
            const fallback = variables.payload.isActive ? text.promoCodesResumeError : text.promoCodesPauseError;
            setFeedback({ tone: "danger", message: error instanceof Error ? error.message : fallback });
        },
        onSettled: () => {
            setBusyCodeId(null);
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

    const metrics = useMemo(() => {
        const sevenDaysAgo = nowMs - 7 * 24 * 60 * 60 * 1000;
        const totalUses = promoCodes.reduce((sum, code) => sum + code.redeemedCount, 0);
        const totalGranted = promoCodes.reduce((sum, code) => sum + (code.rewardKind === "spark" ? code.rewardValue * code.redeemedCount : 0), 0);
        const activeCodes = promoCodes.filter((code) => getPromoStatus(code, text, nowMs).key === "active").length;

        const createdLast7d = promoCodes.filter((code) => new Date(code.createdAtUtc).getTime() >= sevenDaysAgo).length;
        const activeTouchedLast7d = promoCodes.filter((code) => {
            const isActive = getPromoStatus(code, text, nowMs).key === "active";
            return isActive && new Date(code.updatedAtUtc).getTime() >= sevenDaysAgo;
        }).length;

        const usesLast7d = promoCodes.reduce(
            (sum, code) => sum + code.redemptions.filter((redemption) => new Date(redemption.redeemedAtUtc).getTime() >= sevenDaysAgo).length,
            0,
        );

        const grantedLast7d = promoCodes.reduce((sum, code) => {
            return sum + code.redemptions
                .filter((redemption) => new Date(redemption.redeemedAtUtc).getTime() >= sevenDaysAgo && redemption.rewardKind === "spark")
                .reduce((innerSum, redemption) => innerSum + redemption.rewardValue, 0);
        }, 0);

        return {
            totalCodes: promoCodes.length,
            activeCodes,
            totalUses,
            totalGranted,
            createdLast7d,
            activeTouchedLast7d,
            usesLast7d,
            grantedLast7d,
        };
    }, [nowMs, promoCodes, text]);

    const filteredCodes = useMemo(() => {
        const normalizedSearch = deferredSearch.trim().toLowerCase();

        return promoCodes
            .filter((code) => {
                const status = getPromoStatus(code, text, nowMs).key;
                const codeValue = code.code || code.codePrefix;
                const description = code.description || "";

                const matchesStatus = statusFilter === "all" || status === statusFilter;
                const matchesSearch = !normalizedSearch
                    || codeValue.toLowerCase().includes(normalizedSearch)
                    || code.codePrefix.toLowerCase().includes(normalizedSearch)
                    || description.toLowerCase().includes(normalizedSearch);

                return matchesStatus && matchesSearch;
            })
            .sort((firstItem, secondItem) => comparePromoCodes(firstItem, secondItem, sortMode));
    }, [deferredSearch, nowMs, promoCodes, sortMode, statusFilter, text]);

    const totalPages = Math.max(1, Math.ceil(filteredCodes.length / PAGE_SIZE));
    const currentPage = Math.min(page, totalPages);
    const pagedCodes = filteredCodes.slice((currentPage - 1) * PAGE_SIZE, currentPage * PAGE_SIZE);
    const hasCodes = promoCodes.length > 0;
    const hasFilteredCodes = filteredCodes.length > 0;
    const isMutating = createMutation.isPending || updateMutation.isPending || statusMutation.isPending || archiveMutation.isPending;

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
        setShowAllActivations(false);
        setActivationsPage(1);
        setForm(createDefaultPromoForm());
        setFeedback(null);
    }

    function handleOpenEditPanel(code: AdminRedeemCode) {
        setPanelMode("edit");
        setSelectedCodeId(code.redeemCodeId);
        setShowAllActivations(false);
        setActivationsPage(1);
        setForm(toPromoForm(code));
        setFeedback(null);
    }

    function handleOpenDuplicatePanel(code: AdminRedeemCode) {
        setPanelMode("duplicate");
        setSelectedCodeId(code.redeemCodeId);
        setShowAllActivations(false);
        setActivationsPage(1);
        setForm({
            ...toPromoForm(code),
            code: createGeneratedPromoCode(),
        });
        setFeedback(null);
        setActionsMenuCodeId(null);
    }

    function handleFocusUsage(code: AdminRedeemCode) {
        setSelectedCodeId(code.redeemCodeId);
        setShowAllActivations(false);
        setActivationsPage(1);
        if (panelMode === "create") {
            setPanelMode("edit");
            setForm(toPromoForm(code));
        }
        setActionsMenuCodeId(null);
    }

    async function handleCopyCode(code: string) {
        try {
            await copyTextToClipboard(code);
            setFeedback({ tone: "info", message: text.promoCodesCopied });
        } catch {
            setFeedback({ tone: "danger", message: text.promoCodesUpdateError });
        }
        setActionsMenuCodeId(null);
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

    function handleToggleCodeState(code: AdminRedeemCode) {
        try {
            const payload = toUpdatePayload({ ...toPromoForm(code), isActive: !code.isActive }, code, text);
            setBusyCodeId(code.redeemCodeId);
            setActionsMenuCodeId(null);
            statusMutation.mutate({ redeemCodeId: code.redeemCodeId, payload });
        } catch (error) {
            setFeedback({ tone: "danger", message: error instanceof Error ? error.message : text.promoCodesUpdateError });
        }
    }

    function handleArchive(code: AdminRedeemCode) {
        if (!window.confirm(text.promoCodesArchiveConfirm)) {
            return;
        }

        try {
            const payload = toUpdatePayload({ ...toPromoForm(code), isActive: false }, code, text);
            setBusyCodeId(code.redeemCodeId);
            setActionsMenuCodeId(null);
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
        { value: "draft", label: text.promoCodesStatusDraft, tone: "neutral" },
        { value: "active", label: text.activeLabel, tone: "recommended" },
        { value: "scheduled", label: text.promoCodesStatusScheduled, tone: "fast" },
        { value: "paused", label: text.promoCodesStatusPaused, tone: "premium" },
        { value: "exhausted", label: text.promoCodesStatusLimitReached, tone: "premium" },
        { value: "expired", label: text.promoCodesStatusExpired, tone: "neutral" },
        { value: "archived", label: text.promoCodesStatusArchived, tone: "neutral" },
    ];

    const formStatusOptions: SelectOption[] = [
        { value: "active", label: text.promoCodesStatusActiveOption, tone: "recommended" },
        { value: "paused", label: text.promoCodesStatusPausedOption, tone: "premium" },
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
                <AdminStateCard
                    tone="danger"
                    title={text.navPromoCodes}
                    description={text.promoCodesErrorDescription}
                    action={<Button variant="secondary" onClick={() => void promoCodesQuery.refetch()}>{text.promoCodesRefreshAction}</Button>}
                />
            </AdminPage>
        );
    }

    const selectedStatus = selectedCode ? getPromoStatus(selectedCode, text, nowMs) : null;

    return (
        <AdminPage className={styles.page}>
            {feedback ? <div className={`${styles.feedback} ${feedback.tone === "success" ? styles.feedbackSuccess : feedback.tone === "danger" ? styles.feedbackDanger : styles.feedbackInfo}`}>{feedback.message}</div> : null}

            <div className={styles.kpiGrid}>
                <AdminKpiCard
                    label={text.promoCodesTotalLabel}
                    value={formatNumber(metrics.totalCodes, locale)}
                    delta={formatSevenDayDelta(metrics.createdLast7d, locale, text)}
                    hint={text.promoCodesKpiTotalHint}
                    tone="primary"
                    icon={<PromoCodeIcon className={styles.kpiIcon} />}
                />
                <AdminKpiCard
                    label={text.promoCodesActiveLabel}
                    value={formatNumber(metrics.activeCodes, locale)}
                    delta={formatSevenDayDelta(metrics.activeTouchedLast7d, locale, text)}
                    hint={text.promoCodesKpiActiveHint}
                    tone="success"
                    icon={<TrendUpIcon className={styles.kpiIcon} />}
                />
                <AdminKpiCard
                    label={text.promoCodesUsesLabel}
                    value={formatNumber(metrics.totalUses, locale)}
                    delta={formatSevenDayDelta(metrics.usesLast7d, locale, text)}
                    hint={text.promoCodesKpiUsesHint}
                    tone="info"
                    icon={<UsersIcon className={styles.kpiIcon} />}
                />
                <AdminKpiCard
                    label={text.promoCodesGrantedLabel}
                    value={`${formatNumber(metrics.totalGranted, locale)} ${tokenUnit}`}
                    delta={`${formatNumber(metrics.grantedLast7d, locale)} ${tokenUnit} ${text.promoCodesLast7DaysLabel}`}
                    hint={text.promoCodesKpiGrantedHint}
                    tone="warning"
                    icon={<CalendarIcon className={styles.kpiIcon} />}
                />
            </div>

            <div className={styles.workspace}>
                <AdminCard title={text.navPromoCodes} description={text.promoCodesTableDescription} className={styles.tableCard}>
                    <AdminToolbar className={styles.toolbar}>
                        <span className={styles.toolbarCaption}>
                            {hasFilteredCodes
                                ? `${formatNumber(filteredCodes.length, locale)} / ${formatNumber(promoCodes.length, locale)}`
                                : formatNumber(promoCodes.length, locale)}
                        </span>
                        <div className={styles.toolbarActions}>
                            {promoCodesQuery.isFetching ? <span className={styles.syncBadge}>{text.promoCodesUpdatingLabel}</span> : null}
                            <Button variant="secondary" onClick={() => void promoCodesQuery.refetch()} disabled={promoCodesQuery.isFetching}>
                                <RefreshIcon className={styles.actionIcon} /> {text.promoCodesRefreshAction}
                            </Button>
                            <Button variant="secondary" onClick={handleExport} disabled={!hasFilteredCodes}>
                                <DownloadIcon className={styles.actionIcon} /> {text.promoCodesExportAction}
                            </Button>
                        </div>
                    </AdminToolbar>

                    <AdminFilterBar className={styles.filterBar}>
                        <label className={styles.searchField}>
                            <span className={styles.fieldLabel}>{text.promoCodesSearchPlaceholder}</span>
                            <input
                                className={styles.searchInput}
                                value={search}
                                onChange={(event) => {
                                    setSearch(event.target.value);
                                    setPage(1);
                                }}
                                placeholder={text.promoCodesSearchPlaceholder}
                            />
                        </label>
                        <div className={styles.selectField}>
                            <span className={styles.fieldLabel}>{text.promoCodesStatusFilterLabel}</span>
                            <Select
                                value={statusFilter}
                                options={statusOptions}
                                onChange={(value) => {
                                    setStatusFilter(value as PromoStatusFilter);
                                    setPage(1);
                                }}
                                ariaLabel={text.promoCodesStatusFilterLabel}
                                showSelectedDescription={false}
                            />
                        </div>
                        <div className={styles.selectField}>
                            <span className={styles.fieldLabel}>{text.promoCodesSortLabel}</span>
                            <Select
                                value={sortMode}
                                options={sortOptions}
                                onChange={(value) => {
                                    setSortMode(value as PromoSortMode);
                                    setPage(1);
                                }}
                                ariaLabel={text.promoCodesSortLabel}
                                showSelectedDescription={false}
                            />
                        </div>
                    </AdminFilterBar>

                    {!hasCodes ? (
                        <AdminStateCard tone="info" title={text.navPromoCodes} description={text.promoCodesEmptyDescription} />
                    ) : !hasFilteredCodes ? (
                        <AdminStateCard
                            tone="neutral"
                            title={text.navPromoCodes}
                            description={text.promoCodesNoResults}
                            action={
                                <Button
                                    variant="secondary"
                                    size="sm"
                                    onClick={() => {
                                        setSearch("");
                                        setStatusFilter("all");
                                        setPage(1);
                                    }}
                                >
                                    {text.resetForm}
                                </Button>
                            }
                        />
                    ) : (
                        <>
                            <div className={adminTableStyles.tableWrap}>
                                <table className={adminTableStyles.table}>
                                    <thead>
                                        <tr>
                                            <th>{text.promoCodesCodeLabel}</th>
                                            <th>{text.promoCodesRewardLabel}</th>
                                            <th>{text.promoCodesUsageLabel}</th>
                                            <th>{text.statusLabel}</th>
                                            <th>{text.promoCodesWindowLabel}</th>
                                            <th>{text.actionsLabel}</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {pagedCodes.map((code) => {
                                            const status = getPromoStatus(code, text, nowMs);
                                            const isSelected = selectedCodeId === code.redeemCodeId;
                                            const codeValue = code.code || `${code.codePrefix}...`;
                                            const actionBusy = busyCodeId === code.redeemCodeId;
                                            const lastUsedAt = getLastUsedAt(code);
                                            const campaignMeta = formatCampaignMeta(code);

                                            return (
                                                <tr
                                                    key={code.redeemCodeId}
                                                    className={`${styles.tableRow}${isSelected ? ` ${styles.rowSelected}` : ""}`}
                                                    onClick={() => handleOpenEditPanel(code)}
                                                >
                                                    <td>
                                                        <div className={styles.codeCell}>
                                                            <strong className={styles.codeValue}>{codeValue}</strong>
                                                            <span className={styles.codeMeta}>{code.description.trim() || "-"}</span>
                                                            {campaignMeta ? <span className={styles.codeMeta}>{campaignMeta}</span> : null}
                                                            <span className={styles.codeMeta}>{text.promoCodesUpdatedLabel}: {formatDateTime(code.updatedAtUtc, locale)}</span>
                                                        </div>
                                                    </td>
                                                    <td>
                                                        <div className={styles.rewardCell}>
                                                            <AdminStatusBadge color={code.rewardKind === "spark" ? "#22c55e" : "#60a5fa"}>
                                                                {formatRewardValue(code.rewardValue, code.rewardKind, text)}
                                                            </AdminStatusBadge>
                                                            <span className={styles.descriptionMeta}>{getRewardKindLabel(code.rewardKind, text)}</span>
                                                        </div>
                                                    </td>
                                                    <td>
                                                        <div className={styles.usageCell}>
                                                            <strong>{formatNumber(code.redeemedCount, locale)} / {formatNumber(code.maxRedemptions, locale)}</strong>
                                                            <span>{text.promoCodesPerUserLimitLabel}: {formatNumber(code.maxRedemptionsPerUser, locale)}</span>
                                                            <span>{text.promoCodesLastUsedLabel}: {formatDateTime(lastUsedAt, locale)}</span>
                                                        </div>
                                                    </td>
                                                    <td>
                                                        <AdminStatusBadge color={status.color}>{status.label}</AdminStatusBadge>
                                                    </td>
                                                    <td className={styles.windowCell}>{formatWindow(code, locale, text)}</td>
                                                    <td>
                                                        <div className={styles.actionsMenu} data-promo-actions-root onClick={(event) => event.stopPropagation()}>
                                                            <Button
                                                                variant="ghost"
                                                                size="sm"
                                                                className={styles.actionMenuTrigger}
                                                                aria-label={text.promoCodesActionsMenuLabel}
                                                                aria-haspopup="menu"
                                                                aria-expanded={actionsMenuCodeId === code.redeemCodeId}
                                                                onClick={() => setActionsMenuCodeId((current) => current === code.redeemCodeId ? null : code.redeemCodeId)}
                                                                disabled={actionBusy}
                                                            >
                                                                <MoreHorizontalIcon className={styles.inlineIcon} />
                                                            </Button>

                                                            {actionsMenuCodeId === code.redeemCodeId ? (
                                                                <div className={styles.actionsMenuList} role="menu" aria-label={text.promoCodesActionsMenuLabel}>
                                                                    <button type="button" className={styles.actionsMenuItem} onClick={() => void handleCopyCode(codeValue)}>{text.promoCodesCopyAction}</button>
                                                                    <button type="button" className={styles.actionsMenuItem} onClick={() => {
                                                                        handleOpenEditPanel(code);
                                                                        setActionsMenuCodeId(null);
                                                                    }}>{text.editTemplate}</button>
                                                                    <button type="button" className={styles.actionsMenuItem} onClick={() => handleOpenDuplicatePanel(code)}>{text.promoCodesDuplicateAction}</button>
                                                                    <button type="button" className={styles.actionsMenuItem} onClick={() => handleFocusUsage(code)}>{text.promoCodesViewActivationsAction}</button>
                                                                    <button type="button" className={styles.actionsMenuItem} onClick={() => handleToggleCodeState(code)}>
                                                                        {code.isActive ? text.promoCodesPauseAction : text.promoCodesResumeAction}
                                                                    </button>
                                                                    <button
                                                                        type="button"
                                                                        className={`${styles.actionsMenuItem} ${styles.actionsMenuItemDanger}`}
                                                                        onClick={() => handleArchive(code)}
                                                                        disabled={!code.isActive || actionBusy}
                                                                    >
                                                                        {text.archive}
                                                                    </button>
                                                                </div>
                                                            ) : null}
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
                        description={text.promoCodesFormCardDescription}
                        action={panelMode !== "create" ? <Button variant="ghost" size="sm" onClick={handleOpenCreatePanel}>{text.promoCodesNewDraftAction}</Button> : null}
                        className={styles.formCard}
                    >
                        <form className={styles.form} onSubmit={handleSubmit}>
                            <section className={styles.formSection}>
                                <header className={styles.formSectionHeader}>
                                    <h3 className={styles.formSectionTitle}>{text.promoCodesSectionMainTitle}</h3>
                                </header>

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

                                <label className={styles.formField}>
                                    <span className={styles.fieldLabel}>{text.promoCodesStatusFieldLabel}</span>
                                    <Select
                                        value={form.isActive ? "active" : "paused"}
                                        options={formStatusOptions}
                                        onChange={(value) => setForm((current) => ({ ...current, isActive: value === "active" }))}
                                        ariaLabel={text.promoCodesStatusFieldLabel}
                                        showSelectedDescription={false}
                                    />
                                </label>
                            </section>

                            <section className={styles.formSection}>
                                <header className={styles.formSectionHeader}>
                                    <h3 className={styles.formSectionTitle}>{text.promoCodesSectionCampaignTitle}</h3>
                                </header>

                                <div className={styles.formGrid}>
                                    <label className={styles.formField}>
                                        <span className={styles.fieldLabel}>{text.promoCodesCampaignNameLabel}</span>
                                        <input className={styles.input} value={form.campaignName} onChange={(event) => setForm((current) => ({ ...current, campaignName: event.target.value }))} />
                                    </label>

                                    <label className={styles.formField}>
                                        <span className={styles.fieldLabel}>{text.promoCodesCampaignChannelLabel}</span>
                                        <input className={styles.input} value={form.campaignChannel} onChange={(event) => setForm((current) => ({ ...current, campaignChannel: event.target.value }))} />
                                    </label>
                                </div>

                                <label className={styles.formField}>
                                    <span className={styles.fieldLabel}>{text.promoCodesCampaignCreatedByLabel}</span>
                                    <input className={styles.input} value={form.createdBy} onChange={(event) => setForm((current) => ({ ...current, createdBy: event.target.value }))} />
                                </label>
                            </section>

                            <section className={styles.formSection}>
                                <header className={styles.formSectionHeader}>
                                    <h3 className={styles.formSectionTitle}>{text.promoCodesSectionRewardTitle}</h3>
                                </header>

                                <div className={styles.formGrid}>
                                    <label className={styles.formField}>
                                        <span className={styles.fieldLabel}>{text.promoCodesRewardTypeLabel}</span>
                                        <select
                                            className={`${styles.input} ${styles.selectInput}`}
                                            value={form.rewardKind}
                                            onChange={(event) => setForm((current) => ({ ...current, rewardKind: event.target.value as AdminRedeemRewardKind }))}
                                        >
                                            <option value="spark">{text.promoCodesRewardTypeSparkOption}</option>
                                            <option value="premium_days" disabled>{text.promoCodesRewardTypePremiumOption}</option>
                                        </select>
                                        <span className={styles.helperText}>{text.promoCodesRewardTypeHint}</span>
                                    </label>

                                    <label className={styles.formField}>
                                        <span className={styles.fieldLabel}>{text.promoCodesRewardValueLabel}</span>
                                        <input className={styles.input} inputMode="numeric" value={form.rewardValue} onChange={(event) => setForm((current) => ({ ...current, rewardValue: event.target.value }))} />
                                    </label>
                                </div>
                            </section>

                            <section className={styles.formSection}>
                                <header className={styles.formSectionHeader}>
                                    <h3 className={styles.formSectionTitle}>{text.promoCodesSectionLimitsTitle}</h3>
                                </header>

                                <div className={styles.formGrid}>
                                    <label className={styles.formField}>
                                        <span className={styles.fieldLabel}>{text.promoCodesLimitLabel}</span>
                                        <input className={styles.input} inputMode="numeric" value={form.maxRedemptions} onChange={(event) => setForm((current) => ({ ...current, maxRedemptions: event.target.value }))} />
                                    </label>
                                    <label className={styles.formField}>
                                        <span className={styles.fieldLabel}>{text.promoCodesPerUserLimitLabel}</span>
                                        <input className={styles.input} inputMode="numeric" value={form.maxRedemptionsPerUser} onChange={(event) => setForm((current) => ({ ...current, maxRedemptionsPerUser: event.target.value }))} />
                                    </label>
                                    <label className={styles.formField}>
                                        <span className={styles.fieldLabel}>{text.promoCodesMinimumPurchasesLabel}</span>
                                        <input className={styles.input} inputMode="numeric" value={form.minimumSuccessfulPurchases} onChange={(event) => setForm((current) => ({ ...current, minimumSuccessfulPurchases: event.target.value }))} />
                                        <span className={styles.helperText}>{text.promoCodesMinimumPurchasesHint}</span>
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
                            </section>

                            <div className={styles.formActions}>
                                <Button variant="secondary" onClick={handleResetPanel} disabled={isMutating}>{text.resetForm}</Button>
                                <Button variant="primary" type="submit" disabled={isMutating}>{panelMode === "edit" ? text.promoCodesSaveUpdateAction : text.promoCodesSaveCreateAction}</Button>
                            </div>
                        </form>
                    </AdminCard>

                    <AdminCard
                        title={text.promoCodesRecentUsageTitle}
                        description={selectedCode ? `${selectedCode.code || `${selectedCode.codePrefix}...`} · ${selectedStatus?.label ?? ""}` : text.promoCodesNoCodeSelectedDescription}
                        className={styles.usageCard}
                    >
                        {!selectedCode ? (
                            <div className={styles.usageEmpty}>
                                <strong>{text.promoCodesNoCodeSelectedTitle}</strong>
                                <span>{text.promoCodesNoCodeSelectedDescription}</span>
                            </div>
                        ) : activationsQuery.isLoading ? (
                            <div className={styles.usageEmpty}>
                                <strong>{text.promoCodesRecentUsageTitle}</strong>
                                <span>{text.promoCodesActivationsLoading}</span>
                            </div>
                        ) : activationsQuery.isError ? (
                            <div className={styles.usageEmpty}>
                                <strong>{text.promoCodesRecentUsageTitle}</strong>
                                <span>{text.promoCodesActivationsError}</span>
                                <Button variant="secondary" size="sm" onClick={() => void activationsQuery.refetch()}>
                                    {text.promoCodesRefreshAction}
                                </Button>
                            </div>
                        ) : !hasAnyRedemptions ? (
                            <div className={styles.usageEmpty}>
                                <strong>{text.promoCodesRecentUsageTitle}</strong>
                                <span>{text.promoCodesRecentUsageEmpty}</span>
                            </div>
                        ) : (
                            <>
                                <div className={styles.usageTableWrap}>
                                    <table className={styles.usageTable}>
                                        <thead>
                                            <tr>
                                                <th>{text.promoCodesActivationUserColumn}</th>
                                                <th>{text.promoCodesActivationDateColumn}</th>
                                                <th>{text.promoCodesActivationRewardColumn}</th>
                                                <th>{text.promoCodesActivationStatusColumn}</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            {visibleRedemptions.map((redemption) => {
                                                const labels = getUserLabels(redemption.userId, selectedUsersById.get(redemption.userId));

                                                return (
                                                    <tr key={redemption.redemptionId}>
                                                        <td>
                                                            <div className={styles.codeCell}>
                                                                <strong>{labels.primary}</strong>
                                                                <span className={styles.codeMeta}>{labels.secondary}</span>
                                                            </div>
                                                        </td>
                                                        <td>{formatDateTime(redemption.redeemedAtUtc, locale)}</td>
                                                        <td>{formatRewardValue(redemption.rewardValue, redemption.rewardKind, text)}</td>
                                                        <td>
                                                            <AdminStatusBadge color="#22c55e">{text.promoCodesActivationStatusSuccess}</AdminStatusBadge>
                                                        </td>
                                                    </tr>
                                                );
                                            })}
                                        </tbody>
                                    </table>
                                </div>

                                <div className={styles.usageActions}>
                                    {!showAllActivations && selectedCode.redeemedCount > ACTIVATIONS_PREVIEW_LIMIT ? (
                                        <Button
                                            variant="secondary"
                                            size="sm"
                                            onClick={() => {
                                                setShowAllActivations(true);
                                                setActivationsPage(1);
                                            }}
                                        >
                                            {text.promoCodesViewAllActivationsAction}
                                        </Button>
                                    ) : null}

                                    {showAllActivations ? (
                                        <>
                                            <Button
                                                variant="secondary"
                                                size="sm"
                                                onClick={() => setActivationsPage((current) => Math.max(1, current - 1))}
                                                disabled={!canGoToPreviousActivationsPage || activationsQuery.isFetching}
                                            >
                                                {text.promoCodesPreviousAction}
                                            </Button>
                                            <Button
                                                variant="secondary"
                                                size="sm"
                                                onClick={() => setActivationsPage((current) => current + 1)}
                                                disabled={!hasMoreRedemptions || activationsQuery.isFetching}
                                            >
                                                {text.promoCodesNextAction}
                                            </Button>
                                        </>
                                    ) : null}

                                    {showAllActivations ? (
                                        <Button
                                            variant="ghost"
                                            size="sm"
                                            onClick={() => {
                                                setShowAllActivations(false);
                                                setActivationsPage(1);
                                            }}
                                        >
                                            {text.promoCodesShowLatestActivationsAction}
                                        </Button>
                                    ) : null}
                                </div>
                            </>
                        )}
                    </AdminCard>
                </div>
            </div>
        </AdminPage>
    );
}
