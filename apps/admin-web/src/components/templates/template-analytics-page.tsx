"use client";

import {
    CalendarIcon,
    ChartIcon,
    DashboardIcon,
    DownloadIcon,
    GlobeIcon,
    RefreshIcon,
    TableIcon,
    TrendUpIcon,
    UsersIcon,
} from "@/components/admin/admin-icons";
import { AdminMetricStrip, AdminPage, AdminStateCard, AdminToolbar } from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { getTemplateAccessLabel, getTemplateStatusLabel } from "@/components/templates/template-admin-shared";
import {
    TemplateAnalyticsFailureBreakdownSection,
    TemplateAnalyticsFeedbackSection,
    TemplateAnalyticsRecentRunsSection,
} from "@/components/templates/template-analytics-detail-sections";
import styles from "@/components/templates/template-analytics-page.module.css";
import {
    buildChartTicks,
    buildPeriodAnalytics,
    calculateChange,
    formatDateTime,
    formatDelta,
    formatDuration,
    formatModelValue,
    formatNumber,
    formatPercent,
    formatShortDate,
    formatTokens,
    formatTrendValue,
    formatUsd,
    getStatusBadgeClassName,
    getTrendMetricValue,
    shortenId,
    totalsFromStatistics,
    type PeriodKey,
    type TrendMetricKey,
} from "@/components/templates/template-analytics-utils";
import { inferTemplateMediaKind } from "@/components/templates/template-media-utils";
import { useAdminTemplateAnalyticsOverview } from "@/components/templates/use-admin-template-analytics-overview";
import { useAdminTemplateFeedback } from "@/components/templates/use-admin-template-feedback";
import {
    fetchAdminTemplateRecentGenerations,
    useAuthSession,
    type AdminTemplate,
    type AdminTemplateEventAnalytics,
    type AdminTemplateRecentGeneration,
    type AdminTemplateStatistics,
    type AdminTemplateTrendPoint,
} from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";
import Image from "next/image";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";

type TemplateAnalyticsPageProps = {
  locale: Locale;
  templateId: string;
};

