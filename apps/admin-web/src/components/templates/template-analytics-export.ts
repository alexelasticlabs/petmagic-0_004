import type {
  AdminTemplate,
  AdminTemplateAnalyticsDimension,
  AdminTemplateEventAnalytics,
  AdminTemplateFailureBreakdownItem,
  AdminTemplateRecentGeneration,
} from "@/lib/api-client";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

const EXPORT_URL_PATTERN = /\bhttps?:\/\/[^\s<>"')]+/gi;

export type SafeTemplateAnalyticsTemplateExport = Omit<
  AdminTemplate,
  | "previewAsset"
  | "referenceMotionAsset"
  | "imagePrompt"
  | "preprocessingPrompt"
  | "klingPrompt"
> & {
  hasPreviewAsset: boolean;
  previewAssetContentType?: string | null;
  hasReferenceMotionAsset: boolean;
  referenceMotionAssetContentType?: string | null;
  hasImagePrompt: boolean;
  hasPreprocessingPrompt: boolean;
  hasKlingPrompt: boolean;
};

export type SafeRecentGenerationExport = Omit<
  AdminTemplateRecentGeneration,
  "failureMessage" | "outputUrl"
> & {
  hasOutput: boolean;
};

export type SafeTemplateFailureBreakdownExport = AdminTemplateFailureBreakdownItem;
export type SafeTemplateEventAnalyticsExport = AdminTemplateEventAnalytics;

function sanitizeAnalyticsText(value: string, maxLength = 160) {
  return sanitizeSensitiveText(value.replace(EXPORT_URL_PATTERN, "[redacted-url]"), maxLength);
}

function sanitizeAnalyticsOptionalText(value: string | undefined, maxLength?: number): string | undefined;
function sanitizeAnalyticsOptionalText(
  value: string | null | undefined,
  maxLength?: number
): string | null | undefined;
function sanitizeAnalyticsOptionalText(value: string | null | undefined, maxLength = 160) {
  return value ? sanitizeAnalyticsText(value, maxLength) : value;
}

function sanitizeAnalyticsDimension(
  dimension: AdminTemplateAnalyticsDimension
): AdminTemplateAnalyticsDimension {
  return {
    key: sanitizeAnalyticsText(dimension.key, 96),
    label: sanitizeAnalyticsText(dimension.label, 160),
    count: dimension.count,
    sharePercent: dimension.sharePercent,
  };
}

export function sanitizeRecentRunsForExport(
  runs: readonly AdminTemplateRecentGeneration[]
): SafeRecentGenerationExport[] {
  return runs.map((run) => ({
    generationId: run.generationId,
    userId: run.userId,
    status: run.status,
    tokenCost: run.tokenCost,
    attemptCount: run.attemptCount,
    usedPreprocessingModel: sanitizeAnalyticsOptionalText(run.usedPreprocessingModel, 96),
    usedKlingModel: sanitizeAnalyticsOptionalText(run.usedKlingModel, 96),
    motionProviderCostUsd: run.motionProviderCostUsd,
    failureCode: sanitizeAnalyticsOptionalText(run.failureCode, 120),
    createdAtUtc: run.createdAtUtc,
    startedAtUtc: run.startedAtUtc,
    completedAtUtc: run.completedAtUtc,
    hasOutput: Boolean(run.outputUrl),
  }));
}

export function sanitizeTemplateForAnalyticsExport(
  template: AdminTemplate
): SafeTemplateAnalyticsTemplateExport {
  return {
    templateId: template.templateId,
    templateType: template.templateType,
    title: sanitizeAnalyticsText(template.title, 120),
    shortDescription: sanitizeAnalyticsText(template.shortDescription, 240),
    petPhotoRequirements: template.petPhotoRequirements?.map((requirement) =>
      sanitizeAnalyticsText(requirement, 160)
    ),
    category: sanitizeAnalyticsText(template.category, 120),
    status: template.status,
    promoBadgeMode: template.promoBadgeMode,
    effectivePromoBadge: template.effectivePromoBadge,
    isPremium: template.isPremium,
    tokenCost: template.tokenCost,
    tags: template.tags.map((tag) => sanitizeAnalyticsText(tag, 80)),
    musicDescription: sanitizeAnalyticsOptionalText(template.musicDescription, 160),
    referenceVideoDurationSeconds: template.referenceVideoDurationSeconds,
    characterOrientation: sanitizeAnalyticsOptionalText(template.characterOrientation, 80),
    imageModel: sanitizeAnalyticsOptionalText(template.imageModel, 96),
    preprocessingModel: sanitizeAnalyticsOptionalText(template.preprocessingModel, 96),
    klingModel: sanitizeAnalyticsOptionalText(template.klingModel, 96),
    keepOriginalSound: template.keepOriginalSound,
    estimatedProviderCostUsd: template.estimatedProviderCostUsd,
    createdAtUtc: template.createdAtUtc,
    updatedAtUtc: template.updatedAtUtc,
    hasPreviewAsset: Boolean(template.previewAsset),
    previewAssetContentType: template.previewAsset?.contentType ?? null,
    hasReferenceMotionAsset: Boolean(template.referenceMotionAsset),
    referenceMotionAssetContentType: template.referenceMotionAsset?.contentType ?? null,
    hasImagePrompt: Boolean(template.imagePrompt?.trim()),
    hasPreprocessingPrompt: Boolean(template.preprocessingPrompt?.trim()),
    hasKlingPrompt: Boolean(template.klingPrompt?.trim()),
  };
}

export function sanitizeFailureBreakdownForExport(
  items: readonly AdminTemplateFailureBreakdownItem[]
): SafeTemplateFailureBreakdownExport[] {
  return items.map((item) => ({
    failureCode: sanitizeAnalyticsText(item.failureCode, 120),
    count: item.count,
    lastOccurredAtUtc: item.lastOccurredAtUtc,
  }));
}

export function sanitizeEventAnalyticsForExport(
  events: AdminTemplateEventAnalytics
): SafeTemplateEventAnalyticsExport {
  return {
    totalViews: events.totalViews,
    totalVideoViews: events.totalVideoViews,
    totalComplaints: events.totalComplaints,
    sources: events.sources.map(sanitizeAnalyticsDimension),
    devices: events.devices.map(sanitizeAnalyticsDimension),
    geography: events.geography.map(sanitizeAnalyticsDimension),
  };
}
