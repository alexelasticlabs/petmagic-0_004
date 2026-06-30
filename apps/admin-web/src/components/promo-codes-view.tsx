"use client";

import {
  keepPreviousData,
  useMutation,
  useQueries,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState, type FormEvent } from "react";

import { useSyncFeedbackToAdminNotifications } from "@/components/admin/admin-notifications";
import { AdminPage } from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { PromoCodeActivationsCard } from "@/components/promo-code-activations-card";
import { PromoCodesActionsMenuPortal } from "@/components/promo-codes-actions-menu-portal";
import {
  PromoCodesArchiveDialog,
  PromoCodesErrorState,
  PromoCodesLoadingState,
  PromoCodesViewChrome,
} from "@/components/promo-codes-view.chrome";
import { PromoCodesEditorDrawer } from "@/components/promo-codes-editor-drawer";
import { PromoCodesListCard } from "@/components/promo-codes-list-card";
import { getPromoCodesViewText } from "@/components/promo-codes-view.content";
import {
  buildPromoCodesCsv,
  copyTextToClipboard,
  createDefaultPromoForm,
  createGeneratedPromoCode,
  formatNumber,
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
  fetchAdminRedeemCodeMetrics,
  fetchAdminRedeemCodes,
  fetchAdminUser,
  normalizeAdminRedeemCodesQuery,
  updateAdminRedeemCode,
  useAuthSession,
  type AdminRedeemCode,
  type AdminRedeemCodeRedemption,
  type AdminRedeemRewardKind,
  type AdminUserDetail,
} from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { getDictionary, type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

const DEFAULT_PAGE_SIZE = 10;
const PROMO_CODES_AUTO_REFRESH_MS = 15_000;
const EMPTY_PROMO_CODES: AdminRedeemCode[] = [];
const EMPTY_REDEMPTIONS: AdminRedeemCodeRedemption[] = [];
const ACTIVATIONS_PREVIEW_LIMIT = 5;
const ACTIVATIONS_EXPANDED_LIMIT = 20;
const PROMO_ACTIONS_MENU_MIN_WIDTH_PX = 220;
const PROMO_CODES_SEARCH_MAX_LENGTH = 120;

function useDebouncedValue(value: string, delayMs: number) {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    const timeoutId = window.setTimeout(() => setDebounced(value), delayMs);
    return () => window.clearTimeout(timeoutId);
  }, [delayMs, value]);

  return debounced;
}

