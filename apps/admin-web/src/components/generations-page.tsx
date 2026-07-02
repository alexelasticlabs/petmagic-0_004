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
import styles from "@/components/generations-page.module.css";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  fetchAdminTemplateGenerationMetrics,
  fetchAdminTemplateGenerations,
  GENERATION_PROVIDER_FILTER_MAX_LENGTH,
  GENERATION_SEARCH_FILTER_MAX_LENGTH,
  GENERATION_USER_FILTER_MAX_LENGTH,
  grantAdminGenerationCleanDownload,
  normalizeAdminTemplateGenerationsQuery,
  useAuthSession,
} from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import { type Locale } from "@/lib/i18n";

import { getGenerationsPageText } from "./generations-page.content";
import {
  formatStatus,
  formatMetricCount,
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
                    onGrantClean={requestGrantClean}
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
  );
}
