"use client";

import { keepPreviousData, useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";

import {
  CalendarIcon,
  ChartIcon,
  DashboardIcon,
  DownloadIcon,
  ImageIcon,
  TableIcon,
  TrendUpIcon,
  VideoIcon,
} from "@/components/admin/admin-icons";
import {
  AdminFilterBar,
  AdminKpiCard,
  AdminMetricStrip,
  AdminPage,
  AdminPageHero,
  AdminSelectField,
  AdminStateCard,
  AdminToolbar,
  type AdminTone,
} from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import {
  getTemplateAccessLabel,
  getTemplateStatusLabel,
  getTemplateTypeLabel,
} from "@/components/templates/template-admin-shared";
import { TemplateSecureMedia } from "@/components/templates/template-secure-media";
import {
  sanitizeTemplatesAnalyticsOverviewForExport,
  sanitizeTemplatesAnalyticsQueryForExport,
} from "@/components/templates/templates-analytics-hub-export";
import styles from "@/components/templates/templates-analytics-hub-page.module.css";
import { Button } from "@/components/ui/button";
import {
  fetchAdminTemplatesAnalyticsOverview,
  normalizeAdminTemplatesAnalyticsQuery,
  useAuthSession,
  type AdminTemplateAnalyticsDimension,
  type AdminTemplatesAnalyticsBreakdown,
  type AdminTemplatesAnalyticsFeedbackItem,
  type AdminTemplatesAnalyticsOverview,
  type AdminTemplatesAnalyticsQuery,
  type AdminTemplatesAnalyticsTemplateRow,
  type AdminTemplatesAnalyticsTrendPoint,
  type TemplateStatus,
  type TemplateType,
} from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { getDictionary, type Locale as AppLocale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type TemplatesAnalyticsHubPageProps = {
  locale: AppLocale;
};

type PeriodKey = "7" | "30" | "90" | "all";
type TrendMetricKey =
  | "totalViews"
  | "totalGenerationStarts"
  | "completedGenerations"
  | "totalProviderCostUsd";

type Copy = ReturnType<typeof getCopy>;

const PERIOD_OPTIONS: Array<{ key: PeriodKey; ru: string; en: string }> = [
  { key: "7", ru: "7 дней", en: "7 days" },
  { key: "30", ru: "30 дней", en: "30 days" },
  { key: "90", ru: "90 дней", en: "90 days" },
  { key: "all", ru: "Всё время", en: "All time" },
];

function formatAnalyticsDisplayText(value: string, maxLength = 120) {
  return sanitizeSensitiveText(value, maxLength);
}

function getBoundedBarWidthPercent(value: number, minimumVisiblePercent: number) {
  if (!Number.isFinite(value) || value <= 0) {
    return 0;
  }

  return Math.min(100, Math.max(minimumVisiblePercent, value));
}

export function TemplatesAnalyticsHubPage({ locale }: TemplatesAnalyticsHubPageProps) {
  const isRu = locale === "ru";
  const text = useMemo(() => getCopy(locale), [locale]);
  const dictionary = useMemo(() => getDictionary(locale), [locale]);
  const router = useRouter();
  const session = useAuthSession();
  const sessionRoles = session?.user.roles ?? [];
  const canViewTemplateAnalytics =
    sessionRoles.includes("Admin") || sessionRoles.includes("Moderator");
  const [period, setPeriod] = useState<PeriodKey>("30");
  const [templateType, setTemplateType] = useState<TemplateType | "All">("All");
  const [category, setCategory] = useState("");
  const [status, setStatus] = useState<TemplateStatus | "All">("All");
  const [access, setAccess] = useState<"all" | "free" | "premium">("all");
  const [sort, setSort] = useState<NonNullable<AdminTemplatesAnalyticsQuery["sort"]>>("views");
  const [chartMetric, setChartMetric] = useState<TrendMetricKey>("totalViews");

  const query = useMemo<AdminTemplatesAnalyticsQuery>(
    () =>
      normalizeAdminTemplatesAnalyticsQuery({
        periodDays: period === "all" ? undefined : Number(period),
        templateType,
        category: category || undefined,
        status,
        access,
        sort,
        take: 50,
      }),
    [access, category, period, sort, status, templateType]
  );

  useEffect(() => {
    if (!canViewTemplateAnalytics) {
      ensureAdminSession(locale, router);
    }
  }, [canViewTemplateAnalytics, locale, router, session]);

  const overviewQuery = useQuery<AdminTemplatesAnalyticsOverview>({
    queryKey: [
      "admin",
      "templates",
      "analytics-overview",
      query.periodDays ?? null,
      query.templateType ?? null,
      query.category ?? null,
      query.status ?? null,
      query.access ?? null,
      query.sort ?? null,
      query.take ?? null,
    ],
    queryFn: ({ signal }) => fetchAdminTemplatesAnalyticsOverview(query, signal),
    enabled: canViewTemplateAnalytics,
    placeholderData: keepPreviousData,
  });

  useEffect(() => {
    if (!overviewQuery.error) {
      return;
    }

    clientLogger.error("templates.analytics_hub_load_failed", {
      query: sanitizeTemplatesAnalyticsQueryForExport(query),
      errorName: overviewQuery.error instanceof Error ? overviewQuery.error.name : "UnknownError",
      errorDigest:
        overviewQuery.error &&
        typeof overviewQuery.error === "object" &&
        "digest" in overviewQuery.error
          ? String((overviewQuery.error as { digest?: unknown }).digest ?? "")
          : undefined,
    });
  }, [overviewQuery.error, query]);

  const isOverviewRefreshing = overviewQuery.isFetching && overviewQuery.isPlaceholderData;
  const overview = overviewQuery.isPlaceholderData ? null : (overviewQuery.data ?? null);
  const isLoading = (overviewQuery.isPending && !overview) || isOverviewRefreshing;
  const hasBlockingError = overviewQuery.isError && !overview;
  const hasPartialError = overviewQuery.isError && Boolean(overview);
  const isHubControlsLocked = overviewQuery.isFetching;

  if (!canViewTemplateAnalytics) {
    return (
      <AdminPage className={styles.page}>
        <AdminStateCard tone="info" title={text.loading} />
      </AdminPage>
    );
  }

  function handleExport() {
    if (!overview) {
      return;
    }

    const blob = new Blob(
      [
        JSON.stringify(
          {
            query: sanitizeTemplatesAnalyticsQueryForExport(query),
            overview: sanitizeTemplatesAnalyticsOverviewForExport(overview),
          },
          null,
          2
        ),
      ],
      {
        type: "application/json",
      }
    );
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `templates-analytics-${new Date().toISOString().slice(0, 10)}.json`;
    document.body.append(link);
    link.click();
    link.remove();
    window.setTimeout(() => URL.revokeObjectURL(url), 1000);
  }

  function requestOverviewRetry() {
    if (!canViewTemplateAnalytics || overviewQuery.isFetching) {
      return;
    }

    void overviewQuery.refetch().catch(() => undefined);
  }

  if (isLoading) {
    return (
      <AdminPage className={styles.page}>
        <AdminStateCard tone="info" title={text.loading} />
      </AdminPage>
    );
  }

  if (hasBlockingError || !overview) {
    return (
      <AdminPage className={styles.page}>
        <AdminStateCard
          tone="danger"
          title={text.loadError}
          action={
            <Button
              type="button"
              variant="secondary"
              disabled={!canViewTemplateAnalytics || overviewQuery.isFetching}
              onClick={requestOverviewRetry}
            >
              {text.retryAction}
            </Button>
          }
        />
      </AdminPage>
    );
  }

  const summary = overview.summary;
  const kpis = [
    {
      label: text.views,
      value: formatNumber(summary.totalViews, locale),
      hint: text.viewsHint,
      tone: "green",
    },
    {
      label: text.starts,
      value: formatNumber(summary.totalGenerationStarts, locale),
      hint: text.startsHint,
      tone: "violet",
    },
    {
      label: text.completed,
      value: formatNumber(summary.completedGenerations, locale),
      hint: text.completedHint,
      tone: "green",
    },
    {
      label: text.conversion,
      value: formatPercent(summary.conversionPercent, isRu),
      hint: text.conversionHint,
      tone: "blue",
    },
    {
      label: text.tokens,
      value: formatTokens(summary.totalTokenCost, isRu),
      hint: text.tokensHint,
      tone: "amber",
    },
    {
      label: text.providerSpend,
      value: formatMoney(summary.totalProviderCostUsd, locale),
      hint: text.providerSpendHint,
      tone: "red",
    },
    {
      label: text.complaints,
      value: formatNumber(summary.totalComplaints, locale),
      hint: text.complaintsHint,
      tone: summary.totalComplaints > 0 ? "red" : "neutral",
    },
  ];
  const chartTabs: Array<{ key: TrendMetricKey; label: string }> = [
    { key: "totalViews", label: text.chartViews },
    { key: "totalGenerationStarts", label: text.chartStarts },
    { key: "completedGenerations", label: text.chartCompleted },
    { key: "totalProviderCostUsd", label: text.chartCost },
  ];

  return (
    <AdminPage className={styles.page}>
      <AdminPageHero
        eyebrow={text.eyebrow}
        title={text.title}
        description={text.description}
        actions={
          <div className={styles.heroActions}>
            <Link href={`/${locale}/templates/video`} className={styles.secondaryLink}>
              <TableIcon className={styles.controlIcon} />
              <span>{text.catalog}</span>
            </Link>
            <button
              type="button"
              className={styles.primaryButton}
              onClick={handleExport}
              disabled={isHubControlsLocked}
            >
              <DownloadIcon className={styles.controlIcon} />
              <span>{text.export}</span>
            </button>
          </div>
        }
        metaItems={[
          `${text.templates}: ${formatNumber(summary.totalTemplates, locale)}`,
          `${text.video}: ${formatNumber(summary.videoTemplates, locale)}`,
          `${text.image}: ${formatNumber(summary.imageTemplates, locale)}`,
          `${text.updated}: ${formatDateTime(overview.generatedAtUtc, locale)}`,
        ]}
      />

      <AdminMetricStrip
        items={[
          { label: text.active, value: formatNumber(summary.activeTemplates, locale) },
          { label: text.premium, value: formatNumber(summary.premiumTemplates, locale) },
        ]}
      />

      {hasPartialError ? (
        <AdminStateCard
          tone="warning"
          title={text.partialErrorTitle}
          description={text.partialErrorDescription}
          action={
            <Button
              type="button"
              variant="secondary"
              disabled={!canViewTemplateAnalytics || overviewQuery.isFetching}
              onClick={requestOverviewRetry}
            >
              {text.retryAction}
            </Button>
          }
        />
      ) : null}

      <AdminToolbar className={styles.toolbar}>
        <div className={styles.segmented} aria-label={text.periodLabel}>
          {PERIOD_OPTIONS.map((option) => {
            const isActivePeriod = period === option.key;

            return (
              <button
                key={option.key}
                type="button"
                className={isActivePeriod ? styles.segmentedActive : styles.segmentedButton}
                disabled={isActivePeriod || isHubControlsLocked}
                onClick={() => setPeriod(option.key)}
              >
                <CalendarIcon className={styles.controlIcon} />
                <span>{isRu ? option.ru : option.en}</span>
              </button>
            );
          })}
        </div>

        <AdminFilterBar className={styles.filters}>
          <SelectBox
            label={text.typeFilter}
            value={templateType}
            disabled={isHubControlsLocked}
            onChange={(value) => setTemplateType(value as TemplateType | "All")}
            options={[
              { value: "All", label: text.allTemplates },
              { value: "Video", label: getTemplateTypeLabel("Video", dictionary) },
              { value: "Image", label: getTemplateTypeLabel("Image", dictionary) },
            ]}
          />
          <SelectBox
            label={text.categoryFilter}
            value={category}
            disabled={isHubControlsLocked}
            onChange={setCategory}
            options={[
              { value: "", label: text.allCategories },
              ...overview.availableCategories.map((value) => ({
                value,
                label: formatAnalyticsDisplayText(value, 120),
              })),
            ]}
          />
          <SelectBox
            label={text.statusFilter}
            value={status}
            disabled={isHubControlsLocked}
            onChange={(value) => setStatus(value as TemplateStatus | "All")}
            options={[
              { value: "All", label: text.allStatuses },
              { value: "Active", label: getTemplateStatusLabel("Active", locale) },
              { value: "Draft", label: getTemplateStatusLabel("Draft", locale) },
              { value: "Archived", label: getTemplateStatusLabel("Archived", locale) },
            ]}
          />
          <SelectBox
            label={text.accessFilter}
            value={access}
            disabled={isHubControlsLocked}
            onChange={(value) => setAccess(value as "all" | "free" | "premium")}
            options={[
              { value: "all", label: text.allAccess },
              { value: "free", label: getTemplateAccessLabel(false, dictionary) },
              { value: "premium", label: getTemplateAccessLabel(true, dictionary) },
            ]}
          />
          <SelectBox
            label={text.sortFilter}
            value={sort}
            disabled={isHubControlsLocked}
            onChange={(value) =>
              setSort(value as NonNullable<AdminTemplatesAnalyticsQuery["sort"]>)
            }
            options={[
              { value: "views", label: text.sortViews },
              { value: "starts", label: text.sortStarts },
              { value: "conversion", label: text.sortConversion },
              { value: "cost", label: text.sortCost },
              { value: "updated", label: text.sortUpdated },
            ]}
          />
        </AdminFilterBar>
      </AdminToolbar>

      <div className={styles.kpiGrid}>
        {kpis.map((item) => (
          <AdminKpiCard
            key={item.label}
            label={item.label}
            value={item.value}
            hint={item.hint}
            tone={getKpiTone(item.tone)}
          />
        ))}
      </div>

      <div className={styles.mainGrid}>
        <section className={`${styles.panel} ${styles.panelWide}`}>
          <div className={styles.panelHeaderRow}>
            <div>
              <h2 className={styles.panelTitle}>
                <TrendUpIcon className={styles.panelIcon} />
                {text.trendTitle}
              </h2>
              <p>{text.trendHint}</p>
            </div>
            <div className={styles.chartTabs} aria-label={text.trendTitle}>
              {chartTabs.map((tab) => {
                const isActiveChartMetric = chartMetric === tab.key;

                return (
                  <button
                    key={tab.key}
                    type="button"
                    className={isActiveChartMetric ? styles.chartTabActive : styles.chartTab}
                    disabled={isActiveChartMetric || isHubControlsLocked}
                    onClick={() => setChartMetric(tab.key)}
                  >
                    {tab.label}
                  </button>
                );
              })}
            </div>
          </div>
          <TrendChart
            points={overview.trendPoints}
            metric={chartMetric}
            locale={locale}
            text={text}
          />
        </section>

        <section className={styles.panel}>
          <div className={styles.panelHeader}>
            <h2 className={styles.panelTitle}>
              <DashboardIcon className={styles.panelIcon} />
              {text.funnelTitle}
            </h2>
            <p>{text.funnelHint}</p>
          </div>
          <FunnelList overview={overview} locale={locale} text={text} />
        </section>
      </div>

      <div className={styles.secondaryGrid}>
        <BreakdownPanel
          title={text.categoriesTitle}
          hint={text.categoriesHint}
          rows={overview.categories}
          locale={locale}
          templateCountLabel={text.templateCountLabel}
        />
        <TypePanel rows={overview.templateTypes} locale={locale} text={text} />
        <TopTemplatesPanel rows={overview.topTemplates} locale={locale} text={text} />
      </div>

      <section className={styles.panel}>
        <div className={styles.panelHeader}>
          <h2 className={styles.panelTitle}>
            <ChartIcon className={styles.panelIcon} />
            {text.feedbackTitle}
          </h2>
          <p>{text.feedbackHint}</p>
        </div>
        <FeedbackFeedPanel items={overview.feedbackItems} locale={locale} text={text} />
      </section>

      <div className={styles.dimensionGrid}>
        <EventDimensionPanel
          title={text.sourcesTitle}
          hint={text.sourcesHint}
          rows={overview.sources}
          locale={locale}
        />
        <EventDimensionPanel
          title={text.devicesTitle}
          hint={text.devicesHint}
          rows={overview.devices}
          locale={locale}
        />
        <EventDimensionPanel
          title={text.geographyTitle}
          hint={text.geographyHint}
          rows={overview.geography}
          locale={locale}
        />
      </div>

      <section className={styles.panel}>
        <div className={styles.panelHeaderRow}>
          <div>
            <h2 className={styles.panelTitle}>
              <TableIcon className={styles.panelIcon} />
              {text.tableTitle}
            </h2>
            <p>{text.tableHint}</p>
          </div>
          {overviewQuery.isFetching ? <span className={styles.refreshPill}>{text.refreshing}</span> : null}
        </div>
        <TemplatesTable rows={overview.templates} locale={locale} text={text} />
      </section>
    </AdminPage>
  );
}

function SelectBox({
  label,
  value,
  options,
  onChange,
  disabled = false,
}: {
  label: string;
  value: string;
  options: Array<{ value: string; label: string }>;
  onChange: (value: string) => void;
  disabled?: boolean;
}) {
  return (
    <AdminSelectField
      label={label}
      value={value}
      options={options}
      onChange={onChange}
      disabled={disabled}
    />
  );
}

function getKpiTone(tone: string): AdminTone {
  if (tone === "green") {
    return "success";
  }

  if (tone === "violet") {
    return "magenta";
  }

  if (tone === "blue") {
    return "info";
  }

  if (tone === "amber") {
    return "warning";
  }

  if (tone === "red") {
    return "danger";
  }

  return "neutral";
}

function FeedbackFeedPanel({
  items,
  locale,
  text,
}: {
  items: readonly AdminTemplatesAnalyticsFeedbackItem[];
  locale: AppLocale;
  text: Copy;
}) {
  const isRu = locale === "ru";

  if (!items.length) {
    return <div className={styles.emptyState}>{text.feedbackEmpty}</div>;
  }

  return (
    <div className={styles.feedbackList}>
      {items.map((item) => {
        const encodedTemplateId = encodeURIComponent(item.templateId);
        const templatePath =
          item.templateType === "Video"
            ? `/${locale}/templates/video/analytics/${encodedTemplateId}`
            : `/${locale}/templates/image/analytics/${encodedTemplateId}`;

        return (
          <article key={item.eventId} className={styles.feedbackItem}>
            <div className={styles.feedbackHeader}>
              <div className={styles.feedbackTitleBlock}>
                <span
                  className={`${styles.statusBadge} ${styles[item.eventType === "complaint" ? "status_failed" : "status_active"]}`}
                >
                  {item.eventType === "complaint"
                    ? text.feedbackTypeComplaint
                    : text.feedbackTypeFeedback}
                </span>
                <Link href={templatePath} className={styles.feedbackTemplateLink}>
                  {formatAnalyticsDisplayText(item.templateTitle, 120)}
                </Link>
              </div>
              <strong>{formatDateTime(item.createdAtUtc, locale)}</strong>
            </div>
            <p className={styles.feedbackMessage}>
              {item.feedbackMessage?.trim()
                ? sanitizeSensitiveText(item.feedbackMessage, 240)
                : text.feedbackMessageMissing}
            </p>
            <div className={styles.feedbackMeta}>
              <span>
                {text.feedbackSourceLabel}: {formatAnalyticsValue(item.source)}
              </span>
              <span>
                {text.feedbackDeviceLabel}: {formatAnalyticsValue(item.deviceClass)}
              </span>
              <span>
                {text.feedbackCountryLabel}: {formatAnalyticsValue(item.countryCode)}
              </span>
              <span>
                {text.feedbackUserLabel}:{" "}
                {item.userId ? shortId(item.userId) : isRu ? "анон" : "guest"}
              </span>
              {item.generationId ? (
                <span>
                  {text.feedbackGenerationLabel}: {shortId(item.generationId)}
                </span>
              ) : null}
            </div>
          </article>
        );
      })}
    </div>
  );
}

function TrendChart({
  points,
  metric,
  locale,
  text,
}: {
  points: AdminTemplatesAnalyticsTrendPoint[];
  metric: TrendMetricKey;
  locale: AppLocale;
  text: Copy;
}) {
  if (!points.length) {
    return <div className={styles.emptyChart}>{text.noTrend}</div>;
  }

  const width = 720;
  const height = 250;
  const paddingX = 42;
  const paddingY = 28;
  const values = points.map((point) => getTrendValue(point, metric));
  const maxValue = Math.max(1, ...values);
  const stepX = points.length > 1 ? (width - paddingX * 2) / (points.length - 1) : 0;
  const chartHeight = height - paddingY * 2;
  const chartWidth = width - paddingX * 2;
  const coordinates = values.map((value, index) => {
    const x = paddingX + index * stepX;
    const y = paddingY + chartHeight - (value / maxValue) * chartHeight;
    return { x, y, value, point: points[index] };
  });
  const path = coordinates
    .map((point, index) => `${index === 0 ? "M" : "L"}${point.x},${point.y}`)
    .join(" ");
  const area = `${path} L${paddingX + chartWidth},${height - paddingY} L${paddingX},${height - paddingY} Z`;

  return (
    <div className={styles.chartWrap}>
      <svg
        viewBox={`0 0 ${width} ${height}`}
        className={styles.chartSvg}
        role="img"
        aria-label={text.trendTitle}
      >
        <defs>
          <linearGradient id="templatesHubLine" x1="0" x2="1" y1="0" y2="0">
            <stop offset="0" stopColor="var(--success)" />
            <stop offset="1" stopColor="var(--info)" />
          </linearGradient>
          <linearGradient id="templatesHubArea" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0" stopColor="var(--success)" stopOpacity="0.22" />
            <stop offset="1" stopColor="var(--success)" stopOpacity="0" />
          </linearGradient>
        </defs>
        {[0, 0.25, 0.5, 0.75, 1].map((ratio, index) => {
          const y = paddingY + chartHeight * ratio;
          const value = maxValue * (1 - ratio);
          return (
            <g key={`${ratio}-${index}`}>
              <line x1={paddingX} x2={width - paddingX} y1={y} y2={y} className={styles.gridLine} />
              <text x={paddingX} y={y - 5} className={styles.tickLabel}>
                {formatTrendValue(value, metric, locale)}
              </text>
            </g>
          );
        })}
        <path d={area} fill="url(#templatesHubArea)" />
        <path
          d={path}
          fill="none"
          stroke="url(#templatesHubLine)"
          strokeWidth="3"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
        {coordinates.map((point, index) => (
          <g key={`${point.point.dateUtc}-${index}`}>
            <circle cx={point.x} cy={point.y} r="4.5" className={styles.chartPoint} />
            <text x={point.x} y={height - 8} className={styles.dateLabel}>
              {formatShortDate(point.point.dateUtc, locale)}
            </text>
          </g>
        ))}
      </svg>
      <div className={styles.chartSummary}>
        <span>{text.currentMetric}</span>
        <strong>
          {formatTrendValue(
            values.reduce((total, value) => total + value, 0),
            metric,
            locale
          )}
        </strong>
      </div>
    </div>
  );
}

function FunnelList({
  overview,
  locale,
  text,
}: {
  overview: AdminTemplatesAnalyticsOverview;
  locale: AppLocale;
  text: Copy;
}) {
  const max = Math.max(
    1,
    overview.conversionFunnel.views,
    overview.conversionFunnel.generationStarts,
    overview.conversionFunnel.completedGenerations,
    overview.conversionFunnel.failedGenerations
  );
  const rows = [
    { label: text.funnelViews, value: overview.conversionFunnel.views, tone: "green" },
    { label: text.funnelStarts, value: overview.conversionFunnel.generationStarts, tone: "violet" },
    {
      label: text.funnelCompleted,
      value: overview.conversionFunnel.completedGenerations,
      tone: "blue",
    },
    { label: text.funnelFailed, value: overview.conversionFunnel.failedGenerations, tone: "red" },
    { label: text.funnelComplaints, value: overview.conversionFunnel.complaints, tone: "amber" },
  ];

  return (
    <div className={styles.funnelList}>
      {rows.map((row) => (
        <div key={row.label} className={styles.funnelRow}>
          <div>
            <span>{row.label}</span>
            <strong>{formatNumber(row.value, locale)}</strong>
          </div>
          <div className={styles.funnelTrack}>
            <span
              className={styles[`funnel_${row.tone}`]}
              style={{
                width: `${getBoundedBarWidthPercent((row.value / max) * 100, 5)}%`,
              }}
            />
          </div>
        </div>
      ))}
    </div>
  );
}

function BreakdownPanel({
  title,
  hint,
  rows,
  locale,
  templateCountLabel,
}: {
  title: string;
  hint: string;
  rows: AdminTemplatesAnalyticsBreakdown[];
  locale: AppLocale;
  templateCountLabel: string;
}) {
  const maxViews = Math.max(1, ...rows.map((row) => row.views));

  return (
    <section className={styles.panel}>
      <div className={styles.panelHeader}>
        <h2 className={styles.panelTitle}>
          <ChartIcon className={styles.panelIcon} />
          {title}
        </h2>
        <p>{hint}</p>
      </div>
      <div className={styles.breakdownList}>
        {rows.slice(0, 6).map((row) => (
            <div key={row.key} className={styles.breakdownRow}>
            <div className={styles.breakdownMeta}>
              <strong>{formatAnalyticsDisplayText(row.label, 120)}</strong>
              <span>{formatTemplateCount(row.templateCount, locale, templateCountLabel)}</span>
            </div>
            <div className={styles.breakdownBar}>
              <span
                style={{
                  width: `${getBoundedBarWidthPercent((row.views / maxViews) * 100, 6)}%`,
                }}
              />
            </div>
            <span>{formatNumber(row.views, locale)}</span>
          </div>
        ))}
        {!rows.length ? <div className={styles.emptyState}>-</div> : null}
      </div>
    </section>
  );
}

function TypePanel({
  rows,
  locale,
  text,
}: {
  rows: AdminTemplatesAnalyticsBreakdown[];
  locale: AppLocale;
  text: Copy;
}) {
  const dictionary = getDictionary(locale);
  return (
    <section className={styles.panel}>
      <div className={styles.panelHeader}>
        <h2 className={styles.panelTitle}>
          <VideoIcon className={styles.panelIcon} />
          {text.typesTitle}
        </h2>
        <p>{text.typesHint}</p>
      </div>
      <div className={styles.typeGrid}>
        {rows.map((row) => (
          <article key={row.key} className={styles.typeCard}>
            {row.key === "image" ? (
              <ImageIcon className={styles.typeIcon} />
            ) : (
              <VideoIcon className={styles.typeIcon} />
            )}
            <span>{getTemplateTypeLabel(row.key === "image" ? "Image" : "Video", dictionary)}</span>
            <strong>{formatNumber(row.views, locale)}</strong>
            <p>
              {formatNumber(row.generationStarts, locale)} {text.startsShort} ·{" "}
              {formatPercent(row.conversionPercent, locale === "ru")}
            </p>
            <p>
              {formatTokens(row.totalTokenCost, locale === "ru")} ·{" "}
              {formatMoney(row.totalProviderCostUsd, locale)}
            </p>
          </article>
        ))}
      </div>
    </section>
  );
}

function EventDimensionPanel({
  title,
  hint,
  rows,
  locale,
}: {
  title: string;
  hint: string;
  rows: AdminTemplateAnalyticsDimension[];
  locale: AppLocale;
}) {
  return (
    <section className={styles.panel}>
      <div className={styles.panelHeader}>
        <h2 className={styles.panelTitle}>
          <ChartIcon className={styles.panelIcon} />
          {title}
        </h2>
        <p>{hint}</p>
      </div>
      <div className={styles.dimensionList}>
        {rows.slice(0, 6).map((row) => (
          <div key={row.key} className={styles.dimensionRow}>
            <div>
              <strong>{formatAnalyticsDisplayText(row.label, 120)}</strong>
              <span>{formatNumber(row.count, locale)}</span>
            </div>
            <div className={styles.dimensionTrack}>
              <span
                style={{
                  width: `${getBoundedBarWidthPercent(row.sharePercent, 5)}%`,
                }}
              />
            </div>
            <em>{formatPercent(row.sharePercent, locale === "ru")}</em>
          </div>
        ))}
        {!rows.length ? <div className={styles.emptyState}>-</div> : null}
      </div>
    </section>
  );
}

function TopTemplatesPanel({
  rows,
  locale,
  text,
}: {
  rows: AdminTemplatesAnalyticsTemplateRow[];
  locale: AppLocale;
  text: Copy;
}) {
  const dictionary = getDictionary(locale);
  return (
    <section className={`${styles.panel} ${styles.topPanel}`}>
      <div className={styles.panelHeader}>
        <h2 className={styles.panelTitle}>
          <DashboardIcon className={styles.panelIcon} />
          {text.topTitle}
        </h2>
        <p>{text.topHint}</p>
      </div>
      <div className={styles.topList}>
        {rows.map((row, index) => (
          <div key={row.templateId} className={styles.topRow}>
            <span className={styles.rank}>{index + 1}</span>
            <TemplateThumb row={row} />
            <div>
              <strong>{formatAnalyticsDisplayText(row.title, 120)}</strong>
              <span>
                {getTemplateTypeLabel(row.templateType, dictionary)} ·{" "}
                {formatAnalyticsDisplayText(row.category, 120)}
              </span>
            </div>
            <span>{formatNumber(row.views, locale)}</span>
            <span>{formatNumber(row.generationStarts, locale)}</span>
          </div>
        ))}
      </div>
    </section>
  );
}

function TemplatesTable({
  rows,
  locale,
  text,
}: {
  rows: AdminTemplatesAnalyticsTemplateRow[];
  locale: AppLocale;
  text: Copy;
}) {
  const dictionary = getDictionary(locale);
  return (
    <div className={styles.tableWrap}>
      <table className={styles.table}>
        <thead>
          <tr>
            <th>{text.templateColumn}</th>
            <th>{text.typeColumn}</th>
            <th>{text.categoryColumn}</th>
            <th>{text.statusColumn}</th>
            <th>{text.accessColumn}</th>
            <th>{text.viewsColumn}</th>
            <th>{text.startsColumn}</th>
            <th>{text.conversionColumn}</th>
            <th>{text.tokensColumn}</th>
            <th>{text.costColumn}</th>
            <th>{text.actionsColumn}</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row.templateId}>
              <td>
                <div className={styles.templateCell}>
                  <TemplateThumb row={row} />
                  <div>
                    <strong>{formatAnalyticsDisplayText(row.title, 120)}</strong>
                    <span>{shortId(row.templateId)}</span>
                  </div>
                </div>
              </td>
              <td>{getTemplateTypeLabel(row.templateType, dictionary)}</td>
              <td>{formatAnalyticsDisplayText(row.category, 120)}</td>
              <td>
                <span
                  className={`${styles.statusBadge} ${styles[`status_${row.status.toLowerCase()}`]}`}
                >
                  {getTemplateStatusLabel(row.status, locale)}
                </span>
              </td>
              <td>{getTemplateAccessLabel(row.isPremium, dictionary)}</td>
              <td>{formatNumber(row.views, locale)}</td>
              <td>{formatNumber(row.generationStarts, locale)}</td>
              <td>{formatPercent(row.conversionPercent, locale === "ru")}</td>
              <td>{formatTokens(row.totalTokenCost, locale === "ru")}</td>
              <td>{formatMoney(row.totalProviderCostUsd, locale)}</td>
              <td>
                <Link
                  className={styles.inlineAction}
                  href={`/${locale}/templates/${row.templateType === "Video" ? "video" : "image"}/analytics/${encodeURIComponent(row.templateId)}`}
                >
                  {text.openAnalytics}
                </Link>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {!rows.length ? <div className={styles.emptyState}>{text.noRows}</div> : null}
    </div>
  );
}

function TemplateThumb({ row }: { row: AdminTemplatesAnalyticsTemplateRow }) {
  const previewUrl = row.previewAsset?.url;
  if (!previewUrl || row.previewAsset?.contentType.startsWith("video/")) {
    return (
      <div className={styles.thumbFallback}>
        {formatAnalyticsDisplayText(row.title, 24).slice(0, 1)}
      </div>
    );
  }

  return (
    <TemplateSecureMedia
      url={previewUrl}
      kind="image"
      alt=""
      width={48}
      height={48}
      className={styles.thumb}
      ariaHidden
      logContext={{
        templateId: row.templateId,
        contentType: row.previewAsset?.contentType,
        surface: "analytics_hub_thumb",
      }}
    />
  );
}

function getTrendValue(point: AdminTemplatesAnalyticsTrendPoint, metric: TrendMetricKey) {
  return point[metric];
}

function formatTrendValue(value: number, metric: TrendMetricKey, locale: AppLocale) {
  if (metric === "totalProviderCostUsd") {
    return formatMoney(value, locale);
  }

  return formatNumber(value, locale);
}

function formatNumber(value: number, locale: AppLocale) {
  return new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US", {
    maximumFractionDigits: value % 1 === 0 ? 0 : 1,
  }).format(value);
}

