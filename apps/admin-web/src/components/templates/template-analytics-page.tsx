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
    VideoIcon,
} from "@/components/admin/admin-icons";
import { AdminMetricStrip } from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { getTemplateAccessLabel, getTemplateStatusLabel } from "@/components/templates/template-admin-shared";
import styles from "@/components/templates/template-analytics-page.module.css";
import { inferTemplateMediaKind } from "@/components/templates/template-media-utils";
import {
    fetchAdminTemplate,
    fetchAdminTemplateEventAnalytics,
    fetchAdminTemplateFailureBreakdown,
    fetchAdminTemplateFeedback,
    fetchAdminTemplateRecentGenerations,
    fetchAdminTemplateStatistics,
    fetchAdminTemplateTrends,
    type AdminTemplate,
    type AdminTemplateEventAnalytics,
    type AdminTemplateFailureBreakdownItem,
    type AdminTemplateFeedbackItem,
    type AdminTemplateRecentGeneration,
    type AdminTemplateStatistics,
    type AdminTemplateTrendPoint,
    type TemplateGenerationJobStatus,
    type TemplateStatus,
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

type PeriodKey = "7d" | "30d" | "90d" | "all";
type TrendMetricKey = "totalRuns" | "completedRuns" | "failedRuns" | "totalTokenCost" | "averageGenerationSeconds";
type MetricAccent = "blue" | "green" | "red" | "cyan" | "neutral";
type RecentRunsMode = "latest" | "all" | "failed";

const RECENT_RUNS_PREVIEW_LIMIT = 8;

type TrendTotals = {
  totalRuns: number;
  queuedRuns: number;
  processingRuns: number;
  completedRuns: number;
  failedRuns: number;
  totalTokenCost: number;
  totalProviderCostUsd: number;
  averageGenerationSeconds: number | null;
  successRatePercent: number;
};

type PeriodAnalytics = {
  currentPoints: AdminTemplateTrendPoint[];
  previousPoints: AdminTemplateTrendPoint[];
  current: TrendTotals;
  previous: TrendTotals | null;
};

const PERIOD_DAY_COUNTS: Record<Exclude<PeriodKey, "all">, number> = {
  "7d": 7,
  "30d": 30,
  "90d": 90,
};

const EMPTY_EVENT_ANALYTICS: AdminTemplateEventAnalytics = {
  totalViews: 0,
  totalVideoViews: 0,
  totalComplaints: 0,
  sources: [],
  devices: [],
  geography: [],
};

export function TemplateAnalyticsPage({ locale, templateId }: TemplateAnalyticsPageProps) {
  const isRu = locale === "ru";
  const text = useMemo(() => getAnalyticsCopy(locale), [locale]);
  const router = useRouter();
  const [template, setTemplate] = useState<AdminTemplate | null>(null);
  const [statistics, setStatistics] = useState<AdminTemplateStatistics | null>(null);
  const [trendPoints, setTrendPoints] = useState<AdminTemplateTrendPoint[]>([]);
  const [recentRunsPreview, setRecentRunsPreview] = useState<AdminTemplateRecentGeneration[]>([]);
  const [allRecentRuns, setAllRecentRuns] = useState<AdminTemplateRecentGeneration[] | null>(null);
  const [recentRunsMode, setRecentRunsMode] = useState<RecentRunsMode>("latest");
  const [isRecentRunsLoading, setIsRecentRunsLoading] = useState(false);
  const [recentRunsError, setRecentRunsError] = useState<string | null>(null);
  const [failureBreakdown, setFailureBreakdown] = useState<AdminTemplateFailureBreakdownItem[]>([]);
  const [feedbackItems, setFeedbackItems] = useState<AdminTemplateFeedbackItem[]>([]);
  const [eventAnalytics, setEventAnalytics] = useState<AdminTemplateEventAnalytics | null>(null);
  const [period, setPeriod] = useState<PeriodKey>("30d");
  const [chartMetric, setChartMetric] = useState<TrendMetricKey>("totalRuns");
  const [isComparisonEnabled, setIsComparisonEnabled] = useState(true);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const periodAnalytics = useMemo(() => buildPeriodAnalytics(trendPoints, period), [trendPoints, period]);
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
    let isCancelled = false;

    async function loadAnalytics() {
      setIsLoading(true);
      setError(null);
      setRecentRunsError(null);
      setRecentRunsMode("latest");
      setAllRecentRuns(null);

      try {
        if (!ensureAdminSession(locale, router)) {
          return;
        }

        const [
          templateResponse,
          statisticsResponse,
          trendResponse,
          recentResponse,
          failureResponse,
          feedbackResponse,
          eventResponse,
        ] = await Promise.all([
          fetchAdminTemplate(templateId),
          fetchAdminTemplateStatistics(templateId),
          fetchAdminTemplateTrends(templateId),
          fetchAdminTemplateRecentGenerations(templateId, RECENT_RUNS_PREVIEW_LIMIT),
          fetchAdminTemplateFailureBreakdown(templateId),
          fetchAdminTemplateFeedback(templateId),
          fetchAdminTemplateEventAnalytics(templateId),
        ]);

        if (isCancelled) {
          return;
        }

        setTemplate(templateResponse);
        setStatistics(statisticsResponse);
        setTrendPoints(trendResponse);
        setRecentRunsPreview(recentResponse);
        setFailureBreakdown(failureResponse);
        setFeedbackItems(feedbackResponse);
        setEventAnalytics(eventResponse);
      } catch {
        if (!isCancelled) {
          setError(text.loadError);
        }
      } finally {
        if (!isCancelled) {
          setIsLoading(false);
        }
      }
    }

    void loadAnalytics();

    return () => {
      isCancelled = true;
    };
  }, [locale, router, templateId, text.loadError]);

  if (isLoading) {
    return (
      <section className={styles.page}>
        <div className={styles.loadingCard}>{text.loading}</div>
      </section>
    );
  }

  if (error || !template || !statistics) {
    return (
      <section className={styles.page}>
        <div className={styles.errorCard}>{error ?? text.loadError}</div>
      </section>
    );
  }

  const catalogPath = `/${locale}/templates/video`;
  const editorPath = `/${locale}/templates/video/editor?templateId=${templateId}`;
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
    <section className={styles.page}>
      <div className={styles.pageHeaderRow}>
        <div className={styles.breadcrumbs}>
          <Link href={catalogPath}>{text.breadcrumbsRoot}</Link>
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

      <div className={styles.analyticsToolbar}>
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
      </div>

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
        <section className={`${styles.sectionCard} ${styles.sectionCardWide}`}>
          <div className={styles.sectionHeaderRow}>
            <div className={styles.sectionHeader}>
              <h2 className={styles.sectionTitleWithIcon}><TableIcon className={styles.sectionTitleIcon} /><span>{text.recentRunsTitle}</span></h2>
              <p>{recentRunsMode === "all" ? text.recentRunsAllHint : recentRunsMode === "failed" ? text.failedRunsHint : text.recentRunsHint}</p>
            </div>

            {shouldShowRecentRunModes ? (
              <div className={styles.chartTabs} aria-label={text.recentRunsTitle}>
                <button
                  type="button"
                  className={recentRunsMode === "latest" ? styles.chartTabActive : styles.chartTab}
                  onClick={() => void handleRecentRunsModeChange("latest")}
                >
                  <span>{text.recentRunsLatest}</span>
                </button>
                <button
                  type="button"
                  className={recentRunsMode === "all" ? styles.chartTabActive : styles.chartTab}
                  onClick={() => void handleRecentRunsModeChange("all")}
                  disabled={isRecentRunsLoading}
                >
                  <span>{isRecentRunsLoading ? text.recentRunsLoading : text.recentRunsAll}</span>
                </button>
                {canShowFailedRecentRuns ? (
                  <button
                    type="button"
                    className={recentRunsMode === "failed" ? styles.chartTabActive : styles.chartTab}
                    onClick={() => void handleRecentRunsModeChange("failed")}
                    disabled={isRecentRunsLoading}
                  >
                    <span>{text.recentRunsFailed}</span>
                  </button>
                ) : null}
              </div>
            ) : null}
          </div>
          {recentRunsError ? <p className={styles.emptyState}>{recentRunsError}</p> : null}
          <RecentRunsTable locale={locale} items={visibleRecentRuns} text={text} mode={recentRunsMode} />
        </section>

        <section className={styles.sectionCard}>
          <div className={styles.sectionHeader}>
            <h2 className={styles.sectionTitleWithIcon}><ChartIcon className={styles.sectionTitleIcon} /><span>{text.failureBreakdownTitle}</span></h2>
            <p>{text.failureBreakdownHint}</p>
          </div>
          <FailureBreakdownList locale={locale} items={failureBreakdown} text={text} />
        </section>
      </div>

      <section className={styles.sectionCard}>
        <div className={styles.sectionHeader}>
          <h2 className={styles.sectionTitleWithIcon}><ChartIcon className={styles.sectionTitleIcon} /><span>{text.feedbackTitle}</span></h2>
          <p>{text.feedbackHint}</p>
        </div>
        <FeedbackList locale={locale} items={feedbackItems} text={text} />
      </section>

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
    </section>
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
      <div className={styles.templatePreviewWrap}>
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
              <text x={paddingX} y={y - 6} className={styles.chartTick}>{formatTrendValue(tick, metric, locale, text)}</text>
            </g>
          );
        })}

        <path d={areaPath} className={styles.chartArea} />
        <path d={linePath} className={styles.chartLine} />

        {coordinates.map(({ point, value, x, y }) => {
          const label = formatTrendValue(value, metric, locale, text);
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
            <strong>{formatTrendValue(getTrendMetricValue(point, metric), metric, locale, text)}</strong>
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

function RecentRunsTable({ locale, items, text, mode }: { locale: Locale; items: readonly AdminTemplateRecentGeneration[]; text: AnalyticsCopy; mode: RecentRunsMode }) {
  const isRu = locale === "ru";
  const hasFailureDetails = items.some((item) => item.status === "Failed" || Boolean(item.failureCode) || Boolean(item.failureMessage));

  if (!items.length) {
    return <p className={styles.emptyState}>{mode === "failed" ? text.failedRunsEmpty : text.recentRunsEmpty}</p>;
  }

  return (
    <div className={styles.tableWrap}>
      <table className={styles.recentTable}>
        <thead>
          <tr>
            <th>{text.generationIdHeader}</th>
            <th>{text.userHeader}</th>
            <th>{text.recentCreated}</th>
            <th>{text.recentStatus}</th>
            <th>{text.recentTokens}</th>
            <th>{text.recentDuration}</th>
            <th>{text.recentModels}</th>
            {hasFailureDetails ? <th>{text.failureCodeHeader}</th> : null}
            {hasFailureDetails ? <th>{text.failureReasonHeader}</th> : null}
            <th>{text.recentOutput}</th>
          </tr>
        </thead>
        <tbody>
          {items.map((item) => (
            <tr key={item.generationId}>
              <td><span className={styles.monoCell}>{shortenId(item.generationId)}</span></td>
              <td><span className={styles.monoCell}>{shortenId(item.userId)}</span></td>
              <td>{formatDateTime(item.createdAtUtc, locale)}</td>
              <td>
                <span className={`${styles.statusChip} ${styles[getJobStatusClassName(item.status)]}`}>
                  {formatJobStatus(item.status, isRu)}
                </span>
              </td>
              <td>{formatTokens(item.tokenCost, isRu)}</td>
              <td>{formatRangeDuration(item.startedAtUtc, item.completedAtUtc, isRu)}</td>
              <td>{formatModelSummary(item.usedPreprocessingModel, item.usedKlingModel)}</td>
              {hasFailureDetails ? (
                <td>
                  {item.failureCode ? <span className={styles.failureCodeCell}>{formatFailureCode(item.failureCode, text)}</span> : <span className={styles.mutedCell}>-</span>}
                </td>
              ) : null}
              {hasFailureDetails ? (
                <td>
                  {item.failureMessage ? <span className={styles.failureReasonCell}>{item.failureMessage}</span> : <span className={styles.mutedCell}>-</span>}
                </td>
              ) : null}
              <td>
                {item.outputUrl ? (
                  <a href={item.outputUrl} target="_blank" rel="noreferrer" className={styles.inlineLink}>
                    <VideoIcon className={styles.inlineIcon} />
                    <span>{text.openOutput}</span>
                  </a>
                ) : (
                  <span className={styles.mutedCell}>{text.noOutput}</span>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function FailureBreakdownList({ locale, items, text }: { locale: Locale; items: readonly AdminTemplateFailureBreakdownItem[]; text: AnalyticsCopy }) {
  if (!items.length) {
    return <p className={styles.emptyState}>{text.failuresEmpty}</p>;
  }

  return (
    <div className={styles.failureList}>
      {items.map((item) => (
        <div key={item.failureCode} className={styles.failureItem}>
          <strong>{formatFailureCode(item.failureCode, text)}</strong>
          <span>{item.count}</span>
          <p>
            {text.lastFailure}: {formatDateTime(item.lastOccurredAtUtc, locale)}
          </p>
        </div>
      ))}
    </div>
  );
}

function FeedbackList({ locale, items, text }: { locale: Locale; items: readonly AdminTemplateFeedbackItem[]; text: AnalyticsCopy }) {
  if (!items.length) {
    return <p className={styles.emptyState}>{text.feedbackEmpty}</p>;
  }

  const isRu = locale === "ru";

  return (
    <div className={styles.feedbackList}>
      {items.map((item) => (
        <article key={item.eventId} className={styles.feedbackItem}>
          <div className={styles.feedbackHeader}>
            <span className={`${styles.statusChip} ${styles[item.eventType === "complaint" ? "statusChip_danger" : "statusChip_info"]}`}>
              {item.eventType === "complaint" ? text.feedbackTypeComplaint : text.feedbackTypeFeedback}
            </span>
            <strong>{formatDateTime(item.createdAtUtc, locale)}</strong>
          </div>
          <p className={styles.feedbackMessage}>{item.feedbackMessage?.trim() || text.feedbackMessageMissing}</p>
          <div className={styles.feedbackMeta}>
            <span>{text.feedbackSourceLabel}: {formatAnalyticsValue(item.source)}</span>
            <span>{text.feedbackDeviceLabel}: {formatAnalyticsValue(item.deviceClass)}</span>
            <span>{text.feedbackCountryLabel}: {formatAnalyticsValue(item.countryCode)}</span>
            <span>{text.userHeader}: {item.userId ? shortenId(item.userId) : (isRu ? "анон" : "guest")}</span>
            {item.generationId ? <span>{text.generationIdHeader}: {shortenId(item.generationId)}</span> : null}
          </div>
        </article>
      ))}
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
    realProviderSpend: isRu ? "Наши затраты" : "Provider spend",
    realProviderSpendHint: isRu ? "Реальные USD-затраты, сохранённые от AI provider по jobs." : "Real USD costs persisted from the AI provider jobs.",
    averageProviderCost: isRu ? "Средняя AI-стоимость" : "Average AI cost",
    averageProviderCostHint: isRu ? "Средняя реальная provider стоимость на запуск." : "Average real provider cost per run.",
    averageGenerationCost: isRu ? "Средняя стоимость" : "Average cost",
    averageGenerationCostHint: isRu ? "Средние токены на один запуск." : "Average tokens per generation start.",
    complaints: isRu ? "Жалобы" : "Complaints",
    complaintsHint: isRu ? "События complaint из публичного analytics endpoint." : "Complaint events from the public analytics endpoint.",
    feedbackTitle: isRu ? "Жалобы и фидбек" : "Complaints and feedback",
    feedbackHint: isRu ? "Последние обращения пользователей по шаблону: complaint и feedback события с текстом и метаданными." : "Latest user complaints and feedback for this template with message text and event metadata.",
    feedbackEmpty: isRu ? "Пока нет пользовательских жалоб или фидбека по этому шаблону." : "There is no user complaint or feedback for this template yet.",
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
    chartProviderCost: isRu ? "Затраты $" : "Cost $",
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

function buildPeriodAnalytics(points: readonly AdminTemplateTrendPoint[], period: PeriodKey): PeriodAnalytics {
  const sortedPoints = [...points].sort((left, right) => getUtcDay(left.dateUtc) - getUtcDay(right.dateUtc));

  if (!sortedPoints.length) {
    return {
      currentPoints: [],
      previousPoints: [],
      current: summarizeTrendPoints([]),
      previous: null,
    };
  }

  if (period === "all") {
    return {
      currentPoints: sortedPoints,
      previousPoints: [],
      current: summarizeTrendPoints(sortedPoints),
      previous: null,
    };
  }

  const dayMs = 24 * 60 * 60 * 1000;
  const days = PERIOD_DAY_COUNTS[period];
  const latestDay = Math.max(...sortedPoints.map((point) => getUtcDay(point.dateUtc)));
  const currentStart = latestDay - (days - 1) * dayMs;
  const previousStart = currentStart - days * dayMs;
  const previousEnd = currentStart - dayMs;
  const currentPoints = sortedPoints.filter((point) => {
    const day = getUtcDay(point.dateUtc);
    return day >= currentStart && day <= latestDay;
  });
  const previousPoints = sortedPoints.filter((point) => {
    const day = getUtcDay(point.dateUtc);
    return day >= previousStart && day <= previousEnd;
  });

  return {
    currentPoints,
    previousPoints,
    current: summarizeTrendPoints(currentPoints),
    previous: previousPoints.length ? summarizeTrendPoints(previousPoints) : null,
  };
}

function summarizeTrendPoints(points: readonly AdminTemplateTrendPoint[]): TrendTotals {
  const totals = points.reduce(
    (accumulator, point) => {
      accumulator.totalRuns += point.totalRuns;
      accumulator.queuedRuns += point.queuedRuns;
      accumulator.processingRuns += point.processingRuns;
      accumulator.completedRuns += point.completedRuns;
      accumulator.failedRuns += point.failedRuns;
      accumulator.totalTokenCost += point.totalTokenCost;
      accumulator.totalProviderCostUsd += point.totalProviderCostUsd;

      if (typeof point.averageGenerationSeconds === "number" && point.completedRuns > 0) {
        accumulator.durationSeconds += point.averageGenerationSeconds * point.completedRuns;
        accumulator.durationSamples += point.completedRuns;
      }

      return accumulator;
    },
    {
      totalRuns: 0,
      queuedRuns: 0,
      processingRuns: 0,
      completedRuns: 0,
      failedRuns: 0,
      totalTokenCost: 0,
      totalProviderCostUsd: 0,
      durationSeconds: 0,
      durationSamples: 0,
    },
  );

  return {
    totalRuns: totals.totalRuns,
    queuedRuns: totals.queuedRuns,
    processingRuns: totals.processingRuns,
    completedRuns: totals.completedRuns,
    failedRuns: totals.failedRuns,
    totalTokenCost: totals.totalTokenCost,
    totalProviderCostUsd: totals.totalProviderCostUsd,
    averageGenerationSeconds: totals.durationSamples > 0 ? totals.durationSeconds / totals.durationSamples : null,
    successRatePercent: totals.totalRuns > 0 ? (totals.completedRuns / totals.totalRuns) * 100 : 0,
  };
}

function totalsFromStatistics(statistics: AdminTemplateStatistics): TrendTotals {
  return {
    totalRuns: statistics.totalRuns,
    queuedRuns: statistics.queuedRuns,
    processingRuns: statistics.processingRuns,
    completedRuns: statistics.completedRuns,
    failedRuns: statistics.failedRuns,
    totalTokenCost: statistics.totalTokenCost,
    totalProviderCostUsd: statistics.totalProviderCostUsd,
    averageGenerationSeconds: statistics.averageGenerationSeconds ?? null,
    successRatePercent: statistics.successRatePercent,
  };
}

function getUtcDay(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return 0;
  }

  return Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate());
}

function calculateChange(current: number, previous: number | null | undefined) {
  if (typeof previous !== "number" || Number.isNaN(previous) || previous === 0) {
    return null;
  }

  return ((current - previous) / Math.abs(previous)) * 100;
}

function getTrendMetricValue(point: AdminTemplateTrendPoint, metric: TrendMetricKey) {
  if (metric === "averageGenerationSeconds") {
    return point.averageGenerationSeconds ?? 0;
  }

  return point[metric];
}

function buildChartTicks(maxValue: number) {
  const ceiling = Math.max(1, Math.ceil(maxValue));

  if (ceiling <= 4) {
    return Array.from({ length: ceiling + 1 }, (_, index) => ceiling - index);
  }

  const step = Math.ceil(ceiling / 4);
  const top = step * 4;
  return [top, top - step, top - step * 2, step, 0];
}

function formatTrendValue(value: number, metric: TrendMetricKey, locale: Locale, text: AnalyticsCopy) {
  if (metric === "totalTokenCost") {
    return formatTokens(value, locale === "ru");
  }

  if (metric === "averageGenerationSeconds") {
    return formatDuration(value, locale === "ru");
  }

  return `${formatNumber(value, locale)} ${metric === "failedRuns" ? text.failedRuns.toLowerCase() : ""}`.trim();
}

function getStatusBadgeClassName(status: TemplateStatus) {
  if (status === "Active") {
    return "statusBadge_active";
  }

  if (status === "Archived") {
    return "statusBadge_archived";
  }

  return "statusBadge_draft";
}

function getJobStatusClassName(status: TemplateGenerationJobStatus) {
  if (status === "Completed") {
    return "statusChip_success";
  }

  if (status === "Failed") {
    return "statusChip_danger";
  }

  if (status === "Processing") {
    return "statusChip_warning";
  }

  return "statusChip_info";
}

function formatJobStatus(status: TemplateGenerationJobStatus, isRu: boolean) {
  if (!isRu) {
    return status;
  }

  if (status === "Completed") {
    return "Успешно";
  }

  if (status === "Failed") {
    return "Ошибка";
  }

  if (status === "Processing") {
    return "В работе";
  }

  return "В очереди";
}

function formatFailureCode(value: string, text: AnalyticsCopy) {
  if (!value || value === "templates.unknown_failure") {
    return text.unknownFailure;
  }

  return value;
}

function formatAnalyticsValue(value: string | null | undefined) {
  if (!value) {
    return "-";
  }

  return value.toUpperCase() === value && value.length <= 3
    ? value
    : value.replace(/[_-]+/g, " ");
}

function formatPercent(value: number, isRu: boolean) {
  const formatter = new Intl.NumberFormat(isRu ? "ru-RU" : "en-US", {
    minimumFractionDigits: value % 1 === 0 ? 0 : 1,
    maximumFractionDigits: 1,
  });

  return `${formatter.format(value)}%`;
}

function formatDelta(value: number, isRu: boolean) {
  const sign = value > 0 ? "+" : "";
  return `${sign}${formatPercent(value, isRu)}`;
}

function formatNumber(value: number, locale: Locale) {
  return new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US", {
    maximumFractionDigits: value % 1 === 0 ? 0 : 1,
  }).format(value);
}

function formatTokens(value: number, isRu: boolean) {
  const formatter = new Intl.NumberFormat(isRu ? "ru-RU" : "en-US", {
    maximumFractionDigits: value % 1 === 0 ? 0 : 1,
  });

  return `${formatter.format(value)} ${isRu ? "токенов" : "tokens"}`;
}

function formatUsd(value: number | null | undefined, locale: Locale) {
  if (typeof value !== "number" || Number.isNaN(value) || value <= 0) {
    return "-";
  }

  return new Intl.NumberFormat(locale === "ru" ? "en-US" : "en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: 2,
    maximumFractionDigits: 4,
  }).format(value);
}

function formatDuration(value: number | null | undefined, isRu: boolean) {
  if (typeof value !== "number" || Number.isNaN(value) || value <= 0) {
    return "-";
  }

  const rounded = Math.round(value);
  const minutes = Math.floor(rounded / 60);
  const seconds = rounded % 60;

  if (minutes > 0) {
    return `${minutes}:${seconds.toString().padStart(2, "0")}`;
  }

  return `${rounded} ${isRu ? "сек" : "sec"}`;
}

function formatRangeDuration(startedAtUtc: string | null | undefined, completedAtUtc: string | null | undefined, isRu: boolean) {
  if (!startedAtUtc || !completedAtUtc) {
    return "-";
  }

  const started = new Date(startedAtUtc).getTime();
  const completed = new Date(completedAtUtc).getTime();
  if (Number.isNaN(started) || Number.isNaN(completed) || completed < started) {
    return "-";
  }

  return formatDuration(Math.round((completed - started) / 1000), isRu);
}

function formatDateTime(value: string | null | undefined, locale: Locale) {
  if (!value) {
    return "-";
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "-";
  }

  return new Intl.DateTimeFormat(locale === "ru" ? "ru-RU" : "en-US", {
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

function formatShortDate(value: string, locale: Locale) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "-";
  }

  return new Intl.DateTimeFormat(locale === "ru" ? "ru-RU" : "en-US", {
    day: "2-digit",
    month: "short",
  }).format(date);
}

function formatModelSummary(preprocessingModel: string | null | undefined, klingModel: string | null | undefined) {
  const values = [preprocessingModel, klingModel]
    .filter(Boolean)
    .map((value) => {
      const parts = value!.split("/");
      return parts.length >= 2 ? parts.slice(-2).join("/") : value!;
    });

  return values.length ? values.join(" + ") : "-";
}

function formatModelValue(value: string | null | undefined) {
  if (!value) {
    return "-";
  }

  const parts = value.split("/");
  return parts.length >= 2 ? parts.slice(-2).join("/") : value;
}

function shortenId(value: string) {
  return value.length > 13 ? `${value.slice(0, 8)}...${value.slice(-4)}` : value;
}