type AnalyticsCopy = ReturnType<typeof getAnalyticsCopy>;

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
  const isRu = locale === "ru";
  const text = useMemo(() => getAnalyticsCopy(locale), [locale]);
  const router = useRouter();
  const session = useAuthSession();
  const {
    eventAnalytics,
    failureBreakdown,
    hasError,
    isLoading,
    recentRunsPreview,
    statistics,
    template,
    trendPoints,
  } = useAdminTemplateAnalyticsOverview({
    enabled: Boolean(session),
    previewTake: RECENT_RUNS_PREVIEW_LIMIT,
    templateId,
  });
  const [allRecentRuns, setAllRecentRuns] = useState<AdminTemplateRecentGeneration[] | null>(null);
  const [recentRunsMode, setRecentRunsMode] = useState<RecentRunsMode>("latest");
  const [isRecentRunsLoading, setIsRecentRunsLoading] = useState(false);
  const [recentRunsError, setRecentRunsError] = useState<string | null>(null);
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
    enabled: Boolean(session),
    filter: feedbackFilter,
    search: feedbackSearch,
    templateId,
  });
  const error = hasError ? text.loadError : null;
  const feedbackError = hasFeedbackError ? text.feedbackLoadError : null;

  const periodAnalytics = useMemo(() => buildPeriodAnalytics(trendPoints, period), [trendPoints, period]);
  const feedbackOptions: Array<{ key: FeedbackFilterKey; label: string }> = [
    { key: "all", label: text.feedbackFilterAll },
    { key: "complaint", label: text.feedbackFilterComplaint },
    { key: "feedback", label: text.feedbackFilterFeedback },
  ];
  const visibleRecentRuns = useMemo(() => {
    const allRuns = allRecentRuns ?? recentRunsPreview;
    if (recentRunsMode === "all") {
      return allRuns;
    }

    if (recentRunsMode === "failed") {
      return allRuns.filter((run) => run.status === "Failed" || Boolean(run.failureCode) || Boolean(run.failureMessage));
    }

    return recentRunsPreview;
  }, [allRecentRuns, recentRunsMode, recentRunsPreview]);

  useEffect(() => {
    const handle = window.setTimeout(() => {
      setFeedbackSearch(feedbackSearchInput.trim());
    }, 250);

    return () => {
      window.clearTimeout(handle);
    };
  }, [feedbackSearchInput]);

  useEffect(() => {
    if (!session) {
      ensureAdminSession(locale, router);
    }
  }, [locale, router, session]);

  if (isLoading) {
    return (
      <AdminPage className={styles.page}>
        <AdminStateCard tone="info" title={text.loading} />
      </AdminPage>
    );
  }

  if (error || !template || !statistics) {
    return (
      <AdminPage className={styles.page}>
        <AdminStateCard tone="danger" title={error ?? text.loadError} />
      </AdminPage>
    );
  }

  const templateSlug = template.templateType === "Video" ? "video" : "image";
  const catalogPath = `/${locale}/templates/${templateSlug}`;
  const editorPath = `/${locale}/templates/${templateSlug}/editor?templateId=${templateId}`;
  const breadcrumbsRoot = template.templateType === "Video"
    ? (isRu ? "Видео шаблоны" : "Video templates")
    : (isRu ? "Шаблоны изображений" : "Image templates");
  const activeRuns = statistics.queuedRuns + statistics.processingRuns;
  const canShowAllRecentRuns = statistics.totalRuns > RECENT_RUNS_PREVIEW_LIMIT;
  const canShowFailedRecentRuns = statistics.failedRuns > 0;
  const shouldShowRecentRunModes = canShowAllRecentRuns || canShowFailedRecentRuns;
  const events = eventAnalytics ?? EMPTY_EVENT_ANALYTICS;
  const selectedTotals = period === "all" ? totalsFromStatistics(statistics) : periodAnalytics.current;
  const previousTotals = isComparisonEnabled && period !== "all" ? periodAnalytics.previous : null;
  const chartPoints = period === "all" ? trendPoints : periodAnalytics.currentPoints;

  async function handleRecentRunsModeChange(mode: RecentRunsMode) {
    setRecentRunsError(null);

    if (mode === "latest") {
      setRecentRunsMode("latest");
      return;
    }

    setRecentRunsMode(mode);
    if (allRecentRuns || isRecentRunsLoading || !canShowAllRecentRuns) {
      return;
    }

    try {
      setIsRecentRunsLoading(true);
      const response = await fetchAdminTemplateRecentGenerations(templateId);
      setAllRecentRuns(response);
    } catch {
      setRecentRunsMode("latest");
      setRecentRunsError(text.recentRunsExpandError);
    } finally {
      setIsRecentRunsLoading(false);
    }
  }
  const kpiCards = [
    {
      label: text.views,
      value: formatNumber(events.totalViews, locale),
      hint: text.viewsHint,
      accent: "blue" as MetricAccent,
    },
    {
      label: text.generationStarts,
      value: formatNumber(selectedTotals.totalRuns, locale),
      hint: text.generationStartsHint,
      accent: "blue" as MetricAccent,
      delta: calculateChange(selectedTotals.totalRuns, previousTotals?.totalRuns),
    },
    {
      label: text.successfulGenerations,
      value: formatNumber(selectedTotals.completedRuns, locale),
      hint: text.successfulGenerationsHint,
      accent: "green" as MetricAccent,
      delta: calculateChange(selectedTotals.completedRuns, previousTotals?.completedRuns),
    },
    {
      label: text.generationConversion,
      value: formatPercent(selectedTotals.successRatePercent, isRu),
      hint: text.generationConversionHint,
      accent: "green" as MetricAccent,
      delta: calculateChange(selectedTotals.successRatePercent, previousTotals?.successRatePercent),
    },
    {
      label: text.tokenSpend,
      value: formatTokens(selectedTotals.totalTokenCost, isRu),
      hint: text.tokenSpendHint,
      accent: "cyan" as MetricAccent,
      delta: calculateChange(selectedTotals.totalTokenCost, previousTotals?.totalTokenCost),
    },
    {
      label: text.complaints,
      value: formatNumber(events.totalComplaints, locale),
      hint: text.complaintsHint,
      accent: events.totalComplaints > 0 ? "red" as MetricAccent : "neutral" as MetricAccent,
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
      template,
      statistics,
      selectedTotals,
      trendPoints: chartPoints,
      recentRuns: visibleRecentRuns,
      failureBreakdown,
      eventAnalytics: events,
    };
    const blob = new Blob([JSON.stringify(payload, null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `template-${template.templateId}-analytics.json`;
    link.click();
    URL.revokeObjectURL(url);
  }

  return (
    <AdminPage className={styles.page}>
      <div className={styles.pageHeaderRow}>
        <div className={styles.breadcrumbs}>
          <Link href={catalogPath}>{breadcrumbsRoot}</Link>
          <span aria-hidden="true">/</span>
          <Link href={editorPath}>{template.title}</Link>
          <span aria-hidden="true">/</span>
          <span>{text.pageTitle}</span>
        </div>

        <div className={styles.heroActions}>
          <Link href={catalogPath} className={styles.secondaryLink}><TableIcon className={styles.controlIcon} /><span>{text.backToCatalog}</span></Link>
          <Link href={editorPath} className={styles.primaryLink}><ChartIcon className={styles.controlIcon} /><span>{text.openEditor}</span></Link>
        </div>
      </div>

      <AdminMetricStrip
        className={styles.metricStrip}
        items={[
          { label: text.lastRun, value: formatDateTime(statistics.lastRunAtUtc, locale) },
          { label: text.lastCompleted, value: formatDateTime(statistics.lastCompletedAtUtc, locale) },
          { label: text.averageGenerationTime, value: formatDuration(statistics.averageGenerationSeconds, isRu) },
          { label: text.activeQueue, value: String(activeRuns) },
        ]}
      />

      <AdminToolbar className={styles.analyticsToolbar}>
        <div className={styles.segmentedControl} aria-label={text.rangeLabel}>
          {periodOptions.map((option) => (
            <button
              key={option.key}
              type="button"
              className={option.key === period ? styles.segmentedButtonActive : styles.segmentedButton}
              onClick={() => setPeriod(option.key)}
            >
              <CalendarIcon className={styles.controlIcon} />
              <span>{option.label}</span>
            </button>
          ))}
        </div>

        <div className={styles.toolbarActions}>
          <button
            type="button"
            className={isComparisonEnabled ? styles.toolbarButtonActive : styles.toolbarButton}
            aria-pressed={isComparisonEnabled}
            onClick={() => setIsComparisonEnabled((value) => !value)}
          >
            <RefreshIcon className={styles.controlIcon} />
            <span>{text.comparePeriod}</span>
          </button>
          <button type="button" className={styles.exportButton} onClick={handleExportAnalytics}>
            <DownloadIcon className={styles.controlIcon} />
            <span>{text.exportAnalytics}</span>
          </button>
        </div>
        </AdminToolbar>

      <div className={styles.overviewGrid}>
        <TemplateProfileCard template={template} locale={locale} text={text} isRu={isRu} />

        <div className={styles.kpiGrid}>
          {kpiCards.map((card, index) => (
            <KpiCard
              key={`${card.label}-${index}`}
              label={card.label}
              value={card.value}
              hint={card.hint}
              accent={card.accent}
              delta={card.delta}
              text={text}
              isRu={isRu}
            />
          ))}
        </div>
      </div>

      <div className={styles.visualGrid}>
        <section className={`${styles.sectionCard} ${styles.sectionCardWide}`}>
          <div className={styles.sectionHeaderRow}>
            <div className={styles.sectionHeader}>
              <h2 className={styles.sectionTitleWithIcon}><TrendUpIcon className={styles.sectionTitleIcon} /><span>{text.trendTitle}</span></h2>
              <p>{text.trendHint}</p>
            </div>

            <div className={styles.chartTabs} aria-label={text.trendTitle}>
              {chartTabs.map((tab) => (
                <button
                  key={tab.key}
                  type="button"
                  className={tab.key === chartMetric ? styles.chartTabActive : styles.chartTab}
                  onClick={() => setChartMetric(tab.key)}
                >
                  <ChartIcon className={styles.controlIcon} />
                  <span>{tab.label}</span>
                </button>
              ))}
            </div>
          </div>
          <TrendChart points={chartPoints} metric={chartMetric} locale={locale} emptyLabel={text.trendEmpty} text={text} />
        </section>
        <section className={styles.sectionCard}>
          <div className={styles.sectionHeader}>
            <h2 className={styles.sectionTitleWithIcon}><DashboardIcon className={styles.sectionTitleIcon} /><span>{text.statusBreakdownTitle}</span></h2>
            <p>{text.statusBreakdownHint}</p>
          </div>
          <StatusRing statistics={statistics} text={text} isRu={isRu} />
        </section>
      </div>

      <div className={styles.insightGrid}>
        <AnalyticsDimensionPanel
          title={text.sourcesTitle}
          hint={text.sourcesHint}
          emptyText={text.instrumentationPending}
          rows={events.sources}
          locale={locale}
        />
        <FunnelPanel statistics={statistics} text={text} isRu={isRu} />
        <AnalyticsDimensionPanel
          title={text.geographyTitle}
          hint={text.geographyHint}
          emptyText={text.instrumentationPending}
          rows={events.geography}
          locale={locale}
        />
        <AnalyticsDimensionPanel
          title={text.devicesTitle}
          hint={text.devicesHint}
          emptyText={text.instrumentationPending}
          rows={events.devices}
          locale={locale}
        />
      </div>

      <div className={styles.detailsGrid}>
        <TemplateAnalyticsRecentRunsSection
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

        <TemplateAnalyticsFailureBreakdownSection
          items={failureBreakdown}
          locale={locale}
          text={text}
        />
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
        onFeedbackSearchChange={setFeedbackSearchInput}
        text={text}
      />

      <section className={styles.sectionCard}>
        <div className={styles.sectionHeader}>
          <h2 className={styles.sectionTitleWithIcon}><UsersIcon className={styles.sectionTitleIcon} /><span>{text.snapshotTitle}</span></h2>
          <p>{text.snapshotHint}</p>
        </div>

        <div className={styles.summaryGrid}>
          <SummaryRow label={text.totalRuns} value={String(statistics.totalRuns)} />
          <SummaryRow label={text.completedRuns} value={String(statistics.completedRuns)} />
          <SummaryRow label={text.failedRuns} value={String(statistics.failedRuns)} />
          <SummaryRow label={text.runsInQueue} value={String(statistics.queuedRuns)} />
          <SummaryRow label={text.processingNow} value={String(statistics.processingRuns)} />
          <SummaryRow label={text.successRate} value={formatPercent(statistics.successRatePercent, isRu)} />
          <SummaryRow label={text.totalTokenCost} value={formatTokens(statistics.totalTokenCost, isRu)} />
          <SummaryRow label={text.averageTokenCost} value={formatTokens(statistics.averageTokenCost, isRu)} />
          <SummaryRow label={text.averageGenerationTime} value={formatDuration(statistics.averageGenerationSeconds, isRu)} />
          <SummaryRow label={text.lastRun} value={formatDateTime(statistics.lastRunAtUtc, locale)} />
          <SummaryRow label={text.lastCompleted} value={formatDateTime(statistics.lastCompletedAtUtc, locale)} />
          <SummaryRow label={text.activeQueue} value={String(activeRuns)} />
          <SummaryRow label={text.estimatedTemplateCostLabel} value={formatUsd(template.estimatedProviderCostUsd, locale)} />
          <SummaryRow label={text.preprocessingModel} value={formatModelValue(template.preprocessingModel)} />
          <SummaryRow label={text.motionModel} value={formatModelValue(template.klingModel)} />
        </div>

        {!statistics.totalRuns ? <p className={styles.emptyState}>{text.noData}</p> : null}
      </section>
    </AdminPage>
  );
}

function TemplateProfileCard({ template, locale, text, isRu }: { template: AdminTemplate; locale: Locale; text: AnalyticsCopy; isRu: boolean }) {
  const dictionary = getDictionary(locale);
  const previewUrl = template.previewAsset?.url;
  const previewContentType = template.previewAsset?.contentType ?? "";
  const previewKind = previewUrl ? inferTemplateMediaKind(previewContentType, previewUrl) : null;
  const [brokenPreviewUrl, setBrokenPreviewUrl] = useState<string | null>(null);
  const isPreviewBroken = previewUrl === brokenPreviewUrl;

  return (
    <article className={styles.templateCard}>
      <div className={`${styles.templatePreviewWrap} ${previewKind === "video" ? styles.templatePreviewWrapVideo : ""}`.trim()}>
        {previewUrl && !isPreviewBroken ? (
          previewKind === "video" ? (
            <video
              src={previewUrl}
              className={styles.templatePreviewImage}
              muted
              playsInline
              autoPlay
              loop
              preload="metadata"
              onError={() => setBrokenPreviewUrl(previewUrl)}
            />
          ) : (
            <Image src={previewUrl} alt="" width={480} height={600} unoptimized className={styles.templatePreviewImage} onError={() => setBrokenPreviewUrl(previewUrl)} />
          )
        ) : (
          <div className={styles.templatePreviewFallback}>{template.title.slice(0, 1)}</div>
        )}
      </div>

      <div className={styles.templateCardBody}>
        <div className={styles.templateTitleRow}>
          <div>
            <span>{text.templateOverviewTitle}</span>
            <h2>{template.title}</h2>
          </div>
          <span className={`${styles.statusBadge} ${styles[getStatusBadgeClassName(template.status)]}`}>{getTemplateStatusLabel(template.status, locale)}</span>
        </div>

        <p>{template.shortDescription}</p>

        <div className={styles.templateMetaGrid}>
          <SummaryRow label={text.templateIdLabel} value={shortenId(template.templateId)} />
          <SummaryRow label={text.categoryLabel} value={template.category} />
          <SummaryRow label={text.priceLabel} value={getTemplateAccessLabel(template.isPremium, dictionary)} />
          <SummaryRow label={text.tokenCostLabel} value={formatTokens(template.tokenCost, isRu)} />
          <SummaryRow label={text.estimatedTemplateCostLabel} value={formatUsd(template.estimatedProviderCostUsd, locale)} />
          <SummaryRow label={text.createdLabel} value={formatDateTime(template.createdAtUtc, locale)} />
          <SummaryRow label={text.updatedLabel} value={formatDateTime(template.updatedAtUtc, locale)} />
        </div>
      </div>
    </article>
  );
}

function KpiCard({
  label,
  value,
  hint,
  accent,
  delta,
  text,
  isRu,
}: {
  label: string;
  value: string;
  hint: string;
  accent: MetricAccent;
  delta?: number | null;
  text: AnalyticsCopy;
  isRu: boolean;
}) {
  const deltaClassName = typeof delta === "number" && delta < 0 ? styles.deltaNegative : styles.deltaPositive;

  return (
    <article className={`${styles.statCard} ${styles[`statCard_${accent}`]}`}>
      <span>{label}</span>
      <strong>{value}</strong>
      <p>{hint}</p>
      {typeof delta === "number" ? (
        <small className={deltaClassName}>{formatDelta(delta, isRu)}</small>
      ) : (
        <small className={styles.deltaMuted}>{text.compareNoBase}</small>
      )}
    </article>
  );
}

function AnalyticsDimensionPanel({
  title,
  hint,
  emptyText,
  rows,
  locale,
}: {
  title: string;
  hint: string;
  emptyText: string;
  rows: readonly { key: string; label: string; count: number; sharePercent: number }[];
  locale: Locale;
}) {
  return (
    <section className={styles.sectionCard}>
      <div className={styles.sectionHeader}>
        <h2 className={styles.sectionTitleWithIcon}><GlobeIcon className={styles.sectionTitleIcon} /><span>{title}</span></h2>
        <p>{hint}</p>
      </div>
      {rows.length ? (
        <div className={styles.pendingList}>
          {rows.map((row) => (
            <div key={row.key} className={styles.dimensionRow}>
              <div>
                <span>{row.label}</span>
                <strong>{formatPercent(row.sharePercent, locale === "ru")}</strong>
                <em>{formatNumber(row.count, locale)}</em>
              </div>
              <i style={{ width: `${Math.min(100, Math.max(0, row.sharePercent))}%` }} />
            </div>
          ))}
        </div>
      ) : (
        <p className={styles.instrumentationNote}>{emptyText}</p>
      )}
    </section>
  );
}

function FunnelPanel({ statistics, text, isRu }: { statistics: AdminTemplateStatistics; text: AnalyticsCopy; isRu: boolean }) {
  const total = Math.max(statistics.totalRuns, 1);
  const rows = [
    { label: text.funnelStarted, value: statistics.totalRuns, percent: 100 },
    { label: text.funnelCompleted, value: statistics.completedRuns, percent: (statistics.completedRuns / total) * 100 },
    { label: text.funnelFailed, value: statistics.failedRuns, percent: (statistics.failedRuns / total) * 100 },
    { label: text.funnelActive, value: statistics.queuedRuns + statistics.processingRuns, percent: ((statistics.queuedRuns + statistics.processingRuns) / total) * 100 },
  ];

  return (
    <section className={styles.sectionCard}>
      <div className={styles.sectionHeader}>
        <h2 className={styles.sectionTitleWithIcon}><TrendUpIcon className={styles.sectionTitleIcon} /><span>{text.retentionTitle}</span></h2>
        <p>{text.retentionHint}</p>
      </div>
      <div className={styles.funnelList}>
        {rows.map((row) => (
          <div key={row.label} className={styles.funnelRow}>
            <div>
              <span>{row.label}</span>
              <strong>{formatPercent(row.percent, isRu)}</strong>
              <em>{formatNumber(row.value, isRu ? "ru" : "en")}</em>
            </div>
            <i style={{ width: `${Math.min(100, Math.max(0, row.percent))}%` }} />
          </div>
        ))}
      </div>
      </section>
  );
}

function SummaryRow({ label, value }: { label: string; value: string }) {
  return (
    <div className={styles.summaryRow}>
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function TrendChart({
  points,
  metric,
  locale,
  emptyLabel,
  text,
}: {
  points: readonly AdminTemplateTrendPoint[];
  metric: TrendMetricKey;
  locale: Locale;
  emptyLabel: string;
  text: AnalyticsCopy;
}) {
  if (!points.length) {
    return <p className={styles.emptyState}>{emptyLabel}</p>;
  }

  const width = 720;
  const height = 260;
  const paddingX = 26;
  const paddingTop = 20;
  const paddingBottom = 42;
  const graphWidth = width - paddingX * 2;
  const graphHeight = height - paddingTop - paddingBottom;
  const values = points.map((point) => getTrendMetricValue(point, metric));
  const rawMaxValue = Math.max(...values, 1);
  const yTicks = buildChartTicks(rawMaxValue);
  const maxValue = Math.max(yTicks[0] ?? rawMaxValue, 1);

  const coordinates = points.map((point, index) => {
    const value = getTrendMetricValue(point, metric);
    const x = points.length === 1
      ? width / 2
      : paddingX + (graphWidth * index) / (points.length - 1);
    const y = paddingTop + graphHeight - (value / maxValue) * graphHeight;
    return { point, value, x, y };
  });

  const linePath = coordinates
    .map(({ x, y }, index) => `${index === 0 ? "M" : "L"} ${x.toFixed(2)} ${y.toFixed(2)}`)
    .join(" ");
  const areaPath = `${linePath} L ${coordinates[coordinates.length - 1]!.x.toFixed(2)} ${(paddingTop + graphHeight).toFixed(2)} L ${coordinates[0]!.x.toFixed(2)} ${(paddingTop + graphHeight).toFixed(2)} Z`;

  return (
    <div className={styles.chartShell}>
      <svg viewBox={`0 0 ${width} ${height}`} className={styles.chartSvg} aria-label="Template analytics trend chart" role="img">
        <defs>
          <linearGradient id="template-analytics-area" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0%" stopColor="rgba(74, 222, 128, 0.36)" />
            <stop offset="100%" stopColor="rgba(74, 222, 128, 0.02)" />
          </linearGradient>
        </defs>

        {yTicks.map((tick, index) => {
          const y = paddingTop + (graphHeight * index) / (yTicks.length - 1 || 1);
          return (
            <g key={`${tick}-${index}`}>
              <line x1={paddingX} y1={y} x2={width - paddingX} y2={y} className={styles.chartGridLine} />
              <text x={paddingX} y={y - 6} className={styles.chartTick}>{formatTrendValue(tick, metric, locale, text.failedRuns)}</text>
            </g>
          );
        })}

        <path d={areaPath} className={styles.chartArea} />
        <path d={linePath} className={styles.chartLine} />

        {coordinates.map(({ point, value, x, y }) => {
          const label = formatTrendValue(value, metric, locale, text.failedRuns);
          const labelWidth = Math.max(48, Math.min(132, label.length * 7.2 + 20));
          const labelX = Math.min(width - paddingX - labelWidth, Math.max(paddingX, x - labelWidth / 2));
          const labelY = Math.max(8, y - 34);

          return (
          <g key={point.dateUtc}>
            <rect x={labelX} y={labelY} width={labelWidth} height="24" rx="8" className={styles.chartPointBadge} />
            <text x={labelX + labelWidth / 2} y={labelY + 16} textAnchor="middle" className={styles.chartPointValue}>{label}</text>
            <circle cx={x} cy={y} r="4.5" className={styles.chartDot} />
            <text x={x} y={height - 12} textAnchor="middle" className={styles.chartLabel}>
              {formatShortDate(point.dateUtc, locale)}
            </text>
          </g>
          );
        })}
      </svg>

      <div className={styles.chartSummaryRow}>
        {points.slice(-4).map((point) => (
          <div key={point.dateUtc} className={styles.chartSummaryItem}>
            <span>{formatShortDate(point.dateUtc, locale)}</span>
            <strong>{formatTrendValue(getTrendMetricValue(point, metric), metric, locale, text.failedRuns)}</strong>
          </div>
        ))}
      </div>
    </div>
  );
}
function StatusRing({ statistics, text, isRu }: { statistics: AdminTemplateStatistics; text: AnalyticsCopy; isRu: boolean }) {
  const total = Math.max(statistics.totalRuns, 1);
  const segments = [
    { label: text.completedRuns, value: statistics.completedRuns, color: "#22c55e" },
    { label: text.failedRuns, value: statistics.failedRuns, color: "#f87171" },
    { label: text.runsInQueue, value: statistics.queuedRuns, color: "#7dd3fc" },
    { label: text.processingNow, value: statistics.processingRuns, color: "#fcd34d" },
  ];

  let offset = 0;
  const gradient = segments
    .filter((segment) => segment.value > 0)
    .map((segment) => {
      const start = offset;
      offset += (segment.value / total) * 100;
      return `${segment.color} ${start}% ${offset}%`;
    })
    .join(", ");
  const background = gradient ? `conic-gradient(${gradient})` : "conic-gradient(#1f3651 0 100%)";

  return (
    <div className={styles.ringSection}>
      <div className={styles.ringWrap}>
        <div className={styles.ringOuter} style={{ background }}>
          <div className={styles.ringInner}>
            <strong>{statistics.totalRuns}</strong>
            <span>{isRu ? "запусков" : "runs"}</span>
          </div>
        </div>
      </div>

      <div className={styles.breakdownList}>
        {segments.map((segment) => (
          <div key={segment.label} className={styles.breakdownItem}>
            <span>
              <i className={styles.breakdownDot} style={{ backgroundColor: segment.color }} />
              {segment.label}
            </span>
            <strong>{segment.value}</strong>
          </div>
        ))}
      </div>
    </div>
  );
}

function getAnalyticsCopy(locale: Locale) {
  const isRu = locale === "ru";

  return {
    breadcrumbsRoot: isRu ? "Видео шаблоны" : "Video templates",
    eyebrow: isRu ? "Аналитика шаблона" : "Template analytics",
    pageTitle: isRu ? "Аналитика" : "Analytics",
    pageDescription: isRu
      ? "Первая версия аналитики строится на реальных generation metrics шаблона: запуски, успешность, токены, история и breakdown по сбоям."
      : "The first analytics version is built on real template generation metrics: runs, success rate, tokens, history, and failure breakdown.",
    backToCatalog: isRu ? "К каталогу" : "Back to catalog",
    openEditor: isRu ? "Открыть редактор" : "Open editor",
    loading: isRu ? "Загрузка аналитики шаблона..." : "Loading template analytics...",
    loadError: isRu ? "Не удалось загрузить аналитику шаблона." : "Failed to load template analytics.",
    rangeLabel: isRu ? "Период аналитики" : "Analytics period",
    range7: isRu ? "7 дней" : "7 days",
    range30: isRu ? "30 дней" : "30 days",
    range90: isRu ? "90 дней" : "90 days",
    rangeAll: isRu ? "Всё время" : "All time",
    comparePeriod: isRu ? "Сравнить период" : "Compare period",
    exportAnalytics: isRu ? "Экспорт JSON" : "Export JSON",
    compareNoBase: isRu ? "нет базы сравнения" : "no comparison base",
    statusLabel: isRu ? "Статус" : "Status",
    templateOverviewTitle: isRu ? "Карточка шаблона" : "Template card",
    templateIdLabel: "ID",
    categoryLabel: isRu ? "Категория" : "Category",
    priceLabel: isRu ? "Доступ" : "Access",
    tokenCostLabel: isRu ? "Цена запуска" : "Run price",
    estimatedTemplateCostLabel: isRu ? "Себестоимость, $" : "Provider cost, $",
    createdLabel: isRu ? "Создан" : "Created",
    updatedLabel: isRu ? "Обновлён" : "Updated",
    totalRuns: isRu ? "Всего запусков" : "Total runs",
    successRate: isRu ? "Успешность" : "Success rate",
    completedRuns: isRu ? "Успешные" : "Completed",
    failedRuns: isRu ? "Ошибки" : "Failed",
    totalTokenCost: isRu ? "Всего токенов" : "Total token cost",
    averageTokenCost: isRu ? "Средний cost" : "Average token cost",
    views: isRu ? "Просмотры" : "Views",
    viewsHint: isRu ? "События view из публичного template endpoint." : "View events from the public template endpoint.",
    generationStarts: isRu ? "Запуски генерации" : "Generation starts",
    generationStartsHint: isRu ? "Созданные задания генерации за выбранный период." : "Generation jobs created in the selected period.",
    successfulGenerations: isRu ? "Успешные генерации" : "Successful generations",
    successfulGenerationsHint: isRu ? "Задания, завершённые готовым видео." : "Jobs completed with an output video.",
    generationConversion: isRu ? "Конверсия в результат" : "Result conversion",
    generationConversionHint: isRu ? "Доля успешных jobs среди запусков." : "Completed jobs as a share of started jobs.",
    tokenSpend: isRu ? "Потрачено токенов" : "Token spend",
    tokenSpendHint: isRu ? "Суммарная стоимость запусков в токенах." : "Total token cost of runs.",
    complaints: isRu ? "Жалобы" : "Complaints",
    complaintsHint: isRu ? "События complaint из публичного analytics endpoint." : "Complaint events from the public analytics endpoint.",
    feedbackTitle: isRu ? "Жалобы и фидбек" : "Complaints and feedback",
    feedbackHint: isRu ? "Последние обращения пользователей по шаблону: complaint и feedback события с текстом и метаданными." : "Latest user complaints and feedback for this template with message text and event metadata.",
    feedbackFilterLabel: isRu ? "Фильтр фидбека" : "Feedback filter",
    feedbackFilterAll: isRu ? "Все" : "All",
    feedbackFilterComplaint: isRu ? "Жалобы" : "Complaints",
    feedbackFilterFeedback: isRu ? "Фидбек" : "Feedback",
    feedbackSearchLabel: isRu ? "Поиск по тексту фидбека" : "Search feedback text",
    feedbackSearchPlaceholder: isRu ? "Поиск по тексту сообщения" : "Search message text",
    feedbackLoading: isRu ? "Загрузка обращений..." : "Loading feedback...",
    feedbackEmpty: isRu ? "Пока нет пользовательских жалоб или фидбека по этому шаблону." : "There is no user complaint or feedback for this template yet.",
    feedbackFilteredEmpty: isRu ? "По текущему фильтру и поиску ничего не найдено." : "No items matched the current filter and search.",
    feedbackLoadError: isRu ? "Не удалось загрузить жалобы и фидбек." : "Failed to load complaints and feedback.",
    feedbackMessageMissing: isRu ? "Без текста сообщения." : "No message text provided.",
    feedbackTypeComplaint: isRu ? "Жалоба" : "Complaint",
    feedbackTypeFeedback: isRu ? "Фидбек" : "Feedback",
    feedbackSourceLabel: isRu ? "Источник" : "Source",
    feedbackDeviceLabel: isRu ? "Устройство" : "Device",
    feedbackCountryLabel: isRu ? "Страна" : "Country",
    activeQueue: isRu ? "Активная очередь" : "Active queue",
    averageGenerationTime: isRu ? "Среднее время" : "Average generation time",
    lastRun: isRu ? "Последний запуск" : "Last run",
    lastCompleted: isRu ? "Последний успех" : "Last completed",
    overviewHint: isRu ? "Текущий read model по шаблону" : "Current template read model",
    snapshotTitle: isRu ? "Сводка по шаблону" : "Template snapshot",
    snapshotHint: isRu ? "Этот блок собирается из существующей admin statistics модели и служит опорной сводкой для dashboard выше." : "This block is built from the existing admin statistics model and acts as the anchor summary for the dashboard above.",
    trendTitle: isRu ? "Динамика запусков" : "Run trend",
    trendHint: isRu ? "Группировка generation jobs по дням создания шаблонных запусков." : "Generation jobs grouped by creation day.",
    trendEmpty: isRu ? "Для этого шаблона ещё нет исторических точек тренда." : "There are no trend points for this template yet.",
    chartRuns: isRu ? "Запуски" : "Runs",
    chartCompleted: isRu ? "Успешные" : "Completed",
    chartFailed: isRu ? "Ошибки" : "Failed",
    chartTokens: isRu ? "Токены" : "Tokens",
    chartDuration: isRu ? "Время" : "Duration",
    statusBreakdownTitle: isRu ? "Состояние пайплайна" : "Pipeline health",
    statusBreakdownHint: isRu ? "Распределение текущих и завершённых состояний генерации." : "Distribution of current and completed generation pipeline states.",
    runsInQueue: isRu ? "В очереди" : "Queued",
    processingNow: isRu ? "В обработке" : "Processing",
    sourcesTitle: isRu ? "Источники просмотров" : "View sources",
    sourcesHint: isRu ? "Реальные source breakdown из template view events." : "Real source breakdown from template view events.",
    instrumentationPending: isRu ? "Нужна запись событий в публичном приложении/API, чтобы показывать эти метрики без догадок." : "Public app/API instrumentation is required to show this without guessing.",
    sourceHome: isRu ? "Главная" : "Home",
    sourceCategories: isRu ? "Категории" : "Categories",
    sourceSearch: isRu ? "Поиск" : "Search",
    sourceProfile: isRu ? "Профиль" : "Profile",
    retentionTitle: isRu ? "Воронка генерации" : "Generation funnel",
    retentionHint: isRu ? "Реальная operational воронка по generation jobs." : "Real operational funnel from generation jobs.",
    funnelStarted: isRu ? "Начали генерацию" : "Started generation",
    funnelCompleted: isRu ? "Дождались результата" : "Completed result",
    funnelFailed: isRu ? "Получили ошибку" : "Failed",
    funnelActive: isRu ? "Ещё в работе" : "Still active",
    geographyTitle: isRu ? "География пользователей" : "User geography",
    geographyHint: isRu ? "Реальная география из событий public traffic, если страна была записана." : "Real geography from public traffic events when country was captured.",
    countryUnknown: isRu ? "Страна не определена" : "Country unknown",
    countryHeader: isRu ? "Страна" : "Country",
    viewsHeader: isRu ? "Просмотры" : "Views",
    startsHeader: isRu ? "Запуски" : "Starts",
    devicesTitle: isRu ? "Устройства" : "Devices",
    devicesHint: isRu ? "Реальное распределение устройств из записанных analytics events." : "Real device distribution from recorded analytics events.",
    deviceIos: "iOS",
    deviceAndroid: "Android",
    deviceWeb: "Web",
    recentRunsTitle: isRu ? "Последние генерации" : "Recent generations",
    recentRunsHint: isRu ? "Последние задания по этому шаблону с минимальным operational срезом." : "Latest jobs for this template with a compact operational snapshot.",
    recentRunsAllHint: isRu ? "Все доступные генерации по этому шаблону за весь период, который хранится в системе." : "All available generations for this template across the full retained history.",
    recentRunsLatest: isRu ? "Последние" : "Latest",
    recentRunsAll: isRu ? "Все генерации" : "All generations",
    recentRunsFailed: isRu ? "Ошибочные" : "Failed only",
    recentRunsLoading: isRu ? "Загрузка..." : "Loading...",
    recentRunsExpandError: isRu ? "Не удалось загрузить полный список генераций." : "Failed to load the full generation history.",
    recentRunsEmpty: isRu ? "У шаблона пока нет недавних генераций." : "This template has no recent generations yet.",
    failedRunsHint: isRu ? "Все завершившиеся с ошибкой генерации по шаблону с кодом и текстом причины." : "All failed generations for this template with failure code and reason text.",
    failedRunsEmpty: isRu ? "По этому шаблону пока нет ошибочных генераций." : "There are no failed generations for this template yet.",
    generationIdHeader: isRu ? "ID генерации" : "Generation ID",
    userHeader: isRu ? "Пользователь" : "User",
    recentCreated: isRu ? "Создан" : "Created",
    recentStatus: isRu ? "Статус" : "Status",
    recentTokens: isRu ? "Токены" : "Tokens",
    recentDuration: isRu ? "Время" : "Duration",
    recentModels: isRu ? "Модели" : "Models",
    failureCodeHeader: isRu ? "Код ошибки" : "Failure code",
    failureReasonHeader: isRu ? "Причина" : "Reason",
    recentOutput: isRu ? "Выход" : "Output",
    openOutput: isRu ? "Открыть" : "Open",
    noOutput: isRu ? "Нет" : "None",
    failureBreakdownTitle: isRu ? "Breakdown ошибок" : "Failure breakdown",
    failureBreakdownHint: isRu ? "Сводка по failure codes из завершившихся с ошибкой generation jobs." : "Summary of failure codes from failed generation jobs.",
    failuresEmpty: isRu ? "Пока нет зарегистрированных ошибок по этому шаблону." : "There are no recorded failures for this template yet.",
    lastFailure: isRu ? "Последняя" : "Last",
    unknownFailure: isRu ? "Неизвестная ошибка" : "Unknown failure",
    totalProviderCost: isRu ? "Всего реальных затрат" : "Total real spend",
    recentProviderCost: isRu ? "Затраты в последних jobs" : "Cost in recent jobs",
    preprocessingModel: isRu ? "Image model" : "Image model",
    motionModel: isRu ? "Motion model" : "Motion model",
    noData: isRu ? "У шаблона пока нет запусков. После первых генераций здесь появятся полноценные метрики." : "This template has no runs yet. Full metrics will appear here after the first generations.",
  };
}

