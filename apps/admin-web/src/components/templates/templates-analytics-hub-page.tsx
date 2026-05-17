"use client";

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
import { AdminMetricStrip, AdminPageHero } from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { getTemplateAccessLabel, getTemplateStatusLabel, getTemplateTypeLabel } from "@/components/templates/template-admin-shared";
import styles from "@/components/templates/templates-analytics-hub-page.module.css";
import {
    fetchAdminTemplatesAnalyticsOverview,
    type AdminTemplateAnalyticsDimension,
    type AdminTemplatesAnalyticsBreakdown,
    type AdminTemplatesAnalyticsOverview,
    type AdminTemplatesAnalyticsQuery,
    type AdminTemplatesAnalyticsTemplateRow,
    type AdminTemplatesAnalyticsTrendPoint,
    type TemplateStatus,
    type TemplateType,
} from "@/lib/api-client";
import { getDictionary, type Locale as AppLocale } from "@/lib/i18n";
import Image from "next/image";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";

type TemplatesAnalyticsHubPageProps = {
  locale: AppLocale;
};

type PeriodKey = "7" | "30" | "90" | "all";
type TrendMetricKey = "totalViews" | "totalGenerationStarts" | "completedGenerations" | "estimatedRevenueUsd" | "totalProviderCostUsd";

type Copy = ReturnType<typeof getCopy>;

const PERIOD_OPTIONS: Array<{ key: PeriodKey; ru: string; en: string }> = [
  { key: "7", ru: "7 дней", en: "7 days" },
  { key: "30", ru: "30 дней", en: "30 days" },
  { key: "90", ru: "90 дней", en: "90 days" },
  { key: "all", ru: "Всё время", en: "All time" },
];

