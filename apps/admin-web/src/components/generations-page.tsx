"use client";

import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useEffect, useMemo, useState } from "react";

import { CaretDownIcon } from "@/components/admin/admin-icons";
import {
  AdminDataSurface,
  AdminFilterToolbar,
  AdminMetricStrip,
  AdminStateCard,
  AdminSummaryChips,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import { useAdminUrlStateSyncGuard } from "@/components/admin/use-admin-url-state-sync-guard";
import { GenerationCapacityPanel } from "@/components/generation-capacity-panel";
import styles from "@/components/generations-page.module.css";
import { createAdminCorrelationId } from "@/lib/admin-correlation-id";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  cancelAdminTemplateGeneration,
  fetchAdminTemplateGenerationDetail,
  fetchAdminTemplateGenerationMetrics,
  fetchAdminTemplateGenerations,
  GENERATION_PROVIDER_FILTER_MAX_LENGTH,
  GENERATION_REFUND_RETRY_REASON_MAX_LENGTH,
  GENERATION_SEARCH_FILTER_MAX_LENGTH,
  GENERATION_USER_FILTER_MAX_LENGTH,
  GAMIFICATION_LEGACY_DELIVERY_REASON_MAX_LENGTH,
  grantAdminGenerationCleanDownload,
  normalizeAdminTemplateGenerationsQuery,
  retryAdminTemplateGeneration,
  retryAdminTemplateGenerationRefund,
  resolveAdminLegacyGamificationDelivery,
  useAuthSession,
  type AdminGenerationRefundState,
} from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import { type Locale } from "@/lib/i18n";

import { getGenerationsPageText } from "./generations-page.content";
import {
  formatMetricCount,
  formatShortId,
  formatStatus,
  GenerationRow,
  statusOptions,
  type StatusFilter,
} from "./generations-page.row";

type GenerationsPageProps = {
  locale: Locale;
};

const PAGE_SIZE = 25;
type RefundStateFilter = AdminGenerationRefundState | "all";
const refundStateOptions: readonly RefundStateFilter[] = [
  "all",
  "pending",
  "exhausted",
  "refunded",
  "not_applicable",
];

function readGenerationStatus(value: string | null): StatusFilter {
  return statusOptions.includes(value as StatusFilter) ? (value as StatusFilter) : "All";
}

function readGenerationPageIndex(value: string | null): number {
  const parsed = Number.parseInt(value ?? "", 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed - 1 : 0;
}

function readGenerationRefundState(value: string | null): RefundStateFilter {
  return refundStateOptions.includes(value as RefundStateFilter)
    ? (value as RefundStateFilter)
    : "all";
}

function getAdminApiErrorCode(error: unknown): string | undefined {
  if (!error || typeof error !== "object" || !("code" in error)) return undefined;
  return typeof error.code === "string" ? error.code : undefined;
}

function useDebouncedValue(value: string, delayMs: number) {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    const timeoutId = window.setTimeout(() => setDebounced(value), delayMs);
    return () => window.clearTimeout(timeoutId);
  }, [delayMs, value]);

  return debounced;
}