function getPromoClientErrorDetails(error: unknown) {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorDigest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

export function PromoCodesView({ locale }: { locale: Locale }) {
  const text = useMemo(() => getDictionary(locale), [locale]);
  const promoText = useMemo(() => getPromoCodesViewText(locale), [locale]);
  const archiveActionLabel = promoText.archiveActionLabel;
  const tokenUnit = "PawSpark";
  const router = useRouter();
  const queryClient = useQueryClient();
  const session = useAuthSession();
  const sessionRoles = session?.user.roles ?? [];
  const canManagePromoCodes = sessionRoles.includes("Admin");
  const promoCodesAdminOnlyMessage = promoText.adminOnlyMessage;

  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState<PromoStatusFilter>("all");
  const [rewardFilter, setRewardFilter] = useState<"all" | AdminRedeemRewardKind>("all");
  const [sortMode, setSortMode] = useState<PromoSortMode>("updated");
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState<number>(DEFAULT_PAGE_SIZE);
  const [panelMode, setPanelMode] = useState<PromoFormMode>("create");
  const [isEditorOpen, setIsEditorOpen] = useState(false);
  const [selectedCodeId, setSelectedCodeId] = useState<string | null>(null);
  const [selectedCodeSnapshot, setSelectedCodeSnapshot] = useState<AdminRedeemCode | null>(null);
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
  const debouncedSearch = useDebouncedValue(search, 350);

  useSyncFeedbackToAdminNotifications(feedback, {
    category: "promo",
    source: "promo-codes",
    title: promoText.notificationTitle,
    href: `/${locale}/promo-codes`,
  });

  useEffect(() => {
    ensureAdminSession(locale, router, { requiredRole: "Admin" });
  }, [locale, router, session]);

  useEffect(() => {
    if (!feedback) {
      return;
    }

    const timer = window.setTimeout(() => setFeedback(null), 3200);
    return () => window.clearTimeout(timer);
  }, [feedback]);

  const promoCodesQueryParams = useMemo(
    () =>
      normalizeAdminRedeemCodesQuery({
        skip: (page - 1) * pageSize,
        take: pageSize,
        search: debouncedSearch,
        status: statusFilter === "all" ? undefined : statusFilter,
        rewardKind: rewardFilter === "all" ? undefined : rewardFilter,
        sort: sortMode,
      }),
    [debouncedSearch, page, pageSize, rewardFilter, sortMode, statusFilter]
  );

  const promoCodeMetricsQueryParams = useMemo(
    () =>
      normalizeAdminRedeemCodesQuery({
        search: debouncedSearch,
        status: statusFilter === "all" ? undefined : statusFilter,
        rewardKind: rewardFilter === "all" ? undefined : rewardFilter,
      }),
    [debouncedSearch, rewardFilter, statusFilter]
  );

  const promoCodesQuery = useQuery({
    queryKey: adminQueryKeys.economyRedeemCodes(promoCodesQueryParams),
    queryFn: ({ signal }) => fetchAdminRedeemCodes(promoCodesQueryParams, signal),
    enabled: canManagePromoCodes,
    placeholderData: keepPreviousData,
    staleTime: PROMO_CODES_AUTO_REFRESH_MS,
    refetchInterval:
      !canManagePromoCodes || hasActivePromoFilters || isEditorOpen
        ? false
        : PROMO_CODES_AUTO_REFRESH_MS,
    refetchIntervalInBackground: false,
    refetchOnWindowFocus: false,
  });

  const promoMetricsQuery = useQuery({
    queryKey: adminQueryKeys.economyRedeemCodeMetrics(promoCodeMetricsQueryParams),
    queryFn: ({ signal }) => fetchAdminRedeemCodeMetrics(promoCodeMetricsQueryParams, signal),
    enabled: canManagePromoCodes,
    placeholderData: keepPreviousData,
    staleTime: PROMO_CODES_AUTO_REFRESH_MS,
    refetchInterval:
      !canManagePromoCodes || hasActivePromoFilters || isEditorOpen
        ? false
        : PROMO_CODES_AUTO_REFRESH_MS,
    refetchIntervalInBackground: false,
    refetchOnWindowFocus: false,
  });

  const promoCodesPage = promoCodesQuery.isPlaceholderData ? undefined : promoCodesQuery.data;
  const promoCodes = promoCodesPage?.items ?? EMPTY_PROMO_CODES;
  const nowMs = promoCodesQuery.dataUpdatedAt || fallbackNowMs;
  const selectedCode = useMemo(
    () =>
      promoCodes.find((code) => code.redeemCodeId === selectedCodeId) ??
      (selectedCodeSnapshot?.redeemCodeId === selectedCodeId ? selectedCodeSnapshot : null),
    [promoCodes, selectedCodeId, selectedCodeSnapshot]
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
      fetchAdminRedeemCodeActivations(
        selectedCodeId!,
        {
          skip: activationsSkip,
          take: activationsTake,
        },
        signal
      ),
    enabled: canManagePromoCodes && Boolean(selectedCodeId),
    placeholderData: keepPreviousData,
    staleTime: 20_000,
  });

  const activationsPageData = activationsQuery.isPlaceholderData
    ? undefined
    : activationsQuery.data;
  const visibleRedemptions = useMemo(
    () => activationsPageData?.items ?? EMPTY_REDEMPTIONS,
    [activationsPageData?.items]
  );
  const redemptionsForView = activationsQuery.isError ? EMPTY_REDEMPTIONS : visibleRedemptions;
  const hasMoreRedemptions = Boolean(activationsPageData?.hasMore);
  const isActivationsRefreshing = activationsQuery.isFetching && activationsQuery.isPlaceholderData;
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
      enabled: canManagePromoCodes,
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
      setSelectedCodeSnapshot(code);
      setShowAllActivations(false);
      setActivationsPage(1);
      setForm(toPromoForm(code));
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.economyRedeemCodesRoot }),
      ]);
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
      setSelectedCodeSnapshot(code);
      setShowAllActivations(false);
      setActivationsPage(1);
      setForm(toPromoForm(code));
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.economyRedeemCodesRoot }),
      ]);
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
        setSelectedCodeSnapshot(code);
        setForm(toPromoForm(code));
      }
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.economyRedeemCodesRoot }),
      ]);
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
        setSelectedCodeSnapshot(code);
        setForm(toPromoForm(code));
      }
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.economyRedeemCodesRoot }),
      ]);
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

  const metrics = promoMetricsQuery.data ?? {
    totalCodes: 0,
    activeCodes: 0,
    totalUses: 0,
    totalGranted: 0,
    createdLast7d: 0,
    activeTouchedLast7d: 0,
    usesLast7d: 0,
    grantedLast7d: 0,
  };

  const currentPage = page;
  const promoCodesTotalCount = Math.max(0, promoCodesPage?.totalCount ?? 0);
  const totalPages = Math.max(1, Math.ceil(promoCodesTotalCount / pageSize));
  const pagedCodes = promoCodes;
  const hasCodes = promoCodes.length > 0 || page > 1 || hasActivePromoFilters;
  const hasFilteredCodes = promoCodes.length > 0;
  const isMutating =
    createMutation.isPending ||
    updateMutation.isPending ||
    statusMutation.isPending ||
    archiveMutation.isPending;
  const isPromoCodesRefreshing = promoCodesQuery.isFetching && promoCodesQuery.isPlaceholderData;
  const isPromoRefreshFetching = promoCodesQuery.isFetching || promoMetricsQuery.isFetching;
  const visiblePromoCodeIds = useMemo(
    () => new Set(promoCodes.map((code) => code.redeemCodeId)),
    [promoCodes]
  );

  useEffect(() => {
    if (!isEditorOpen) {
      return;
    }

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key !== "Escape") {
        return;
      }

      if (isMutating) {
        event.preventDefault();
        return;
      }

      setIsEditorOpen(false);
    }

    window.addEventListener("keydown", handleKeyDown);

    return () => {
      window.removeEventListener("keydown", handleKeyDown);
    };
  }, [isEditorOpen, isMutating]);

  useEffect(() => {
    if (!promoCodesPage || isPromoCodesRefreshing || isMutating) {
      return;
    }

    const shouldCloseActionsMenu =
      actionsMenuCodeId !== null && !visiblePromoCodeIds.has(actionsMenuCodeId);
    const shouldCloseArchiveConfirmation =
      codePendingArchive !== null && !visiblePromoCodeIds.has(codePendingArchive.redeemCodeId);

    if (!shouldCloseActionsMenu && !shouldCloseArchiveConfirmation) {
      return;
    }

    queueMicrotask(() => {
      if (shouldCloseActionsMenu) {
        closeActionsMenu();
      }

      if (shouldCloseArchiveConfirmation) {
        setCodePendingArchive(null);
      }
    });
  }, [
    actionsMenuCodeId,
    closeActionsMenu,
    codePendingArchive,
    isMutating,
    isPromoCodesRefreshing,
    promoCodesPage,
    visiblePromoCodeIds,
  ]);

  function requestRefreshPromoCodes() {
    if (!canManagePromoCodes || isPromoRefreshFetching) {
      return;
    }

    void Promise.allSettled([promoCodesQuery.refetch(), promoMetricsQuery.refetch()]);
  }

  function requestRefreshPromoMetrics() {
    if (!canManagePromoCodes || isPromoRefreshFetching) {
      return;
    }

    void promoMetricsQuery.refetch().catch(() => undefined);
  }

  function resetSelectedPromoCode(nextPage = 1) {
    setSelectedCodeId(null);
    setSelectedCodeSnapshot(null);
    setShowAllActivations(false);
    setActivationsPage(1);
    setPage(nextPage);
    closeActionsMenu();
  }

  const shownRangeStart = hasFilteredCodes ? (currentPage - 1) * pageSize + 1 : 0;
  const shownRangeEnd = hasFilteredCodes ? shownRangeStart + promoCodes.length - 1 : 0;

  const visiblePageNumbers = useMemo(() => {
    const maxVisible = 5;
    const end = Math.min(totalPages, Math.max(1, currentPage));
    const start = Math.max(1, end - maxVisible + 1);

    return Array.from({ length: end - start + 1 }, (_, index) => start + index);
  }, [currentPage, totalPages]);

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

    if (isMutating) {
      return;
    }

    setPanelMode("create");
    setIsEditorOpen(true);
    setSelectedCodeId(null);
    setSelectedCodeSnapshot(null);
    setShowAllActivations(false);
    setActivationsPage(1);
    setForm(createDefaultPromoForm());
    setFeedback(null);
    closeActionsMenu();
  }

  function handleCloseEditor() {
    if (isMutating) {
      return;
    }

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
    setSelectedCodeSnapshot(code);
    setShowAllActivations(false);
    setActivationsPage(1);
    setForm(toPromoForm(code));
    setFeedback(null);
    closeActionsMenu();
  }

  function handleFocusUsage(code: AdminRedeemCode) {
    setSelectedCodeId(code.redeemCodeId);
    setSelectedCodeSnapshot(code);
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
      clientLogger.warn("promo.copy_failed", getPromoClientErrorDetails(error));
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

    if (!promoCodes.length) {
      return;
    }

    const csv = buildPromoCodesCsv(promoCodes, locale, text, nowMs);
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `promo-codes-${new Date().toISOString().slice(0, 10)}.csv`;
    document.body.append(link);
    link.click();
    link.remove();
    window.setTimeout(() => URL.revokeObjectURL(url), 1000);
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

  if (!canManagePromoCodes || promoCodesQuery.isLoading) {
    return (
      <PromoCodesLoadingState
        title={text.navPromoCodes}
        description={text.promoCodesLoadingDescription}
      />
    );
  }

  if (promoCodesQuery.isError) {
    return (
      <PromoCodesErrorState
        title={text.navPromoCodes}
        description={getAdminErrorMessage(promoCodesQuery.error, text.promoCodesErrorDescription)}
        refreshLabel={text.promoCodesRefreshAction}
        disabled={!canManagePromoCodes || isPromoRefreshFetching}
        onRefresh={requestRefreshPromoCodes}
      />
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
      <PromoCodesViewChrome
        feedback={feedback}
        locale={locale}
        metrics={metrics}
        promoText={promoText}
        title={text.navPromoCodes}
        subtitle={text.promoCodesHeroDescription}
        tokenUnit={tokenUnit}
        metricsError={promoMetricsQuery.isError ? promoMetricsQuery.error : null}
        canManagePromoCodes={canManagePromoCodes}
        isPromoRefreshFetching={isPromoRefreshFetching}
        refreshLabel={text.promoCodesRefreshAction}
        metricsErrorTitle={text.promoCodesMetricsErrorDescription}
        lastSevenDaysLabel={text.promoCodesLast7DaysLabel}
        onRefreshMetrics={requestRefreshPromoMetrics}
      />

      <div className={styles.workspace}>
        <PromoCodesListCard
          text={text}
          promoText={promoText}
          locale={locale}
          nowMs={nowMs}
          search={search}
          statusFilter={statusFilter}
          rewardFilter={rewardFilter}
          sortMode={sortMode}
          statusTabs={statusTabs}
          statusOptions={statusOptions}
          rewardOptions={rewardOptions}
          sortOptions={sortOptions}
          pageSizeOptions={pageSizeOptions}
          hasCodes={hasCodes}
          hasFilteredCodes={hasFilteredCodes}
          canManagePromoCodes={canManagePromoCodes}
          promoCodesActionLocked={isMutating}
          promoCodesQueryIsFetching={isPromoRefreshFetching}
          promoCodesQueryIsRefreshing={isPromoCodesRefreshing}
          autoRefreshMs={PROMO_CODES_AUTO_REFRESH_MS}
          dataUpdatedAt={promoCodesQuery.dataUpdatedAt}
          pagedCodes={pagedCodes}
          selectedCodeId={selectedCodeId}
          actionsMenuCodeId={actionsMenuCodeId}
          busyCodeId={busyCodeId}
          currentPage={currentPage}
          totalPages={totalPages}
          totalCount={promoCodesTotalCount}
          visiblePageNumbers={visiblePageNumbers}
          shownRangeStart={shownRangeStart}
          shownRangeEnd={shownRangeEnd}
          pageSize={pageSize}
          onStatusTabChange={(value) => {
            setStatusFilter(value);
            resetSelectedPromoCode();
          }}
          onSearchChange={(value) => {
            setSearch(value.slice(0, PROMO_CODES_SEARCH_MAX_LENGTH));
            resetSelectedPromoCode();
          }}
          onStatusFilterChange={(value) => {
            setStatusFilter(value);
            resetSelectedPromoCode();
          }}
          onRewardFilterChange={(value) => {
            setRewardFilter(value);
            resetSelectedPromoCode();
          }}
          onSortModeChange={(value) => {
            setSortMode(value);
            resetSelectedPromoCode();
          }}
          onPageSizeChange={(value) => {
            setPageSize(value);
            resetSelectedPromoCode();
          }}
          onResetFilters={() => {
            setSearch("");
            setStatusFilter("all");
            setRewardFilter("all");
            resetSelectedPromoCode();
          }}
          onExport={handleExport}
          onRefresh={requestRefreshPromoCodes}
          onOpenCreatePanel={handleOpenCreatePanel}
          onFocusUsage={handleFocusUsage}
          onToggleActionsMenu={handleToggleActionsMenu}
          onPreviousPage={() => resetSelectedPromoCode(Math.max(1, currentPage - 1))}
          onNextPage={() => resetSelectedPromoCode(Math.min(totalPages, currentPage + 1))}
          onSelectPage={resetSelectedPromoCode}
        />

        <PromoCodeActivationsCard
          text={text}
          locale={locale}
          selectedCode={selectedCode}
          selectedStatusLabel={selectedStatus?.label}
          activationsIsLoading={activationsQuery.isLoading || isActivationsRefreshing}
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

      <PromoCodesArchiveDialog
        archiveActionLabel={archiveActionLabel}
        cancelLabel={promoText.archiveCancelLabel}
        archiveConfirmText={text.promoCodesArchiveConfirm}
        codePendingArchive={codePendingArchive}
        busyCodeId={busyCodeId}
        isMutating={isMutating}
        onCancel={() => setCodePendingArchive(null)}
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
