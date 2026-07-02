"use client";

import Link from "next/link";

import {
  CalendarIcon,
  CancelCircleIcon,
  ChartIcon,
  ImageIcon,
  PencilIcon,
  PlayCircleIcon,
  RefreshIcon,
  VideoIcon,
} from "@/components/admin/admin-icons";
import { AdminCard, AdminStatusBadge, adminTableStyles } from "@/components/admin/admin-primitives";
import {
  getCharacterOrientationLabel,
  getTemplateAccessLabel,
  getTemplateStatusLabel,
  getTemplateTypeLabel,
} from "@/components/templates/template-admin-shared";
import { TemplateSecureMedia } from "@/components/templates/template-secure-media";
import {
  formatAnalyticsInteger,
  formatDate,
  formatDuration,
  formatPercentMetric,
  getSuccessRatePercent,
  statusColors,
} from "@/components/templates/templates-catalog-view.card";
import type { TemplatesCatalogViewText } from "@/components/templates/templates-catalog-view.content";
import styles from "@/components/templates/templates-catalog.module.css";
import { Button } from "@/components/ui/button";
import type {
  AdminTemplateListItem,
  AdminTemplatesAnalyticsTemplateRow,
  TemplateStatus,
} from "@/lib/api-client";
import type { Dictionary, Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type TemplatesCatalogListTableProps = {
  analyticsBasePath: string;
  canManageTemplates: boolean;
  copy: TemplatesCatalogViewText;
  editorBasePath: string;
  getAnalyticsRow: (templateId: string) => AdminTemplatesAnalyticsTemplateRow | undefined;
  isCatalogInteractionLocked: boolean;
  isFetching: boolean;
  locale: Locale;
  onDeleteTemplate: (templateId: string) => void;
  onStatusChange: (templateId: string, status: TemplateStatus) => void;
  templates: AdminTemplateListItem[];
  testBasePath: string;
  text: Dictionary;
};

export function TemplatesCatalogListTable({
  analyticsBasePath,
  canManageTemplates,
  copy,
  editorBasePath,
  getAnalyticsRow,
  isCatalogInteractionLocked,
  isFetching,
  locale,
  onDeleteTemplate,
  onStatusChange,
  templates,
  testBasePath,
  text,
}: TemplatesCatalogListTableProps) {
  return (
    <AdminCard padding="md" className={styles.listCard}>
      <div className={adminTableStyles.tableWrap} aria-busy={isFetching ? "true" : undefined}>
        <table className={`${adminTableStyles.table} ${styles.listTable}`}>
          <thead>
            <tr>
              <th>{copy.tableTemplate}</th>
              <th>{copy.tableType}</th>
              <th>{text.categoryLabel}</th>
              <th>{copy.accessLabel}</th>
              <th>{text.statusLabel}</th>
              <th>{copy.tableViews}</th>
              <th>{copy.tableStarts}</th>
              <th>{copy.tableConversion}</th>
              <th>{copy.tableSuccess}</th>
              <th>{copy.tableAverageCost}</th>
              <th>{copy.updatedLabel}</th>
              <th>{text.actionsLabel}</th>
            </tr>
          </thead>
          <tbody>
            {templates.map((template) => {
              const isBusy = isCatalogInteractionLocked;
              const analytics = getAnalyticsRow(template.templateId);
              const safeTemplateTitle = sanitizeSensitiveText(template.title, 96);
              const safeTemplateDescription = sanitizeSensitiveText(template.shortDescription, 180);
              const safeTemplateCategory = sanitizeSensitiveText(template.category, 64);

              return (
                <tr key={template.templateId}>
                  <td data-label={copy.tableTemplate}>
                    <div className={styles.listTemplateCell}>
                      <div
                        className={`${styles.listTemplateThumb} ${template.templateType === "Video" ? styles.listTemplateThumbVideo : ""}`.trim()}
                        aria-hidden="true"
                      >
                        {template.previewAsset?.url ? (
                          template.previewAsset.contentType?.startsWith("video/") ? (
                            <TemplateSecureMedia
                              className={styles.listTemplateMedia}
                              url={template.previewAsset.url}
                              kind="video"
                              muted
                              playsInline
                              autoPlay
                              loop
                              preload="metadata"
                              ariaHidden
                              logContext={{
                                templateId: template.templateId,
                                contentType: template.previewAsset.contentType,
                                surface: "catalog_list",
                              }}
                            />
                          ) : (
                            <TemplateSecureMedia
                              className={styles.listTemplateMedia}
                              url={template.previewAsset.url}
                              kind="image"
                              alt=""
                              width={56}
                              height={56}
                              ariaHidden
                              logContext={{
                                templateId: template.templateId,
                                contentType: template.previewAsset.contentType,
                                surface: "catalog_list",
                              }}
                            />
                          )
                        ) : template.templateType === "Video" ? (
                          <VideoIcon className={styles.listTemplateThumbIcon} />
                        ) : (
                          <ImageIcon className={styles.listTemplateThumbIcon} />
                        )}
                      </div>
                      <div className={styles.titleCell} title={safeTemplateDescription}>
                        <strong>{safeTemplateTitle}</strong>
                        <span>{safeTemplateDescription}</span>
                        <small className={styles.templateMetaId}>
                          ID: {formatTemplateId(template.templateId, 12)}
                        </small>
                      </div>
                    </div>
                  </td>
                  <td data-label={copy.tableType}>
                    <div className={styles.typeCell}>
                      <span className={styles.typeBadge}>
                        {template.templateType === "Video" ? (
                          <VideoIcon className={styles.typeIcon} />
                        ) : (
                          <ImageIcon className={styles.typeIcon} />
                        )}
                        {getTemplateTypeLabel(template.templateType, text)}
                      </span>
                      <span className={styles.typeMeta}>
                        {template.templateType === "Video"
                          ? formatDuration(template.referenceVideoDurationSeconds)
                          : getCharacterOrientationLabel(template.characterOrientation, text)}
                      </span>
                    </div>
                  </td>
                  <td data-label={text.categoryLabel}>{safeTemplateCategory}</td>
                  <td data-label={copy.accessLabel}>
                    <div className={styles.accessPillGroup}>
                      <span className={template.isPremium ? styles.premiumPill : styles.freePill}>
                        {getTemplateAccessLabel(template.isPremium, text)}
                      </span>
                      {template.isQaOnly ? (
                        <span className={styles.qaOnlyPill}>{copy.qaOnlyLabel}</span>
                      ) : null}
                    </div>
                  </td>
                  <td data-label={text.statusLabel}>
                    <AdminStatusBadge
                      className={styles.listStatusBadge}
                      color={statusColors[template.status]}
                    >
                      {getTemplateStatusLabel(template.status, locale)}
                    </AdminStatusBadge>
                  </td>
                  <td data-label={copy.tableViews} className={styles.metricValueCell}>
                    {formatAnalyticsInteger(analytics?.views, locale)}
                  </td>
                  <td data-label={copy.tableStarts} className={styles.metricValueCell}>
                    {formatAnalyticsInteger(analytics?.generationStarts, locale)}
                  </td>
                  <td data-label={copy.tableConversion} className={styles.metricValueCell}>
                    {formatPercentMetric(
                      analytics?.generationStarts ? analytics.conversionPercent : null,
                      locale
                    )}
                  </td>
                  <td data-label={copy.tableSuccess} className={styles.metricValueCell}>
                    {formatPercentMetric(getSuccessRatePercent(analytics), locale)}
                  </td>
                  <td data-label={copy.tableAverageCost} className={styles.numericCell}>
                    {formatAnalyticsInteger(template.tokenCost, locale)}{" "}
                    <span className={styles.numericSuffix}>{copy.tokensShort}</span>
                  </td>
                  <td data-label={copy.updatedLabel}>
                    <div className={styles.updatedCell}>
                      <CalendarIcon className={styles.updatedIcon} />
                      <span>{formatDate(template.updatedAtUtc, locale)}</span>
                    </div>
                  </td>
                  <td data-label={text.actionsLabel} className={styles.tableActionsCell}>
                    <div className={styles.tableActions}>
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
                          ) : null}
                          {template.status !== "Archived" ? (
                            <Button
                              size="sm"
                              variant="danger"
                              className={`${styles.cardActionIconButton} ${styles.cardActionDanger}`}
                              disabled={isBusy}
                              aria-label={text.archive}
                              title={text.archive}
                              onClick={() => onStatusChange(template.templateId, "Archived")}
                            >
                              <RefreshIcon className={styles.actionIcon} />
                            </Button>
                          ) : null}
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
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </AdminCard>
  );
}

export function formatTemplateId(templateId: string, maxLength: number): string {
  return sanitizeSensitiveText(templateId, Math.max(maxLength, 1)).slice(0, maxLength);
}
