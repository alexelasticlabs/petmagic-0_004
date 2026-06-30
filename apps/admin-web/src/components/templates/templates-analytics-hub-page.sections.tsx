"use client";

import Link from "next/link";

import {
  ChartIcon,
  DashboardIcon,
  ImageIcon,
  VideoIcon,
} from "@/components/admin/admin-icons";
import { AdminSelectField, type AdminTone } from "@/components/admin/admin-primitives";
import {
  getTemplateAccessLabel,
  getTemplateStatusLabel,
  getTemplateTypeLabel,
} from "@/components/templates/template-admin-shared";
import { TemplateSecureMedia } from "@/components/templates/template-secure-media";
import {
  getTemplatesAnalyticsHubIntlLocale,
  type TemplatesAnalyticsHubPageText,
} from "@/components/templates/templates-analytics-hub-page.content";
import styles from "@/components/templates/templates-analytics-hub-page.module.css";
import type {
  AdminTemplateAnalyticsDimension,
  AdminTemplatesAnalyticsBreakdown,
  AdminTemplatesAnalyticsFeedbackItem,
  AdminTemplatesAnalyticsOverview,
  AdminTemplatesAnalyticsTemplateRow,
  AdminTemplatesAnalyticsTrendPoint,
} from "@/lib/api-client";
import { getDictionary, type Locale as AppLocale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

export type TrendMetricKey =
  | "totalViews"
  | "totalGenerationStarts"
  | "completedGenerations"
  | "totalProviderCostUsd";

export function formatAnalyticsDisplayText(value: string, maxLength = 120) {
  return sanitizeSensitiveText(value, maxLength);
}

export function getBoundedBarWidthPercent(value: number, minimumVisiblePercent: number) {
  if (!Number.isFinite(value) || value <= 0) {
    return 0;
  }

  return Math.min(100, Math.max(minimumVisiblePercent, value));
}

export function SelectBox({
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

export function getKpiTone(tone: string): AdminTone {
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

export function FeedbackFeedPanel({
  items,
  locale,
  text,
}: {
  items: readonly AdminTemplatesAnalyticsFeedbackItem[];
  locale: AppLocale;
  text: TemplatesAnalyticsHubPageText;
}) {
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
                {text.feedbackUserLabel}: {item.userId ? shortId(item.userId) : text.anonymousUser}
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

export function TrendChart({
  points,
  metric,
  locale,
  text,
}: {
  points: AdminTemplatesAnalyticsTrendPoint[];
  metric: TrendMetricKey;
  locale: AppLocale;
  text: TemplatesAnalyticsHubPageText;
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

export function FunnelList({
  overview,
  locale,
  text,
}: {
  overview: AdminTemplatesAnalyticsOverview;
  locale: AppLocale;
  text: TemplatesAnalyticsHubPageText;
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

export function BreakdownPanel({
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

export function TypePanel({
  rows,
  locale,
  text,
}: {
  rows: AdminTemplatesAnalyticsBreakdown[];
  locale: AppLocale;
  text: TemplatesAnalyticsHubPageText;
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
              {formatPercent(row.conversionPercent, locale)}
            </p>
            <p>
              {formatTokens(row.totalTokenCost, locale)} ·{" "}
              {formatMoney(row.totalProviderCostUsd, locale)}
            </p>
          </article>
        ))}
      </div>
    </section>
  );
}

export function EventDimensionPanel({
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
            <em>{formatPercent(row.sharePercent, locale)}</em>
          </div>
        ))}
        {!rows.length ? <div className={styles.emptyState}>-</div> : null}
      </div>
    </section>
  );
}

export function TopTemplatesPanel({
  rows,
  locale,
  text,
}: {
  rows: AdminTemplatesAnalyticsTemplateRow[];
  locale: AppLocale;
  text: TemplatesAnalyticsHubPageText;
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

export function TemplatesTable({
  rows,
  locale,
  text,
}: {
  rows: AdminTemplatesAnalyticsTemplateRow[];
  locale: AppLocale;
  text: TemplatesAnalyticsHubPageText;
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
              <td>{formatPercent(row.conversionPercent, locale)}</td>
              <td>{formatTokens(row.totalTokenCost, locale)}</td>
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

export function formatNumber(value: number, locale: AppLocale) {
  return new Intl.NumberFormat(getTemplatesAnalyticsHubIntlLocale(locale), {
    maximumFractionDigits: value % 1 === 0 ? 0 : 1,
  }).format(value);
}

export function formatPercent(value: number, locale: AppLocale) {
  return `${new Intl.NumberFormat(getTemplatesAnalyticsHubIntlLocale(locale), {
    maximumFractionDigits: 1,
  }).format(value)}%`;
}

export function formatTokens(value: number, locale: AppLocale) {
  return `${new Intl.NumberFormat(getTemplatesAnalyticsHubIntlLocale(locale), {
    maximumFractionDigits: value % 1 === 0 ? 0 : 1,
  }).format(value)} PawSpark`;
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

export function formatMoney(value: number, locale: AppLocale) {
  return new Intl.NumberFormat(getTemplatesAnalyticsHubIntlLocale(locale), {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: value > 0 && value < 1 ? 4 : 2,
    maximumFractionDigits: value > 0 && value < 1 ? 4 : 2,
  }).format(value);
}

export function formatDateTime(value: string, locale: AppLocale) {
  return new Intl.DateTimeFormat(getTemplatesAnalyticsHubIntlLocale(locale), {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}

function formatShortDate(value: string, locale: AppLocale) {
  return new Intl.DateTimeFormat(getTemplatesAnalyticsHubIntlLocale(locale), {
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
