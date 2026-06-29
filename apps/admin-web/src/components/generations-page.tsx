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
  AdminStatusBadge,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import styles from "@/components/generations-page.module.css";
import { TemplateSecureMedia } from "@/components/templates/template-secure-media";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  fetchAdminFeedback,
  fetchAdminTemplateGenerationMetrics,
  fetchAdminTemplateGenerations,
  GENERATION_PROVIDER_FILTER_MAX_LENGTH,
  GENERATION_SEARCH_FILTER_MAX_LENGTH,
  GENERATION_USER_FILTER_MAX_LENGTH,
  grantAdminGenerationCleanDownload,
  normalizeAdminTemplateGenerationsQuery,
  useAuthSession,
  type AdminGenerationStatus,
  type AdminFeedbackListItem,
  type AdminTemplateGenerationListItem,
} from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import { type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

import {
  getGenerationsPageIntlLocale,
  getGenerationsPageText,
  type GenerationsPageText,
} from "./generations-page.content";

type GenerationsPageProps = {
  locale: Locale;
};

type StatusFilter = AdminGenerationStatus | "All";

const PAGE_SIZE = 25;

const statusOptions: StatusFilter[] = [
  "All",
  "Pending",
  "Running",
  "Completed",
  "Failed",
  "Cancelled",
  "Retrying",
];

function useDebouncedValue(value: string, delayMs: number) {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    const timeoutId = window.setTimeout(() => setDebounced(value), delayMs);
    return () => window.clearTimeout(timeoutId);
  }, [delayMs, value]);

  return debounced;
}

function getStatusTone(status: AdminGenerationStatus) {
  if (status === "Completed") {
    return "var(--success)";
  }

  if (status === "Failed") {
    return "var(--danger)";
  }

  if (status === "Cancelled") {
    return "var(--neutral)";
  }

  if (status === "Retrying") {
    return "var(--magenta)";
  }

  if (status === "Running") {
    return "var(--info)";
  }

  return "var(--warning)";
}

function formatShortId(value: string) {
  const safeValue = sanitizeSensitiveText(value, 32);
  return safeValue.length > 12 ? `${safeValue.slice(0, 8)}...${safeValue.slice(-4)}` : safeValue;
}

function formatSafeText(value: string | null | undefined, fallback = "-") {
  const trimmed = value?.trim();
  return trimmed ? sanitizeSensitiveText(trimmed, 160) : fallback;
}

function formatMappedLabel(
  labels: Record<string, string>,
  value: string | null | undefined,
  fallback = "-"
) {
  if (!value) {
    return fallback;
  }

  return labels[value] ?? sanitizeSensitiveText(value, 80);
}

function formatMoney(value: number | null | undefined, locale: Locale) {
  if (typeof value !== "number") {
    return "-";
  }

  return new Intl.NumberFormat(getGenerationsPageIntlLocale(locale), {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 4,
  }).format(value);
}

function formatMetricCount(value: number | null | undefined): string {
  return typeof value === "number" && Number.isFinite(value) ? String(Math.max(0, value)) : "-";
}

function formatFeedbackRating(value: number | null | undefined, text: GenerationsPageText) {
  if (value === 1) return text.ratingLabels.positive;
  if (value === 0) return text.ratingLabels.neutral;
  if (value === -1) return text.ratingLabels.negative;
  return "-";
}

function formatStatus(status: StatusFilter, text: GenerationsPageText) {
  return text.generationStatusOptions[status] ?? status;
}

function formatTemplateType(
  templateType: AdminTemplateGenerationListItem["templateType"],
  text: GenerationsPageText
) {
  return text.templateTypeLabels[templateType];
}

function formatWatermarkMethod(value?: string | null) {
  const normalized = value?.trim();
  return normalized ? sanitizeSensitiveText(normalized, 32) : null;
}