function formatPercent(value: number, isRu: boolean) {
  return `${new Intl.NumberFormat(isRu ? "ru-RU" : "en-US", { maximumFractionDigits: 1 }).format(value)}%`;
}

function formatTokens(value: number, isRu: boolean) {
  return `${new Intl.NumberFormat(isRu ? "ru-RU" : "en-US", { maximumFractionDigits: value % 1 === 0 ? 0 : 1 }).format(value)} PawSpark`;
}

function formatTemplateCount(value: number, locale: AppLocale, fallbackLabel: string) {
  const formattedValue = formatNumber(value, locale);
  if (locale !== "ru") {
    return `${formattedValue} ${fallbackLabel}`;
  }

  const normalized = Math.abs(value) % 100;
  const lastDigit = normalized % 10;
  const label =
    normalized > 10 && normalized < 20
      ? "шаблонов"
      : lastDigit === 1
        ? "шаблон"
        : lastDigit >= 2 && lastDigit <= 4
          ? "шаблона"
          : "шаблонов";

  return `${formattedValue} ${label}`;
}

function formatMoney(value: number, locale: AppLocale) {
  return new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: value > 0 && value < 1 ? 4 : 2,
    maximumFractionDigits: value > 0 && value < 1 ? 4 : 2,
  }).format(value);
}

