"use client";

import { useQuery } from "@tanstack/react-query";

import {
  AdminBadge,
  AdminStateCard,
  AdminStatusBadge,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import styles from "@/components/generations-page.module.css";
import { TemplateSecureMedia } from "@/components/templates/template-secure-media";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  fetchAdminFeedback,
  type AdminGenerationStatus,
  type AdminFeedbackListItem,
  type AdminTemplateGenerationListItem,
} from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import { type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

import { getGenerationsPageIntlLocale, type GenerationsPageText } from "./generations-page.content";

export type StatusFilter = AdminGenerationStatus | "All";

export const statusOptions: StatusFilter[] = [
  "All",
  "Pending",
  "Running",
  "Completed",
  "Failed",
  "Cancelled",
  "Cancelling",
  "Retrying",
];

export function getStatusTone(status: AdminGenerationStatus) {
  if (status === "Completed") {
    return "var(--success)";
  }

  if (status === "Failed") {
    return "var(--danger)";
  }

  if (status === "Cancelled") {
    return "var(--neutral)";
  }

  if (status === "Cancelling") {
    return "var(--warning)";
  }

  if (status === "Retrying") {
    return "var(--magenta)";
  }

  if (status === "Running") {
    return "var(--info)";
  }

  return "var(--warning)";
}

export function formatShortId(value: string) {
  const safeValue = sanitizeSensitiveText(value, 32);
  return safeValue.length > 12 ? `${safeValue.slice(0, 8)}...${safeValue.slice(-4)}` : safeValue;
}

export function formatSafeText(value: string | null | undefined, fallback = "-") {
  const trimmed = value?.trim();
  return trimmed ? sanitizeSensitiveText(trimmed, 160) : fallback;
}

export function formatMappedLabel(
  labels: Record<string, string>,
  value: string | null | undefined,
  fallback = "-"
) {
  if (!value) {
    return fallback;
  }

  return labels[value] ?? sanitizeSensitiveText(value, 80);
}

export function formatMoney(value: number | null | undefined, locale: Locale) {
  if (typeof value !== "number") {
    return "-";
  }

  return new Intl.NumberFormat(getGenerationsPageIntlLocale(locale), {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 4,
  }).format(value);
}

export function formatMetricCount(value: number | null | undefined): string {
  return typeof value === "number" && Number.isFinite(value) ? String(Math.max(0, value)) : "-";
}

export function formatFeedbackRating(value: number | null | undefined, text: GenerationsPageText) {
  if (value === 1) return text.ratingLabels.positive;
  if (value === 0) return text.ratingLabels.neutral;
  if (value === -1) return text.ratingLabels.negative;
  return "-";
}

export function formatStatus(status: StatusFilter, text: GenerationsPageText) {
  return text.generationStatusOptions[status] ?? status;
}

export function formatTemplateType(
  templateType: AdminTemplateGenerationListItem["templateType"],
  text: GenerationsPageText
) {
  return text.templateTypeLabels[templateType];
}

export function formatWatermarkMethod(value?: string | null) {
  const normalized = value?.trim();
  return normalized ? sanitizeSensitiveText(normalized, 32) : null;
}

export function formatInputSourceType(
  value: AdminTemplateGenerationListItem["inputSourceType"],
  text: GenerationsPageText
) {
  const normalized = value.trim().toLowerCase();
  if (normalized === "generation_result") {
    return text.inputSourceTypeLabels.generation_result;
  }
  if (normalized === "pet_photo") {
    return text.inputSourceTypeLabels.pet_photo;
  }
  return text.inputSourceTypeLabels.user_upload;
}

export function GenerationRow({
  item,
  locale,
  text,
  onGrantClean,
  onCancelGeneration,
  onRetryGeneration,
  grantingGenerationId,
  grantCleanPending,
  cancellingGenerationId,
  cancelGenerationPending,
  retryingGenerationId,
  retryGenerationPending,
  isExpanded,
  onToggleDetails,
}: {
  item: AdminTemplateGenerationListItem;
  locale: Locale;
  text: GenerationsPageText;
  onGrantClean: (generationId: string) => void;
  onCancelGeneration: (generationId: string) => void;
  onRetryGeneration: (generationId: string) => void;
  grantingGenerationId: string | null;
  grantCleanPending: boolean;
  cancellingGenerationId: string | null;
  cancelGenerationPending: boolean;
  retryingGenerationId: string | null;
  retryGenerationPending: boolean;
  isExpanded: boolean;
  onToggleDetails: (generationId: string) => void;
}) {
  const failureText = formatSafeText(item.failureCode, text.noFailure);
  const providerText = formatSafeText(item.provider);
  const modelText = formatSafeText(item.model, "");
  const templateTitle = formatSafeText(item.templateTitle);
  const generationIdText = formatShortId(item.generationId);
  const userIdText = formatShortId(item.userId);
  const templateIdText = formatShortId(item.templateId);
  const detailsPanelId = `generation-details-${item.generationId.replace(/[^a-zA-Z0-9_-]/g, "-")}`;
  const toggleDetailsLabel = `${isExpanded ? text.hideDetails : text.showDetails}: ${generationIdText}`;
  const grantCleanLabel = `${text.grantClean}: ${generationIdText}`;
  const cancelGenerationLabel = `${text.cancelGeneration}: ${generationIdText}`;
  const retryGenerationLabel = `${text.retryGeneration}: ${generationIdText}`;
  const parentTitle = item.parentTemplateTitle
    ? sanitizeSensitiveText(item.parentTemplateTitle, 48)
    : item.similarToGenerationId
      ? `${text.lineageSimilarPrefix} ${formatShortId(item.similarToGenerationId)}`
      : formatInputSourceType(item.inputSourceType, text);
  const lineageText = `${parentTitle} -> ${templateTitle}${
    item.childCount > 0
      ? ` -> ${item.childCount} ${
          item.childCount === 1 ? text.lineageChildSingular : text.lineageChildPlural
        }`
      : ""
  }`;
  const lineageMetadataText =
    item.generationMode === "similar"
      ? [
          item.variationStrength
            ? `${text.variationLabel} ${sanitizeSensitiveText(item.variationStrength, 16)}`
            : null,
          typeof item.generationSeed === "number"
            ? `${text.seedLabel} ${item.generationSeed}`
            : null,
        ]
          .filter(Boolean)
          .join(" / ")
      : "";
  const watermarkMethod = formatWatermarkMethod(item.watermarkUnlockMethod);
  const watermarkUnlockedByText = item.watermarkUnlockedByUserId
    ? formatShortId(item.watermarkUnlockedByUserId)
    : null;
  const watermarkState = !item.isWatermarkRequired
    ? text.watermarkNotRequired
    : item.isWatermarkRemoved
      ? text.watermarkRemoved
      : item.watermarkedMediaPath
        ? text.watermarkApplied
        : text.watermarkPending;
  const compareState = item.canCompareBeforeAfter ? text.compareReady : text.compareUnavailable;
  const feedbackQuery = useQuery({
    queryKey: adminQueryKeys.feedback({ generationId: item.generationId, take: 5 }),
    queryFn: ({ signal }) =>
      fetchAdminFeedback({ generationId: item.generationId, take: 5 }, signal),
    enabled: isExpanded,
  });
  const feedbackItems = feedbackQuery.data?.items ?? [];

  function requestFeedbackRetry() {
    if (feedbackQuery.isFetching) {
      return;
    }

    void feedbackQuery.refetch().catch(() => undefined);
  }

  return (
    <>
      <tr>
        <td className={adminTableStyles.mono}>
          <span className={styles.jobId} title={generationIdText} aria-label={generationIdText}>
            {generationIdText}
          </span>
          <div>
            <button
              type="button"
              className={styles.inlineAction}
              onClick={() => onToggleDetails(item.generationId)}
              aria-expanded={isExpanded}
              aria-controls={detailsPanelId}
              aria-label={toggleDetailsLabel}
              title={toggleDetailsLabel}
            >
              {isExpanded ? text.hideDetails : text.showDetails}
            </button>
            {item.canCancel ? (
              <button
                type="button"
                className={styles.inlineAction}
                disabled={cancelGenerationPending}
                onClick={() => onCancelGeneration(item.generationId)}
                aria-label={cancelGenerationLabel}
                title={cancelGenerationLabel}
              >
                {cancellingGenerationId === item.generationId
                  ? text.cancellingGeneration
                  : text.cancelGeneration}
              </button>
            ) : null}
            {item.canRetry ? (
              <button
                type="button"
                className={styles.inlineAction}
                disabled={retryGenerationPending}
                onClick={() => onRetryGeneration(item.generationId)}
                aria-label={retryGenerationLabel}
                title={retryGenerationLabel}
              >
                {retryingGenerationId === item.generationId
                  ? text.retryingGeneration
                  : text.retryGeneration}
              </button>
            ) : null}
          </div>
        </td>
        <td className={adminTableStyles.mono}>
          <span className={styles.jobId} title={userIdText} aria-label={userIdText}>
            {userIdText}
          </span>
        </td>
        <td>
          <span className={styles.templateTitle}>
            <strong>{templateTitle}</strong>
            <span>
              {formatTemplateType(item.templateType, text)} / {templateIdText}
            </span>
            <span className={styles.lineage}>{lineageText}</span>
            {lineageMetadataText ? (
              <span className={styles.lineage}>{lineageMetadataText}</span>
            ) : null}
          </span>
        </td>
        <td>
          <AdminStatusBadge color={getStatusTone(item.status)}>
            {formatStatus(item.status, text)}
          </AdminStatusBadge>
        </td>
        <td>
          {providerText !== "-" ? <AdminBadge tone="info">{providerText}</AdminBadge> : "-"}
          {modelText ? <div className={adminTableStyles.mono}>{modelText}</div> : null}
        </td>
        <td className={adminTableStyles.numeric}>{item.tokenCost}</td>
        <td className={adminTableStyles.numeric}>{item.attemptCount}</td>
        <td className={adminTableStyles.numeric}>{formatMoney(item.providerCostUsd, locale)}</td>
        <td>
          <span className={styles.failure}>{failureText}</span>
        </td>
        <td>
          <span className={styles.watermarkMeta}>
            <strong>{watermarkState}</strong>
            {watermarkMethod ? (
              <span>
                {watermarkMethod}
                {typeof item.watermarkCreditsSpent === "number"
                  ? ` / ${item.watermarkCreditsSpent} ${text.creditsLabel}`
                  : ""}
              </span>
            ) : null}
            {watermarkUnlockedByText ? (
              <span>
                {text.watermarkUnlockedBy} {watermarkUnlockedByText}
              </span>
            ) : null}
            {item.watermarkUnlockedAtUtc ? (
              <span>{formatDateTime(item.watermarkUnlockedAtUtc, locale)}</span>
            ) : null}
            {item.isWatermarkRequired && !item.isWatermarkRemoved ? (
              <button
                type="button"
                className={styles.inlineAction}
                disabled={grantCleanPending}
                onClick={() => onGrantClean(item.generationId)}
                aria-label={grantCleanLabel}
                title={grantCleanLabel}
              >
                {grantingGenerationId === item.generationId ? text.grantingClean : text.grantClean}
              </button>
            ) : null}
          </span>
        </td>
        <td>{formatDateTime(item.createdAtUtc, locale)}</td>
        <td>{item.completedAtUtc ? formatDateTime(item.completedAtUtc, locale) : "-"}</td>
      </tr>
      {isExpanded ? (
        <tr>
          <td colSpan={12} className={styles.detailsCell}>
            <div className={styles.detailsPanel} id={detailsPanelId}>
              <div className={styles.previewGrid}>
                <section className={styles.previewCard}>
                  <header>
                    <strong>{text.before}</strong>
                  </header>
                  {item.inputPreviewUrl ? (
                    <TemplateSecureMedia
                      className={styles.previewImage}
                      url={item.inputPreviewUrl}
                      kind="image"
                      alt={text.before}
                      width={512}
                      height={512}
                      logContext={{
                        surface: "generations-before-preview",
                        templateId: item.templateId,
                      }}
                    />
                  ) : (
                    <div className={styles.previewFallback}>{text.previewMissing}</div>
                  )}
                </section>
                <section className={styles.previewCard}>
                  <header>
                    <strong>{text.after}</strong>
                  </header>
                  {item.resultPreviewUrl ? (
                    <TemplateSecureMedia
                      className={styles.previewImage}
                      url={item.resultPreviewUrl}
                      kind="image"
                      alt={text.after}
                      width={512}
                      height={512}
                      logContext={{
                        surface: "generations-after-preview",
                        templateId: item.templateId,
                      }}
                    />
                  ) : (
                    <div className={styles.previewFallback}>{text.previewMissing}</div>
                  )}
                </section>
              </div>
              <div className={styles.detailsGrid}>
                <div>
                  <span>{text.sourceType}</span>
                  <strong>{formatInputSourceType(item.inputSourceType, text)}</strong>
                </div>
                <div>
                  <span>{text.compareState}</span>
                  <strong>{compareState}</strong>
                </div>
                <div>
                  <span>{text.pet}</span>
                  <strong>{item.petId ? formatShortId(item.petId) : "-"}</strong>
                </div>
                <div>
                  <span>{text.petPhoto}</span>
                  <strong>{item.petPhotoId ? formatShortId(item.petPhotoId) : "-"}</strong>
                </div>
                <div>
                  <span>{text.inputAsset}</span>
                  <strong>
                    {item.inputMediaAssetId ? formatShortId(item.inputMediaAssetId) : "-"}
                  </strong>
                </div>
                <div>
                  <span>{text.resultAsset}</span>
                  <strong>
                    {item.resultMediaAssetId ? formatShortId(item.resultMediaAssetId) : "-"}
                  </strong>
                </div>
                <div>
                  <span>{text.diagnosticsTitle}</span>
                  <strong>{watermarkState}</strong>
                </div>
              </div>
              <section className={styles.feedbackPanel}>
                <header>
                  <strong>{text.feedbackTab}</strong>
                  <span>{feedbackQuery.data?.totalCount ?? 0}</span>
                </header>
                {feedbackQuery.isLoading ? (
                  <p>{text.loadingTitle}</p>
                ) : feedbackQuery.isError ? (
                  <AdminStateCard
                    tone="warning"
                    title={text.feedbackError}
                    description={getAdminErrorMessage(feedbackQuery.error, text.feedbackError)}
                    action={
                      <button
                        type="button"
                        className={styles.button}
                        disabled={feedbackQuery.isFetching}
                        onClick={requestFeedbackRetry}
                      >
                        {text.retry}
                      </button>
                    }
                  />
                ) : feedbackItems.length === 0 ? (
                  <p>{text.feedbackEmpty}</p>
                ) : (
                  <div className={styles.feedbackList}>
                    {feedbackItems.map((feedback: AdminFeedbackListItem) => (
                      <div key={feedback.id} className={styles.feedbackItem}>
                        <strong>
                          {formatMappedLabel(text.feedbackTypeOptions, feedback.type)} /{" "}
                          {sanitizeSensitiveText(feedback.category, 80)} /{" "}
                          {formatFeedbackRating(feedback.rating, text)}
                        </strong>
                        <span>
                          {formatMappedLabel(text.feedbackStatusOptions, feedback.status)} /{" "}
                          {formatMappedLabel(text.feedbackPriorityOptions, feedback.priority)} /{" "}
                          {formatDateTime(feedback.createdAtUtc, locale)}
                        </span>
                        {feedback.message ? (
                          <p>{sanitizeSensitiveText(feedback.message, 220)}</p>
                        ) : null}
                      </div>
                    ))}
                  </div>
                )}
              </section>
            </div>
          </td>
        </tr>
      ) : null}
    </>
  );
}
