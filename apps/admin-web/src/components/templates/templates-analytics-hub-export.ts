import type {
  AdminTemplateAnalyticsDimension,
  AdminTemplatesAnalyticsFeedbackItem,
  AdminTemplatesAnalyticsOverview,
  AdminTemplatesAnalyticsQuery,
  AdminTemplatesAnalyticsBreakdown,
  AdminTemplatesAnalyticsTemplateRow,
} from "@/lib/api-client";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

const EXPORT_URL_PATTERN = /\bhttps?:\/\/[^\s<>"')]+/gi;

export type SafeTemplatesAnalyticsTemplateRowExport = Omit<
  AdminTemplatesAnalyticsTemplateRow,
  "previewAsset"
> & {
  hasPreviewAsset: boolean;
  previewAssetContentType?: string | null;
};

export type SafeTemplatesAnalyticsFeedbackExport = Omit<
  AdminTemplatesAnalyticsFeedbackItem,
  "feedbackMessage" | "userId" | "generationId"
> & {
  hasFeedbackMessage: boolean;
  hasUser: boolean;
  hasGeneration: boolean;
};

export type SafeTemplatesAnalyticsOverviewExport = Omit<
  AdminTemplatesAnalyticsOverview,
  "topTemplates" | "templates" | "feedbackItems"
> & {
  topTemplates: SafeTemplatesAnalyticsTemplateRowExport[];
  templates: SafeTemplatesAnalyticsTemplateRowExport[];
  feedbackItems: SafeTemplatesAnalyticsFeedbackExport[];
};

export type SafeTemplatesAnalyticsQueryExport = Omit<AdminTemplatesAnalyticsQuery, "category"> & {
  category?: string;
};

function sanitizeAnalyticsText(value: string, maxLength = 160) {
  return sanitizeSensitiveText(value.replace(EXPORT_URL_PATTERN, "[redacted-url]"), maxLength);
}

function sanitizeBreakdownForExport(
  item: AdminTemplatesAnalyticsBreakdown
): AdminTemplatesAnalyticsBreakdown {
  return {
    key: sanitizeAnalyticsText(item.key, 96),
    label: sanitizeAnalyticsText(item.label, 160),
    templateCount: item.templateCount,
    views: item.views,
    generationStarts: item.generationStarts,
    completedGenerations: item.completedGenerations,
    conversionPercent: item.conversionPercent,
    totalTokenCost: item.totalTokenCost,
    totalProviderCostUsd: item.totalProviderCostUsd,
  };
}

function sanitizeDimensionForExport(
  item: AdminTemplateAnalyticsDimension
): AdminTemplateAnalyticsDimension {
  return {
    key: sanitizeAnalyticsText(item.key, 96),
    label: sanitizeAnalyticsText(item.label, 160),
    count: item.count,
    sharePercent: item.sharePercent,
  };
}

function sanitizeTemplateRowForExport(
  row: AdminTemplatesAnalyticsTemplateRow
): SafeTemplatesAnalyticsTemplateRowExport {
  return {
    templateId: row.templateId,
    templateType: row.templateType,
    title: sanitizeAnalyticsText(row.title, 120),
    category: sanitizeAnalyticsText(row.category, 120),
    status: row.status,
    isPremium: row.isPremium,
    tokenCost: row.tokenCost,
    views: row.views,
    generationStarts: row.generationStarts,
    completedGenerations: row.completedGenerations,
    failedGenerations: row.failedGenerations,
    conversionPercent: row.conversionPercent,
    totalTokenCost: row.totalTokenCost,
    totalProviderCostUsd: row.totalProviderCostUsd,
    updatedAtUtc: row.updatedAtUtc,
    hasPreviewAsset: Boolean(row.previewAsset),
    previewAssetContentType: row.previewAsset?.contentType ?? null,
  };
}

function sanitizeFeedbackForExport(
  item: AdminTemplatesAnalyticsFeedbackItem
): SafeTemplatesAnalyticsFeedbackExport {
  return {
    eventId: item.eventId,
    templateId: item.templateId,
    templateTitle: sanitizeAnalyticsText(item.templateTitle, 120),
    templateType: item.templateType,
    eventType: sanitizeAnalyticsText(item.eventType, 80),
    source: sanitizeAnalyticsText(item.source, 80),
    deviceClass: sanitizeAnalyticsText(item.deviceClass, 80),
    countryCode: sanitizeAnalyticsText(item.countryCode, 16),
    createdAtUtc: item.createdAtUtc,
    hasFeedbackMessage: Boolean(item.feedbackMessage?.trim()),
    hasUser: Boolean(item.userId),
    hasGeneration: Boolean(item.generationId),
  };
}

export function sanitizeTemplatesAnalyticsOverviewForExport(
  overview: AdminTemplatesAnalyticsOverview
): SafeTemplatesAnalyticsOverviewExport {
  return {
    summary: overview.summary,
    trendPoints: overview.trendPoints,
    topTemplates: overview.topTemplates.map(sanitizeTemplateRowForExport),
    categories: overview.categories.map(sanitizeBreakdownForExport),
    templateTypes: overview.templateTypes.map(sanitizeBreakdownForExport),
    sources: overview.sources.map(sanitizeDimensionForExport),
    devices: overview.devices.map(sanitizeDimensionForExport),
    geography: overview.geography.map(sanitizeDimensionForExport),
    feedbackItems: overview.feedbackItems.map(sanitizeFeedbackForExport),
    conversionFunnel: overview.conversionFunnel,
    templates: overview.templates.map(sanitizeTemplateRowForExport),
    availableCategories: overview.availableCategories.map((category) =>
      sanitizeAnalyticsText(category, 120)
    ),
    generatedAtUtc: overview.generatedAtUtc,
  };
}

export function sanitizeTemplatesAnalyticsQueryForExport(
  query: AdminTemplatesAnalyticsQuery
): SafeTemplatesAnalyticsQueryExport {
  return {
    ...query,
    category: query.category ? sanitizeAnalyticsText(query.category, 120) : undefined,
  };
}
