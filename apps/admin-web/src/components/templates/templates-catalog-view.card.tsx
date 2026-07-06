"use client";

import Link from "next/link";

import {
  CancelCircleIcon,
  ChartIcon,
  DollarIcon,
  ImageIcon,
  PencilIcon,
  PlayCircleIcon,
  RefreshIcon,
} from "@/components/admin/admin-icons";
import { AdminStatusBadge } from "@/components/admin/admin-primitives";
import {
  getTemplateAccessLabel,
  getTemplateStatusLabel,
} from "@/components/templates/template-admin-shared";
import { TemplatePreviewCard } from "@/components/templates/template-phone-preview-card";
import {
  getTemplatesCatalogIntlLocale,
  type TemplatesCatalogViewText,
} from "@/components/templates/templates-catalog-view.content";
import styles from "@/components/templates/templates-catalog.module.css";
import { Button } from "@/components/ui/button";
import type {
  AdminTemplateListItem,
  AdminTemplatesAnalyticsTemplateRow,
  TemplateStatus,
} from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";

import type { ReactElement } from "react";

export const statusColors: Record<TemplateStatus, string> = {
  Draft: "var(--warning)",
  Active: "var(--success)",
  Archived: "var(--text-muted)",
};

const METRIC_ICONS: Record<string, ReactElement> = {
  cardMetric_primary: <DollarIcon className={styles.cardMetricIcon} />,
  cardMetric_info: <ImageIcon className={styles.cardMetricIcon} />,
  cardMetric_success: <PlayCircleIcon className={styles.cardMetricIcon} />,
  cardMetric_danger: <CancelCircleIcon className={styles.cardMetricIcon} />,
};

export type TemplateCatalogCardProps = {
  locale: Locale;
  copy: TemplatesCatalogViewText;
  template: AdminTemplateListItem;
  analytics?: AdminTemplatesAnalyticsTemplateRow;
  editorBasePath: string;
  analyticsBasePath: string;
  testBasePath: string;
  busyTemplateId: string | null;
  canManageTemplates: boolean;
  onStatusChange: (templateId: string, status: TemplateStatus) => void;
  onDeleteTemplate: (templateId: string) => void;
};

export function TemplateCatalogCard({
  locale,
  copy,
  template,
  analytics,
  editorBasePath,
  analyticsBasePath,
  testBasePath,
  busyTemplateId,
  canManageTemplates,
  onStatusChange,
  onDeleteTemplate,
}: TemplateCatalogCardProps) {
  const text = getDictionary(locale);
  const isBusy = busyTemplateId !== null;

  return (
    <article className={styles.templateCard}>
      <TemplatePreviewCard
        className={styles.previewCard}
        title={template.title}
        shortDescription={template.shortDescription}
        tags={template.tags}
        previewUrl={template.previewAsset?.url}
        previewContentType={template.previewAsset?.contentType}
        templateKind={template.templateType === "Video" ? "video" : "image"}
        templateKindLabel={
          template.templateType === "Video"
            ? text.templateKindVideoBadge
            : text.templateKindImageBadge
        }
        tokenCost={template.tokenCost}
        category={template.category}
        isPremium={template.isPremium}
        accessLabel={getTemplateAccessLabel(template.isPremium, text)}
        referenceDurationSeconds={template.referenceVideoDurationSeconds}
        promoBadge={template.effectivePromoBadge}
        musicDescription={template.musicDescription}
      />
      <div className={styles.cardBody}>
        <div className={styles.cardFooter}>
          <span className={styles.cardTimestamp}>
            {copy.updatedShort} {formatDate(template.updatedAtUtc, locale)}
          </span>
          <AdminStatusBadge
            className={styles.cardStatusBadge}
            color={statusColors[template.status]}
          >
            {getTemplateStatusLabel(template.status, locale)}
          </AdminStatusBadge>
          {template.isQaOnly ? <span className={styles.qaOnlyPill}>{copy.qaOnlyLabel}</span> : null}
        </div>
        <div className={styles.cardMetrics}>
          {getTemplateCardMetrics(template, analytics, locale, copy).map((metric) => (
            <div
              key={metric.label}
              className={`${styles.cardMetric} ${styles[metric.tone]}`}
              title={metric.label}
            >
              {METRIC_ICONS[metric.tone]}
              <strong>{metric.value}</strong>
            </div>
          ))}
        </div>
        <div className={styles.cardActions}>
          <Link
            href={`${analyticsBasePath}/${encodeURIComponent(template.templateId)}`}
            className={`${styles.cardActionIconButton}${
              isBusy ? ` ${styles.cardActionIconButtonDisabled}` : ""
            }`}
            aria-label={copy.analyticsAction}
            aria-disabled={isBusy}
            tabIndex={isBusy ? -1 : undefined}
            title={copy.analyticsAction}
            onClick={(event) => {
              if (isBusy) {
                event.preventDefault();
              }
            }}
          >
            <ChartIcon className={styles.actionIcon} />
          </Link>
          {canManageTemplates ? (
            <>
              <Link
                href={`${editorBasePath}?templateId=${encodeURIComponent(template.templateId)}`}
                className={`${styles.cardActionIconButton}${
                  isBusy ? ` ${styles.cardActionIconButtonDisabled}` : ""
                }`}
                aria-label={text.editTemplate}
                aria-disabled={isBusy}
                tabIndex={isBusy ? -1 : undefined}
                title={text.editTemplate}
                onClick={(event) => {
                  if (isBusy) {
                    event.preventDefault();
                  }
                }}
              >
                <PencilIcon className={styles.actionIcon} />
              </Link>
              <Link
                href={`${testBasePath}/${encodeURIComponent(template.templateId)}`}
                className={`${styles.cardActionIconButton}${
                  isBusy ? ` ${styles.cardActionIconButtonDisabled}` : ""
                }`}
                aria-label={copy.testAction}
                aria-disabled={isBusy}
                tabIndex={isBusy ? -1 : undefined}
                title={copy.testAction}
                onClick={(event) => {
                  if (isBusy) {
                    event.preventDefault();
                  }
                }}
              >
                <PlayCircleIcon className={styles.actionIcon} />
              </Link>
              {template.status !== "Active" ? (
                <Button
                  size="sm"
                  variant="ghost"
                  className={styles.cardActionIconButton}
                  disabled={isBusy}
                  aria-label={text.activate}
                  title={text.activate}
                  onClick={() => onStatusChange(template.templateId, "Active")}
                >
                  <RefreshIcon className={styles.actionIcon} />
                </Button>
              ) : (
                <Button
                  size="sm"
                  variant="ghost"
                  className={`${styles.cardActionIconButton} ${styles.cardActionDanger}`}
                  disabled={isBusy}
                  aria-label={text.archive}
                  title={text.archive}
                  onClick={() => onStatusChange(template.templateId, "Archived")}
                >
                  <RefreshIcon className={styles.actionIcon} />
                </Button>
              )}
              <Button
                size="sm"
                variant="danger"
                className={`${styles.cardActionIconButton} ${styles.cardActionDanger}`}
                disabled={isBusy}
                aria-label={text.deleteTemplate}
                title={text.deleteTemplate}
                onClick={() => onDeleteTemplate(template.templateId)}
              >
                <CancelCircleIcon className={styles.actionIcon} />
              </Button>
            </>
          ) : null}
        </div>
      </div>
    </article>
  );
}