export function TemplatesAnalyticsHubPage({ locale }: TemplatesAnalyticsHubPageProps) {
  const isRu = locale === "ru";
  const text = useMemo(() => getCopy(locale), [locale]);
  const dictionary = useMemo(() => getDictionary(locale), [locale]);
  const router = useRouter();
  const [overview, setOverview] = useState<AdminTemplatesAnalyticsOverview | null>(null);
  const [period, setPeriod] = useState<PeriodKey>("30");
  const [templateType, setTemplateType] = useState<TemplateType | "All">("All");
  const [category, setCategory] = useState("");
  const [status, setStatus] = useState<TemplateStatus | "All">("All");
  const [access, setAccess] = useState<"all" | "free" | "premium">("all");
  const [sort, setSort] = useState<NonNullable<AdminTemplatesAnalyticsQuery["sort"]>>("views");
  const [chartMetric, setChartMetric] = useState<TrendMetricKey>("totalViews");
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const query = useMemo<AdminTemplatesAnalyticsQuery>(() => ({
    periodDays: period === "all" ? undefined : Number(period),
    templateType,
    category: category || undefined,
    status,
    access,
    sort,
    take: 50,
  }), [access, category, period, sort, status, templateType]);

  useEffect(() => {
    let isCancelled = false;

    async function loadOverview() {
      setIsLoading(true);
      setError(null);

      try {
        if (!ensureAdminSession(locale, router)) {
          return;
        }

        const response = await fetchAdminTemplatesAnalyticsOverview(query);
        if (!isCancelled) {
          setOverview(response);
        }
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

    void loadOverview();

    return () => {
      isCancelled = true;
    };
  }, [locale, query, router, text.loadError]);

  function handleExport() {
    if (!overview) {
      return;
    }

    const blob = new Blob([JSON.stringify({ query, overview }, null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `templates-analytics-${new Date().toISOString().slice(0, 10)}.json`;
    link.click();
    URL.revokeObjectURL(url);
  }

  if (isLoading && !overview) {
    return <section className={styles.page}><div className={styles.stateCard}>{text.loading}</div></section>;
  }

  if (error || !overview) {
    return <section className={styles.page}><div className={styles.stateCard}>{error ?? text.loadError}</div></section>;
  }

  const summary = overview.summary;
  const kpis = [
    { label: text.views, value: formatNumber(summary.totalViews, locale), hint: text.viewsHint, tone: "green" },
    { label: text.starts, value: formatNumber(summary.totalGenerationStarts, locale), hint: text.startsHint, tone: "violet" },
    { label: text.completed, value: formatNumber(summary.completedGenerations, locale), hint: text.completedHint, tone: "green" },
    { label: text.conversion, value: formatPercent(summary.conversionPercent, isRu), hint: text.conversionHint, tone: "blue" },
    { label: text.tokens, value: formatTokens(summary.totalTokenCost, isRu), hint: text.tokensHint, tone: "amber" },
    { label: text.revenue, value: formatMoney(summary.estimatedRevenueUsd, locale), hint: text.revenueHint, tone: "green" },
    { label: text.providerSpend, value: formatMoney(summary.totalProviderCostUsd, locale), hint: text.providerSpendHint, tone: "red" },
    { label: text.complaints, value: formatNumber(summary.totalComplaints, locale), hint: text.complaintsHint, tone: summary.totalComplaints > 0 ? "red" : "neutral" },
  ];
  const chartTabs: Array<{ key: TrendMetricKey; label: string }> = [
    { key: "totalViews", label: text.chartViews },
    { key: "totalGenerationStarts", label: text.chartStarts },
    { key: "completedGenerations", label: text.chartCompleted },
    { key: "estimatedRevenueUsd", label: text.chartRevenue },
    { key: "totalProviderCostUsd", label: text.chartCost },
  ];

  return (
    <section className={styles.page}>
      <AdminPageHero
        eyebrow={text.eyebrow}
        title={text.title}
        description={text.description}
        badge={<span className={styles.heroBadge}>{text.liveBadge}</span>}
        actions={(
          <div className={styles.heroActions}>
            <Link href={`/${locale}/templates/video`} className={styles.secondaryLink}><TableIcon className={styles.controlIcon} /><span>{text.catalog}</span></Link>
            <button type="button" className={styles.primaryButton} onClick={handleExport}><DownloadIcon className={styles.controlIcon} /><span>{text.export}</span></button>
          </div>
        )}
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
          { label: text.margin, value: formatMoney(summary.estimatedGrossMarginUsd, locale) },
          { label: text.averageTokenCost, value: formatTokens(summary.averageTokenCost, isRu) },
        ]}
      />

      <div className={styles.toolbar}>
        <div className={styles.segmented} aria-label={text.periodLabel}>
          {PERIOD_OPTIONS.map((option) => (
            <button key={option.key} type="button" className={period === option.key ? styles.segmentedActive : styles.segmentedButton} onClick={() => setPeriod(option.key)}>
              <CalendarIcon className={styles.controlIcon} />
              <span>{isRu ? option.ru : option.en}</span>
            </button>
          ))}
        </div>

        <div className={styles.filters}>
          <SelectBox label={text.typeFilter} value={templateType} onChange={(value) => setTemplateType(value as TemplateType | "All")} options={[{ value: "All", label: text.allTemplates }, { value: "Video", label: getTemplateTypeLabel("Video", dictionary) }, { value: "Image", label: getTemplateTypeLabel("Image", dictionary) }]} />
          <SelectBox label={text.categoryFilter} value={category} onChange={setCategory} options={[{ value: "", label: text.allCategories }, ...overview.availableCategories.map((value) => ({ value, label: value }))]} />
          <SelectBox label={text.statusFilter} value={status} onChange={(value) => setStatus(value as TemplateStatus | "All")} options={[{ value: "All", label: text.allStatuses }, { value: "Active", label: getTemplateStatusLabel("Active", locale) }, { value: "Draft", label: getTemplateStatusLabel("Draft", locale) }, { value: "Archived", label: getTemplateStatusLabel("Archived", locale) }]} />
          <SelectBox label={text.accessFilter} value={access} onChange={(value) => setAccess(value as "all" | "free" | "premium")} options={[{ value: "all", label: text.allAccess }, { value: "free", label: getTemplateAccessLabel(false, dictionary) }, { value: "premium", label: getTemplateAccessLabel(true, dictionary) }]} />
          <SelectBox label={text.sortFilter} value={sort} onChange={(value) => setSort(value as NonNullable<AdminTemplatesAnalyticsQuery["sort"]>)} options={[{ value: "views", label: text.sortViews }, { value: "starts", label: text.sortStarts }, { value: "conversion", label: text.sortConversion }, { value: "revenue", label: text.sortRevenue }, { value: "cost", label: text.sortCost }, { value: "updated", label: text.sortUpdated }]} />
        </div>
      </div>

      <div className={styles.kpiGrid}>
        {kpis.map((item) => <KpiCard key={item.label} {...item} />)}
      </div>

      <div className={styles.mainGrid}>
        <section className={`${styles.panel} ${styles.panelWide}`}>
          <div className={styles.panelHeaderRow}>
            <div>
              <h2 className={styles.panelTitle}><TrendUpIcon className={styles.panelIcon} />{text.trendTitle}</h2>
              <p>{text.trendHint}</p>
            </div>
            <div className={styles.chartTabs}>
              {chartTabs.map((tab) => (
                <button key={tab.key} type="button" className={chartMetric === tab.key ? styles.chartTabActive : styles.chartTab} onClick={() => setChartMetric(tab.key)}>
                  {tab.label}
                </button>
              ))}
            </div>
          </div>
          <TrendChart points={overview.trendPoints} metric={chartMetric} locale={locale} text={text} />
        </section>

        <section className={styles.panel}>
          <div className={styles.panelHeader}>
            <h2 className={styles.panelTitle}><DashboardIcon className={styles.panelIcon} />{text.funnelTitle}</h2>
            <p>{text.funnelHint}</p>
          </div>
          <FunnelList overview={overview} locale={locale} text={text} />
        </section>
      </div>

      <div className={styles.secondaryGrid}>
        <BreakdownPanel title={text.categoriesTitle} hint={text.categoriesHint} rows={overview.categories} locale={locale} templateCountLabel={text.templateCountLabel} />
        <TypePanel rows={overview.templateTypes} locale={locale} text={text} />
        <TopTemplatesPanel rows={overview.topTemplates} locale={locale} text={text} />
      </div>

      <div className={styles.dimensionGrid}>
        <EventDimensionPanel title={text.sourcesTitle} hint={text.sourcesHint} rows={overview.sources} locale={locale} />
        <EventDimensionPanel title={text.devicesTitle} hint={text.devicesHint} rows={overview.devices} locale={locale} />
        <EventDimensionPanel title={text.geographyTitle} hint={text.geographyHint} rows={overview.geography} locale={locale} />
      </div>

      <section className={styles.panel}>
        <div className={styles.panelHeaderRow}>
          <div>
            <h2 className={styles.panelTitle}><TableIcon className={styles.panelIcon} />{text.tableTitle}</h2>
            <p>{text.tableHint}</p>
          </div>
          {isLoading ? <span className={styles.refreshPill}>{text.refreshing}</span> : null}
        </div>
        <TemplatesTable rows={overview.templates} locale={locale} text={text} />
      </section>
    </section>
  );
}

function SelectBox({ label, value, options, onChange }: { label: string; value: string; options: Array<{ value: string; label: string }>; onChange: (value: string) => void }) {
  return (
    <label className={styles.selectWrap}>
      <span>{label}</span>
      <select value={value} onChange={(event) => onChange(event.target.value)}>
        {options.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}
      </select>
    </label>
  );
}

function KpiCard({ label, value, hint, tone }: { label: string; value: string; hint: string; tone: string }) {
  return (
    <article className={`${styles.kpiCard} ${styles[`kpi_${tone}`]}`}>
      <span>{label}</span>
      <strong>{value}</strong>
      <p>{hint}</p>
    </article>
  );
}

function TrendChart({ points, metric, locale, text }: { points: AdminTemplatesAnalyticsTrendPoint[]; metric: TrendMetricKey; locale: AppLocale; text: Copy }) {
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
  const path = coordinates.map((point, index) => `${index === 0 ? "M" : "L"}${point.x},${point.y}`).join(" ");
  const area = `${path} L${paddingX + chartWidth},${height - paddingY} L${paddingX},${height - paddingY} Z`;

  return (
    <div className={styles.chartWrap}>
      <svg viewBox={`0 0 ${width} ${height}`} className={styles.chartSvg} role="img" aria-label={text.trendTitle}>
        <defs>
          <linearGradient id="templatesHubLine" x1="0" x2="1" y1="0" y2="0">
            <stop offset="0" stopColor="#22c55e" />
            <stop offset="1" stopColor="#38bdf8" />
          </linearGradient>
          <linearGradient id="templatesHubArea" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0" stopColor="#22c55e" stopOpacity="0.22" />
            <stop offset="1" stopColor="#22c55e" stopOpacity="0" />
          </linearGradient>
        </defs>
        {[0, 0.25, 0.5, 0.75, 1].map((ratio, index) => {
          const y = paddingY + chartHeight * ratio;
          const value = maxValue * (1 - ratio);
          return (
            <g key={`${ratio}-${index}`}>
              <line x1={paddingX} x2={width - paddingX} y1={y} y2={y} className={styles.gridLine} />
              <text x={paddingX} y={y - 5} className={styles.tickLabel}>{formatTrendValue(value, metric, locale)}</text>
            </g>
          );
        })}
        <path d={area} fill="url(#templatesHubArea)" />
        <path d={path} fill="none" stroke="url(#templatesHubLine)" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />
        {coordinates.map((point, index) => (
          <g key={`${point.point.dateUtc}-${index}`}>
            <circle cx={point.x} cy={point.y} r="4.5" className={styles.chartPoint} />
            <text x={point.x} y={height - 8} className={styles.dateLabel}>{formatShortDate(point.point.dateUtc, locale)}</text>
          </g>
        ))}
      </svg>
      <div className={styles.chartSummary}>
        <span>{text.currentMetric}</span>
        <strong>{formatTrendValue(values.reduce((total, value) => total + value, 0), metric, locale)}</strong>
      </div>
    </div>
  );
}

function FunnelList({ overview, locale, text }: { overview: AdminTemplatesAnalyticsOverview; locale: AppLocale; text: Copy }) {
  const max = Math.max(1, overview.conversionFunnel.views, overview.conversionFunnel.generationStarts, overview.conversionFunnel.completedGenerations, overview.conversionFunnel.failedGenerations);
  const rows = [
    { label: text.funnelViews, value: overview.conversionFunnel.views, tone: "green" },
    { label: text.funnelStarts, value: overview.conversionFunnel.generationStarts, tone: "violet" },
    { label: text.funnelCompleted, value: overview.conversionFunnel.completedGenerations, tone: "blue" },
    { label: text.funnelFailed, value: overview.conversionFunnel.failedGenerations, tone: "red" },
    { label: text.funnelComplaints, value: overview.conversionFunnel.complaints, tone: "amber" },
  ];

  return (
    <div className={styles.funnelList}>
      {rows.map((row) => (
        <div key={row.label} className={styles.funnelRow}>
          <div><span>{row.label}</span><strong>{formatNumber(row.value, locale)}</strong></div>
          <div className={styles.funnelTrack}><span className={styles[`funnel_${row.tone}`]} style={{ width: `${Math.max(5, (row.value / max) * 100)}%` }} /></div>
        </div>
      ))}
    </div>
  );
}

function BreakdownPanel({ title, hint, rows, locale, templateCountLabel }: { title: string; hint: string; rows: AdminTemplatesAnalyticsBreakdown[]; locale: AppLocale; templateCountLabel: string }) {
  const maxViews = Math.max(1, ...rows.map((row) => row.views));

  return (
    <section className={styles.panel}>
      <div className={styles.panelHeader}>
        <h2 className={styles.panelTitle}><ChartIcon className={styles.panelIcon} />{title}</h2>
        <p>{hint}</p>
      </div>
      <div className={styles.breakdownList}>
        {rows.slice(0, 6).map((row) => (
          <div key={row.key} className={styles.breakdownRow}>
            <div className={styles.breakdownMeta}><strong>{row.label}</strong><span>{formatTemplateCount(row.templateCount, locale, templateCountLabel)}</span></div>
            <div className={styles.breakdownBar}><span style={{ width: `${Math.max(6, (row.views / maxViews) * 100)}%` }} /></div>
            <span>{formatNumber(row.views, locale)}</span>
          </div>
        ))}
        {!rows.length ? <div className={styles.emptyState}>-</div> : null}
      </div>
    </section>
  );
}

function TypePanel({ rows, locale, text }: { rows: AdminTemplatesAnalyticsBreakdown[]; locale: AppLocale; text: Copy }) {
  const dictionary = getDictionary(locale);
  return (
    <section className={styles.panel}>
      <div className={styles.panelHeader}>
        <h2 className={styles.panelTitle}><VideoIcon className={styles.panelIcon} />{text.typesTitle}</h2>
        <p>{text.typesHint}</p>
      </div>
      <div className={styles.typeGrid}>
        {rows.map((row) => (
          <article key={row.key} className={styles.typeCard}>
            {row.key === "image" ? <ImageIcon className={styles.typeIcon} /> : <VideoIcon className={styles.typeIcon} />}
            <span>{getTemplateTypeLabel(row.key === "image" ? "Image" : "Video", dictionary)}</span>
            <strong>{formatNumber(row.views, locale)}</strong>
            <p>{formatNumber(row.generationStarts, locale)} {text.startsShort} · {formatPercent(row.conversionPercent, locale === "ru")}</p>
            <p>{formatMoney(row.estimatedRevenueUsd, locale)} · {formatMoney(row.totalProviderCostUsd, locale)}</p>
          </article>
        ))}
      </div>
    </section>
  );
}

function EventDimensionPanel({ title, hint, rows, locale }: { title: string; hint: string; rows: AdminTemplateAnalyticsDimension[]; locale: AppLocale }) {
  return (
    <section className={styles.panel}>
      <div className={styles.panelHeader}>
        <h2 className={styles.panelTitle}><ChartIcon className={styles.panelIcon} />{title}</h2>
        <p>{hint}</p>
      </div>
      <div className={styles.dimensionList}>
        {rows.slice(0, 6).map((row) => (
          <div key={row.key} className={styles.dimensionRow}>
            <div>
              <strong>{row.label}</strong>
              <span>{formatNumber(row.count, locale)}</span>
            </div>
            <div className={styles.dimensionTrack}>
              <span style={{ width: `${Math.max(5, row.sharePercent)}%` }} />
            </div>
            <em>{formatPercent(row.sharePercent, locale === "ru")}</em>
          </div>
        ))}
        {!rows.length ? <div className={styles.emptyState}>-</div> : null}
      </div>
    </section>
  );
}

function TopTemplatesPanel({ rows, locale, text }: { rows: AdminTemplatesAnalyticsTemplateRow[]; locale: AppLocale; text: Copy }) {
  const dictionary = getDictionary(locale);
  return (
    <section className={`${styles.panel} ${styles.topPanel}`}>
      <div className={styles.panelHeader}>
        <h2 className={styles.panelTitle}><DashboardIcon className={styles.panelIcon} />{text.topTitle}</h2>
        <p>{text.topHint}</p>
      </div>
      <div className={styles.topList}>
        {rows.map((row, index) => (
          <div key={row.templateId} className={styles.topRow}>
            <span className={styles.rank}>{index + 1}</span>
            <TemplateThumb row={row} />
            <div>
              <strong>{row.title}</strong>
              <span>{getTemplateTypeLabel(row.templateType, dictionary)} · {row.category}</span>
            </div>
            <span>{formatNumber(row.views, locale)}</span>
            <span>{formatMoney(row.estimatedRevenueUsd, locale)}</span>
          </div>
        ))}
      </div>
    </section>
  );
}

function TemplatesTable({ rows, locale, text }: { rows: AdminTemplatesAnalyticsTemplateRow[]; locale: AppLocale; text: Copy }) {
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
            <th>{text.revenueColumn}</th>
            <th>{text.actionsColumn}</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row.templateId}>
              <td><div className={styles.templateCell}><TemplateThumb row={row} /><div><strong>{row.title}</strong><span>{shortId(row.templateId)}</span></div></div></td>
              <td>{getTemplateTypeLabel(row.templateType, dictionary)}</td>
              <td>{row.category}</td>
              <td><span className={`${styles.statusBadge} ${styles[`status_${row.status.toLowerCase()}`]}`}>{getTemplateStatusLabel(row.status, locale)}</span></td>
              <td>{getTemplateAccessLabel(row.isPremium, dictionary)}</td>
              <td>{formatNumber(row.views, locale)}</td>
              <td>{formatNumber(row.generationStarts, locale)}</td>
              <td>{formatPercent(row.conversionPercent, locale === "ru")}</td>
              <td>{formatTokens(row.totalTokenCost, locale === "ru")}</td>
              <td>{formatMoney(row.totalProviderCostUsd, locale)}</td>
              <td>{formatMoney(row.estimatedRevenueUsd, locale)}</td>
              <td>
                {row.templateType === "Video" ? (
                  <Link className={styles.inlineAction} href={`/${locale}/templates/video/analytics/${row.templateId}`}>{text.openAnalytics}</Link>
                ) : (
                  <Link className={styles.inlineAction} href={`/${locale}/templates/image/editor?templateId=${row.templateId}`}>{text.openEditor}</Link>
                )}
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
    return <div className={styles.thumbFallback}>{row.title.slice(0, 1)}</div>;
  }

  return <Image src={previewUrl} alt="" width={48} height={48} unoptimized className={styles.thumb} />;
}

function getTrendValue(point: AdminTemplatesAnalyticsTrendPoint, metric: TrendMetricKey) {
  return point[metric];
}

function formatTrendValue(value: number, metric: TrendMetricKey, locale: AppLocale) {
  if (metric === "estimatedRevenueUsd" || metric === "totalProviderCostUsd") {
    return formatMoney(value, locale);
  }

  return formatNumber(value, locale);
}

function formatNumber(value: number, locale: AppLocale) {
  return new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US", { maximumFractionDigits: value % 1 === 0 ? 0 : 1 }).format(value);
}

function formatPercent(value: number, isRu: boolean) {
  return `${new Intl.NumberFormat(isRu ? "ru-RU" : "en-US", { maximumFractionDigits: 1 }).format(value)}%`;
}

function formatTokens(value: number, isRu: boolean) {
  return `${new Intl.NumberFormat(isRu ? "ru-RU" : "en-US", { maximumFractionDigits: value % 1 === 0 ? 0 : 1 }).format(value)} ${isRu ? "токенов" : "tokens"}`;
}

function formatTemplateCount(value: number, locale: AppLocale, fallbackLabel: string) {
  const formattedValue = formatNumber(value, locale);
  if (locale !== "ru") {
    return `${formattedValue} ${fallbackLabel}`;
  }

  const normalized = Math.abs(value) % 100;
  const lastDigit = normalized % 10;
  const label = normalized > 10 && normalized < 20
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
  return new Intl.DateTimeFormat(locale === "ru" ? "ru-RU" : "en-US", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value));
}

