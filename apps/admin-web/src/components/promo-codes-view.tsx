"use client";

import { useMutation, useQueries, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useDeferredValue, useEffect, useMemo, useState, type FormEvent } from "react";

import {
  CalendarIcon,
  PromoCodeIcon,
  TrendUpIcon,
  UsersIcon,
} from "@/components/admin/admin-icons";
import { useSyncFeedbackToAdminNotifications } from "@/components/admin/admin-notifications";
import { AdminKpiCard, AdminPage, AdminStateCard } from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import { PromoCodeActivationsCard } from "@/components/promo-code-activations-card";
import { PromoCodesActionsMenuPortal } from "@/components/promo-codes-actions-menu-portal";
import { PromoCodesEditorDrawer } from "@/components/promo-codes-editor-drawer";
import { PromoCodesListCard } from "@/components/promo-codes-list-card";
import {
  buildPromoCodesCsv,
  comparePromoCodes,
  copyTextToClipboard,
  createDefaultPromoForm,
  createGeneratedPromoCode,
  formatPromoDisplayText,
  formatNumber,
  formatSevenDayDelta,
  getPromoStatus,
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
import { buildPromoCodesViewOptions } from "@/components/promo-codes-view.options";
import { Button } from "@/components/ui/button";
import { usePromoActionsMenu } from "@/components/use-promo-actions-menu";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
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
import { clientLogger } from "@/lib/client-logger";
import { getDictionary, type Locale } from "@/lib/i18n";

const DEFAULT_PAGE_SIZE = 10;
const PROMO_CODES_AUTO_REFRESH_MS = 15_000;
const EMPTY_PROMO_CODES: AdminRedeemCode[] = [];
const EMPTY_REDEMPTIONS: AdminRedeemCodeRedemption[] = [];
const ACTIVATIONS_PREVIEW_LIMIT = 5;
const ACTIVATIONS_EXPANDED_LIMIT = 20;
const PROMO_ACTIONS_MENU_MIN_WIDTH_PX = 220;

export function PromoCodesView({ locale }: { locale: Locale }) {
  const text = getDictionary(locale);
  const archiveActionLabel = locale === "ru" ? "Архивировать" : "Archive";
  const tokenUnit = "PawSpark";
  const router = useRouter();
  const queryClient = useQueryClient();
  const session = useAuthSession();
  const canManagePromoCodes = session?.user.roles.includes("Admin") ?? false;
  const promoCodesAdminOnlyMessage =
    locale === "ru"
      ? "Управление промокодами доступно только Admin."
      : "Promo code management is available to Admin only.";

  const [search, setSearch] = useState("");
  const deferredSearch = useDeferredValue(search);
  const [statusFilter, setStatusFilter] = useState<PromoStatusFilter>("all");
  const [rewardFilter, setRewardFilter] = useState<"all" | AdminRedeemRewardKind>("all");
  const [sortMode, setSortMode] = useState<PromoSortMode>("updated");
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState<number>(DEFAULT_PAGE_SIZE);
  const [panelMode, setPanelMode] = useState<PromoFormMode>("create");
  const [isEditorOpen, setIsEditorOpen] = useState(false);
  const [selectedCodeId, setSelectedCodeId] = useState<string | null>(null);
  const [form, setForm] = useState<PromoForm>(() => createDefaultPromoForm());
  const [feedback, setFeedback] = useState<PromoFeedback | null>(null);
  const [busyCodeId, setBusyCodeId] = useState<string | null>(null);
  const [showAllActivations, setShowAllActivations] = useState(false);
  const [activationsPage, setActivationsPage] = useState(1);
  const [codePendingArchive, setCodePendingArchive] = useState<AdminRedeemCode | null>(null);
  const [fallbackNowMs] = useState(() => Date.now());
  const { actionsMenuCodeId, actionsMenuPosition, closeActionsMenu, handleToggleActionsMenu } =
    usePromoActionsMenu();
  const hasActivePromoFilters =
    search.trim().length > 0 || statusFilter !== "all" || rewardFilter !== "all";

  useSyncFeedbackToAdminNotifications(feedback, {
    category: "promo",
    source: "promo-codes",
    title: locale === "ru" ? "Промокоды" : "Promo codes",
    href: `/${locale}/promo-codes`,
  });

  useEffect(() => {
    if (!session) {
      ensureAdminSession(locale, router);
    }
  }, [locale, router, session]);

  useEffect(() => {
    if (!feedback) {
      return;
    }

    const timer = window.setTimeout(() => setFeedback(null), 3200);
    return () => window.clearTimeout(timer);
  }, [feedback]);

  useEffect(() => {
    if (!isEditorOpen) {
      return;
    }

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        setIsEditorOpen(false);
      }
    }

    window.addEventListener("keydown", handleKeyDown);

    return () => {
      window.removeEventListener("keydown", handleKeyDown);
    };
  }, [isEditorOpen]);

  const promoCodesQuery = useQuery({
    queryKey: adminQueryKeys.economyRedeemCodes,
    queryFn: ({ signal }) => fetchAdminRedeemCodes(signal),
    staleTime: PROMO_CODES_AUTO_REFRESH_MS,
    refetchInterval:
      hasActivePromoFilters || isEditorOpen ? false : PROMO_CODES_AUTO_REFRESH_MS,
    refetchIntervalInBackground: false,
    refetchOnWindowFocus: false,
  });

  const promoCodes = promoCodesQuery.data ?? EMPTY_PROMO_CODES;
  const nowMs = promoCodesQuery.dataUpdatedAt || fallbackNowMs;
  const selectedCode = useMemo(
    () => promoCodes.find((code) => code.redeemCodeId === selectedCodeId) ?? null,
    [promoCodes, selectedCodeId]
  );

  const activationsTake = showAllActivations
    ? ACTIVATIONS_EXPANDED_LIMIT
    : ACTIVATIONS_PREVIEW_LIMIT;
  const activationsSkip = showAllActivations ? (activationsPage - 1) * activationsTake : 0;

  const activationsQuery = useQuery({
    queryKey: adminQueryKeys.economyRedeemCodeActivations(
      selectedCodeId ?? "none",
      activationsSkip,
      activationsTake
    ),
    queryFn: ({ signal }) =>
      fetchAdminRedeemCodeActivations(selectedCodeId!, {
        skip: activationsSkip,
        take: activationsTake,
      }, signal),
    enabled: Boolean(selectedCodeId),
    staleTime: 20_000,
  });

  const visibleRedemptions = useMemo(
    () => activationsQuery.data?.items ?? EMPTY_REDEMPTIONS,
    [activationsQuery.data?.items]
  );
  const redemptionsForView = activationsQuery.isError ? EMPTY_REDEMPTIONS : visibleRedemptions;
  const hasMoreRedemptions = Boolean(activationsQuery.data?.hasMore);
  const hasAnyRedemptions = (selectedCode?.redeemedCount ?? 0) > 0;
  const canExpandActivations =
    !showAllActivations && (selectedCode?.redeemedCount ?? 0) > ACTIVATIONS_PREVIEW_LIMIT;
  const canGoToPreviousActivationsPage = showAllActivations && activationsPage > 1;
  const canGoToNextActivationsPage = !activationsQuery.isError && hasMoreRedemptions;

  const selectedUserIds = useMemo(
    () => [...new Set(redemptionsForView.map((item) => item.userId))],
    [redemptionsForView]
  );

  const selectedUsersQueries = useQueries({
    queries: selectedUserIds.map((userId) => ({
      queryKey: adminQueryKeys.userDetail(userId),
      queryFn: ({ signal }) => fetchAdminUser(userId, signal),
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
      setIsEditorOpen(true);
      setSelectedCodeId(code.redeemCodeId);
      setShowAllActivations(false);
      setActivationsPage(1);
      setForm(toPromoForm(code));
      await queryClient.invalidateQueries({ queryKey: adminQueryKeys.economyRedeemCodes });
    },
    onError: (error) => {
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(error, text.promoCodesCreateError),
      });
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({
      redeemCodeId,
      payload,
    }: {
      redeemCodeId: string;
      payload: ReturnType<typeof toUpdatePayload>;
    }) => updateAdminRedeemCode(redeemCodeId, payload),
    onSuccess: async (code) => {
      setFeedback({ tone: "success", message: text.promoCodesUpdateSuccess });
      setPanelMode("edit");
      setIsEditorOpen(true);
      setSelectedCodeId(code.redeemCodeId);
      setShowAllActivations(false);
      setActivationsPage(1);
      setForm(toPromoForm(code));
      await queryClient.invalidateQueries({ queryKey: adminQueryKeys.economyRedeemCodes });
    },
    onError: (error) => {
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(error, text.promoCodesUpdateError),
      });
    },
  });

  const statusMutation = useMutation({
    mutationFn: ({
      redeemCodeId,
      payload,
    }: {
      redeemCodeId: string;
      payload: ReturnType<typeof toUpdatePayload>;
      mode?: "toggle" | "restore";
    }) => updateAdminRedeemCode(redeemCodeId, payload),
    onSuccess: async (code, variables) => {
      setFeedback({
        tone: "success",
        message:
          variables.mode === "restore"
            ? text.promoCodesRestoreSuccess
            : variables.payload.isActive
              ? text.promoCodesResumeSuccess
              : text.promoCodesPauseSuccess,
      });
      if (selectedCodeId === code.redeemCodeId) {
        setForm(toPromoForm(code));
      }
      await queryClient.invalidateQueries({ queryKey: adminQueryKeys.economyRedeemCodes });
    },
    onError: (error, variables) => {
      const fallback =
        variables.mode === "restore"
          ? text.promoCodesRestoreError
          : variables.payload.isActive
            ? text.promoCodesResumeError
            : text.promoCodesPauseError;
      setFeedback({ tone: "danger", message: getAdminErrorMessage(error, fallback) });
    },
    onSettled: () => {
      setBusyCodeId(null);
    },
  });

  const archiveMutation = useMutation({
    mutationFn: ({
      redeemCodeId,
      payload,
    }: {
      redeemCodeId: string;
      payload: ReturnType<typeof toUpdatePayload>;
    }) => updateAdminRedeemCode(redeemCodeId, payload),
    onSuccess: async (code) => {
      setFeedback({ tone: "success", message: text.promoCodesArchiveSuccess });
      if (selectedCodeId === code.redeemCodeId) {
        setForm(toPromoForm(code));
      }
      await queryClient.invalidateQueries({ queryKey: adminQueryKeys.economyRedeemCodes });
    },
    onError: (error) => {
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(error, text.promoCodesArchiveError),
      });
    },
    onSettled: () => {
      setBusyCodeId(null);
    },
  });

  const metrics = useMemo(() => {
    const sevenDaysAgo = nowMs - 7 * 24 * 60 * 60 * 1000;
    const totalUses = promoCodes.reduce((sum, code) => sum + code.redeemedCount, 0);
    const totalGranted = promoCodes.reduce(
      (sum, code) =>
        sum + (code.rewardKind === "spark" ? code.rewardValue * code.redeemedCount : 0),
      0
    );
    const activeCodes = promoCodes.filter(
      (code) => getPromoStatus(code, text, nowMs).key === "active"
    ).length;

    const createdLast7d = promoCodes.filter(
      (code) => new Date(code.createdAtUtc).getTime() >= sevenDaysAgo
    ).length;
    const activeTouchedLast7d = promoCodes.filter((code) => {
      const isActive = getPromoStatus(code, text, nowMs).key === "active";
      return isActive && new Date(code.updatedAtUtc).getTime() >= sevenDaysAgo;
    }).length;

    const usesLast7d = promoCodes.reduce((sum, code) => sum + code.usesLast7d, 0);

    const grantedLast7d = promoCodes.reduce((sum, code) => {
      return sum + code.grantedLast7d;
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
        const matchesSearch =
          !normalizedSearch ||
          codeValue.toLowerCase().includes(normalizedSearch) ||
          code.codePrefix.toLowerCase().includes(normalizedSearch) ||
          description.toLowerCase().includes(normalizedSearch);
        const matchesReward = rewardFilter === "all" || code.rewardKind === rewardFilter;

        return matchesStatus && matchesSearch && matchesReward;
      })
      .sort((firstItem, secondItem) => comparePromoCodes(firstItem, secondItem, sortMode));
  }, [deferredSearch, nowMs, promoCodes, rewardFilter, sortMode, statusFilter, text]);

  const totalPages = Math.max(1, Math.ceil(filteredCodes.length / pageSize));
  const currentPage = Math.min(page, totalPages);
  const pagedCodes = filteredCodes.slice((currentPage - 1) * pageSize, currentPage * pageSize);
  const hasCodes = promoCodes.length > 0;
  const hasFilteredCodes = filteredCodes.length > 0;
  const isMutating =
    createMutation.isPending ||
    updateMutation.isPending ||
    statusMutation.isPending ||
    archiveMutation.isPending;

  const shownRangeStart = hasFilteredCodes ? (currentPage - 1) * pageSize + 1 : 0;
  const shownRangeEnd = hasFilteredCodes
    ? Math.min(filteredCodes.length, currentPage * pageSize)
    : 0;

  const visiblePageNumbers = useMemo(() => {
    const maxVisible = 5;
    if (totalPages <= maxVisible) {
      return Array.from({ length: totalPages }, (_, index) => index + 1);
    }

    const half = Math.floor(maxVisible / 2);
    const end = Math.min(totalPages, Math.max(1, currentPage - half) + maxVisible - 1);
    const start = Math.max(1, end - maxVisible + 1);

    return Array.from({ length: end - start + 1 }, (_, index) => start + index);
  }, [currentPage, totalPages]);

  const statusCounts = useMemo(() => {
    const counts: Record<PromoStatusFilter, number> = {
      all: promoCodes.length,
      draft: 0,
      scheduled: 0,
      active: 0,
      paused: 0,
      exhausted: 0,
      expired: 0,
      archived: 0,
    };

    for (const code of promoCodes) {
      const key = getPromoStatus(code, text, nowMs).key;
      counts[key] += 1;
    }

    return counts;
  }, [nowMs, promoCodes, text]);

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

  function assertCanManagePromoCodes(): boolean {
    if (canManagePromoCodes) {
      return true;
    }

    setBusyCodeId(null);
    setCodePendingArchive(null);
    setFeedback({ tone: "danger", message: promoCodesAdminOnlyMessage });
    closeActionsMenu();
    return false;
  }

  function handleOpenCreatePanel() {
    if (!assertCanManagePromoCodes()) {
      return;
    }

    setPanelMode("create");
    setIsEditorOpen(true);
    setSelectedCodeId(null);
    setShowAllActivations(false);
    setActivationsPage(1);
    setForm(createDefaultPromoForm());
    setFeedback(null);
    closeActionsMenu();
  }

  function handleCloseEditor() {
    setIsEditorOpen(false);
    closeActionsMenu();
  }

  function handleOpenEditPanel(code: AdminRedeemCode) {
    if (!assertCanManagePromoCodes()) {
      return;
    }

    setPanelMode("edit");
    setIsEditorOpen(true);
    setSelectedCodeId(code.redeemCodeId);
    setShowAllActivations(false);
    setActivationsPage(1);
    setForm(toPromoForm(code));
    setFeedback(null);
    closeActionsMenu();
  }

  function handleFocusUsage(code: AdminRedeemCode) {
    setSelectedCodeId(code.redeemCodeId);
    setShowAllActivations(false);
    setActivationsPage(1);
    closeActionsMenu();
  }

  function getCurrentLocalDateTimeValue() {
    return new Date(new Date().getTime() - new Date().getTimezoneOffset() * 60_000)
      .toISOString()
      .slice(0, 16);
  }

  async function handleCopyCode(code: string) {
    if (!assertCanManagePromoCodes()) {
      return;
    }

    try {
      await copyTextToClipboard(code);
      setFeedback({ tone: "info", message: text.promoCodesCopied });
    } catch (error) {
      clientLogger.warn("promo.copy_failed", { error });
      setFeedback({ tone: "danger", message: text.promoCodesUpdateError });
    }
    closeActionsMenu();
  }

  function handleGenerateCode() {
    if (!assertCanManagePromoCodes()) {
      return;
    }

    setForm((current) => ({ ...current, code: createGeneratedPromoCode() }));
  }

  function handleExport() {
    if (!assertCanManagePromoCodes()) {
      return;
    }

    if (!filteredCodes.length) {
      return;
    }

    const csv = buildPromoCodesCsv(filteredCodes, locale, text, nowMs);
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `promo-codes-${new Date().toISOString().slice(0, 10)}.csv`;
    link.click();
    URL.revokeObjectURL(url);
    setFeedback({ tone: "info", message: text.promoCodesExported });
  }

  function requestArchiveCode(code: AdminRedeemCode) {
    if (!assertCanManagePromoCodes()) {
      return;
    }

    if (isMutating || busyCodeId === code.redeemCodeId || !code.isActive) {
      return;
    }

    closeActionsMenu();
    setCodePendingArchive(code);
  }

  function handleToggleCodeState(code: AdminRedeemCode) {
    if (!assertCanManagePromoCodes()) {
      return;
    }

    if (isMutating) {
      return;
    }

    try {
      const status = getPromoStatus(code, text, nowMs);
      const nextIsActive = !code.isActive;
      const nextForm = toPromoForm(code);
      const payload = toUpdatePayload(
        {
          ...nextForm,
          isActive: nextIsActive,
          startsAtUtc: nextIsActive && status.key === "archived" ? "" : nextForm.startsAtUtc,
          expiresAtUtc: nextIsActive && status.key === "archived" ? "" : nextForm.expiresAtUtc,
        },
        code,
        text
      );
      setBusyCodeId(code.redeemCodeId);
      closeActionsMenu();
      statusMutation.mutate({ redeemCodeId: code.redeemCodeId, payload, mode: "toggle" });
    } catch (error) {
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(error, text.promoCodesUpdateError),
      });
    }
  }

  async function handleArchive(code: AdminRedeemCode): Promise<boolean> {
    if (!assertCanManagePromoCodes()) {
      return false;
    }

    if (isMutating) {
      return false;
    }

    try {
      const archivedAt = getCurrentLocalDateTimeValue();
      const payload = toUpdatePayload(
        {
          ...toPromoForm(code),
          isActive: false,
          startsAtUtc: archivedAt,
          expiresAtUtc: archivedAt,
        },
        code,
        text
      );
      setBusyCodeId(code.redeemCodeId);
      closeActionsMenu();
      await archiveMutation.mutateAsync({ redeemCodeId: code.redeemCodeId, payload });
      return true;
    } catch (error) {
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(error, text.promoCodesArchiveError),
      });
      return false;
    }
  }

  function handleRestore(code: AdminRedeemCode) {
    if (!assertCanManagePromoCodes()) {
      return;
    }

    if (isMutating) {
      return;
    }

    try {
      const status = getPromoStatus(code, text, nowMs);
      const nextForm = toPromoForm(code);
      const payload = toUpdatePayload(
        {
          ...nextForm,
          isActive: true,
          startsAtUtc: status.key === "archived" ? "" : nextForm.startsAtUtc,
          expiresAtUtc: status.key === "archived" ? "" : nextForm.expiresAtUtc,
        },
        code,
        text
      );
      setBusyCodeId(code.redeemCodeId);
      closeActionsMenu();
      statusMutation.mutate({ redeemCodeId: code.redeemCodeId, payload, mode: "restore" });
    } catch (error) {
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(error, text.promoCodesRestoreError),
      });
    }
  }

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!assertCanManagePromoCodes()) {
      return;
    }

    if (isMutating) {
      return;
    }

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
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(error, text.promoCodesCreateError),
      });
    }
  }

  const {
    statusTabs,
    statusOptions,
    rewardOptions,
    formStatusOptions,
    sortOptions,
    pageSizeOptions,
  } = buildPromoCodesViewOptions(locale, text);

  if (promoCodesQuery.isLoading) {
    return (
      <AdminPage className={styles.page}>
        <AdminStateCard
          tone="info"
          title={text.navPromoCodes}
          description={text.promoCodesLoadingDescription}
        />
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
          action={
            <Button
              variant="secondary"
              disabled={promoCodesQuery.isFetching}
              onClick={() => void promoCodesQuery.refetch().catch(() => undefined)}
            >
              {text.promoCodesRefreshAction}
            </Button>
          }
        />
      </AdminPage>
    );
  }

  const selectedStatus = selectedCode ? getPromoStatus(selectedCode, text, nowMs) : null;
  const actionsMenuCode =
    promoCodes.find((code) => code.redeemCodeId === actionsMenuCodeId) ?? null;
  const actionsMenuStatus = actionsMenuCode ? getPromoStatus(actionsMenuCode, text, nowMs) : null;
  const isActionsMenuArchived = actionsMenuStatus?.key === "archived";
  const isActionsMenuBusy = actionsMenuCode !== null && busyCodeId === actionsMenuCode.redeemCodeId;

  return (
    <AdminPage className={styles.page}>
      {feedback ? (
        <div
          className={`${styles.feedback} ${feedback.tone === "success" ? styles.feedbackSuccess : feedback.tone === "danger" ? styles.feedbackDanger : styles.feedbackInfo}`}
        >
          {feedback.message}
        </div>
      ) : null}

      <header className={styles.pageHeader}>
        <h1 className={styles.pageTitle}>{text.navPromoCodes}</h1>
        <p className={styles.pageSubtitle}>{text.promoCodesHeroDescription}</p>
      </header>

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
        <PromoCodesListCard
          text={text}
          locale={locale}
          nowMs={nowMs}
          search={search}
          statusFilter={statusFilter}
          rewardFilter={rewardFilter}
          sortMode={sortMode}
          statusTabs={statusTabs}
          statusCounts={statusCounts}
          statusOptions={statusOptions}
          rewardOptions={rewardOptions}
          sortOptions={sortOptions}
          pageSizeOptions={pageSizeOptions}
          hasCodes={hasCodes}
          hasFilteredCodes={hasFilteredCodes}
          canManagePromoCodes={canManagePromoCodes}
          promoCodesQueryIsFetching={promoCodesQuery.isFetching}
          autoRefreshMs={PROMO_CODES_AUTO_REFRESH_MS}
          dataUpdatedAt={promoCodesQuery.dataUpdatedAt}
          pagedCodes={pagedCodes}
          filteredCodesCount={filteredCodes.length}
          selectedCodeId={selectedCodeId}
          actionsMenuCodeId={actionsMenuCodeId}
          busyCodeId={busyCodeId}
          currentPage={currentPage}
          totalPages={totalPages}
          visiblePageNumbers={visiblePageNumbers}
          shownRangeStart={shownRangeStart}
          shownRangeEnd={shownRangeEnd}
          pageSize={pageSize}
          onStatusTabChange={(value) => {
            setStatusFilter(value);
            setPage(1);
          }}
          onSearchChange={(value) => {
            setSearch(value);
            setPage(1);
          }}
          onStatusFilterChange={(value) => {
            setStatusFilter(value);
            setPage(1);
          }}
          onRewardFilterChange={(value) => {
            setRewardFilter(value);
            setPage(1);
          }}
          onSortModeChange={(value) => {
            setSortMode(value);
            setPage(1);
          }}
          onPageSizeChange={(value) => {
            setPageSize(value);
            setPage(1);
          }}
          onResetFilters={() => {
            setSearch("");
            setStatusFilter("all");
            setRewardFilter("all");
            setPage(1);
          }}
          onExport={handleExport}
          onRefresh={() => void promoCodesQuery.refetch().catch(() => undefined)}
          onOpenCreatePanel={handleOpenCreatePanel}
          onFocusUsage={handleFocusUsage}
          onToggleActionsMenu={handleToggleActionsMenu}
          onPreviousPage={() => setPage(Math.max(1, currentPage - 1))}
          onNextPage={() => setPage(Math.min(totalPages, currentPage + 1))}
          onSelectPage={setPage}
        />

        <PromoCodeActivationsCard
          text={text}
          locale={locale}
          selectedCode={selectedCode}
          selectedStatusLabel={selectedStatus?.label}
          activationsIsLoading={activationsQuery.isLoading}
          activationsIsError={activationsQuery.isError}
          activationsIsFetching={activationsQuery.isFetching}
          redemptionsForView={redemptionsForView}
          selectedUsersById={selectedUsersById}
          hasAnyRedemptions={hasAnyRedemptions}
          showAllActivations={showAllActivations}
          canExpandActivations={canExpandActivations}
          canGoToPreviousActivationsPage={canGoToPreviousActivationsPage}
          canGoToNextActivationsPage={canGoToNextActivationsPage}
          onRefetchActivations={activationsQuery.refetch}
          onShowAllActivations={() => {
            setShowAllActivations(true);
            setActivationsPage(1);
          }}
          onPreviousActivationsPage={() =>
            setActivationsPage((current) => Math.max(1, current - 1))
          }
          onNextActivationsPage={() => setActivationsPage((current) => current + 1)}
          onShowLatestActivations={() => {
            setShowAllActivations(false);
            setActivationsPage(1);
          }}
        />
      </div>

      <PromoCodesActionsMenuPortal
        actionsMenuCode={actionsMenuCode}
        actionsMenuPosition={actionsMenuPosition}
        text={text}
        minWidthPx={PROMO_ACTIONS_MENU_MIN_WIDTH_PX}
        isActionsMenuArchived={isActionsMenuArchived}
        isActionsMenuBusy={isActionsMenuBusy}
        onViewActivations={handleFocusUsage}
        onRestore={handleRestore}
        onCopyCode={handleCopyCode}
        onEdit={handleOpenEditPanel}
        onToggleState={handleToggleCodeState}
        onArchive={requestArchiveCode}
      />

      <PromoCodesEditorDrawer
        isOpen={isEditorOpen}
        panelMode={panelMode}
        text={text}
        form={form}
        setForm={setForm}
        formStatusOptions={formStatusOptions}
        selectedCode={selectedCode}
        isMutating={isMutating}
        onSubmit={handleSubmit}
        onClose={handleCloseEditor}
        onReset={handleResetPanel}
        onGenerateCode={handleGenerateCode}
        onToggleCodeState={handleToggleCodeState}
      />

      <ConfirmationDialog
        open={codePendingArchive !== null}
        title={archiveActionLabel}
        description={
          codePendingArchive
            ? `${formatPromoDisplayText(
                codePendingArchive.code || `${codePendingArchive.codePrefix}...`,
                80
              )}: ${text.promoCodesArchiveConfirm}`
            : ""
        }
        confirmLabel={archiveActionLabel}
        cancelLabel={locale === "ru" ? "Отмена" : "Cancel"}
        isSubmitting={Boolean(codePendingArchive && busyCodeId === codePendingArchive.redeemCodeId)}
        onCancel={() => {
          if (!isMutating) {
            setCodePendingArchive(null);
          }
        }}
        onConfirm={() => {
          if (!codePendingArchive) {
            return;
          }

          void handleArchive(codePendingArchive).then((succeeded) => {
            if (succeeded) {
              setCodePendingArchive(null);
            }
          });
        }}
      />
    </AdminPage>
  );
}