export function GenerationsPage({ locale }: GenerationsPageProps) {
  const text = getGenerationsPageText(locale);
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const queryClient = useQueryClient();
  const session = useAuthSession();
  const canViewGenerations = session?.user.roles.includes("Admin") ?? false;
  const [pageIndex, setPageIndex] = useState(() =>
    readGenerationPageIndex(searchParams.get("page"))
  );
  const [status, setStatus] = useState<StatusFilter>(() =>
    readGenerationStatus(searchParams.get("status"))
  );
  const [refundState, setRefundState] = useState<RefundStateFilter>(() =>
    readGenerationRefundState(searchParams.get("refundState"))
  );
  const [provider, setProvider] = useState(() =>
    (searchParams.get("provider") ?? "").trim().slice(0, GENERATION_PROVIDER_FILTER_MAX_LENGTH)
  );
  const [user, setUser] = useState(() =>
    (searchParams.get("user") ?? "").trim().slice(0, GENERATION_USER_FILTER_MAX_LENGTH)
  );
  const [search, setSearch] = useState(() =>
    (searchParams.get("search") ?? "").trim().slice(0, GENERATION_SEARCH_FILTER_MAX_LENGTH)
  );
  const [expandedGenerationId, setExpandedGenerationId] = useState<string | null>(() =>
    searchParams.get("selected")
  );
  const [grantCleanError, setGrantCleanError] = useState<string | null>(null);
  const [cancelGenerationError, setCancelGenerationError] = useState<string | null>(null);
  const [pendingCancelGenerationId, setPendingCancelGenerationId] = useState<string | null>(null);
  const [retryGenerationError, setRetryGenerationError] = useState<string | null>(null);
  const [pendingRetryGenerationId, setPendingRetryGenerationId] = useState<string | null>(null);
  const [refundRecoveryError, setRefundRecoveryError] = useState<string | null>(null);
  const [refundRecoveryReason, setRefundRecoveryReason] = useState("");
  const [pendingRefundRecovery, setPendingRefundRecovery] = useState<{
    generationId: string;
    idempotencyKey: string;
  } | null>(null);
  const [legacyGamificationError, setLegacyGamificationError] = useState<string | null>(null);
  const [pendingLegacyGamificationResolution, setPendingLegacyGamificationResolution] = useState<{
    generationId: string;
    action: "mark_delivered" | "replay";
  } | null>(null);
  const [legacyGamificationReason, setLegacyGamificationReason] = useState("");

  const debouncedProvider = useDebouncedValue(provider, 350);
  const debouncedUser = useDebouncedValue(user, 350);
  const debouncedSearch = useDebouncedValue(search, 350);
  const currentSearchParams = searchParams.toString();
  const { consumeUrlStateApplication, markUrlStateWritten } = useAdminUrlStateSyncGuard({
    currentSearch: currentSearchParams,
    applyUrlState: (nextSearchParams) => {
      setPageIndex(readGenerationPageIndex(nextSearchParams.get("page")));
      setStatus(readGenerationStatus(nextSearchParams.get("status")));
      setRefundState(readGenerationRefundState(nextSearchParams.get("refundState")));
      setProvider(
        (nextSearchParams.get("provider") ?? "")
          .trim()
          .slice(0, GENERATION_PROVIDER_FILTER_MAX_LENGTH)
      );
      setUser(
        (nextSearchParams.get("user") ?? "").trim().slice(0, GENERATION_USER_FILTER_MAX_LENGTH)
      );
      setSearch(
        (nextSearchParams.get("search") ?? "").trim().slice(0, GENERATION_SEARCH_FILTER_MAX_LENGTH)
      );
      setExpandedGenerationId(nextSearchParams.get("selected"));
    },
  });
  const generationUrlStatus = readGenerationStatus(searchParams.get("status"));
  const generationUrlRefundState = readGenerationRefundState(searchParams.get("refundState"));
  const generationUrlPageIndex = readGenerationPageIndex(searchParams.get("page"));
  const generationUrlProvider = (searchParams.get("provider") ?? "")
    .trim()
    .slice(0, GENERATION_PROVIDER_FILTER_MAX_LENGTH);
  const generationUrlUser = (searchParams.get("user") ?? "")
    .trim()
    .slice(0, GENERATION_USER_FILTER_MAX_LENGTH);
  const generationUrlSearch = (searchParams.get("search") ?? "")
    .trim()
    .slice(0, GENERATION_SEARCH_FILTER_MAX_LENGTH);
  const generationUrlSelection = searchParams.get("selected");
  const isGenerationUrlStatePending =
    status !== generationUrlStatus ||
    refundState !== generationUrlRefundState ||
    pageIndex !== generationUrlPageIndex ||
    provider.trim() !== generationUrlProvider ||
    user.trim() !== generationUrlUser ||
    search.trim() !== generationUrlSearch ||
    debouncedProvider !== generationUrlProvider ||
    debouncedUser !== generationUrlUser ||
    debouncedSearch !== generationUrlSearch ||
    expandedGenerationId !== generationUrlSelection;

  useEffect(() => {
    ensureAdminSession(locale, router, { requiredRole: "Admin" });
  }, [locale, router, session]);

  useEffect(() => {
    if (consumeUrlStateApplication(isGenerationUrlStatePending)) {
      return;
    }

    const next = new URLSearchParams(searchParams.toString());
    const setOptional = (key: string, value: string, defaultValue = "") => {
      if (!value || value === defaultValue) next.delete(key);
      else next.set(key, value);
    };

    setOptional("status", status, "All");
    setOptional("refundState", refundState, "all");
    setOptional("provider", debouncedProvider);
    setOptional("user", debouncedUser);
    setOptional("search", debouncedSearch);
    setOptional("page", pageIndex > 0 ? String(pageIndex + 1) : "");
    setOptional("selected", expandedGenerationId ?? "");

    const nextSearch = next.toString();
    if (nextSearch !== searchParams.toString()) {
      markUrlStateWritten(nextSearch);
      router.replace(nextSearch ? `${pathname}?${nextSearch}` : pathname, { scroll: false });
    }
  }, [
    debouncedProvider,
    debouncedSearch,
    debouncedUser,
    expandedGenerationId,
    consumeUrlStateApplication,
    markUrlStateWritten,
    isGenerationUrlStatePending,
    pageIndex,
    pathname,
    router,
    searchParams,
    refundState,
    status,
  ]);

  const query = useMemo(
    () =>
      normalizeAdminTemplateGenerationsQuery({
        status,
        refundState,
        provider: debouncedProvider,
        user: debouncedUser,
        search: debouncedSearch,
        skip: pageIndex * PAGE_SIZE,
        take: PAGE_SIZE,
      }),
    [debouncedProvider, debouncedSearch, debouncedUser, pageIndex, refundState, status]
  );
  const generationsQuery = useQuery({
    queryKey: adminQueryKeys.templateGenerations(query),
    queryFn: ({ signal }) => fetchAdminTemplateGenerations(query, signal),
    enabled: canViewGenerations,
    placeholderData: keepPreviousData,
    refetchInterval: (queryState) =>
      queryState.state.data?.items.some((item) => item.status === "Cancelling") ? 2_000 : false,
  });
  const generationMetricsQuery = useQuery({
    queryKey: adminQueryKeys.templateGenerationMetrics,
    queryFn: ({ signal }) => fetchAdminTemplateGenerationMetrics(signal),
    enabled: canViewGenerations,
    placeholderData: keepPreviousData,
    staleTime: 30_000,
  });
  const generationDetailQuery = useQuery({
    queryKey: adminQueryKeys.templateGenerationDetail(expandedGenerationId ?? ""),
    queryFn: ({ signal }) => fetchAdminTemplateGenerationDetail(expandedGenerationId ?? "", signal),
    enabled: canViewGenerations && Boolean(expandedGenerationId),
    refetchInterval: (queryState) => {
      const detailStatus = queryState.state.data?.generation.status;
      return detailStatus && ["Pending", "Running", "Retrying", "Cancelling"].includes(detailStatus)
        ? 2_000
        : false;
    },
  });

  const visiblePage = generationsQuery.isPlaceholderData ? undefined : generationsQuery.data;
  const visibleItems = useMemo(() => visiblePage?.items ?? [], [visiblePage]);
  const visibleTotalCount = visiblePage?.totalCount ?? 0;
  const visiblePageCount = Math.max(1, Math.ceil(visibleTotalCount / PAGE_SIZE));
  const visibleGenerationIds = useMemo(
    () => new Set(visibleItems.map((item) => item.generationId)),
    [visibleItems]
  );
  const isGenerationsRefreshing = generationsQuery.isFetching && generationsQuery.isPlaceholderData;
  const areGenerationFiltersLocked = generationsQuery.isFetching;
  const generationMetrics = generationMetricsQuery.data ?? null;
  const grantCleanMutation = useMutation({
    mutationFn: grantAdminGenerationCleanDownload,
    onMutate: () => {
      setGrantCleanError(null);
    },
    onSuccess: async (_result, generationId) => {
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateGenerations(query) }),
        queryClient.invalidateQueries({
          queryKey: adminQueryKeys.templateGenerationDetail(generationId),
        }),
      ]);
    },
    onError: (error) => {
      setGrantCleanError(getAdminErrorMessage(error, text.grantCleanError));
    },
  });
  const grantingGenerationId = grantCleanMutation.variables ?? null;
  const isGrantCleanLocked = grantCleanMutation.isPending || generationsQuery.isFetching;
  const cancelGenerationMutation = useMutation({
    mutationFn: cancelAdminTemplateGeneration,
    onMutate: () => {
      setCancelGenerationError(null);
    },
    onSuccess: async (_result, generationId) => {
      setPendingCancelGenerationId(null);
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateGenerations(query) }),
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateGenerationMetrics }),
        queryClient.invalidateQueries({
          queryKey: adminQueryKeys.templateGenerationDetail(generationId),
        }),
      ]);
    },
    onError: (error) => {
      setPendingCancelGenerationId(null);
      setCancelGenerationError(getAdminErrorMessage(error, text.cancelGenerationError));
    },
  });
  const cancellingGenerationId = cancelGenerationMutation.variables ?? null;
  const isCancelGenerationLocked =
    cancelGenerationMutation.isPending || generationsQuery.isFetching;
  const pendingCancelGenerationDescription = pendingCancelGenerationId
    ? text.cancelGenerationConfirmDescription(formatShortId(pendingCancelGenerationId))
    : text.cancelGenerationConfirmDescription("");
  const retryGenerationMutation = useMutation({
    mutationFn: retryAdminTemplateGeneration,
    onMutate: () => {
      setRetryGenerationError(null);
    },
    onSuccess: async (_result, generationId) => {
      setPendingRetryGenerationId(null);
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateGenerations(query) }),
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateGenerationMetrics }),
        queryClient.invalidateQueries({
          queryKey: adminQueryKeys.templateGenerationDetail(generationId),
        }),
      ]);
    },
    onError: (error) => {
      setPendingRetryGenerationId(null);
      setRetryGenerationError(getAdminErrorMessage(error, text.retryGenerationError));
    },
  });
  const retryingGenerationId = retryGenerationMutation.variables ?? null;
  const isRetryGenerationLocked = retryGenerationMutation.isPending || generationsQuery.isFetching;
  const pendingRetryGenerationDescription = pendingRetryGenerationId
    ? text.retryGenerationConfirmDescription(formatShortId(pendingRetryGenerationId))
    : text.retryGenerationConfirmDescription("");
  const refundRecoveryMutation = useMutation({
    mutationFn: retryAdminTemplateGenerationRefund,
    onMutate: () => setRefundRecoveryError(null),
    onSuccess: async (_result, variables) => {
      setPendingRefundRecovery(null);
      setRefundRecoveryReason("");
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateGenerations(query) }),
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateGenerationMetrics }),
        queryClient.invalidateQueries({ queryKey: ["admin", "dashboard"] }),
        queryClient.invalidateQueries({
          queryKey: adminQueryKeys.templateGenerationDetail(variables.generationId),
        }),
      ]);
    },
    onError: (error) => {
      setRefundRecoveryError(
        getAdminApiErrorCode(error) === "templates.generation_refund_retry_idempotency_conflict"
          ? text.retryRefundConflict
          : getAdminErrorMessage(error, text.retryRefundError)
      );
    },
  });
  const retryingRefundGenerationId = refundRecoveryMutation.variables?.generationId ?? null;
  const isRefundRecoveryLocked = refundRecoveryMutation.isPending || generationsQuery.isFetching;
  const pendingRefundRecoveryDescription = pendingRefundRecovery
    ? text.retryRefundConfirmDescription(formatShortId(pendingRefundRecovery.generationId))
    : text.retryRefundConfirmDescription("");
  const legacyGamificationResolutionMutation = useMutation({
    mutationFn: ({
      generationId,
      action,
      reason,
    }: {
      generationId: string;
      action: "mark_delivered" | "replay";
      reason: string;
    }) => resolveAdminLegacyGamificationDelivery(generationId, { action, reason }),
    onMutate: () => {
      setLegacyGamificationError(null);
    },
    onSuccess: async (_result, variables) => {
      setPendingLegacyGamificationResolution(null);
      setLegacyGamificationReason("");
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateGenerations(query) }),
        queryClient.invalidateQueries({
          queryKey: adminQueryKeys.templateGenerationDetail(variables.generationId),
        }),
      ]);
    },
    onError: (error) => {
      setLegacyGamificationError(getAdminErrorMessage(error, text.gamificationLegacyReviewError));
    },
  });
  const isLegacyGamificationResolutionLocked =
    legacyGamificationResolutionMutation.isPending || generationsQuery.isFetching;
  const pendingLegacyGamificationDescription = pendingLegacyGamificationResolution
    ? text.gamificationLegacyReviewDescription(
        formatShortId(pendingLegacyGamificationResolution.generationId)
      )
    : text.gamificationLegacyReviewDescription("");

  useEffect(() => {
    let isActive = true;
    if (!expandedGenerationId || visibleGenerationIds.has(expandedGenerationId)) {
      return;
    }

    queueMicrotask(() => {
      if (isActive) {
        setExpandedGenerationId(null);
      }
    });

    return () => {
      isActive = false;
    };
  }, [expandedGenerationId, visibleGenerationIds]);

  function resetGenerationListContext(nextPageIndex = 0) {
    setExpandedGenerationId(null);
    setPageIndex(nextPageIndex);
  }

  function requestGenerationMetricsRetry() {
    if (!canViewGenerations || generationMetricsQuery.isFetching) {
      return;
    }

    void generationMetricsQuery.refetch().catch(() => undefined);
  }

  function requestGenerationsRetry() {
    if (!canViewGenerations || generationsQuery.isFetching) {
      return;
    }

    void generationsQuery.refetch().catch(() => undefined);
  }

  function requestGrantClean(generationId: string) {
    if (!canViewGenerations || isGrantCleanLocked) {
      return;
    }

    grantCleanMutation.mutate(generationId);
  }

  function requestCancelGeneration(generationId: string) {
    if (!canViewGenerations || isCancelGenerationLocked) {
      return;
    }

    setCancelGenerationError(null);
    setPendingCancelGenerationId(generationId);
  }

  function confirmCancelGeneration() {
    if (!canViewGenerations || !pendingCancelGenerationId || isCancelGenerationLocked) {
      return;
    }

    cancelGenerationMutation.mutate(pendingCancelGenerationId);
  }

  function requestRetryGeneration(generationId: string) {
    if (!canViewGenerations || isRetryGenerationLocked) {
      return;
    }

    setRetryGenerationError(null);
    setPendingRetryGenerationId(generationId);
  }

  function confirmRetryGeneration() {
    if (!canViewGenerations || !pendingRetryGenerationId || isRetryGenerationLocked) {
      return;
    }

    retryGenerationMutation.mutate(pendingRetryGenerationId);
  }

  function requestRefundRecovery(generationId: string) {
    if (!canViewGenerations || isRefundRecoveryLocked) return;

    try {
      setRefundRecoveryError(null);
      setRefundRecoveryReason("");
      setPendingRefundRecovery({
        generationId,
        idempotencyKey: `generation-refund:${createAdminCorrelationId()}`,
      });
    } catch (error) {
      setRefundRecoveryError(getAdminErrorMessage(error, text.retryRefundError));
    }
  }

  function confirmRefundRecovery() {
    const reason = refundRecoveryReason.trim();
    if (!canViewGenerations || !pendingRefundRecovery || !reason || isRefundRecoveryLocked) {
      return;
    }

    refundRecoveryMutation.mutate({
      ...pendingRefundRecovery,
      reason,
    });
  }

  function requestLegacyGamificationResolution(generationId: string) {
    if (!canViewGenerations || isLegacyGamificationResolutionLocked) {
      return;
    }

    setLegacyGamificationError(null);
    setLegacyGamificationReason("");
    setPendingLegacyGamificationResolution({ generationId, action: "mark_delivered" });
  }

  function confirmLegacyGamificationResolution() {
    const reason = legacyGamificationReason.trim();
    if (
      !canViewGenerations ||
      !pendingLegacyGamificationResolution ||
      !reason ||
      isLegacyGamificationResolutionLocked
    ) {
      return;
    }

    legacyGamificationResolutionMutation.mutate({
      ...pendingLegacyGamificationResolution,
      reason,
    });
  }

  if (!canViewGenerations) {
    return (
      <section className={styles.page} data-admin-route="generations">
        <AdminStateCard tone="info" title={text.loadingTitle} />
      </section>
    );
  }

  return (
    <>
      <section className={styles.page} data-admin-route="generations">
        <GenerationCapacityPanel locale={locale} enabled={canViewGenerations} />

        <AdminMetricStrip
          items={[
            { label: text.total, value: formatMetricCount(generationMetrics?.totalJobs) },
            { label: text.pending, value: formatMetricCount(generationMetrics?.pendingJobs) },
            { label: text.running, value: formatMetricCount(generationMetrics?.runningJobs) },
            { label: text.failed, value: formatMetricCount(generationMetrics?.failedJobs) },
          ]}
        />
        <AdminSummaryChips
          items={[
            `${text.retrying}: ${formatMetricCount(generationMetrics?.retryingJobs)}`,
            `${text.cancelled}: ${formatMetricCount(generationMetrics?.cancelledJobs)}`,
            `${text.cancelling}: ${formatMetricCount(generationMetrics?.cancellingJobs)}`,
            `${text.pendingRefunds}: ${formatMetricCount(generationMetrics?.pendingRefunds)}`,
            `${text.exhaustedRefunds}: ${formatMetricCount(generationMetrics?.exhaustedRefunds)}`,
          ]}
        />

        {generationMetricsQuery.isError ? (
          <AdminStateCard
            className={styles.metricsWarning}
            tone="warning"
            title={text.metricsErrorTitle}
            description={getAdminErrorMessage(
              generationMetricsQuery.error,
              text.metricsErrorDescription
            )}
            action={
              <button
                type="button"
                className={styles.button}
                disabled={!canViewGenerations || generationMetricsQuery.isFetching}
                onClick={requestGenerationMetricsRetry}
              >
                {text.retry}
              </button>
            }
          />
        ) : null}

        <AdminFilterToolbar title={text.filtersTitle} description={text.filtersDescription}>
          <div className={styles.filters}>
            <label className={styles.field}>
              <span className={styles.label}>{text.searchLabel}</span>
              <input
                className={styles.input}
                value={search}
                disabled={areGenerationFiltersLocked}
                onChange={(event) => {
                  setSearch(event.target.value.slice(0, GENERATION_SEARCH_FILTER_MAX_LENGTH));
                  resetGenerationListContext();
                }}
                maxLength={GENERATION_SEARCH_FILTER_MAX_LENGTH}
                placeholder={text.searchPlaceholder}
              />
            </label>
            <label className={styles.field}>
              <span className={styles.label}>{text.statusLabel}</span>
              <select
                className={styles.select}
                value={status}
                disabled={areGenerationFiltersLocked}
                onChange={(event) => {
                  setStatus(event.target.value as StatusFilter);
                  resetGenerationListContext();
                }}
              >
                {statusOptions.map((option) => (
                  <option key={option} value={option}>
                    {formatStatus(option, text)}
                  </option>
                ))}
              </select>
            </label>
            <label className={styles.field}>
              <span className={styles.label}>{text.providerLabel}</span>
              <input
                className={styles.input}
                value={provider}
                disabled={areGenerationFiltersLocked}
                onChange={(event) => {
                  setProvider(event.target.value.slice(0, GENERATION_PROVIDER_FILTER_MAX_LENGTH));
                  resetGenerationListContext();
                }}
                maxLength={GENERATION_PROVIDER_FILTER_MAX_LENGTH}
                placeholder={text.providerPlaceholder}
              />
            </label>
            <label className={styles.field}>
              <span className={styles.label}>{text.refundStateLabel}</span>
              <select
                className={styles.select}
                value={refundState}
                disabled={areGenerationFiltersLocked}
                onChange={(event) => {
                  setRefundState(event.target.value as RefundStateFilter);
                  resetGenerationListContext();
                }}
              >
                {refundStateOptions.map((option) => (
                  <option key={option} value={option}>
                    {text.refundStateOptions[option]}
                  </option>
                ))}
              </select>
            </label>
            <label className={styles.field}>
              <span className={styles.label}>{text.userLabel}</span>
              <input
                className={styles.input}
                value={user}
                disabled={areGenerationFiltersLocked}
                onChange={(event) => {
                  setUser(event.target.value.slice(0, GENERATION_USER_FILTER_MAX_LENGTH));
                  resetGenerationListContext();
                }}
                maxLength={GENERATION_USER_FILTER_MAX_LENGTH}
                placeholder={text.userPlaceholder}
              />
            </label>
          </div>
        </AdminFilterToolbar>

        {generationsQuery.isLoading || isGenerationsRefreshing ? (
          <AdminStateCard title={text.loadingTitle} />
        ) : generationsQuery.isError ? (
          <AdminStateCard
            title={text.errorTitle}
            description={getAdminErrorMessage(generationsQuery.error, text.errorTitle)}
            tone="danger"
            action={
              <button
                type="button"
                className={styles.button}
                disabled={!canViewGenerations || generationsQuery.isFetching}
                onClick={requestGenerationsRetry}
              >
                {text.retry}
              </button>
            }
          />
        ) : visibleItems.length === 0 ? (
          <AdminStateCard title={text.emptyTitle} description={text.emptyDescription} />
        ) : (
          <AdminDataSurface
            title={
              <span className={styles.tableHeader}>
                <span className={styles.tableTitle}>{text.tableTitle}</span>
                <span className={styles.tableMeta}>
                  {visibleTotalCount} {text.tableTotalLabel} /{" "}
                  {formatDateTime(visiblePage?.generatedAtUtc, locale)}
                </span>
              </span>
            }
          >
            {grantCleanError ? <AdminStateCard tone="warning" title={grantCleanError} /> : null}
            {cancelGenerationError ? (
              <AdminStateCard tone="warning" title={cancelGenerationError} />
            ) : null}
            {retryGenerationError ? (
              <AdminStateCard tone="warning" title={retryGenerationError} />
            ) : null}
            {refundRecoveryError && !pendingRefundRecovery ? (
              <AdminStateCard tone="warning" title={refundRecoveryError} />
            ) : null}
            {legacyGamificationError ? (
              <AdminStateCard tone="warning" title={legacyGamificationError} />
            ) : null}
            <div
              className={`${adminTableStyles.tableWrap} ${styles.generationTableWrap}`}
              aria-busy={generationsQuery.isFetching ? "true" : undefined}
            >
              <table className={`${adminTableStyles.table} ${styles.generationTable}`}>
                <thead>
                  <tr>
                    <th>{text.job}</th>
                    <th>{text.user}</th>
                    <th>{text.template}</th>
                    <th>{text.status}</th>
                    <th>{text.provider}</th>
                    <th>{text.cost}</th>
                    <th>{text.attempts}</th>
                    <th>{text.usdLabel}</th>
                    <th>{text.failure}</th>
                    <th>{text.watermark}</th>
                    <th>{text.created}</th>
                    <th>{text.completedAt}</th>
                  </tr>
                </thead>
                <tbody>
                  {visibleItems.map((item) => (
                    <GenerationRow
                      key={item.generationId}
                      item={
                        expandedGenerationId === item.generationId &&
                        generationDetailQuery.data?.generation.generationId === item.generationId
                          ? generationDetailQuery.data.generation
                          : item
                      }
                      locale={locale}
                      text={text}
                      grantingGenerationId={grantingGenerationId}
                      grantCleanPending={isGrantCleanLocked}
                      cancellingGenerationId={cancellingGenerationId}
                      cancelGenerationPending={isCancelGenerationLocked}
                      retryingGenerationId={retryingGenerationId}
                      retryGenerationPending={isRetryGenerationLocked}
                      retryingRefundGenerationId={retryingRefundGenerationId}
                      refundRecoveryPending={isRefundRecoveryLocked}
                      legacyGamificationResolutionPending={isLegacyGamificationResolutionLocked}
                      detailLoading={
                        expandedGenerationId === item.generationId &&
                        generationDetailQuery.isLoading
                      }
                      detailError={
                        expandedGenerationId === item.generationId && generationDetailQuery.isError
                          ? getAdminErrorMessage(generationDetailQuery.error, text.errorTitle)
                          : null
                      }
                      onRetryDetail={() => {
                        if (!generationDetailQuery.isFetching) {
                          void generationDetailQuery.refetch().catch(() => undefined);
                        }
                      }}
                      onGrantClean={requestGrantClean}
                      onCancelGeneration={requestCancelGeneration}
                      onRetryGeneration={requestRetryGeneration}
                      onRetryRefund={requestRefundRecovery}
                      onResolveLegacyGamification={requestLegacyGamificationResolution}
                      isExpanded={expandedGenerationId === item.generationId}
                      onToggleDetails={(generationId) =>
                        setExpandedGenerationId((current) =>
                          current === generationId ? null : generationId
                        )
                      }
                    />
                  ))}
                </tbody>
              </table>
            </div>
            <div className={styles.pager}>
              <span className={styles.pageInfo}>
                {text.page} {pageIndex + 1} {text.of} {visiblePageCount}
              </span>
              <button
                type="button"
                className={`${styles.button} ${styles.pagerButton}`}
                disabled={pageIndex === 0 || generationsQuery.isFetching}
                aria-label={text.previousPageLabel}
                title={text.previousPageLabel}
                onClick={() => resetGenerationListContext(Math.max(0, pageIndex - 1))}
              >
                <CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconPrevious}`} />
              </button>
              <button
                type="button"
                className={`${styles.button} ${styles.pagerButton}`}
                disabled={!visiblePage?.hasMore || generationsQuery.isFetching}
                aria-label={text.nextPageLabel}
                title={text.nextPageLabel}
                onClick={() => resetGenerationListContext(pageIndex + 1)}
              >
                <CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconNext}`} />
              </button>
            </div>
          </AdminDataSurface>
        )}
      </section>
      <ConfirmationDialog
        open={canViewGenerations && pendingCancelGenerationId !== null}
        title={text.cancelGenerationConfirmTitle}
        description={pendingCancelGenerationDescription}
        confirmLabel={text.cancelGenerationConfirmSubmit}
        cancelLabel={text.cancelGenerationConfirmCancel}
        isSubmitting={cancelGenerationMutation.isPending}
        confirmDisabled={!pendingCancelGenerationId}
        onCancel={() => {
          if (!cancelGenerationMutation.isPending) {
            setPendingCancelGenerationId(null);
          }
        }}
        onConfirm={confirmCancelGeneration}
      />
      <ConfirmationDialog
        open={canViewGenerations && pendingLegacyGamificationResolution !== null}
        title={text.gamificationLegacyReview}
        description={pendingLegacyGamificationDescription}
        confirmLabel={text.gamificationLegacyReviewSubmit}
        cancelLabel={text.gamificationLegacyReviewCancel}
        tone="primary"
        isSubmitting={legacyGamificationResolutionMutation.isPending}
        confirmDisabled={!legacyGamificationReason.trim()}
        onCancel={() => {
          if (!legacyGamificationResolutionMutation.isPending) {
            setPendingLegacyGamificationResolution(null);
            setLegacyGamificationReason("");
          }
        }}
        onConfirm={confirmLegacyGamificationResolution}
      >
        <label className={styles.resolutionField}>
          <span>{text.gamificationLegacyReviewActionLabel}</span>
          <select
            className={styles.select}
            value={pendingLegacyGamificationResolution?.action ?? "mark_delivered"}
            disabled={legacyGamificationResolutionMutation.isPending}
            onChange={(event) =>
              setPendingLegacyGamificationResolution((current) =>
                current
                  ? {
                      ...current,
                      action: event.target.value as "mark_delivered" | "replay",
                    }
                  : null
              )
            }
          >
            <option value="mark_delivered">{text.gamificationLegacyReviewMarkDelivered}</option>
            <option value="replay">{text.gamificationLegacyReviewReplay}</option>
          </select>
        </label>
        <label className={styles.resolutionField}>
          <span>{text.gamificationLegacyReviewReasonLabel}</span>
          <textarea
            className={styles.resolutionTextarea}
            value={legacyGamificationReason}
            maxLength={GAMIFICATION_LEGACY_DELIVERY_REASON_MAX_LENGTH}
            disabled={legacyGamificationResolutionMutation.isPending}
            placeholder={text.gamificationLegacyReviewReasonPlaceholder}
            onChange={(event) =>
              setLegacyGamificationReason(
                event.target.value.slice(0, GAMIFICATION_LEGACY_DELIVERY_REASON_MAX_LENGTH)
              )
            }
          />
          {!legacyGamificationReason.trim() ? (
            <small>{text.gamificationLegacyReviewReasonRequired}</small>
          ) : null}
        </label>
      </ConfirmationDialog>
      <ConfirmationDialog
        open={canViewGenerations && pendingRefundRecovery !== null}
        title={text.retryRefundConfirmTitle}
        description={pendingRefundRecoveryDescription}
        confirmLabel={text.retryRefundConfirmSubmit}
        cancelLabel={text.retryRefundConfirmCancel}
        tone="primary"
        isSubmitting={refundRecoveryMutation.isPending}
        confirmDisabled={!pendingRefundRecovery || !refundRecoveryReason.trim()}
        onCancel={() => {
          if (!refundRecoveryMutation.isPending) {
            setPendingRefundRecovery(null);
            setRefundRecoveryReason("");
            setRefundRecoveryError(null);
          }
        }}
        onConfirm={confirmRefundRecovery}
      >
        {refundRecoveryError ? <AdminStateCard tone="warning" title={refundRecoveryError} /> : null}
        <label className={styles.resolutionField}>
          <span>{text.retryRefundReasonLabel}</span>
          <textarea
            className={styles.resolutionTextarea}
            value={refundRecoveryReason}
            maxLength={GENERATION_REFUND_RETRY_REASON_MAX_LENGTH}
            disabled={refundRecoveryMutation.isPending}
            placeholder={text.retryRefundReasonPlaceholder}
            onChange={(event) =>
              setRefundRecoveryReason(
                event.target.value.slice(0, GENERATION_REFUND_RETRY_REASON_MAX_LENGTH)
              )
            }
          />
          {!refundRecoveryReason.trim() ? <small>{text.retryRefundReasonRequired}</small> : null}
        </label>
      </ConfirmationDialog>
      <ConfirmationDialog
        open={canViewGenerations && pendingRetryGenerationId !== null}
        title={text.retryGenerationConfirmTitle}
        description={pendingRetryGenerationDescription}
        confirmLabel={text.retryGenerationConfirmSubmit}
        cancelLabel={text.retryGenerationConfirmCancel}
        isSubmitting={retryGenerationMutation.isPending}
        confirmDisabled={!pendingRetryGenerationId}
        onCancel={() => {
          if (!retryGenerationMutation.isPending) {
            setPendingRetryGenerationId(null);
          }
        }}
        onConfirm={confirmRetryGeneration}
      />
    </>
  );
}
