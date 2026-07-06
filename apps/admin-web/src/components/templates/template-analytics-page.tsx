"use client";

import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useRef, useState, type ComponentType } from "react";

import {
  CalendarIcon,
  ChartIcon,
  DownloadIcon,
  GlobeIcon,
  RefreshIcon,
  TableIcon,
  TrendUpIcon,
} from "@/components/admin/admin-icons";
import {
  AdminMetricStrip,
  AdminPage,
  AdminStateCard,
  AdminToolbar,
} from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { getTemplateAnalyticsCopy } from "@/components/templates/template-analytics-copy";
import {
  TemplateAnalyticsFailureBreakdownSection,
  TemplateAnalyticsFeedbackSection,
  TemplateAnalyticsRecentRunsSection,
} from "@/components/templates/template-analytics-detail-sections";
import {
  formatSafeTemplateAnalyticsExportName,
  sanitizeEventAnalyticsForExport,
  sanitizeFailureBreakdownForExport,
  sanitizeRecentRunsForExport,
  sanitizeTemplateForAnalyticsExport,
} from "@/components/templates/template-analytics-export";
import {
  TemplateAnalyticsInsightGridSection,
  TemplateAnalyticsOverviewSection,
  TemplateAnalyticsSnapshotSection,
  TemplateAnalyticsVisualSection,
} from "@/components/templates/template-analytics-overview-sections";
import styles from "@/components/templates/template-analytics-page.module.css";
import {
  buildPeriodAnalytics,
  calculateChange,
  formatDateTime,
  formatDuration,
  formatNumber,
  formatPercent,
  formatTokens,
  totalsFromStatistics,
  type PeriodKey,
  type TrendMetricKey,
} from "@/components/templates/template-analytics-utils";
import { useAdminTemplateAnalyticsOverview } from "@/components/templates/use-admin-template-analytics-overview";
import { useAdminTemplateFeedback } from "@/components/templates/use-admin-template-feedback";
import { Button } from "@/components/ui/button";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  TEMPLATE_FEEDBACK_SEARCH_MAX_LENGTH,
  fetchAdminTemplateFeedbackSummary,
  fetchAdminTemplateRecentGenerations,
  useAuthSession,
  type AdminTemplateEventAnalytics,
  type AdminTemplateRecentGeneration,
} from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type TemplateAnalyticsPageProps = {
  locale: Locale;
  templateId: string;
};

type MetricAccent = "blue" | "green" | "red" | "cyan" | "neutral";
type RecentRunsMode = "latest" | "all" | "failed";
type FeedbackFilterKey = "all" | "complaint" | "feedback";

const RECENT_RUNS_PREVIEW_LIMIT = 8;

const EMPTY_EVENT_ANALYTICS: AdminTemplateEventAnalytics = {
  totalViews: 0,
  totalVideoViews: 0,
  totalComplaints: 0,
  sources: [],
  devices: [],
  geography: [],
};

export function TemplateAnalyticsPage({ locale, templateId }: TemplateAnalyticsPageProps) {
  return <TemplateAnalyticsPageContent key={templateId} locale={locale} templateId={templateId} />;
}

