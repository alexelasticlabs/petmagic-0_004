"use client";

import { useQuery } from "@tanstack/react-query";
import { useEffect, useRef, useState } from "react";

import {
  AdminBadge,
  AdminStateCard,
  AdminStatusBadge,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import styles from "@/components/generations-page.module.css";
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
import { GenerationMedia, generationMediaKind } from "./generations-page.media";

export type StatusFilter = AdminGenerationStatus | "All";

export const statusOptions: StatusFilter[] = [
  "All",
  "Pending",
  "Running",
  "Completed",
  "Failed",
  "Cancelled",
  "Retrying",
  "Cancelling",
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

  if (status === "Retrying") {
    return "var(--magenta)";
  }

  if (status === "Cancelling") {
    return "var(--warning)";
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

function TechnicalId({ value, text }: { value: string; text: GenerationsPageText }) {
  const safeValue = sanitizeSensitiveText(value, 160);
  const [copyState, setCopyState] = useState<"idle" | "copied" | "failed">("idle");
  const resetTimerRef = useRef<number | null>(null);

  useEffect(() => {
    return () => {
      if (resetTimerRef.current !== null) {
        window.clearTimeout(resetTimerRef.current);
      }
    };
  }, []);

  async function copyFullId() {
    try {
      await navigator.clipboard.writeText(safeValue);
      setCopyState("copied");
    } catch {
      setCopyState("failed");
    }

    if (resetTimerRef.current !== null) {
      window.clearTimeout(resetTimerRef.current);
    }
    resetTimerRef.current = window.setTimeout(() => setCopyState("idle"), 1800);
  }

  const copyLabel =
    copyState === "copied"
      ? text.copiedId
      : copyState === "failed"
        ? text.copyIdFailed
        : text.copyId;

  return (
    <span className={styles.technicalId}>
      <span className={styles.jobId} title={safeValue} aria-label={safeValue}>
        {formatShortId(safeValue)}
      </span>
      <button
        type="button"
        className={styles.copyIdButton}
        onClick={() => void copyFullId()}
        aria-label={`${copyLabel}: ${safeValue}`}
        title={copyLabel}
      >
        {copyState === "copied" ? "✓" : "⧉"}
      </button>
    </span>
  );
}

export function GenerationRow({
  item,
  locale,
  text,
  onGrantClean,
  onCancelGeneration,
  onRetryGeneration,
  onRetryRefund,
  onResolveLegacyGamification,
  grantingGenerationId,
  grantCleanPending,
  cancellingGenerationId,
  cancelGenerationPending,
  retryingGenerationId,
  retryGenerationPending,
  retryingRefundGenerationId,
  refundRecoveryPending,
  legacyGamificationResolutionPending,
  isExpanded,
  detailLoading,
  detailError,
  onRetryDetail,
  onToggleDetails,
}: {
  item: AdminTemplateGenerationListItem;
  locale: Locale;
  text: GenerationsPageText;
  onGrantClean: (generationId: string) => void;
  onCancelGeneration: (generationId: string) => void;
  onRetryGeneration: (generationId: string) => void;
  onRetryRefund: (generationId: string) => void;
  onResolveLegacyGamification: (generationId: string) => void;
  grantingGenerationId: string | null;
  grantCleanPending: boolean;
  cancellingGenerationId: string | null;
  cancelGenerationPending: boolean;
  retryingGenerationId: string | null;
  retryGenerationPending: boolean;
  retryingRefundGenerationId: string | null;
  refundRecoveryPending: boolean;
  legacyGamificationResolutionPending: boolean;
  isExpanded: boolean;
  detailLoading: boolean;
  detailError: string | null;
  onRetryDetail: () => void;
  onToggleDetails: (generationId: string) => void;
}) {
  const failureText = formatSafeText(item.failureCode, text.noFailure);
  const failureDisplayText = failureText.replace(/([._:/-])/g, "$1\u200B");
  const providerText = formatSafeText(item.provider);
  const modelText = formatSafeText(item.model, "");
  const templateTitle = formatSafeText(item.templateTitle);
  const generationIdText = formatShortId(item.generationId);
  const detailsPanelId = `generation-details-${item.generationId.replace(/[^a-zA-Z0-9_-]/g, "-")}`;
  const toggleDetailsLabel = `${isExpanded ? text.hideDetails : text.showDetails}: ${generationIdText}`;
  const grantCleanLabel = `${text.grantClean}: ${generationIdText}`;
  const cancelGenerationLabel = `${text.cancelGeneration}: ${generationIdText}`;
  const retryGenerationLabel = `${text.retryGeneration}: ${generationIdText}`;
  const retryRefundLabel = `${text.retryRefund}: ${generationIdText}`;
  const gamificationLegacyReviewLabel = `${text.gamificationLegacyReview}: ${generationIdText}`;
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
  const resultUrl = item.resultMediaUrl || item.resultPreviewUrl;
  const compareState =
    item.inputPreviewUrl && resultUrl ? text.compareReady : text.compareUnavailable;
  const hasPreviewMedia = Boolean(item.inputPreviewUrl || resultUrl);
  const [mediaRevision, setMediaRevision] = useState(0);
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
      <tr className={styles.generationRow} data-expanded={isExpanded || undefined}>
        <td className={adminTableStyles.mono} data-label={text.job}>
          <TechnicalId value={item.generationId} text={text} />
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
              {isExpanded ? text.hideDetails : `${text.before} / ${text.after}`}
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
            {item.canRetryRefund ? (
              <button
                type="button"
                className={styles.inlineAction}
                disabled={refundRecoveryPending}
                onClick={() => onRetryRefund(item.generationId)}
                aria-label={retryRefundLabel}
                title={retryRefundLabel}
              >
                {retryingRefundGenerationId === item.generationId
                  ? text.retryingRefund
                  : text.retryRefund}
              </button>
            ) : null}
            {item.gamificationLegacyReviewRequired ? (
              <button
                type="button"
                className={styles.inlineAction}
                disabled={legacyGamificationResolutionPending}
                onClick={() => onResolveLegacyGamification(item.generationId)}
                aria-label={gamificationLegacyReviewLabel}
                title={gamificationLegacyReviewLabel}
              >
                {text.gamificationLegacyReview}
              </button>
            ) : null}
          </div>
        </td>
        <td className={adminTableStyles.mono} data-label={text.user}>
          <TechnicalId value={item.userId} text={text} />
        </td>
        <td data-label={text.template}>
          <span className={styles.templateTitle}>
            <strong>{templateTitle}</strong>
            <span>
              {formatTemplateType(item.templateType, text)} /{" "}
              <TechnicalId value={item.templateId} text={text} />
            </span>
            <span className={styles.lineage}>{lineageText}</span>
            {lineageMetadataText ? (
              <span className={styles.lineage}>{lineageMetadataText}</span>
            ) : null}
          </span>
        </td>
        <td className={styles.statusCell} data-label={text.status}>
          <AdminStatusBadge color={getStatusTone(item.status)}>
            {formatStatus(item.status, text)}
          </AdminStatusBadge>
        </td>
        <td data-label={text.provider}>
          {providerText !== "-" ? <AdminBadge tone="info">{providerText}</AdminBadge> : "-"}
          {modelText ? <div className={adminTableStyles.mono}>{modelText}</div> : null}
        </td>
        <td className={adminTableStyles.numeric} data-label={text.cost}>
          <strong>
            {item.tokenCost} {text.creditsLabel}
          </strong>
          <div className={styles.secondaryText}>{formatMoney(item.providerCostUsd, locale)}</div>
        </td>
        <td data-label={text.failure}>
          <span className={styles.failure} aria-label={failureText} title={failureText}>
            {failureDisplayText}
          </span>
        </td>
        <td data-label={text.watermark}>
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
        <td data-label={text.created}>{formatDateTime(item.createdAtUtc, locale)}</td>
      </tr>
      {isExpanded ? (
        <tr className={styles.detailsRow}>
          <td colSpan={9} className={styles.detailsCell}>
            <div className={styles.detailsPanel} id={detailsPanelId}>
              {detailLoading ? <p role="status">{text.loadingTitle}</p> : null}
              {detailError ? (
                <AdminStateCard
                  tone="warning"
                  title={text.errorTitle}
                  description={detailError}
                  action={
                    <button type="button" className={styles.button} onClick={onRetryDetail}>
                      {text.retry}
                    </button>
                  }
                />
              ) : null}
              <div className={styles.detailsToolbar}>
                <strong>
                  {text.before} / {text.after}
                </strong>
                <button
                  type="button"
                  className={styles.button}
                  disabled={detailLoading}
                  onClick={() => {
                    setMediaRevision((value) => value + 1);
                    onRetryDetail();
                  }}
                >
                  {text.refreshMedia}
                </button>
              </div>
              {hasPreviewMedia || !detailLoading ? (
                <div className={styles.previewGrid}>
                  <GenerationMedia
                    key={`before-${item.inputPreviewUrl}-${mediaRevision}`}
                    url={item.inputPreviewUrl}
                    kind={generationMediaKind(item.inputPreviewUrl ?? "")}
                    title={text.before}
                    emptyText={text.mediaMissingBefore}
                    text={text}
                  />
                  <GenerationMedia
                    key={`after-${resultUrl}-${mediaRevision}`}
                    url={resultUrl}
                    kind={generationMediaKind(
                      resultUrl ?? "",
                      item.resultMediaType === "video" ? "video" : "image"
                    )}
                    title={text.after}
                    emptyText={text.mediaMissingAfter}
                    text={text}
                  />
                </div>
              ) : null}
              <details className={styles.technicalDetails}>
                <summary>{text.technicalDetails}</summary>
                <div className={styles.detailsGrid}>
                  <div>
                    <span>{text.cost}</span>
                    <strong>
                      {item.tokenCost} {text.creditsLabel}
                    </strong>
                  </div>
                  <div>
                    <span>{text.attempts}</span>
                    <strong>{item.attemptCount}</strong>
                  </div>
                  <div>
                    <span>{text.usdLabel}</span>
                    <strong>{formatMoney(item.providerCostUsd, locale)}</strong>
                  </div>
                  <div>
                    <span>{text.completedAt}</span>
                    <strong>{formatDateTime(item.completedAtUtc, locale)}</strong>
                  </div>
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
                  <div>
                    <span>{text.refundState}</span>
                    <strong>{text.refundStateOptions[item.refundState]}</strong>
                  </div>
                  <div>
                    <span>{text.refundAttempts}</span>
                    <strong>
                      {item.refundAttemptCount} / {item.refundAttemptLimit}
                    </strong>
                  </div>
                  <div>
                    <span>{text.refundLastAttempt}</span>
                    <strong>
                      {item.refundLastAttemptedAtUtc
                        ? formatDateTime(item.refundLastAttemptedAtUtc, locale)
                        : "-"}
                    </strong>
                  </div>
                  <div>
                    <span>{text.refundLastError}</span>
                    <strong>{formatSafeText(item.refundLastErrorCode)}</strong>
                  </div>
                </div>
              </details>
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
