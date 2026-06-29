"use client";

import { useState } from "react";

import { ChartIcon, DashboardIcon, GlobeIcon, TrendUpIcon } from "@/components/admin/admin-icons";
import {
  getTemplateAccessLabel,
  getTemplateStatusLabel,
} from "@/components/templates/template-admin-shared";
import styles from "@/components/templates/template-analytics-page.module.css";
import {
  buildChartTicks,
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
  type TrendMetricKey,
} from "@/components/templates/template-analytics-utils";
import { inferTemplateMediaKind } from "@/components/templates/template-media-utils";
import { TemplateSecureMedia } from "@/components/templates/template-secure-media";
import {
  type AdminTemplate,
  type AdminTemplateEventAnalytics,
  type AdminTemplateStatistics,
  type AdminTemplateTrendPoint,
} from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type AnalyticsText = Record<string, string>;
type MetricAccent = "blue" | "green" | "red" | "cyan" | "neutral";

export function TemplateAnalyticsOverviewSection({
  kpiCards,
  locale,
  template,
  text,
}: {
  kpiCards: readonly {
    label: string;
    value: string;
    hint: string;
    accent: MetricAccent;
    delta?: number | null;
  }[];
  locale: Locale;
  template: AdminTemplate;
  text: AnalyticsText;
}) {
  return (
    <div className={styles.overviewGrid}>
      <TemplateProfileCard template={template} locale={locale} text={text} />

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
            locale={locale}
          />
        ))}
      </div>
    </div>
  );
}

export function TemplateAnalyticsVisualSection({
  chartMetric,
  chartPoints,
  chartTabs,
  isChartMetricLocked = false,
  locale,
  onChartMetricChange,
  statistics,
  text,
}: {
  chartMetric: TrendMetricKey;
  chartPoints: readonly AdminTemplateTrendPoint[];
  chartTabs: readonly { key: TrendMetricKey; label: string }[];
  isChartMetricLocked?: boolean;
  locale: Locale;
  onChartMetricChange: (value: TrendMetricKey) => void;
  statistics: AdminTemplateStatistics;
  text: AnalyticsText;
}) {
  return (
    <div className={styles.visualGrid}>
      <section className={`${styles.sectionCard} ${styles.sectionCardWide}`}>
        <div className={styles.sectionHeaderRow}>
          <div className={styles.sectionHeader}>
            <h2 className={styles.sectionTitleWithIcon}>
              <TrendUpIcon className={styles.sectionTitleIcon} />
              <span>{text.trendTitle}</span>
            </h2>
            <p>{text.trendHint}</p>
          </div>

          <div className={styles.chartTabs} aria-label={text.trendTitle}>
            {chartTabs.map((tab) => {
              const isActiveChartMetric = tab.key === chartMetric;

              return (
                <button
                  key={tab.key}
                  type="button"
                  className={isActiveChartMetric ? styles.chartTabActive : styles.chartTab}
                  disabled={isActiveChartMetric || isChartMetricLocked}
                  onClick={() => onChartMetricChange(tab.key)}
                >
                  <ChartIcon className={styles.controlIcon} />
                  <span>{tab.label}</span>
                </button>
              );
            })}
          </div>
        </div>
        <TrendChart
          points={chartPoints}
          metric={chartMetric}
          locale={locale}
          emptyLabel={text.trendEmpty}
          text={text}
        />
      </section>
      <section className={styles.sectionCard}>
        <div className={styles.sectionHeader}>
          <h2 className={styles.sectionTitleWithIcon}>
            <DashboardIcon className={styles.sectionTitleIcon} />
            <span>{text.statusBreakdownTitle}</span>
          </h2>
          <p>{text.statusBreakdownHint}</p>
        </div>
        <StatusRing statistics={statistics} text={text} locale={locale} />
      </section>
    </div>
  );
}

export function TemplateAnalyticsInsightGridSection({
  events,
  locale,
  statistics,
  text,
}: {
  events: AdminTemplateEventAnalytics;
  locale: Locale;
  statistics: AdminTemplateStatistics;
  text: AnalyticsText;
}) {
  return (
    <div className={styles.insightGrid}>
      <AnalyticsDimensionPanel
        title={text.sourcesTitle}
        hint={text.sourcesHint}
        emptyText={text.instrumentationPending}
        rows={events.sources}
        locale={locale}
      />
      <FunnelPanel statistics={statistics} text={text} locale={locale} />
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
  );
}