function TemplateAnalyticsPageContent({ locale, templateId }: TemplateAnalyticsPageProps) {
  const text = useMemo(() => getTemplateAnalyticsCopy(locale), [locale]);
  const router = useRouter();
  const session = useAuthSession();
  const sessionRoles = session?.user.roles ?? [];
  const canViewTemplateAnalytics =
    sessionRoles.includes("Admin") || sessionRoles.includes("Moderator");
  const {
    eventAnalytics,
    failureBreakdown,
    hasError,
    hasSecondaryError,
    hasSecondaryPartialError,
    isFetching,
    isLoading,
    isSecondaryLoading,
    recentRunsPreview,
    refresh,
    statistics,
    template,
    trendPoints,
  } = useAdminTemplateAnalyticsOverview({
    enabled: canViewTemplateAnalytics,
    previewTake: RECENT_RUNS_PREVIEW_LIMIT,
    templateId,
  });
  const [allRecentRuns, setAllRecentRuns] = useState<AdminTemplateRecentGeneration[] | null>(null);
  const [recentRunsMode, setRecentRunsMode] = useState<RecentRunsMode>("latest");
  const [isRecentRunsLoading, setIsRecentRunsLoading] = useState(false);
  const [recentRunsError, setRecentRunsError] = useState<string | null>(null);
  const recentRunsAbortControllerRef = useRef<AbortController | null>(null);
  const [feedbackFilter, setFeedbackFilter] = useState<FeedbackFilterKey>("all");
  const [feedbackSearchInput, setFeedbackSearchInput] = useState("");
  const [feedbackSearch, setFeedbackSearch] = useState("");
  const [period, setPeriod] = useState<PeriodKey>("30d");
  const [chartMetric, setChartMetric] = useState<TrendMetricKey>("totalRuns");
  const [isComparisonEnabled, setIsComparisonEnabled] = useState(true);
  const {
    hasError: hasFeedbackError,
    isLoading: isFeedbackLoading,
    items: feedbackItems,
  } = useAdminTemplateFeedback({
    enabled: canViewTemplateAnalytics,
    filter: feedbackFilter,
    search: feedbackSearch,
    templateId,
  });
  const feedbackSummaryQuery = useQuery({
    queryKey: adminQueryKeys.templateFeedbackSummary(templateId),
    queryFn: ({ signal }) => fetchAdminTemplateFeedbackSummary(templateId, signal),
    enabled: canViewTemplateAnalytics && Boolean(templateId),
  });
  const error = hasError ? text.loadError : null;
  const feedbackError = hasFeedbackError ? text.feedbackLoadError : null;
  const secondaryStateMessage = isSecondaryLoading ? text.loading : text.loadError;

  const periodAnalytics = useMemo(
    () => buildPeriodAnalytics(trendPoints, period),
    [trendPoints, period]
  );
  const feedbackOptions: Array<{ key: FeedbackFilterKey; label: string }> = [
    { key: "all", label: text.feedbackFilterAll },
    { key: "complaint", label: text.feedbackFilterComplaint },
    { key: "feedback", label: text.feedbackFilterFeedback },
  ];
  const recentRunsPreviewSignature = useMemo(
    () => recentRunsPreview.map((run) => run.generationId).join("|"),
    [recentRunsPreview]
  );
  const visibleRecentRuns = useMemo(() => {
    const allRuns = allRecentRuns ?? recentRunsPreview;
    if (recentRunsMode === "all") {
      return allRuns;
    }

    if (recentRunsMode === "failed") {
      return allRuns.filter((run) => run.status === "Failed" || Boolean(run.failureCode));
    }

    return recentRunsPreview;
  }, [allRecentRuns, recentRunsMode, recentRunsPreview]);

  useEffect(() => {
    const handle = window.setTimeout(() => {
      setFeedbackSearch(feedbackSearchInput.trim().slice(0, TEMPLATE_FEEDBACK_SEARCH_MAX_LENGTH));
    }, 250);

    return () => {
      window.clearTimeout(handle);
    };
  }, [feedbackSearchInput]);

  useEffect(() => {
    if (!canViewTemplateAnalytics) {
      ensureAdminSession(locale, router);
    }
  }, [canViewTemplateAnalytics, locale, router, session]);

  useEffect(
    () => () => {
      const controller = recentRunsAbortControllerRef.current;
      controller?.abort();
      if (recentRunsAbortControllerRef.current === controller) {
        recentRunsAbortControllerRef.current = null;
      }
    },
    []
  );

  useEffect(() => {
    let isActive = true;
    recentRunsAbortControllerRef.current?.abort();
    recentRunsAbortControllerRef.current = null;

    queueMicrotask(() => {
      if (!isActive) {
        return;
      }

      setIsRecentRunsLoading(false);
      setAllRecentRuns(null);
      setRecentRunsError(null);
      setRecentRunsMode((current) => (current === "latest" ? current : "latest"));
    });

    return () => {
      isActive = false;
    };
  }, [recentRunsPreviewSignature]);

  function requestAnalyticsRetry() {
    if (!canViewTemplateAnalytics || isFetching) {
      return;
    }

    void refresh().catch(() => undefined);
  }

  if (!canViewTemplateAnalytics || isLoading) {
    return (
      <AdminPage className={styles.page}>
        <AdminStateCard tone="info" title={text.loading} />
      </AdminPage>
    );
  }

  if (error || !template || !statistics) {
    return (
      <AdminPage className={styles.page}>
        <AdminStateCard
          tone="danger"
          title={error ?? text.loadError}
          action={
            <Button
              type="button"
              variant="secondary"
              disabled={!canViewTemplateAnalytics || isFetching}
              onClick={requestAnalyticsRetry}
            >
              {text.retryAction}
            </Button>
          }
        />
      </AdminPage>
    );
  }

  const templateSlug = template.templateType === "Video" ? "video" : "image";
  const catalogPath = `/${locale}/templates/${templateSlug}`;
  const editorPath = `/${locale}/templates/${templateSlug}/editor?templateId=${encodeURIComponent(templateId)}`;
  const templateTitle = sanitizeSensitiveText(template.title, 120);
  const breadcrumbsRoot =
    template.templateType === "Video" ? text.videoTemplatesLabel : text.imageTemplatesLabel;
  const activeRuns = statistics.queuedRuns + statistics.processingRuns;
  const canShowAllRecentRuns = statistics.totalRuns > RECENT_RUNS_PREVIEW_LIMIT;
  const canShowFailedRecentRuns = statistics.failedRuns > 0;
  const shouldShowRecentRunModes = canShowAllRecentRuns || canShowFailedRecentRuns;
  const isSecondaryReady = !isSecondaryLoading && !hasSecondaryError;
  const events = eventAnalytics ?? EMPTY_EVENT_ANALYTICS;
  const selectedTotals = isSecondaryReady
    ? period === "all"
      ? totalsFromStatistics(statistics)
      : periodAnalytics.current
    : period === "all"
      ? totalsFromStatistics(statistics)
      : null;
  const previousTotals =
    isSecondaryReady && isComparisonEnabled && period !== "all" ? periodAnalytics.previous : null;
  const chartPoints = isSecondaryReady
    ? period === "all"
      ? trendPoints
      : periodAnalytics.currentPoints
    : [];
  const isAnalyticsToolbarLocked = isFetching || isSecondaryLoading;

  async function handleRecentRunsModeChange(mode: RecentRunsMode) {
    setRecentRunsError(null);

    if (mode === "latest") {
      recentRunsAbortControllerRef.current?.abort();
      recentRunsAbortControllerRef.current = null;
      setIsRecentRunsLoading(false);
      setRecentRunsMode("latest");
      return;
    }

    setRecentRunsMode(mode);
    if (!canViewTemplateAnalytics) {
      recentRunsAbortControllerRef.current?.abort();
      setIsRecentRunsLoading(false);
      setRecentRunsMode("latest");
      return;
    }

    if (allRecentRuns || isRecentRunsLoading || !canShowAllRecentRuns) {
      return;
    }

    recentRunsAbortControllerRef.current?.abort();
    const controller = new AbortController();
    recentRunsAbortControllerRef.current = controller;

    try {
      setIsRecentRunsLoading(true);
      const response = await fetchAdminTemplateRecentGenerations(
        templateId,
        undefined,
        controller.signal
      );
      if (controller.signal.aborted) {
        return;
      }

      setAllRecentRuns(response);
    } catch (error) {
      if (controller.signal.aborted) {
        return;
      }

      clientLogger.warn("templates.analytics_recent_runs_load_failed", {
        templateId: sanitizeSensitiveText(templateId, 80),
        mode,
        errorName: error instanceof Error ? error.name : "UnknownError",
      });
      setRecentRunsMode("latest");
      setRecentRunsError(text.recentRunsExpandError);
    } finally {
      if (recentRunsAbortControllerRef.current === controller) {
        recentRunsAbortControllerRef.current = null;
        setIsRecentRunsLoading(false);
      }
    }
  }
  const kpiCards = [
    {
      label: text.views,
      value: isSecondaryReady ? formatNumber(events.totalViews, locale) : "...",
      hint: isSecondaryReady ? text.viewsHint : secondaryStateMessage,
      accent: "blue" as MetricAccent,
    },
    {
      label: text.generationStarts,
      value: selectedTotals ? formatNumber(selectedTotals.totalRuns, locale) : "...",
      hint: selectedTotals ? text.generationStartsHint : secondaryStateMessage,
      accent: "blue" as MetricAccent,
      delta: selectedTotals
        ? calculateChange(selectedTotals.totalRuns, previousTotals?.totalRuns)
        : null,
    },
    {
      label: text.successfulGenerations,
      value: selectedTotals ? formatNumber(selectedTotals.completedRuns, locale) : "...",
      hint: selectedTotals ? text.successfulGenerationsHint : secondaryStateMessage,
      accent: "green" as MetricAccent,
      delta: selectedTotals
        ? calculateChange(selectedTotals.completedRuns, previousTotals?.completedRuns)
        : null,
    },
    {
      label: text.generationConversion,
      value: selectedTotals ? formatPercent(selectedTotals.successRatePercent, locale) : "...",
      hint: selectedTotals ? text.generationConversionHint : secondaryStateMessage,
      accent: "green" as MetricAccent,
      delta: selectedTotals
        ? calculateChange(selectedTotals.successRatePercent, previousTotals?.successRatePercent)
        : null,
    },
    {
      label: text.tokenSpend,
      value: selectedTotals ? formatTokens(selectedTotals.totalTokenCost, locale) : "...",
      hint: selectedTotals ? text.tokenSpendHint : secondaryStateMessage,
      accent: "cyan" as MetricAccent,
      delta: selectedTotals
        ? calculateChange(selectedTotals.totalTokenCost, previousTotals?.totalTokenCost)
        : null,
    },
    {
      label: text.complaints,
      value: isSecondaryReady ? formatNumber(events.totalComplaints, locale) : "...",
      hint: isSecondaryReady ? text.complaintsHint : secondaryStateMessage,
      accent:
        isSecondaryReady && events.totalComplaints > 0
          ? ("red" as MetricAccent)
          : ("neutral" as MetricAccent),
    },
  ];
  const periodOptions: Array<{ key: PeriodKey; label: string }> = [
    { key: "7d", label: text.range7 },
    { key: "30d", label: text.range30 },
    { key: "90d", label: text.range90 },
    { key: "all", label: text.rangeAll },
  ];
  const chartTabs: Array<{ key: TrendMetricKey; label: string }> = [
    { key: "totalRuns", label: text.chartRuns },
    { key: "completedRuns", label: text.chartCompleted },
    { key: "failedRuns", label: text.chartFailed },
    { key: "totalTokenCost", label: text.chartTokens },
    { key: "averageGenerationSeconds", label: text.chartDuration },
  ];

  function handleExportAnalytics() {
    if (!template || !statistics) {
      return;
    }

    const payload = {
      exportedAtUtc: new Date().toISOString(),
      period,
      template: sanitizeTemplateForAnalyticsExport(template),
      statistics,
      selectedTotals,
      trendPoints: chartPoints,
      recentRuns: sanitizeRecentRunsForExport(visibleRecentRuns),
      failureBreakdown: sanitizeFailureBreakdownForExport(failureBreakdown),
      eventAnalytics: sanitizeEventAnalyticsForExport(events),
    };
    const blob = new Blob([JSON.stringify(payload, null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = formatSafeTemplateAnalyticsExportName(template.templateId);
    try {
      document.body.append(link);
      link.click();
      window.setTimeout(() => URL.revokeObjectURL(url), 1000);
    } catch (error) {
      URL.revokeObjectURL(url);
      throw error;
    } finally {
      link.remove();
    }
  }

  return (
    <AdminPage className={styles.page}>
      <div className={styles.pageHeaderRow}>
        <div className={styles.breadcrumbs}>
          <Link href={catalogPath}>{breadcrumbsRoot}</Link>
          <span aria-hidden="true">/</span>
          <Link href={editorPath}>{templateTitle}</Link>
          <span aria-hidden="true">/</span>
          <span>{text.pageTitle}</span>
        </div>

        <div className={styles.heroActions}>
          <Link href={catalogPath} className={styles.secondaryLink}>
            <TableIcon className={styles.controlIcon} />
            <span>{text.backToCatalog}</span>
          </Link>
          <Link href={editorPath} className={styles.primaryLink}>
            <ChartIcon className={styles.controlIcon} />
            <span>{text.openEditor}</span>
          </Link>
        </div>
      </div>

      <AdminMetricStrip
        className={styles.metricStrip}
        items={[
          { label: text.lastRun, value: formatDateTime(statistics.lastRunAtUtc, locale) },
          {
            label: text.lastCompleted,
            value: formatDateTime(statistics.lastCompletedAtUtc, locale),
          },
          {
            label: text.averageGenerationTime,
            value: formatDuration(statistics.averageGenerationSeconds, locale),
          },
          { label: text.activeQueue, value: String(activeRuns) },
        ]}
      />

      <AdminToolbar className={styles.analyticsToolbar}>
        <div className={styles.segmentedControl} aria-label={text.rangeLabel}>
          {periodOptions.map((option) => {
            const isActivePeriod = option.key === period;

            return (
              <button
                key={option.key}
                type="button"
                className={isActivePeriod ? styles.segmentedButtonActive : styles.segmentedButton}
                disabled={isActivePeriod || isAnalyticsToolbarLocked}
                onClick={() => setPeriod(option.key)}
              >
                <CalendarIcon className={styles.controlIcon} />
                <span>{option.label}</span>
              </button>
            );
          })}
        </div>

        <div className={styles.toolbarActions}>
          <button
            type="button"
            className={isComparisonEnabled ? styles.toolbarButtonActive : styles.toolbarButton}
            aria-pressed={isComparisonEnabled}
            disabled={isAnalyticsToolbarLocked}
            onClick={() => setIsComparisonEnabled((value) => !value)}
          >
            <RefreshIcon className={styles.controlIcon} />
            <span>{text.comparePeriod}</span>
          </button>
          <button
            type="button"
            className={styles.exportButton}
            onClick={handleExportAnalytics}
            disabled={isAnalyticsToolbarLocked}
          >
            <DownloadIcon className={styles.controlIcon} />
            <span>{text.exportAnalytics}</span>
          </button>
        </div>
      </AdminToolbar>

      <TemplateAnalyticsOverviewSection
        kpiCards={kpiCards}
        locale={locale}
        template={template}
        text={text}
      />

      {hasSecondaryPartialError ? (
        <AdminStateCard
          tone="warning"
          title={text.secondaryPartialErrorTitle}
          description={text.secondaryPartialErrorDescription}
          action={
            <Button
              type="button"
              variant="secondary"
              disabled={!canViewTemplateAnalytics || isFetching}
              onClick={requestAnalyticsRetry}
            >
              {text.retryAction}
            </Button>
          }
        />
      ) : null}

      <TemplateAnalyticsVisualSection
        chartMetric={chartMetric}
        chartPoints={chartPoints}
        chartTabs={chartTabs}
        isChartMetricLocked={isAnalyticsToolbarLocked}
        locale={locale}
        onChartMetricChange={setChartMetric}
        statistics={statistics}
        text={text}
      />

      {isSecondaryReady ? (
        <TemplateAnalyticsInsightGridSection
          events={events}
          locale={locale}
          statistics={statistics}
          text={text}
        />
      ) : (
        <div className={styles.insightGrid}>
          <TemplateAnalyticsSectionPlaceholder
            icon={GlobeIcon}
            message={secondaryStateMessage}
            title={text.sourcesTitle}
            hint={text.sourcesHint}
          />
          <TemplateAnalyticsSectionPlaceholder
            icon={TrendUpIcon}
            message={secondaryStateMessage}
            title={text.retentionTitle}
            hint={text.retentionHint}
          />
          <TemplateAnalyticsSectionPlaceholder
            icon={GlobeIcon}
            message={secondaryStateMessage}
            title={text.geographyTitle}
            hint={text.geographyHint}
          />
          <TemplateAnalyticsSectionPlaceholder
            icon={GlobeIcon}
            message={secondaryStateMessage}
            title={text.devicesTitle}
            hint={text.devicesHint}
          />
        </div>
      )}

      <div className={styles.detailsGrid}>
        {isSecondaryReady ? (
          <TemplateAnalyticsRecentRunsSection
            canLoadRecentRuns={canViewTemplateAnalytics}
            canShowFailedRecentRuns={canShowFailedRecentRuns}
            canShowRecentRunModes={shouldShowRecentRunModes}
            error={recentRunsError}
            isLoading={isRecentRunsLoading}
            items={visibleRecentRuns}
            locale={locale}
            mode={recentRunsMode}
            onModeChange={(mode) => void handleRecentRunsModeChange(mode)}
            text={text}
          />
        ) : (
          <TemplateAnalyticsSectionPlaceholder
            wide
            icon={TableIcon}
            message={secondaryStateMessage}
            title={text.recentRunsTitle}
            hint={text.recentRunsHint}
          />
        )}

        {isSecondaryReady ? (
          <TemplateAnalyticsFailureBreakdownSection
            items={failureBreakdown}
            locale={locale}
            text={text}
          />
        ) : (
          <TemplateAnalyticsSectionPlaceholder
            icon={ChartIcon}
            message={secondaryStateMessage}
            title={text.failureBreakdownTitle}
            hint={text.failureBreakdownHint}
          />
        )}
      </div>

      <TemplateAnalyticsFeedbackSection
        error={feedbackError}
        feedbackFilter={feedbackFilter}
        feedbackOptions={feedbackOptions}
        feedbackSearch={feedbackSearchInput}
        isLoading={isFeedbackLoading}
        items={feedbackItems}
        locale={locale}
        onFeedbackFilterChange={setFeedbackFilter}
        onFeedbackSearchChange={(value) =>
          setFeedbackSearchInput(value.slice(0, TEMPLATE_FEEDBACK_SEARCH_MAX_LENGTH))
        }
        text={text}
      />

      {feedbackSummaryQuery.data ? (
        <AdminStateCard
          title={text.feedbackSummaryTitle}
          description={
            feedbackSummaryQuery.data.hasNegativeWarning
              ? text.feedbackSummaryNegativeWarning
              : text.feedbackSummaryDescription
          }
          tone={feedbackSummaryQuery.data.hasNegativeWarning ? "warning" : "info"}
        >
          <AdminMetricStrip
            items={[
              {
                label: text.feedbackSummaryPositive,
                value: `${feedbackSummaryQuery.data.positiveRate.toFixed(1)}% (${feedbackSummaryQuery.data.positiveCount})`,
              },
              {
                label: text.feedbackSummaryNeutral,
                value: `${feedbackSummaryQuery.data.neutralRate.toFixed(1)}% (${feedbackSummaryQuery.data.neutralCount})`,
              },
              {
                label: text.feedbackSummaryNegative,
                value: `${feedbackSummaryQuery.data.negativeRate.toFixed(1)}% (${feedbackSummaryQuery.data.negativeCount})`,
              },
              {
                label: text.feedbackSummaryTopIssues,
                value:
                  feedbackSummaryQuery.data.topIssues
                    .map((issue) => `${sanitizeSensitiveText(issue.category, 80)}: ${issue.count}`)
                    .join(", ") || "-",
              },
            ]}
          />
        </AdminStateCard>
      ) : null}

      <TemplateAnalyticsSnapshotSection
        activeRuns={activeRuns}
        locale={locale}
        statistics={statistics}
        template={template}
        text={text}
      />
    </AdminPage>
  );
}

function TemplateAnalyticsSectionPlaceholder({
  hint,
  icon: Icon,
  message,
  title,
  wide = false,
}: {
  hint: string;
  icon: ComponentType<{ className?: string }>;
  message: string;
  title: string;
  wide?: boolean;
}) {
  return (
    <section
      className={wide ? `${styles.sectionCard} ${styles.sectionCardWide}` : styles.sectionCard}
    >
      <div className={styles.sectionHeader}>
        <h2 className={styles.sectionTitleWithIcon}>
          <Icon className={styles.sectionTitleIcon} />
          <span>{title}</span>
        </h2>
        <p>{hint}</p>
      </div>
      <p className={styles.emptyState}>{message}</p>
    </section>
  );
}