function formatInputSourceType(
  value: AdminTemplateGenerationListItem["inputSourceType"],
  text: GenerationsPageText
) {
  const normalized = value.trim().toLowerCase();
  if (normalized === "generation_result") {
    return text.inputSourceTypeLabels.generation_result;
  }
  if (normalized === "pet_photo") {
    return text.inputSourceTypeLabels.pet_photo;
  }
  return text.inputSourceTypeLabels.user_upload;
}

function GenerationRow({
  item,
  locale,
  text,
  onGrantClean,
  grantingGenerationId,
  grantCleanPending,
  isExpanded,
  onToggleDetails,
}: {
  item: AdminTemplateGenerationListItem;
  locale: Locale;
  text: GenerationsPageText;
  onGrantClean: (generationId: string) => void;
  grantingGenerationId: string | null;
  grantCleanPending: boolean;
  isExpanded: boolean;
  onToggleDetails: (generationId: string) => void;
}) {
  const failureText = formatSafeText(item.failureCode, text.noFailure);
  const providerText = formatSafeText(item.provider);
  const modelText = formatSafeText(item.model, "");
  const templateTitle = formatSafeText(item.templateTitle);
  const generationIdText = formatShortId(item.generationId);
  const userIdText = formatShortId(item.userId);
  const templateIdText = formatShortId(item.templateId);
  const detailsPanelId = `generation-details-${item.generationId.replace(/[^a-zA-Z0-9_-]/g, "-")}`;
  const toggleDetailsLabel = `${isExpanded ? text.hideDetails : text.showDetails}: ${generationIdText}`;
  const grantCleanLabel = `${text.grantClean}: ${generationIdText}`;
  const parentTitle = item.parentTemplateTitle
    ? sanitizeSensitiveText(item.parentTemplateTitle, 48)
    : item.similarToGenerationId
      ? `${text.lineageSimilarPrefix} ${formatShortId(item.similarToGenerationId)}`
      : formatInputSourceType(item.inputSourceType, text);
  const lineageText = `${parentTitle} -> ${templateTitle}${
    item.childCount > 0
      ? ` -> ${item.childCount} ${
          item.childCount === 1 ? text.lineageChildSingular : text.lineageChildPlural
        }`
      : ""
  }`;
  const debugText =
    item.generationMode === "similar"
      ? [
          item.variationStrength
            ? `${text.variationLabel} ${sanitizeSensitiveText(item.variationStrength, 16)}`
            : null,
          typeof item.generationSeed === "number" ? `${text.seedLabel} ${item.generationSeed}` : null,
        ]
          .filter(Boolean)
          .join(" / ")
      : "";
  const watermarkMethod = formatWatermarkMethod(item.watermarkUnlockMethod);
  const watermarkUnlockedByText = item.watermarkUnlockedByUserId
    ? formatShortId(item.watermarkUnlockedByUserId)
    : null;
  const watermarkState = !item.isWatermarkRequired
    ? text.watermarkNotRequired
    : item.isWatermarkRemoved
      ? text.watermarkRemoved
      : item.watermarkedMediaPath
        ? text.watermarkApplied
        : text.watermarkPending;
  const compareState = item.canCompareBeforeAfter ? text.compareReady : text.compareUnavailable;
  const feedbackQuery = useQuery({
    queryKey: adminQueryKeys.feedback({ generationId: item.generationId, take: 5 }),
    queryFn: ({ signal }) =>
      fetchAdminFeedback({ generationId: item.generationId, take: 5 }, signal),
    enabled: isExpanded,
  });
  const feedbackItems = feedbackQuery.data?.items ?? [];

  function requestFeedbackRetry() {
    if (feedbackQuery.isFetching) {
      return;
    }

    void feedbackQuery.refetch().catch(() => undefined);
  }

  return (
    <>
      <tr>
        <td className={adminTableStyles.mono}>
          <span className={styles.jobId} title={generationIdText} aria-label={generationIdText}>
            {generationIdText}
          </span>
          <div>
            <button
              type="button"
              className={styles.inlineAction}
              onClick={() => onToggleDetails(item.generationId)}
              aria-expanded={isExpanded}
              aria-controls={detailsPanelId}
              aria-label={toggleDetailsLabel}
              title={toggleDetailsLabel}
            >
              {isExpanded ? text.hideDetails : text.showDetails}
            </button>
          </div>
        </td>
        <td className={adminTableStyles.mono}>
          <span className={styles.jobId} title={userIdText} aria-label={userIdText}>
            {userIdText}
          </span>
        </td>
        <td>
          <span className={styles.templateTitle}>
            <strong>{templateTitle}</strong>
            <span>
              {formatTemplateType(item.templateType, text)} / {templateIdText}
            </span>
            <span className={styles.lineage}>{lineageText}</span>
            {debugText ? <span className={styles.lineage}>{debugText}</span> : null}
          </span>
        </td>
        <td>
          <AdminStatusBadge color={getStatusTone(item.status)}>
            {formatStatus(item.status, text)}
          </AdminStatusBadge>
        </td>
        <td>
          {providerText !== "-" ? <AdminBadge tone="info">{providerText}</AdminBadge> : "-"}
          {modelText ? <div className={adminTableStyles.mono}>{modelText}</div> : null}
        </td>
        <td className={adminTableStyles.numeric}>{item.tokenCost}</td>
        <td className={adminTableStyles.numeric}>{item.attemptCount}</td>
        <td className={adminTableStyles.numeric}>{formatMoney(item.providerCostUsd, locale)}</td>
        <td>
          <span className={styles.failure}>{failureText}</span>
        </td>
        <td>
          <span className={styles.watermarkMeta}>
            <strong>{watermarkState}</strong>
            {watermarkMethod ? (
              <span>
                {watermarkMethod}
                {typeof item.watermarkCreditsSpent === "number"
                  ? ` / ${item.watermarkCreditsSpent} ${text.creditsLabel}`
                  : ""}
              </span>
            ) : null}
            {watermarkUnlockedByText ? (
              <span>
                {text.watermarkUnlockedBy} {watermarkUnlockedByText}
              </span>
            ) : null}
            {item.watermarkUnlockedAtUtc ? (
              <span>{formatDateTime(item.watermarkUnlockedAtUtc, locale)}</span>
            ) : null}
            {item.isWatermarkRequired && !item.isWatermarkRemoved ? (
              <button
                type="button"
                className={styles.inlineAction}
                disabled={grantCleanPending}
                onClick={() => onGrantClean(item.generationId)}
                aria-label={grantCleanLabel}
                title={grantCleanLabel}
              >
                {grantingGenerationId === item.generationId ? text.grantingClean : text.grantClean}
              </button>
            ) : null}
          </span>
        </td>
        <td>{formatDateTime(item.createdAtUtc, locale)}</td>
        <td>{item.completedAtUtc ? formatDateTime(item.completedAtUtc, locale) : "-"}</td>
      </tr>
      {isExpanded ? (
        <tr>
          <td colSpan={12} className={styles.detailsCell}>
            <div className={styles.detailsPanel} id={detailsPanelId}>
              <div className={styles.previewGrid}>
                <section className={styles.previewCard}>
                  <header>
                    <strong>{text.before}</strong>
                  </header>
                  {item.inputPreviewUrl ? (
                    <TemplateSecureMedia
                      className={styles.previewImage}
                      url={item.inputPreviewUrl}
                      kind="image"
                      alt={text.before}
                      width={512}
                      height={512}
                      logContext={{
                        surface: "generations-before-preview",
                        templateId: item.templateId,
                      }}
                    />
                  ) : (
                    <div className={styles.previewFallback}>{text.previewMissing}</div>
                  )}
                </section>
                <section className={styles.previewCard}>
                  <header>
                    <strong>{text.after}</strong>
                  </header>
                  {item.resultPreviewUrl ? (
                    <TemplateSecureMedia
                      className={styles.previewImage}
                      url={item.resultPreviewUrl}
                      kind="image"
                      alt={text.after}
                      width={512}
                      height={512}
                      logContext={{
                        surface: "generations-after-preview",
                        templateId: item.templateId,
                      }}
                    />
                  ) : (
                    <div className={styles.previewFallback}>{text.previewMissing}</div>
                  )}
                </section>
              </div>
              <div className={styles.detailsGrid}>
                <div>
                  <span>{text.sourceType}</span>
                  <strong>{formatInputSourceType(item.inputSourceType, text)}</strong>
                </div>
                <div>
                  <span>{text.compareState}</span>
                  <strong>{compareState}</strong>
                </div>
                <div>
                  <span>{text.pet}</span>
                  <strong>{item.petId ? formatShortId(item.petId) : "-"}</strong>
                </div>
                <div>
                  <span>{text.petPhoto}</span>
                  <strong>{item.petPhotoId ? formatShortId(item.petPhotoId) : "-"}</strong>
                </div>
                <div>
                  <span>{text.inputAsset}</span>
                  <strong>
                    {item.inputMediaAssetId ? formatShortId(item.inputMediaAssetId) : "-"}
                  </strong>
                </div>
                <div>
                  <span>{text.resultAsset}</span>
                  <strong>
                    {item.resultMediaAssetId ? formatShortId(item.resultMediaAssetId) : "-"}
                  </strong>
                </div>
                <div>
                  <span>{text.debugTitle}</span>
                  <strong>{watermarkState}</strong>
                </div>
              </div>
              <section className={styles.feedbackPanel}>
                <header>
                  <strong>{text.feedbackTab}</strong>
                  <span>{feedbackQuery.data?.totalCount ?? 0}</span>
                </header>
                {feedbackQuery.isLoading ? (
                  <p>{text.loadingTitle}</p>
                ) : feedbackQuery.isError ? (
                  <AdminStateCard
                    tone="warning"
                    title={text.feedbackError}
                    description={getAdminErrorMessage(feedbackQuery.error, text.feedbackError)}
                    action={
                      <button
                        type="button"
                        className={styles.button}
                        disabled={feedbackQuery.isFetching}
                        onClick={requestFeedbackRetry}
                      >
                        {text.retry}
                      </button>
                    }
                  />
                ) : feedbackItems.length === 0 ? (
                  <p>{text.feedbackEmpty}</p>
                ) : (
                  <div className={styles.feedbackList}>
                    {feedbackItems.map((feedback: AdminFeedbackListItem) => (
                      <div key={feedback.id} className={styles.feedbackItem}>
                        <strong>
                          {formatMappedLabel(text.feedbackTypeOptions, feedback.type)} /{" "}
                          {sanitizeSensitiveText(feedback.category, 80)} /{" "}
                          {formatFeedbackRating(feedback.rating, text)}
                        </strong>
                        <span>
                          {formatMappedLabel(text.feedbackStatusOptions, feedback.status)} /{" "}
                          {formatMappedLabel(text.feedbackPriorityOptions, feedback.priority)} /{" "}
                          {formatDateTime(feedback.createdAtUtc, locale)}
                        </span>
                        {feedback.message ? (
                          <p>{sanitizeSensitiveText(feedback.message, 220)}</p>
                        ) : null}
                      </div>
                    ))}
                  </div>
                )}
              </section>
            </div>
          </td>
        </tr>
      ) : null}
    </>
  );
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
    if (!expandedGenerationId || visibleGenerationIds.has(expandedGenerationId)) {
      return;
    }

    queueMicrotask(() => setExpandedGeneration(null));
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
          {grantCleanError ? (
            <AdminStateCard tone="warning" title={grantCleanError} />
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