export function TemplateAnalyticsSnapshotSection({
  activeRuns,
  locale,
  statistics,
  template,
  text,
}: {
  activeRuns: number;
  locale: Locale;
  statistics: AdminTemplateStatistics;
  template: AdminTemplate;
  text: AnalyticsText;
}) {
  return (
    <section className={styles.sectionCard}>
      <div className={styles.sectionHeader}>
        <h2 className={styles.sectionTitleWithIcon}>
          <GlobeIcon className={styles.sectionTitleIcon} />
          <span>{text.snapshotTitle}</span>
        </h2>
        <p>{text.snapshotHint}</p>
      </div>

      <div className={styles.summaryGrid}>
        <SummaryRow label={text.totalRuns} value={String(statistics.totalRuns)} />
        <SummaryRow label={text.completedRuns} value={String(statistics.completedRuns)} />
        <SummaryRow label={text.failedRuns} value={String(statistics.failedRuns)} />
        <SummaryRow label={text.runsInQueue} value={String(statistics.queuedRuns)} />
        <SummaryRow label={text.processingNow} value={String(statistics.processingRuns)} />
        <SummaryRow
          label={text.successRate}
          value={formatPercent(statistics.successRatePercent, locale)}
        />
        <SummaryRow
          label={text.totalTokenCost}
          value={formatTokens(statistics.totalTokenCost, locale)}
        />
        <SummaryRow
          label={text.averageTokenCost}
          value={formatTokens(statistics.averageTokenCost, locale)}
        />
        <SummaryRow
          label={text.averageGenerationTime}
          value={formatDuration(statistics.averageGenerationSeconds, locale)}
        />
        <SummaryRow label={text.lastRun} value={formatDateTime(statistics.lastRunAtUtc, locale)} />
        <SummaryRow
          label={text.lastCompleted}
          value={formatDateTime(statistics.lastCompletedAtUtc, locale)}
        />
        <SummaryRow label={text.activeQueue} value={String(activeRuns)} />
        <SummaryRow
          label={text.estimatedTemplateCostLabel}
          value={formatUsd(template.estimatedProviderCostUsd, locale)}
        />
        <SummaryRow
          label={text.preprocessingModel}
          value={formatModelValue(template.preprocessingModel)}
        />
        <SummaryRow label={text.motionModel} value={formatModelValue(template.klingModel)} />
      </div>

      {!statistics.totalRuns ? <p className={styles.emptyState}>{text.noData}</p> : null}
    </section>
  );
}