function formatDateTime(value: string, locale: AppLocale) {
  return new Intl.DateTimeFormat(locale === "ru" ? "ru-RU" : "en-US", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}

function formatShortDate(value: string, locale: AppLocale) {
  return new Intl.DateTimeFormat(locale === "ru" ? "ru-RU" : "en-US", {
    day: "2-digit",
    month: "short",
  }).format(new Date(value));
}

function shortId(value: string) {
  const safeValue = formatAnalyticsDisplayText(value, 32).replace(/\s/g, "");
  if (!safeValue) {
    return "-";
  }

  return safeValue.length > 12 ? `${safeValue.slice(0, 8)}...${safeValue.slice(-4)}` : safeValue;
}

function formatAnalyticsValue(value: string | null | undefined) {
  const normalized = value?.trim();
  return normalized ? formatAnalyticsDisplayText(normalized, 96) : "-";
}

function getCopy(locale: AppLocale) {
  const isRu = locale === "ru";

  return {
    eyebrow: isRu ? "Интеллект шаблонов" : "Template intelligence",
    title: isRu ? "Аналитика шаблонов" : "Template analytics",
    description: isRu
      ? "Общая статистика по просмотрам, генерациям, расходам и эффективности шаблонов."
      : "Global view of template views, generations, spend, and performance.",
    catalog: isRu ? "Каталог" : "Catalog",
    export: isRu ? "Экспорт" : "Export",
    templates: isRu ? "Шаблонов" : "Templates",
    video: isRu ? "Видео" : "Video",
    image: isRu ? "Изображения" : "Images",
    updated: isRu ? "Обновлено" : "Updated",
    active: isRu ? "Активные" : "Active",
    premium: "Premium",
    free: "Free",
    loading: isRu ? "Загрузка аналитики шаблонов..." : "Loading template analytics...",
    loadError: isRu
      ? "Не удалось загрузить аналитику шаблонов."
      : "Failed to load template analytics.",
    partialErrorTitle: isRu
      ? "Отчет показан из последнего успешного ответа"
      : "Showing the last successful report",
    partialErrorDescription: isRu
      ? "Обновление аналитики не завершилось. Данные ниже остаются доступными."
      : "Template analytics did not refresh. The report below is still available.",
    retryAction: isRu ? "Повторить" : "Retry",
    periodLabel: isRu ? "Период" : "Period",
    typeFilter: isRu ? "Тип" : "Type",
    categoryFilter: isRu ? "Категория" : "Category",
    statusFilter: isRu ? "Статус" : "Status",
    accessFilter: isRu ? "Доступ" : "Access",
    sortFilter: isRu ? "Сортировка" : "Sort",
    allTemplates: isRu ? "Все шаблоны" : "All templates",
    allCategories: isRu ? "Все категории" : "All categories",
    allStatuses: isRu ? "Все статусы" : "All statuses",
    allAccess: isRu ? "Все" : "All",
    draft: isRu ? "Черновик" : "Draft",
    archived: isRu ? "Архив" : "Archived",
    sortViews: isRu ? "Просмотры" : "Views",
    sortStarts: isRu ? "Запуски" : "Starts",
    sortConversion: isRu ? "Конверсия" : "Conversion",
    sortCost: isRu ? "Затраты" : "Cost",
    sortUpdated: isRu ? "Обновление" : "Updated",
    views: isRu ? "Просмотры шаблонов" : "Template views",
    viewsHint: isRu
      ? "Просмотры всех выбранных шаблонов."
      : "View events across selected templates.",
    starts: isRu ? "Запуски генераций" : "Generation starts",
    startsHint: isRu
      ? "Запуски генерации за выбранный период."
      : "Generation jobs created in the selected period.",
    completed: isRu ? "Успешные генерации" : "Completed generations",
    completedHint: isRu ? "Завершились готовым результатом." : "Completed with an output result.",
    conversion: isRu ? "Конверсия в результат" : "Result conversion",
    conversionHint: isRu
      ? "Успешные генерации от всех запусков."
      : "Completed jobs divided by starts.",
    tokens: isRu ? "Потрачено PawSpark" : "PawSpark spend",
    tokensHint: isRu
      ? "Суммарный расход пользователей на генерации."
      : "Total user PawSpark spend for generations.",
    providerSpend: isRu ? "Наши затраты" : "Provider spend",
    providerSpendHint: isRu
      ? "Реальные USD-затраты на AI-провайдера."
      : "Real AI provider USD costs from jobs.",
    complaints: isRu ? "Жалобы" : "Complaints",
    complaintsHint: isRu
      ? "Количество complaint событий; ниже доступен список самих обращений."
      : "Complaint event count; see the feed below for actual messages.",
    feedbackTitle: isRu ? "Жалобы и фидбек" : "Complaints and feedback",
    feedbackHint: isRu
      ? "Последние complaint и feedback события по выбранным шаблонам с текстом сообщения и переходом в конкретный шаблон."
      : "Latest complaint and feedback events for the selected templates with message text and a link to the specific template.",
    feedbackEmpty: isRu
      ? "По выбранным фильтрам пока нет жалоб или фидбека."
      : "There are no complaints or feedback items for the current filters yet.",
    feedbackMessageMissing: isRu ? "Без текста сообщения." : "No message text provided.",
    feedbackTypeComplaint: isRu ? "Жалоба" : "Complaint",
    feedbackTypeFeedback: isRu ? "Фидбек" : "Feedback",
    feedbackSourceLabel: isRu ? "Источник" : "Source",
    feedbackDeviceLabel: isRu ? "Устройство" : "Device",
    feedbackCountryLabel: isRu ? "Страна" : "Country",
    feedbackUserLabel: isRu ? "Пользователь" : "User",
    feedbackGenerationLabel: isRu ? "Генерация" : "Generation",
    chartViews: isRu ? "Просмотры" : "Views",
    chartStarts: isRu ? "Запуски" : "Starts",
    chartCompleted: isRu ? "Успех" : "Completed",
    chartCost: isRu ? "Затраты" : "Cost",
    trendTitle: isRu ? "Динамика по времени" : "Trend over time",
    trendHint: isRu
      ? "Дневная динамика просмотров, запусков, успешных генераций и реальных затрат."
      : "Daily trend for views, starts, completions, and real spend.",
    noTrend: isRu ? "Пока нет точек тренда." : "No trend points yet.",
    currentMetric: isRu ? "Сумма выбранной метрики" : "Selected metric total",
    funnelTitle: isRu ? "Воронка конверсии" : "Conversion funnel",
    funnelHint: isRu
      ? "От просмотра шаблона до результата и жалоб."
      : "From template view to result and complaints.",
    funnelViews: isRu ? "Увидели шаблон" : "Viewed template",
    funnelStarts: isRu ? "Запустили генерацию" : "Started generation",
    funnelCompleted: isRu ? "Получили результат" : "Completed result",
    funnelFailed: isRu ? "Получили ошибку" : "Failed",
    funnelComplaints: isRu ? "Пожаловались" : "Complaints",
    categoriesTitle: isRu ? "Категории" : "Categories",
    categoriesHint: isRu
      ? "Где концентрируются просмотры, запуски и расходы."
      : "Where views, starts, and spend concentrate.",
    typesTitle: isRu ? "Типы шаблонов" : "Template types",
    typesHint: isRu ? "Видео и изображения в одной сводке." : "Video and Image in one overview.",
    sourcesTitle: isRu ? "Источники просмотров" : "View sources",
    sourcesHint: isRu
      ? "Откуда пользователи открывали выбранные шаблоны."
      : "Real source events for selected templates.",
    devicesTitle: isRu ? "Устройства" : "Devices",
    devicesHint: isRu
      ? "Классы устройств из публичной аналитики шаблонов."
      : "Device class from public analytics instrumentation.",
    geographyTitle: isRu ? "География" : "Geography",
    geographyHint: isRu
      ? "Страны из событий просмотра, без расчётных догадок."
      : "Country code from view events, without guessing.",
    startsShort: isRu ? "запусков" : "starts",
    topTitle: isRu ? "Топ шаблонов" : "Top templates",
    topHint: isRu
      ? "Сортировка синхронизирована с выбранными фильтрами."
      : "Sorted with the selected filters.",
    tableTitle: isRu ? "Все шаблоны" : "All templates",
    tableHint: isRu
      ? "Сводная таблица шаблонов по просмотрам, генерациям, ошибкам и реальным затратам."
      : "Template table with views, generations, failures, and real provider costs.",
    templateCountLabel: isRu ? "шаблонов" : "templates",
    refreshing: isRu ? "обновляется" : "refreshing",
    templateColumn: isRu ? "Шаблон" : "Template",
    typeColumn: isRu ? "Тип" : "Type",
    categoryColumn: isRu ? "Категория" : "Category",
    statusColumn: isRu ? "Статус" : "Status",
    accessColumn: isRu ? "Доступ" : "Access",
    viewsColumn: isRu ? "Просмотры" : "Views",
    startsColumn: isRu ? "Запуски" : "Starts",
    conversionColumn: isRu ? "Конверсия" : "Conversion",
    tokensColumn: isRu ? "PawSpark" : "PawSpark",
    costColumn: isRu ? "Затраты" : "Cost",
    actionsColumn: isRu ? "Действия" : "Actions",
    openAnalytics: isRu ? "Аналитика" : "Analytics",
    openEditor: isRu ? "Редактор" : "Editor",
    noRows: isRu
      ? "Под выбранные фильтры шаблоны не найдены."
      : "No templates match the selected filters.",
  };
}
