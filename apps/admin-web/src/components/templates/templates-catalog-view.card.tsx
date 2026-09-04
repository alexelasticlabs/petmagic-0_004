"use client";

import Link from "next/link";

import { AdminActionMenu, type AdminActionMenuItem } from "@/components/admin/admin-action-menu";
import {
  CancelCircleIcon,
  DollarIcon,
  ImageIcon,
  PlayCircleIcon,
  VideoIcon,
} from "@/components/admin/admin-icons";
import { AdminStatusBadge } from "@/components/admin/admin-primitives";
import {
  getTemplateAccessLabel,
  getTemplateStatusLabel,
} from "@/components/templates/template-admin-shared";
import { inferTemplateMediaKind } from "@/components/templates/template-media-utils";
import { TemplateSecureMedia } from "@/components/templates/template-secure-media";
import {
  getTemplatesCatalogIntlLocale,
  type TemplatesCatalogViewText,
} from "@/components/templates/templates-catalog-view.content";
import styles from "@/components/templates/templates-catalog.module.css";
import type {
  AdminTemplateListItem,
  AdminTemplatesAnalyticsTemplateRow,
  TemplateStatus,
} from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

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
  busyTemplateId,
  canManageTemplates,
  onStatusChange,
  onDeleteTemplate,
}: TemplateCatalogCardProps) {
  const text = getDictionary(locale);
  const isBusy = busyTemplateId !== null;
  const safeTemplateTitle = sanitizeSensitiveText(template.title, 96);
  const safeTemplateDescription = sanitizeSensitiveText(template.shortDescription, 180);
  const safeTemplateCategory = sanitizeSensitiveText(template.category, 64);
  const templateTypeSegment = template.templateType === "Video" ? "video" : "image";
  const templateBasePath = `/${locale}/templates/${templateTypeSegment}`;
  const previewUrl = template.previewAsset?.url?.trim() ?? "";
  const previewKind = inferTemplateMediaKind(
    template.previewAsset?.contentType?.trim() ?? "",
    previewUrl
  );
  const mediaFallback = (
    <div className={styles.cardMediaFallback} role="status">
      <ImageIcon className={styles.cardMediaPlaceholderIcon} aria-hidden="true" />
      <strong>{copy.previewUnavailable}</strong>
      <span>{copy.previewUnavailableDescription}</span>
    </div>
  );
  const actionItems: AdminActionMenuItem[] = [
    {
      id: "analytics",
      label: copy.analyticsAction,
      href: `${templateBasePath}/analytics/${encodeURIComponent(template.templateId)}`,
      disabled: isBusy,
    },
    {
      id: "test",
      label: copy.testAction,
      href: `${templateBasePath}/test/${encodeURIComponent(template.templateId)}`,
      disabled: isBusy,
    },
    ...(template.status !== "Active"
      ? [
          {
            id: "activate",
            label: text.activate,
            disabled: isBusy,
            onSelect: () => onStatusChange(template.templateId, "Active"),
          } satisfies AdminActionMenuItem,
        ]
      : []),
    ...(template.status !== "Archived"
      ? [
          {
            id: "archive",
            label: text.archive,
            disabled: isBusy,
            tone: "danger" as const,
            onSelect: () => onStatusChange(template.templateId, "Archived"),
          } satisfies AdminActionMenuItem,
        ]
      : []),
    {
      id: "delete",
      label: text.deleteTemplate,
      disabled: isBusy,
      tone: "danger",
      onSelect: () => onDeleteTemplate(template.templateId),
    },
  ];

  return (
    <article className={styles.templateCard}>
      <div className={styles.cardMedia}>
        {previewUrl ? (
          previewKind === "video" ? (
            <TemplateSecureMedia
              className={styles.cardMediaAsset}
              url={previewUrl}
              kind="video"
              muted
              playsInline
              preload="metadata"
              ariaLabel={safeTemplateTitle}
              fallback={mediaFallback}
              logContext={{
                templateId: template.templateId,
                contentType: template.previewAsset?.contentType,
                surface: "catalog_card",
              }}
            />
          ) : (
            <TemplateSecureMedia
              className={styles.cardMediaAsset}
              url={previewUrl}
              kind="image"
              alt={safeTemplateTitle}
              width={640}
              height={360}
              fallback={mediaFallback}
              logContext={{
                templateId: template.templateId,
                contentType: template.previewAsset?.contentType,
                surface: "catalog_card",
              }}
            />
          )
        ) : (
          <div className={styles.cardMediaPlaceholder} aria-label={copy.missingPreviewMetric}>
            {template.templateType === "Video" ? (
              <VideoIcon className={styles.cardMediaPlaceholderIcon} />
            ) : (
              <ImageIcon className={styles.cardMediaPlaceholderIcon} />
            )}
            <span>{copy.missingPreviewMetric}</span>
          </div>
        )}
        <span className={styles.cardMediaKind}>
          {template.templateType === "Video" ? (
            <VideoIcon className={styles.cardMediaKindIcon} />
          ) : (
            <ImageIcon className={styles.cardMediaKindIcon} />
          )}
          {template.templateType === "Video"
            ? text.templateKindVideoBadge
            : text.templateKindImageBadge}
        </span>
      </div>
      <div className={styles.cardBody}>
        <div className={styles.cardTitleRow}>
          <div>
            <h2 title={safeTemplateTitle}>{safeTemplateTitle}</h2>
            <p>{safeTemplateDescription}</p>
          </div>
        </div>
        <div className={styles.metaRow}>
          <span>{safeTemplateCategory}</span>
          <span className={template.isPremium ? styles.premiumPill : styles.freePill}>
            {getTemplateAccessLabel(template.isPremium, text)}
          </span>
          {template.isQaOnly ? <span className={styles.qaOnlyPill}>{copy.qaOnlyLabel}</span> : null}
        </div>
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
        </div>
        <div className={styles.cardMetrics}>
          {getTemplateCardMetrics(template, analytics, locale, copy).map((metric) => (
            <div
              key={metric.label}
              className={`${styles.cardMetric} ${styles[metric.tone]}`}
              title={metric.label}
            >
              {METRIC_ICONS[metric.tone]}
              <span className={styles.cardMetricLabel}>{metric.label}</span>
              <strong>{metric.value}</strong>
            </div>
          ))}
        </div>
      </div>
      <div className={styles.cardActions}>
        <Link
          href={
            canManageTemplates
              ? `${templateBasePath}/editor?templateId=${encodeURIComponent(template.templateId)}`
              : `${templateBasePath}/analytics/${encodeURIComponent(template.templateId)}`
          }
          className={`ui-button ui-button--primary ui-button--sm${
            isBusy ? ` ${styles.cardActionIconButtonDisabled}` : ""
          }`}
          aria-label={`${
            canManageTemplates ? text.editTemplate : copy.analyticsAction
          }: ${safeTemplateTitle}`}
          aria-disabled={isBusy}
          tabIndex={isBusy ? -1 : undefined}
          onClick={(event) => {
            if (isBusy) {
              event.preventDefault();
            }
          }}
        >
          {canManageTemplates ? copy.editAction : copy.analyticsAction}
        </Link>
        {canManageTemplates ? (
          <>
            <Link
              href={`${templateBasePath}/test/${encodeURIComponent(template.templateId)}`}
              className={styles.cardSecondaryAction}
              aria-label={`${copy.testAction}: ${safeTemplateTitle}`}
            >
              {copy.testAction}
            </Link>
            <Link
              href={`${templateBasePath}/analytics/${encodeURIComponent(template.templateId)}`}
              className={styles.cardSecondaryAction}
              aria-label={`${copy.analyticsAction}: ${safeTemplateTitle}`}
            >
              {copy.analyticsAction}
            </Link>
          </>
        ) : null}
        {canManageTemplates ? (
          <AdminActionMenu
            label={text.actionsLabel}
            items={actionItems}
            disabled={isBusy}
            align="end"
            className={styles.cardActionMenu}
          />
        ) : null}
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

export function formatUsdEstimate(value: number, locale: Locale) {
  return new Intl.NumberFormat(getTemplatesCatalogIntlLocale(locale), {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(value);
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
      ? formatUsdEstimate(template.estimatedCostUsd, locale)
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