export function formatDate(value: string, locale: Locale) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "-";
  }

  return new Intl.DateTimeFormat(getTemplatesCatalogIntlLocale(locale), {
    day: "2-digit",
    month: "short",
    year: "numeric",
  }).format(date);
}

export function formatDuration(seconds?: number) {
  if (!seconds) {
    return "-";
  }

  const roundedSeconds = Math.max(0, Math.round(seconds));
  const minutes = Math.floor(roundedSeconds / 60)
    .toString()
    .padStart(2, "0");
  const remainder = (roundedSeconds % 60).toString().padStart(2, "0");
  return `${minutes}:${remainder}`;
}

export function formatAnalyticsInteger(value: number | null | undefined, locale: Locale) {
  if (value === undefined || value === null) {
    return "-";
  }

  return new Intl.NumberFormat(getTemplatesCatalogIntlLocale(locale)).format(value);
}

export function formatPercentMetric(value: number | null | undefined, locale: Locale) {
  if (value === undefined || value === null || Number.isNaN(value)) {
    return "-";
  }

  return `${new Intl.NumberFormat(getTemplatesCatalogIntlLocale(locale), {
    minimumFractionDigits: 1,
    maximumFractionDigits: 1,
  }).format(value)}%`;
}

export function getSuccessRatePercent(analytics?: AdminTemplatesAnalyticsTemplateRow) {
  if (!analytics) {
    return null;
  }

  const finishedCount = analytics.completedGenerations + analytics.failedGenerations;
  if (finishedCount <= 0) {
    return null;
  }

  return (analytics.completedGenerations / finishedCount) * 100;
}

export function getTemplateCardMetrics(
  template: AdminTemplateListItem,
  analytics: AdminTemplatesAnalyticsTemplateRow | undefined,
  locale: Locale,
  copy: Pick<
    TemplatesCatalogViewText,
    "tokenUnit" | "metricCost" | "metricViews" | "metricGenerations" | "metricErrors"
  >
) {
  const costValue =
    template.estimatedCostUsd !== undefined && template.estimatedCostUsd !== null
      ? `$${template.estimatedCostUsd.toFixed(3)}`
      : `${formatAnalyticsInteger(template.tokenCost, locale)} ${copy.tokenUnit}`;

  return [
    {
      label: copy.metricCost,
      value: costValue,
      tone: "cardMetric_primary",
    },
    {
      label: copy.metricViews,
      value: formatAnalyticsInteger(analytics?.views, locale),
      tone: "cardMetric_info",
    },
    {
      label: copy.metricGenerations,
      value: formatAnalyticsInteger(analytics?.generationStarts, locale),
      tone: "cardMetric_success",
    },
    {
      label: copy.metricErrors,
      value: formatAnalyticsInteger(analytics?.failedGenerations, locale),
      tone: "cardMetric_danger",
    },
  ];
}
