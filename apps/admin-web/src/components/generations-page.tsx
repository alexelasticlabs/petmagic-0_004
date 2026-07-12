"use client";

import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";

import { CaretDownIcon } from "@/components/admin/admin-icons";
import {
  AdminBadge,
  AdminCard,
  AdminKpiCard,
  AdminPageHero,
  AdminStateCard,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import styles from "@/components/generations-page.module.css";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  cancelAdminTemplateGeneration,
  fetchAdminTemplateGenerationMetrics,
  fetchAdminTemplateGenerations,
  GENERATION_PROVIDER_FILTER_MAX_LENGTH,
  GENERATION_SEARCH_FILTER_MAX_LENGTH,
  GENERATION_USER_FILTER_MAX_LENGTH,
  GAMIFICATION_LEGACY_DELIVERY_REASON_MAX_LENGTH,
  grantAdminGenerationCleanDownload,
  normalizeAdminTemplateGenerationsQuery,
  retryAdminTemplateGeneration,
  resolveAdminLegacyGamificationDelivery,
  useAuthSession,
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
  const queryClient = useQueryClient();
  const session = useAuthSession();
  const canViewGenerations = session?.user.roles.includes("Admin") ?? false;
  const [pageIndex, setPageIndex] = useState(0);
  const [status, setStatus] = useState<StatusFilter>("All");
  const [provider, setProvider] = useState("");
  const [user, setUser] = useState("");
  const [search, setSearch] = useState("");
  const [expandedGeneration, setExpandedGeneration] = useState<{
    queryKey: string;
    generationId: string;
  } | null>(null);
  const [grantCleanError, setGrantCleanError] = useState<string | null>(null);
  const [cancelGenerationError, setCancelGenerationError] = useState<string | null>(null);
  const [pendingCancelGenerationId, setPendingCancelGenerationId] = useState<string | null>(null);
  const [retryGenerationError, setRetryGenerationError] = useState<string | null>(null);
  const [pendingRetryGenerationId, setPendingRetryGenerationId] = useState<string | null>(null);
  const [legacyGamificationError, setLegacyGamificationError] = useState<string | null>(null);
  const [pendingLegacyGamificationResolution, setPendingLegacyGamificationResolution] = useState<{
    generationId: string;
    action: "mark_delivered" | "replay";
  } | null>(null);
  const [legacyGamificationReason, setLegacyGamificationReason] = useState("");

  const debouncedProvider = useDebouncedValue(provider, 350);
  const debouncedUser = useDebouncedValue(user, 350);
  const debouncedSearch = useDebouncedValue(search, 350);

  useEffect(() => {
    ensureAdminSession(locale, router, { requiredRole: "Admin" });
  }, [locale, router, session]);

  const query = useMemo(
    () =>
      normalizeAdminTemplateGenerationsQuery({
        status,
        provider: debouncedProvider,
        user: debouncedUser,
        search: debouncedSearch,
        skip: pageIndex * PAGE_SIZE,
        take: PAGE_SIZE,
      }),
    [debouncedProvider, debouncedSearch, debouncedUser, pageIndex, status]
  );
  const queryKey = JSON.stringify(query);
  const expandedGenerationId =
    expandedGeneration?.queryKey === queryKey ? expandedGeneration.generationId : null;

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
    onSuccess: async () => {
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateGenerations(query) }),
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
    onSuccess: async () => {
      setPendingCancelGenerationId(null);
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateGenerations(query) }),
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateGenerationMetrics }),
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
    onSuccess: async () => {
      setPendingRetryGenerationId(null);
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateGenerations(query) }),
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateGenerationMetrics }),
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
    onSuccess: async () => {
      setPendingLegacyGamificationResolution(null);
      setLegacyGamificationReason("");
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateGenerations(query) }),
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
        setExpandedGeneration(null);
      }
    });

    return () => {
      isActive = false;
    };
  }, [expandedGenerationId, visibleGenerationIds]);

  function resetGenerationListContext(nextPageIndex = 0) {
    setExpandedGeneration(null);
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
      <section className={styles.page}>
        <AdminPageHero
          eyebrow={text.eyebrow}
          title={text.title}
          description={text.description}
          badge={<AdminBadge tone="danger">{text.adminOnly}</AdminBadge>}
        />
        <AdminStateCard tone="info" title={text.loadingTitle} />
      </section>
    );
  }

  return (
    <>
      <section className={styles.page}>
        <AdminPageHero
          eyebrow={text.eyebrow}
          title={text.title}
          description={text.description}
          badge={<AdminBadge tone="danger">{text.adminOnly}</AdminBadge>}
        />

        <div className={styles.kpiGrid}>
          <AdminKpiCard
            label={text.total}
            value={formatMetricCount(generationMetrics?.totalJobs)}
            tone="primary"
          />
          <AdminKpiCard
            label={text.pending}
            value={formatMetricCount(generationMetrics?.pendingJobs)}
            hint={text.allJobsScope}
            tone="warning"
          />
          <AdminKpiCard
            label={text.running}
            value={formatMetricCount(generationMetrics?.runningJobs)}
            hint={text.allJobsScope}
            tone="info"
          />
          <AdminKpiCard
            label={text.failed}
            value={formatMetricCount(generationMetrics?.failedJobs)}
            hint={text.allJobsScope}
            tone="danger"
          />
          <AdminKpiCard
            label={text.retrying}
            value={formatMetricCount(generationMetrics?.retryingJobs)}
            hint={text.allJobsScope}
            tone="warning"
          />
          <AdminKpiCard
            label={text.cancelled}
            value={formatMetricCount(generationMetrics?.cancelledJobs)}
            hint={text.allJobsScope}
            tone="neutral"
          />
          <AdminKpiCard
            label={text.cancelling}
            value={formatMetricCount(generationMetrics?.cancellingJobs)}
            hint={text.allJobsScope}
            tone="warning"
          />
        </div>

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

        <AdminCard title={text.filtersTitle} description={text.filtersDescription}>
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
        </AdminCard>

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
          <AdminCard
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
            {legacyGamificationError ? (
              <AdminStateCard tone="warning" title={legacyGamificationError} />
            ) : null}
            <div
              className={adminTableStyles.tableWrap}
              aria-busy={generationsQuery.isFetching ? "true" : undefined}
            >
              <table className={adminTableStyles.table}>
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
                      item={item}
                      locale={locale}
                      text={text}
                      grantingGenerationId={grantingGenerationId}
                      grantCleanPending={isGrantCleanLocked}
                      cancellingGenerationId={cancellingGenerationId}
                      cancelGenerationPending={isCancelGenerationLocked}
                      retryingGenerationId={retryingGenerationId}
                      retryGenerationPending={isRetryGenerationLocked}
                      legacyGamificationResolutionPending={isLegacyGamificationResolutionLocked}
                      onGrantClean={requestGrantClean}
                      onCancelGeneration={requestCancelGeneration}
                      onRetryGeneration={requestRetryGeneration}
                      onResolveLegacyGamification={requestLegacyGamificationResolution}
                      isExpanded={expandedGenerationId === item.generationId}
                      onToggleDetails={(generationId) =>
                        setExpandedGeneration((current) =>
                          current?.queryKey === queryKey && current.generationId === generationId
                            ? null
                            : { queryKey, generationId }
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
          </AdminCard>
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
