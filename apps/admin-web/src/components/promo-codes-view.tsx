"use client";

import { useMutation, useQueries, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useDeferredValue, useEffect, useMemo, useState, type FormEvent } from "react";
import { createPortal } from "react-dom";

import {
  CalendarIcon,
  DownloadIcon,
  MoreHorizontalIcon,
  PromoCodeIcon,
  RefreshIcon,
  TrendUpIcon,
  UsersIcon,
} from "@/components/admin/admin-icons";
import {
  AdminCard,
  AdminFilterBar,
  AdminKpiCard,
  AdminPage,
  AdminStateCard,
  AdminStatusBadge,
  AdminToolbar,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
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

const DEFAULT_PAGE_SIZE = 10;
const PAGE_SIZE_OPTIONS = [6, 10, 20] as const;
const PROMO_CODES_AUTO_REFRESH_MS = 15_000;
const EMPTY_PROMO_CODES: AdminRedeemCode[] = [];
const EMPTY_REDEMPTIONS: AdminRedeemCodeRedemption[] = [];
const ACTIVATIONS_PREVIEW_LIMIT = 5;
const ACTIVATIONS_EXPANDED_LIMIT = 20;
const ACTIONS_MENU_WIDTH_PX = 220;
const ACTIONS_MENU_HEIGHT_ESTIMATE_PX = 236;
const ACTIONS_MENU_GAP_PX = 8;

type ActionsMenuPosition = {
  top: number;
  left: number;
  openUpward: boolean;
};

export function PromoCodesView({ locale }: { locale: Locale }) {
  const text = getDictionary(locale);
  const tokenUnit = "PawSpark";
  const router = useRouter();
  const queryClient = useQueryClient();
  const session = useAuthSession();

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
  const [nowTick, setNowTick] = useState(() => Date.now());
  const [busyCodeId, setBusyCodeId] = useState<string | null>(null);
  const [actionsMenuCodeId, setActionsMenuCodeId] = useState<string | null>(null);
  const [actionsMenuPosition, setActionsMenuPosition] = useState<ActionsMenuPosition | null>(null);
  const [showAllActivations, setShowAllActivations] = useState(false);
  const [activationsPage, setActivationsPage] = useState(1);

  useEffect(() => {
    if (!session) {
      ensureAdminSession(locale, router);
    }
  }, [locale, router, session]);

  useEffect(() => {
    const timerId = window.setInterval(() => {
      setNowTick(Date.now());
    }, 1000);

    return () => {
      window.clearInterval(timerId);
    };
  }, []);

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
      setActionsMenuPosition(null);
    }

    window.addEventListener("pointerdown", handlePointerDown);
    return () => {
      window.removeEventListener("pointerdown", handlePointerDown);
    };
  }, [actionsMenuCodeId]);

  useEffect(() => {
    if (!actionsMenuCodeId) {
      return;
    }

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        closeActionsMenu();
      }
    }

    window.addEventListener("keydown", handleKeyDown);
    return () => {
      window.removeEventListener("keydown", handleKeyDown);
    };
  }, [actionsMenuCodeId]);

  useEffect(() => {
    if (!actionsMenuCodeId) {
      return;
    }

    function handleViewportChange() {
      setActionsMenuCodeId(null);
      setActionsMenuPosition(null);
    }

    window.addEventListener("resize", handleViewportChange);
    window.addEventListener("scroll", handleViewportChange, true);

    return () => {
      window.removeEventListener("resize", handleViewportChange);
      window.removeEventListener("scroll", handleViewportChange, true);
    };
  }, [actionsMenuCodeId]);

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
    queryFn: fetchAdminRedeemCodes,
    refetchInterval: PROMO_CODES_AUTO_REFRESH_MS,
    refetchIntervalInBackground: false,
    refetchOnWindowFocus: true,
  });

  const promoCodes = promoCodesQuery.data ?? EMPTY_PROMO_CODES;
  const nowMs = promoCodesQuery.dataUpdatedAt || 0;
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
    queryFn: () =>
      fetchAdminRedeemCodeActivations(selectedCodeId!, {
        skip: activationsSkip,
        take: activationsTake,
      }),
    enabled: Boolean(selectedCodeId),
    staleTime: 20_000,
  });

  const visibleRedemptions = useMemo(
    () => activationsQuery.data?.items ?? EMPTY_REDEMPTIONS,
    [activationsQuery.data?.items]
  );
  const localRedemptions = useMemo(() => {
    if (!selectedCode) {
      return EMPTY_REDEMPTIONS;
    }

    return [...selectedCode.redemptions].sort(
      (firstItem, secondItem) =>
        new Date(secondItem.redeemedAtUtc).getTime() - new Date(firstItem.redeemedAtUtc).getTime()
    );
  }, [selectedCode]);
  const fallbackRedemptions = useMemo(() => {
    if (!activationsQuery.isError) {
      return EMPTY_REDEMPTIONS;
    }

    return localRedemptions.slice(activationsSkip, activationsSkip + activationsTake);
  }, [activationsQuery.isError, activationsSkip, activationsTake, localRedemptions]);
  const redemptionsForView = activationsQuery.isError ? fallbackRedemptions : visibleRedemptions;
  const hasMoreRedemptions = Boolean(activationsQuery.data?.hasMore);
  const hasAnyRedemptions = (selectedCode?.redeemedCount ?? 0) > 0;
  const canGoToPreviousActivationsPage = showAllActivations && activationsPage > 1;
  const canGoToNextActivationsPage = activationsQuery.isError
    ? localRedemptions.length > activationsSkip + activationsTake
    : hasMoreRedemptions;

  const selectedUserIds = useMemo(
    () => [...new Set(redemptionsForView.map((item) => item.userId))],
    [redemptionsForView]
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
        message: error instanceof Error ? error.message : text.promoCodesCreateError,
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
        message: error instanceof Error ? error.message : text.promoCodesUpdateError,
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
      setFeedback({ tone: "danger", message: error instanceof Error ? error.message : fallback });
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
        message: error instanceof Error ? error.message : text.promoCodesArchiveError,
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

    const usesLast7d = promoCodes.reduce(
      (sum, code) =>
        sum +
        code.redemptions.filter(
          (redemption) => new Date(redemption.redeemedAtUtc).getTime() >= sevenDaysAgo
        ).length,
      0
    );

    const grantedLast7d = promoCodes.reduce((sum, code) => {
      return (
        sum +
        code.redemptions
          .filter(
            (redemption) =>
              new Date(redemption.redeemedAtUtc).getTime() >= sevenDaysAgo &&
              redemption.rewardKind === "spark"
          )
          .reduce((innerSum, redemption) => innerSum + redemption.rewardValue, 0)
      );
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

  const secondsUntilAutoRefresh = useMemo(() => {
    if (!promoCodesQuery.dataUpdatedAt) {
      return Math.ceil(PROMO_CODES_AUTO_REFRESH_MS / 1000);
    }

    const elapsed = Math.max(0, nowTick - promoCodesQuery.dataUpdatedAt);
    const remaining = PROMO_CODES_AUTO_REFRESH_MS - (elapsed % PROMO_CODES_AUTO_REFRESH_MS);
    return Math.max(1, Math.ceil(remaining / 1000));
  }, [nowTick, promoCodesQuery.dataUpdatedAt]);

  useEffect(() => {
    setPage((current) => Math.min(current, totalPages));
  }, [totalPages]);

  const visiblePageNumbers = useMemo(() => {
    const maxVisible = 5;
    if (totalPages <= maxVisible) {
      return Array.from({ length: totalPages }, (_, index) => index + 1);
    }

    const half = Math.floor(maxVisible / 2);
    let start = Math.max(1, currentPage - half);
    let end = Math.min(totalPages, start + maxVisible - 1);
    start = Math.max(1, end - maxVisible + 1);

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

  function handleOpenCreatePanel() {
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

  function closeActionsMenu() {
    setActionsMenuCodeId(null);
    setActionsMenuPosition(null);
  }

  function getCurrentLocalDateTimeValue() {
    return new Date(new Date().getTime() - new Date().getTimezoneOffset() * 60_000)
      .toISOString()
      .slice(0, 16);
  }

  function getActionsMenuPosition(trigger: HTMLElement): ActionsMenuPosition {
    const rect = trigger.getBoundingClientRect();
    const openUpward = window.innerHeight - rect.bottom < ACTIONS_MENU_HEIGHT_ESTIMATE_PX;
    const maxLeft = Math.max(
      ACTIONS_MENU_GAP_PX,
      window.innerWidth - ACTIONS_MENU_WIDTH_PX - ACTIONS_MENU_GAP_PX
    );

    return {
      top: openUpward ? rect.top - ACTIONS_MENU_GAP_PX : rect.bottom + ACTIONS_MENU_GAP_PX,
      left: Math.min(Math.max(ACTIONS_MENU_GAP_PX, rect.right - ACTIONS_MENU_WIDTH_PX), maxLeft),
      openUpward,
    };
  }

  function handleToggleActionsMenu(code: AdminRedeemCode, trigger: HTMLElement) {
    if (actionsMenuCodeId === code.redeemCodeId) {
      closeActionsMenu();
      return;
    }

    setActionsMenuCodeId(code.redeemCodeId);
    setActionsMenuPosition(getActionsMenuPosition(trigger));
  }

  async function handleCopyCode(code: string) {
    try {
      await copyTextToClipboard(code);
      setFeedback({ tone: "info", message: text.promoCodesCopied });
    } catch {
      setFeedback({ tone: "danger", message: text.promoCodesUpdateError });
    }
    closeActionsMenu();
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
        message: error instanceof Error ? error.message : text.promoCodesUpdateError,
      });
    }
  }

  function handleArchive(code: AdminRedeemCode) {
    if (!window.confirm(text.promoCodesArchiveConfirm)) {
      return;
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
      archiveMutation.mutate({ redeemCodeId: code.redeemCodeId, payload });
    } catch (error) {
      setFeedback({
        tone: "danger",
        message: error instanceof Error ? error.message : text.promoCodesArchiveError,
      });
    }
  }

  function handleRestore(code: AdminRedeemCode) {
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
        message: error instanceof Error ? error.message : text.promoCodesRestoreError,
      });
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
      setFeedback({
        tone: "danger",
        message: error instanceof Error ? error.message : text.promoCodesCreateError,
      });
    }
  }

  const statusOptions: SelectOption[] = [
    { value: "all", label: text.promoCodesStatusAll, tone: "neutral" },
    { value: "draft", label: text.promoCodesStatusDraft, tone: "neutral" },
    { value: "active", label: text.promoCodesStatusActiveOption, tone: "recommended" },
    { value: "scheduled", label: text.promoCodesStatusScheduled, tone: "fast" },
    { value: "paused", label: text.promoCodesStatusPaused, tone: "premium" },
    { value: "exhausted", label: text.promoCodesStatusLimitReached, tone: "premium" },
    { value: "expired", label: text.promoCodesStatusExpired, tone: "neutral" },
    { value: "archived", label: text.promoCodesStatusArchived, tone: "neutral" },
  ];

  const statusTabs: Array<{ value: PromoStatusFilter; label: string }> = [
    { value: "all", label: locale === "ru" ? "Все" : "All" },
    { value: "active", label: locale === "ru" ? "Активные" : "Active" },
    { value: "draft", label: locale === "ru" ? "Черновики" : "Drafts" },
    { value: "paused", label: locale === "ru" ? "Приостановленные" : "Paused" },
    { value: "expired", label: locale === "ru" ? "Истекшие" : "Expired" },
    { value: "archived", label: locale === "ru" ? "Архивные" : "Archived" },
  ];

  const rewardOptions: SelectOption[] = [
    { value: "all", label: locale === "ru" ? "Все награды" : "All rewards", tone: "neutral" },
    { value: "spark", label: text.promoCodesRewardTypeSparkOption, tone: "recommended" },
    { value: "premium_days", label: text.promoCodesRewardTypePremiumOption, tone: "premium" },
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

  const pageSizeOptions: SelectOption[] = PAGE_SIZE_OPTIONS.map((option) => ({
    value: option.toString(),
    label: locale === "ru" ? `${option} на странице` : `${option} per page`,
    tone: "neutral",
  }));

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
            <Button variant="secondary" onClick={() => void promoCodesQuery.refetch()}>
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
        <AdminCard className={styles.tableCard}>
          <AdminToolbar className={styles.tableTopBar}>
            <div
              className={styles.statusTabs}
              role="tablist"
              aria-label={text.promoCodesStatusFilterLabel}
            >
              {statusTabs.map((tab, index) => {
                const isActiveTab = statusFilter === tab.value;

                return (
                  <button
                    key={tab.value}
                    type="button"
                    role="tab"
                    aria-selected={isActiveTab}
                    className={`${styles.statusTab}${isActiveTab ? ` ${styles.statusTabActive}` : ""}`}
                    onClick={() => {
                      setStatusFilter(tab.value);
                      setPage(1);
                    }}
                    onKeyDown={(event) => {
                      if (
                        event.key !== "ArrowLeft" &&
                        event.key !== "ArrowRight" &&
                        event.key !== "Home" &&
                        event.key !== "End"
                      ) {
                        return;
                      }

                      event.preventDefault();

                      let nextIndex = index;
                      if (event.key === "ArrowRight") {
                        nextIndex = (index + 1) % statusTabs.length;
                      } else if (event.key === "ArrowLeft") {
                        nextIndex = (index - 1 + statusTabs.length) % statusTabs.length;
                      } else if (event.key === "Home") {
                        nextIndex = 0;
                      } else if (event.key === "End") {
                        nextIndex = statusTabs.length - 1;
                      }

                      setStatusFilter(statusTabs[nextIndex].value);
                      setPage(1);
                    }}
                  >
                    <span>{tab.label}</span>
                    <span className={styles.statusTabCount}>
                      {formatNumber(statusCounts[tab.value], locale)}
                    </span>
                  </button>
                );
              })}
            </div>

            <div className={styles.toolbarActions}>
              <Button variant="secondary" onClick={handleExport} disabled={!hasFilteredCodes}>
                <DownloadIcon className={styles.actionIcon} /> {text.promoCodesExportAction}
              </Button>
              <Button
                variant="secondary"
                onClick={() => void promoCodesQuery.refetch()}
                disabled={promoCodesQuery.isFetching}
              >
                <RefreshIcon className={styles.actionIcon} /> {text.promoCodesRefreshAction}
              </Button>
              <Button variant="primary" onClick={handleOpenCreatePanel}>
                {text.promoCodesCreateAction}
              </Button>
              <span
                className={`${styles.autoRefreshBadge}${promoCodesQuery.isFetching ? ` ${styles.autoRefreshBadgeLoading}` : ""}`}
                aria-live="polite"
              >
                <span className={styles.autoRefreshDot} />
                {promoCodesQuery.isFetching
                  ? text.promoCodesUpdatingLabel
                  : locale === "ru"
                    ? `Автообновление: ${secondsUntilAutoRefresh}с`
                    : `Auto refresh: ${secondsUntilAutoRefresh}s`}
              </span>
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
              <span className={styles.fieldLabel}>{text.promoCodesRewardTypeLabel}</span>
              <Select
                value={rewardFilter}
                options={rewardOptions}
                onChange={(value) => {
                  setRewardFilter(value as "all" | AdminRedeemRewardKind);
                  setPage(1);
                }}
                ariaLabel={text.promoCodesRewardTypeLabel}
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
            <AdminStateCard
              tone="info"
              title={text.navPromoCodes}
              description={text.promoCodesEmptyDescription}
            />
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
                    setRewardFilter("all");
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
                      <th>{text.promoCodesPerUserLimitLabel}</th>
                      <th>{text.promoCodesWindowLabel}</th>
                      <th>{text.statusLabel}</th>
                      <th>{text.createdAtLabel}</th>
                      <th>{text.actionsLabel}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {pagedCodes.map((code) => {
                      const status = getPromoStatus(code, text, nowMs);
                      const isSelected = selectedCodeId === code.redeemCodeId;
                      const codeValue = code.code || `${code.codePrefix}...`;
                      const actionBusy = busyCodeId === code.redeemCodeId;
                      const campaignMeta = formatCampaignMeta(code);
                      const usagePercent = Math.min(
                        100,
                        Math.round((code.redeemedCount / Math.max(1, code.maxRedemptions)) * 100)
                      );
                      const usageToneClass =
                        usagePercent >= 80
                          ? styles.usageToneCritical
                          : usagePercent >= 45
                            ? styles.usageToneMedium
                            : styles.usageToneGood;

                      return (
                        <tr
                          key={code.redeemCodeId}
                          className={`${styles.tableRow}${isSelected ? ` ${styles.rowSelected}` : ""}`}
                          onClick={() => handleFocusUsage(code)}
                          onKeyDown={(event) => {
                            if (event.key === "Enter" || event.key === " ") {
                              event.preventDefault();
                              handleFocusUsage(code);
                            }
                          }}
                          tabIndex={0}
                          aria-selected={isSelected}
                        >
                          <td>
                            <div className={styles.codeCell}>
                              <strong className={styles.codeValue}>{codeValue}</strong>
                              <span className={styles.codeMeta}>
                                {code.description.trim() || "-"}
                              </span>
                              {campaignMeta ? (
                                <span className={styles.codeMeta}>{campaignMeta}</span>
                              ) : null}
                              <span className={styles.codeMeta}>
                                {text.promoCodesUpdatedLabel}:{" "}
                                {formatDateTime(code.updatedAtUtc, locale)}
                              </span>
                            </div>
                          </td>
                          <td>
                            <div className={styles.rewardCell}>
                              <AdminStatusBadge
                                color={code.rewardKind === "spark" ? "#22c55e" : "#60a5fa"}
                              >
                                {formatRewardValue(code.rewardValue, code.rewardKind, text)}
                              </AdminStatusBadge>
                              <span className={styles.descriptionMeta}>
                                {getRewardKindLabel(code.rewardKind, text)}
                              </span>
                            </div>
                          </td>
                          <td>
                            <div className={styles.usageCell}>
                              <div className={styles.usageTopRow}>
                                <strong>
                                  {formatNumber(code.redeemedCount, locale)} /{" "}
                                  {formatNumber(code.maxRedemptions, locale)}
                                </strong>
                                <span className={`${styles.usagePercent} ${usageToneClass}`}>
                                  {usagePercent}%
                                </span>
                              </div>
                              <div className={`${styles.usageMeter} ${usageToneClass}`}>
                                <span style={{ width: `${usagePercent}%` }} />
                              </div>
                            </div>
                          </td>
                          <td>
                            <span className={styles.inlineNumeric}>
                              {formatNumber(code.maxRedemptionsPerUser, locale)}
                            </span>
                          </td>
                          <td className={styles.windowCell}>{formatWindow(code, locale, text)}</td>
                          <td>
                            <AdminStatusBadge color={status.color}>{status.label}</AdminStatusBadge>
                          </td>
                          <td>
                            <div className={styles.createdCell}>
                              <strong>{formatDateTime(code.createdAtUtc, locale)}</strong>
                              <span>{code.createdBy?.trim() || "-"}</span>
                            </div>
                          </td>
                          <td>
                            <div
                              className={styles.actionsMenu}
                              data-promo-actions-root
                              onClick={(event) => event.stopPropagation()}
                            >
                              <Button
                                variant="ghost"
                                size="sm"
                                className={styles.actionMenuTrigger}
                                aria-label={text.promoCodesActionsMenuLabel}
                                aria-haspopup="menu"
                                aria-expanded={actionsMenuCodeId === code.redeemCodeId}
                                onClick={(event) =>
                                  handleToggleActionsMenu(code, event.currentTarget)
                                }
                                disabled={actionBusy}
                              >
                                <MoreHorizontalIcon className={styles.inlineIcon} />
                              </Button>
                            </div>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>

              <div className={styles.pagination}>
                <span className={styles.paginationInfo}>
                  {locale === "ru"
                    ? `Показано ${formatNumber(shownRangeStart, locale)}-${formatNumber(shownRangeEnd, locale)} из ${formatNumber(filteredCodes.length, locale)}`
                    : `Showing ${formatNumber(shownRangeStart, locale)}-${formatNumber(shownRangeEnd, locale)} of ${formatNumber(filteredCodes.length, locale)}`}
                </span>
                <div className={styles.paginationCenter}>
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={() => setPage((current) => Math.max(1, current - 1))}
                    disabled={currentPage <= 1}
                    aria-label={text.promoCodesPreviousAction}
                  >
                    {"<"}
                  </Button>

                  <div className={styles.paginationActions}>
                    {visiblePageNumbers.map((pageNumber) => (
                      <Button
                        key={pageNumber}
                        variant={pageNumber === currentPage ? "primary" : "secondary"}
                        size="sm"
                        className={styles.paginationNumber}
                        onClick={() => setPage(pageNumber)}
                      >
                        {formatNumber(pageNumber, locale)}
                      </Button>
                    ))}
                  </div>

                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={() => setPage((current) => Math.min(totalPages, current + 1))}
                    disabled={currentPage >= totalPages}
                    aria-label={text.promoCodesNextAction}
                  >
                    {">"}
                  </Button>
                </div>

                <div className={styles.pageSizeControl}>
                  <Select
                    value={pageSize.toString()}
                    options={pageSizeOptions}
                    onChange={(value) => {
                      setPageSize(Number(value));
                      setPage(1);
                    }}
                    ariaLabel={locale === "ru" ? "Размер страницы" : "Page size"}
                    showSelectedDescription={false}
                  />
                </div>
              </div>
            </>
          )}
        </AdminCard>

        <AdminCard
          title={text.promoCodesRecentUsageTitle}
          description={
            selectedCode
              ? `${selectedCode.code || `${selectedCode.codePrefix}...`} · ${selectedStatus?.label ?? ""}`
              : text.promoCodesNoCodeSelectedDescription
          }
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
          ) : !hasAnyRedemptions ? (
            <div className={styles.usageEmpty}>
              <strong>{text.promoCodesRecentUsageTitle}</strong>
              <span>{text.promoCodesRecentUsageEmpty}</span>
            </div>
          ) : (
            <>
              {activationsQuery.isError ? (
                <div className={styles.usageWarning}>
                  <span>{text.promoCodesActivationsError}</span>
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={() => void activationsQuery.refetch()}
                  >
                    {text.promoCodesRefreshAction}
                  </Button>
                </div>
              ) : null}

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
                    {redemptionsForView.map((redemption) => {
                      const labels = getUserLabels(
                        redemption.userId,
                        selectedUsersById.get(redemption.userId)
                      );

                      return (
                        <tr key={redemption.redemptionId}>
                          <td>
                            <div className={styles.codeCell}>
                              <strong>{labels.primary}</strong>
                              <span className={styles.codeMeta}>{labels.secondary}</span>
                            </div>
                          </td>
                          <td>{formatDateTime(redemption.redeemedAtUtc, locale)}</td>
                          <td>
                            {formatRewardValue(redemption.rewardValue, redemption.rewardKind, text)}
                          </td>
                          <td>
                            <AdminStatusBadge color="#22c55e">
                              {text.promoCodesActivationStatusSuccess}
                            </AdminStatusBadge>
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
                      disabled={!canGoToNextActivationsPage || activationsQuery.isFetching}
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

      {actionsMenuCode && actionsMenuPosition && typeof window !== "undefined"
        ? createPortal(
            <div
              className={styles.actionsMenuPortal}
              style={{
                top: actionsMenuPosition.top,
                left: actionsMenuPosition.left,
                minWidth: ACTIONS_MENU_WIDTH_PX,
                transform: actionsMenuPosition.openUpward ? "translateY(-100%)" : undefined,
              }}
              role="menu"
              aria-label={text.promoCodesActionsMenuLabel}
              data-promo-actions-root
            >
              <div className={`${styles.actionsMenuList} ${styles.actionsMenuListPortal}`}>
                {isActionsMenuArchived ? (
                  <>
                    <button
                      type="button"
                      className={styles.actionsMenuItem}
                      onClick={() => handleFocusUsage(actionsMenuCode)}
                    >
                      {text.promoCodesViewActivationsAction}
                    </button>
                    <button
                      type="button"
                      className={styles.actionsMenuItem}
                      onClick={() => handleRestore(actionsMenuCode)}
                      disabled={isActionsMenuBusy}
                    >
                      {text.promoCodesRestoreAction}
                    </button>
                  </>
                ) : (
                  <>
                    <button
                      type="button"
                      className={styles.actionsMenuItem}
                      onClick={() =>
                        void handleCopyCode(
                          actionsMenuCode.code || `${actionsMenuCode.codePrefix}...`
                        )
                      }
                    >
                      {text.promoCodesCopyAction}
                    </button>
                    <button
                      type="button"
                      className={styles.actionsMenuItem}
                      onClick={() => handleOpenEditPanel(actionsMenuCode)}
                    >
                      {text.editTemplate}
                    </button>
                    <button
                      type="button"
                      className={styles.actionsMenuItem}
                      onClick={() => handleFocusUsage(actionsMenuCode)}
                    >
                      {text.promoCodesViewActivationsAction}
                    </button>
                    <button
                      type="button"
                      className={styles.actionsMenuItem}
                      onClick={() => handleToggleCodeState(actionsMenuCode)}
                      disabled={isActionsMenuBusy}
                    >
                      {actionsMenuCode.isActive
                        ? text.promoCodesPauseAction
                        : text.promoCodesResumeAction}
                    </button>
                    <button
                      type="button"
                      className={`${styles.actionsMenuItem} ${styles.actionsMenuItemDanger}`}
                      onClick={() => handleArchive(actionsMenuCode)}
                      disabled={!actionsMenuCode.isActive || isActionsMenuBusy}
                    >
                      {text.archive}
                    </button>
                  </>
                )}
              </div>
            </div>,
            document.body
          )
        : null}

      {isEditorOpen ? (
        <div className={styles.drawerBackdrop} onClick={handleCloseEditor}>
          <aside
            className={styles.editorDrawer}
            role="dialog"
            aria-modal="true"
            aria-label={
              panelMode === "edit"
                ? text.promoCodesEditPanelTitle
                : panelMode === "duplicate"
                  ? text.promoCodesDuplicatePanelTitle
                  : text.promoCodesCreatePanelTitle
            }
            onClick={(event) => event.stopPropagation()}
          >
            <AdminCard
              title={
                panelMode === "edit"
                  ? text.promoCodesEditPanelTitle
                  : panelMode === "duplicate"
                    ? text.promoCodesDuplicatePanelTitle
                    : text.promoCodesCreatePanelTitle
              }
              description={text.promoCodesFormCardDescription}
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
                        onChange={(event) =>
                          setForm((current) => ({
                            ...current,
                            code: event.target.value.toUpperCase(),
                          }))
                        }
                        readOnly={panelMode === "edit"}
                      />
                      <Button
                        type="button"
                        variant="secondary"
                        size="sm"
                        onClick={handleGenerateCode}
                        disabled={panelMode === "edit"}
                      >
                        {text.promoCodesGenerateCodeAction}
                      </Button>
                    </div>
                    <span className={styles.helperText}>{text.promoCodesCodeHelp}</span>
                  </label>

                  <label className={styles.formField}>
                    <span className={styles.fieldLabel}>{text.promoCodesDescriptionLabel}</span>
                    <input
                      className={styles.input}
                      value={form.description}
                      onChange={(event) =>
                        setForm((current) => ({ ...current, description: event.target.value }))
                      }
                    />
                  </label>

                  <label className={styles.formField}>
                    <span className={styles.fieldLabel}>{text.promoCodesStatusFieldLabel}</span>
                    <Select
                      value={form.isActive ? "active" : "paused"}
                      options={formStatusOptions}
                      onChange={(value) =>
                        setForm((current) => ({ ...current, isActive: value === "active" }))
                      }
                      ariaLabel={text.promoCodesStatusFieldLabel}
                      showSelectedDescription={false}
                    />
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
                        onChange={(event) =>
                          setForm((current) => ({
                            ...current,
                            rewardKind: event.target.value as AdminRedeemRewardKind,
                          }))
                        }
                      >
                        <option value="spark">{text.promoCodesRewardTypeSparkOption}</option>
                        <option value="premium_days" disabled>
                          {text.promoCodesRewardTypePremiumOption}
                        </option>
                      </select>
                      <span className={styles.helperText}>{text.promoCodesRewardTypeHint}</span>
                    </label>

                    <label className={styles.formField}>
                      <span className={styles.fieldLabel}>{text.promoCodesRewardValueLabel}</span>
                      <input
                        className={styles.input}
                        inputMode="numeric"
                        value={form.rewardValue}
                        onChange={(event) =>
                          setForm((current) => ({ ...current, rewardValue: event.target.value }))
                        }
                      />
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
                      <input
                        className={styles.input}
                        inputMode="numeric"
                        value={form.maxRedemptions}
                        onChange={(event) =>
                          setForm((current) => ({ ...current, maxRedemptions: event.target.value }))
                        }
                      />
                    </label>
                    <label className={styles.formField}>
                      <span className={styles.fieldLabel}>{text.promoCodesPerUserLimitLabel}</span>
                      <input
                        className={styles.input}
                        inputMode="numeric"
                        value={form.maxRedemptionsPerUser}
                        onChange={(event) =>
                          setForm((current) => ({
                            ...current,
                            maxRedemptionsPerUser: event.target.value,
                          }))
                        }
                      />
                    </label>
                  </div>
                </section>

                <section className={styles.formSection}>
                  <header className={styles.formSectionHeader}>
                    <h3 className={styles.formSectionTitle}>{text.promoCodesWindowLabel}</h3>
                  </header>

                  <div className={styles.formGrid}>
                    <label className={styles.formField}>
                      <span className={styles.fieldLabel}>{text.promoCodesStartsLabel}</span>
                      <div className={styles.optionalDateControl}>
                        <input
                          className={styles.input}
                          type="datetime-local"
                          value={form.startsAtUtc}
                          onChange={(event) =>
                            setForm((current) => ({ ...current, startsAtUtc: event.target.value }))
                          }
                        />
                        {form.startsAtUtc ? (
                          <Button
                            type="button"
                            variant="ghost"
                            size="sm"
                            onClick={() => setForm((current) => ({ ...current, startsAtUtc: "" }))}
                          >
                            {text.resetForm}
                          </Button>
                        ) : null}
                      </div>
                      <span className={styles.helperText}>{text.promoCodesDatesOptionalHint}</span>
                    </label>
                    <label className={styles.formField}>
                      <span className={styles.fieldLabel}>{text.promoCodesExpiresLabel}</span>
                      <div className={styles.optionalDateControl}>
                        <input
                          className={styles.input}
                          type="datetime-local"
                          value={form.expiresAtUtc}
                          onChange={(event) =>
                            setForm((current) => ({ ...current, expiresAtUtc: event.target.value }))
                          }
                        />
                        <Button
                          type="button"
                          variant="ghost"
                          size="sm"
                          onClick={() =>
                            setForm((current) => ({
                              ...current,
                              expiresAtUtc: current.expiresAtUtc
                                ? ""
                                : new Date(
                                    new Date().getTime() - new Date().getTimezoneOffset() * 60_000
                                  )
                                    .toISOString()
                                    .slice(0, 16),
                            }))
                          }
                        >
                          {form.expiresAtUtc
                            ? text.promoCodesNoExpiryAction
                            : text.promoCodesPickDateAction}
                        </Button>
                      </div>
                      <span className={styles.helperText}>{text.promoCodesDatesOptionalHint}</span>
                    </label>
                  </div>
                </section>

                <section className={styles.formSection}>
                  <header className={styles.formSectionHeader}>
                    <h3 className={styles.formSectionTitle}>
                      {text.promoCodesSectionCampaignTitle}
                    </h3>
                  </header>

                  <div className={styles.formGrid}>
                    <label className={styles.formField}>
                      <span className={styles.fieldLabel}>
                        {text.promoCodesMinimumPurchasesLabel}
                      </span>
                      <input
                        className={styles.input}
                        inputMode="numeric"
                        value={form.minimumSuccessfulPurchases}
                        onChange={(event) =>
                          setForm((current) => ({
                            ...current,
                            minimumSuccessfulPurchases: event.target.value,
                          }))
                        }
                      />
                      <span className={styles.helperText}>
                        {text.promoCodesMinimumPurchasesHint}
                      </span>
                    </label>
                    <label className={styles.formField}>
                      <span className={styles.fieldLabel}>{text.promoCodesCampaignNameLabel}</span>
                      <input
                        className={styles.input}
                        value={form.campaignName}
                        onChange={(event) =>
                          setForm((current) => ({ ...current, campaignName: event.target.value }))
                        }
                      />
                    </label>
                    <label className={styles.formField}>
                      <span className={styles.fieldLabel}>
                        {text.promoCodesCampaignChannelLabel}
                      </span>
                      <input
                        className={styles.input}
                        value={form.campaignChannel}
                        onChange={(event) =>
                          setForm((current) => ({
                            ...current,
                            campaignChannel: event.target.value,
                          }))
                        }
                      />
                    </label>
                  </div>
                </section>

                <div className={styles.formActionsSticky}>
                  {panelMode === "edit" && selectedCode ? (
                    <Button
                      type="button"
                      variant="ghost"
                      className={styles.deactivateButton}
                      disabled={isMutating}
                      onClick={() => handleToggleCodeState(selectedCode)}
                    >
                      {selectedCode.isActive ? text.deactivate : text.activate}
                    </Button>
                  ) : (
                    <span />
                  )}

                  <div className={styles.formActions}>
                    <Button
                      type="button"
                      variant="secondary"
                      onClick={handleCloseEditor}
                      disabled={isMutating}
                    >
                      {text.editorCancel}
                    </Button>
                    <Button
                      type="button"
                      variant="secondary"
                      onClick={handleResetPanel}
                      disabled={isMutating}
                    >
                      {text.resetForm}
                    </Button>
                    <Button variant="primary" type="submit" disabled={isMutating}>
                      {panelMode === "edit"
                        ? text.promoCodesSaveUpdateAction
                        : text.promoCodesSaveCreateAction}
                    </Button>
                  </div>
                </div>
              </form>
            </AdminCard>
          </aside>
        </div>
      ) : null}
    </AdminPage>
  );
}