function TemplateProfileCard({
  template,
  locale,
  text,
}: {
  template: AdminTemplate;
  locale: Locale;
  text: AnalyticsText;
}) {
  const dictionary = getDictionary(locale);
  const previewUrl = template.previewAsset?.url;
  const previewContentType = template.previewAsset?.contentType ?? "";
  const previewKind = previewUrl ? inferTemplateMediaKind(previewContentType, previewUrl) : null;
  const [brokenPreviewUrl, setBrokenPreviewUrl] = useState<string | null>(null);
  const isPreviewBroken = previewUrl === brokenPreviewUrl;
  const safeTemplateTitle = sanitizeSensitiveText(template.title, 96);
  const safeTemplateDescription = sanitizeSensitiveText(template.shortDescription, 180);
  const safeTemplateCategory = sanitizeSensitiveText(template.category, 64);

  return (
    <article className={styles.templateCard}>
      <div
        className={`${styles.templatePreviewWrap} ${previewKind === "video" ? styles.templatePreviewWrapVideo : ""}`.trim()}
      >
        {previewUrl && !isPreviewBroken ? (
          previewKind === "video" ? (
            <TemplateSecureMedia
              url={previewUrl}
              kind="video"
              className={styles.templatePreviewImage}
              muted
              playsInline
              autoPlay
              loop
              preload="metadata"
              onLoadFailed={() => setBrokenPreviewUrl(previewUrl)}
              logContext={{
                templateId: template.templateId,
                contentType: previewContentType,
                surface: "template_analytics_profile",
              }}
            />
          ) : (
            <TemplateSecureMedia
              url={previewUrl}
              kind="image"
              alt=""
              width={480}
              height={600}
              className={styles.templatePreviewImage}
              onLoadFailed={() => setBrokenPreviewUrl(previewUrl)}
              logContext={{
                templateId: template.templateId,
                contentType: previewContentType,
                surface: "template_analytics_profile",
              }}
            />
          )
        ) : (
          <div className={styles.templatePreviewFallback}>{safeTemplateTitle.slice(0, 1)}</div>
        )}
      </div>

      <div className={styles.templateCardBody}>
        <div className={styles.templateTitleRow}>
          <div>
            <span>{text.templateOverviewTitle}</span>
            <h2>{safeTemplateTitle}</h2>
          </div>
          <span
            className={`${styles.statusBadge} ${styles[getStatusBadgeClassName(template.status)]}`}
          >
            {getTemplateStatusLabel(template.status, locale)}
          </span>
        </div>

        <p>{safeTemplateDescription}</p>

        <div className={styles.templateMetaGrid}>
          <SummaryRow label={text.templateIdLabel} value={shortenId(template.templateId)} />
          <SummaryRow label={text.categoryLabel} value={safeTemplateCategory} />
          <SummaryRow
            label={text.priceLabel}
            value={getTemplateAccessLabel(template.isPremium, dictionary)}
          />
          <SummaryRow label={text.tokenCostLabel} value={formatTokens(template.tokenCost, locale)} />
          <SummaryRow
            label={text.estimatedTemplateCostLabel}
            value={formatUsd(template.estimatedProviderCostUsd, locale)}
          />
          <SummaryRow
            label={text.createdLabel}
            value={formatDateTime(template.createdAtUtc, locale)}
          />
          <SummaryRow
            label={text.updatedLabel}
            value={formatDateTime(template.updatedAtUtc, locale)}
          />
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
  locale,
}: {
  label: string;
  value: string;
  hint: string;
  accent: MetricAccent;
  delta?: number | null;
  text: AnalyticsText;
  locale: Locale;
}) {
  const deltaClassName =
    typeof delta === "number" && delta < 0 ? styles.deltaNegative : styles.deltaPositive;

  return (
    <article className={`${styles.statCard} ${styles[`statCard_${accent}`]}`}>
      <span>{label}</span>
      <strong>{value}</strong>
      <p>{hint}</p>
      {typeof delta === "number" ? (
        <small className={deltaClassName}>{formatDelta(delta, locale)}</small>
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
        <h2 className={styles.sectionTitleWithIcon}>
          <GlobeIcon className={styles.sectionTitleIcon} />
          <span>{title}</span>
        </h2>
        <p>{hint}</p>
      </div>
      {rows.length ? (
        <div className={styles.pendingList}>
          {rows.map((row) => (
            <div key={row.key} className={styles.dimensionRow}>
              <div>
                <span>{row.label}</span>
                <strong>{formatPercent(row.sharePercent, locale)}</strong>
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

function FunnelPanel({
  statistics,
  text,
  locale,
}: {
  statistics: AdminTemplateStatistics;
  text: AnalyticsText;
  locale: Locale;
}) {
  const total = Math.max(statistics.totalRuns, 1);
  const rows = [
    { label: text.funnelStarted, value: statistics.totalRuns, percent: 100 },
    {
      label: text.funnelCompleted,
      value: statistics.completedRuns,
      percent: (statistics.completedRuns / total) * 100,
    },
    {
      label: text.funnelFailed,
      value: statistics.failedRuns,
      percent: (statistics.failedRuns / total) * 100,
    },
    {
      label: text.funnelActive,
      value: statistics.queuedRuns + statistics.processingRuns,
      percent: ((statistics.queuedRuns + statistics.processingRuns) / total) * 100,
    },
  ];

  return (
    <section className={styles.sectionCard}>
      <div className={styles.sectionHeader}>
        <h2 className={styles.sectionTitleWithIcon}>
          <TrendUpIcon className={styles.sectionTitleIcon} />
          <span>{text.retentionTitle}</span>
        </h2>
        <p>{text.retentionHint}</p>
      </div>
      <div className={styles.funnelList}>
        {rows.map((row) => (
          <div key={row.label} className={styles.funnelRow}>
            <div>
              <span>{row.label}</span>
              <strong>{formatPercent(row.percent, locale)}</strong>
              <em>{formatNumber(row.value, locale)}</em>
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
  text: AnalyticsText;
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
    const x =
      points.length === 1 ? width / 2 : paddingX + (graphWidth * index) / (points.length - 1);
    const y = paddingTop + graphHeight - (value / maxValue) * graphHeight;
    return { point, value, x, y };
  });

  const linePath = coordinates
    .map(({ x, y }, index) => `${index === 0 ? "M" : "L"} ${x.toFixed(2)} ${y.toFixed(2)}`)
    .join(" ");
  const areaPath = `${linePath} L ${coordinates[coordinates.length - 1]!.x.toFixed(2)} ${(paddingTop + graphHeight).toFixed(2)} L ${coordinates[0]!.x.toFixed(2)} ${(paddingTop + graphHeight).toFixed(2)} Z`;

  return (
    <div className={styles.chartShell}>
      <svg
        viewBox={`0 0 ${width} ${height}`}
        className={styles.chartSvg}
        aria-label="Template analytics trend chart"
        role="img"
      >
        <defs>
          <linearGradient id="template-analytics-area" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0%" stopColor="var(--success)" stopOpacity="0.36" />
            <stop offset="100%" stopColor="var(--success)" stopOpacity="0.02" />
          </linearGradient>
        </defs>

        {yTicks.map((tick, index) => {
          const y = paddingTop + (graphHeight * index) / (yTicks.length - 1 || 1);
          return (
            <g key={`${tick}-${index}`}>
              <line
                x1={paddingX}
                y1={y}
                x2={width - paddingX}
                y2={y}
                className={styles.chartGridLine}
              />
              <text x={paddingX} y={y - 6} className={styles.chartTick}>
                {formatTrendValue(tick, metric, locale, text.failedRuns)}
              </text>
            </g>
          );
        })}

        <path d={areaPath} className={styles.chartArea} />
        <path d={linePath} className={styles.chartLine} />

        {coordinates.map(({ point, value, x, y }) => {
          const label = formatTrendValue(value, metric, locale, text.failedRuns);
          const labelWidth = Math.max(48, Math.min(132, label.length * 7.2 + 20));
          const labelX = Math.min(
            width - paddingX - labelWidth,
            Math.max(paddingX, x - labelWidth / 2)
          );
          const labelY = Math.max(8, y - 34);

          return (
            <g key={point.dateUtc}>
              <rect
                x={labelX}
                y={labelY}
                width={labelWidth}
                height="24"
                rx="8"
                className={styles.chartPointBadge}
              />
              <text
                x={labelX + labelWidth / 2}
                y={labelY + 16}
                textAnchor="middle"
                className={styles.chartPointValue}
              >
                {label}
              </text>
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
            <strong>
              {formatTrendValue(
                getTrendMetricValue(point, metric),
                metric,
                locale,
                text.failedRuns
              )}
            </strong>
          </div>
        ))}
      </div>
    </div>
  );
}

function StatusRing({
  statistics,
  text,
  locale,
}: {
  statistics: AdminTemplateStatistics;
  text: AnalyticsText;
  locale: Locale;
}) {
  const total = Math.max(statistics.totalRuns, 1);
  const segments = [
    { label: text.completedRuns, value: statistics.completedRuns, color: "var(--success)" },
    { label: text.failedRuns, value: statistics.failedRuns, color: "var(--danger)" },
    { label: text.runsInQueue, value: statistics.queuedRuns, color: "var(--info)" },
    { label: text.processingNow, value: statistics.processingRuns, color: "var(--warning)" },
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
  const background = gradient
    ? `conic-gradient(${gradient})`
    : "conic-gradient(var(--surface-3) 0 100%)";

  return (
    <div className={styles.ringSection}>
      <div className={styles.ringWrap}>
        <div className={styles.ringOuter} style={{ background }}>
          <div className={styles.ringInner}>
            <strong>{statistics.totalRuns}</strong>
            <span>{text.runsLabel}</span>
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