function formatShortDate(value: string, locale: AppLocale) {
  return new Intl.DateTimeFormat(locale === "ru" ? "ru-RU" : "en-US", { day: "2-digit", month: "short" }).format(new Date(value));
}

function shortId(value: string) {
  return `${value.slice(0, 8)}...${value.slice(-4)}`;
}

function getCopy(locale: AppLocale) {
  const isRu = locale === "ru";

  return {
    eyebrow: isRu ? "Интеллект шаблонов" : "Template intelligence",
    title: isRu ? "Аналитика шаблонов" : "Template analytics",
    description: isRu ? "Общая статистика по просмотрам, генерациям, расходам и эффективности шаблонов." : "Global view of template views, generations, spend, and performance.",
    liveBadge: isRu ? "Данные с сервера" : "Live backend data",
    catalog: isRu ? "Каталог" : "Catalog",
    export: isRu ? "Экспорт" : "Export",
    templates: isRu ? "Шаблонов" : "Templates",
    video: isRu ? "Видео" : "Video",
    image: isRu ? "Изображения" : "Images",
    updated: isRu ? "Обновлено" : "Updated",
    active: isRu ? "Активные" : "Active",
    premium: "Premium",
    free: "Free",
    margin: isRu ? "Маржа" : "Margin",
    averageTokenCost: isRu ? "Средний расход" : "Average spend",
    loading: isRu ? "Загрузка аналитики шаблонов..." : "Loading template analytics...",
    loadError: isRu ? "Не удалось загрузить аналитику шаблонов." : "Failed to load template analytics.",
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
    sortRevenue: isRu ? "Доход" : "Revenue",
    sortCost: isRu ? "Затраты" : "Cost",
    sortUpdated: isRu ? "Обновление" : "Updated",
    views: isRu ? "Просмотры шаблонов" : "Template views",
    viewsHint: isRu ? "Просмотры всех выбранных шаблонов." : "View events across selected templates.",
    starts: isRu ? "Запуски генераций" : "Generation starts",
    startsHint: isRu ? "Запуски генерации за выбранный период." : "Generation jobs created in the selected period.",
    completed: isRu ? "Успешные генерации" : "Completed generations",
    completedHint: isRu ? "Завершились готовым результатом." : "Completed with an output result.",
    conversion: isRu ? "Конверсия в результат" : "Result conversion",
    conversionHint: isRu ? "Успешные генерации от всех запусков." : "Completed jobs divided by starts.",
    tokens: isRu ? "Потрачено токенов" : "Token spend",
    tokensHint: isRu ? "Суммарный расход пользователей на генерации." : "Total user token spend for generations.",
    revenue: isRu ? "Доход (оценка)" : "Revenue estimate",
    revenueHint: isRu ? "Оценка по токенам, пока без платежной модели." : "Estimated from tokens until payment data exists.",
    providerSpend: isRu ? "Наши затраты" : "Provider spend",
    providerSpendHint: isRu ? "Реальные USD-затраты на AI-провайдера." : "Real AI provider USD costs from jobs.",
    complaints: isRu ? "Жалобы" : "Complaints",
    complaintsHint: isRu ? "Жалобы из событий аналитики." : "Complaint events from analytics endpoint.",
    chartViews: isRu ? "Просмотры" : "Views",
    chartStarts: isRu ? "Запуски" : "Starts",
    chartCompleted: isRu ? "Успех" : "Completed",
    chartRevenue: isRu ? "Доход" : "Revenue",
    chartCost: isRu ? "Затраты" : "Cost",
    trendTitle: isRu ? "Динамика по времени" : "Trend over time",
    trendHint: isRu ? "Дневная динамика просмотров, запусков, дохода и реальных затрат." : "Daily backend buckets for views, starts, revenue, and real spend.",
    noTrend: isRu ? "Пока нет точек тренда." : "No trend points yet.",
    currentMetric: isRu ? "Сумма выбранной метрики" : "Selected metric total",
    funnelTitle: isRu ? "Воронка конверсии" : "Conversion funnel",
    funnelHint: isRu ? "От просмотра шаблона до результата и жалоб." : "From template view to result and complaints.",
    funnelViews: isRu ? "Увидели шаблон" : "Viewed template",
    funnelStarts: isRu ? "Запустили генерацию" : "Started generation",
    funnelCompleted: isRu ? "Получили результат" : "Completed result",
    funnelFailed: isRu ? "Получили ошибку" : "Failed",
    funnelComplaints: isRu ? "Пожаловались" : "Complaints",
    categoriesTitle: isRu ? "Категории" : "Categories",
    categoriesHint: isRu ? "Где концентрируются просмотры, запуски и расходы." : "Where views, starts, and spend concentrate.",
    typesTitle: isRu ? "Типы шаблонов" : "Template types",
    typesHint: isRu ? "Видео и изображения в одной сводке." : "Video and Image in one overview.",
    sourcesTitle: isRu ? "Источники просмотров" : "View sources",
    sourcesHint: isRu ? "Откуда пользователи открывали выбранные шаблоны." : "Real source events for selected templates.",
    devicesTitle: isRu ? "Устройства" : "Devices",
    devicesHint: isRu ? "Классы устройств из публичной аналитики шаблонов." : "Device class from public analytics instrumentation.",
    geographyTitle: isRu ? "География" : "Geography",
    geographyHint: isRu ? "Страны из событий просмотра, без расчётных догадок." : "Country code from view events, without guessing.",
    startsShort: isRu ? "запусков" : "starts",
    topTitle: isRu ? "Топ шаблонов" : "Top templates",
    topHint: isRu ? "Сортировка синхронизирована с выбранными фильтрами." : "Sorted by the backend query.",
    tableTitle: isRu ? "Все шаблоны" : "All templates",
    tableHint: isRu ? "Строки приходят из общего серверного API; admin UI не обращается к базе напрямую." : "Rows come from the aggregate endpoint, with no direct DB access from admin UI.",
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
    tokensColumn: isRu ? "Токены" : "Tokens",
    costColumn: isRu ? "Затраты" : "Cost",
    revenueColumn: isRu ? "Доход" : "Revenue",
    actionsColumn: isRu ? "Действия" : "Actions",
    openAnalytics: isRu ? "Аналитика" : "Analytics",
    openEditor: isRu ? "Редактор" : "Editor",
    noRows: isRu ? "Под выбранные фильтры шаблоны не найдены." : "No templates match the selected filters.",
  };
}