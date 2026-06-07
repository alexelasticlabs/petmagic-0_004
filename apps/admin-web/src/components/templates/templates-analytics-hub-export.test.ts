import { describe, expect, it } from "vitest";

import {
  sanitizeTemplatesAnalyticsOverviewForExport,
  sanitizeTemplatesAnalyticsQueryForExport,
} from "@/components/templates/templates-analytics-hub-export";
import type { AdminTemplatesAnalyticsOverview } from "@/lib/api-client";

function createOverview(): AdminTemplatesAnalyticsOverview {
  const templateRow = {
    templateId: "template-1",
    templateType: "Video" as const,
    title: "Template token=raw-template-secret",
    category: "Fun https://cdn.example.com/category?sig=1",
    status: "Active" as const,
    isPremium: false,
    tokenCost: 20,
    previewAsset: {
      url: "https://cdn.example.com/preview.jpg?X-Amz-Signature=secret",
      fileName: "preview.jpg",
      contentType: "image/jpeg",
      fileSizeBytes: 100,
    },
    views: 10,
    generationStarts: 5,
    completedGenerations: 4,
    failedGenerations: 1,
    conversionPercent: 80,
    totalTokenCost: 100,
    totalProviderCostUsd: 1.5,
    updatedAtUtc: "2026-06-06T12:00:00Z",
  };

  return {
    summary: {
      totalTemplates: 1,
      videoTemplates: 1,
      imageTemplates: 0,
      activeTemplates: 1,
      premiumTemplates: 0,
      totalViews: 10,
      totalGenerationStarts: 5,
      completedGenerations: 4,
      failedGenerations: 1,
      conversionPercent: 80,
      totalTokenCost: 100,
      averageTokenCost: 20,
      totalProviderCostUsd: 1.5,
      totalComplaints: 1,
    },
    trendPoints: [],
    topTemplates: [templateRow],
    categories: [
      {
        key: "Fun receipt=raw-receipt",
        label: "Fun https://cdn.example.com/category?token=secret",
        templateCount: 1,
        views: 10,
        generationStarts: 5,
        completedGenerations: 4,
        conversionPercent: 80,
        totalTokenCost: 100,
        totalProviderCostUsd: 1.5,
      },
    ],
    templateTypes: [],
    sources: [
      {
        key: "web api_key=raw-key",
        label: "Web https://cdn.example.com/source?sig=1",
        count: 10,
        sharePercent: 100,
      },
    ],
    devices: [],
    geography: [],
    feedbackItems: [
      {
        eventId: "event-1",
        templateId: "template-1",
        templateTitle: "Template access_token=raw-token",
        templateType: "Video",
        eventType: "complaint password=raw-password",
        feedbackMessage: "Raw user feedback with private detail",
        source: "app secret=raw-secret",
        deviceClass: "ios receipt=raw-receipt",
        countryCode: "US token=raw-country-token",
        userId: "user-secret",
        generationId: "generation-secret",
        createdAtUtc: "2026-06-06T12:10:00Z",
      },
    ],
    conversionFunnel: {
      views: 10,
      generationStarts: 5,
      completedGenerations: 4,
      failedGenerations: 1,
      complaints: 1,
    },
    templates: [templateRow],
    availableCategories: [
      "Fun https://cdn.example.com/category?secret=1",
      "Internal token=raw-category-token",
    ],
    generatedAtUtc: "2026-06-06T12:15:00Z",
  };
}

describe("templates analytics hub export", () => {
  it("omits media URLs and raw feedback/user identifiers", () => {
    const sanitized = sanitizeTemplatesAnalyticsOverviewForExport(createOverview());
    const serialized = JSON.stringify(sanitized);

    expect(sanitized.templates[0]?.hasPreviewAsset).toBe(true);
    expect(sanitized.templates[0]?.previewAssetContentType).toBe("image/jpeg");
    expect(sanitized.feedbackItems[0]?.hasFeedbackMessage).toBe(true);
    expect(sanitized.feedbackItems[0]?.hasUser).toBe(true);
    expect(sanitized.feedbackItems[0]?.hasGeneration).toBe(true);
    expect(serialized).not.toContain('"url"');
    expect(serialized).not.toContain("preview.jpg");
    expect(serialized).not.toContain("X-Amz-Signature");
    expect(serialized).not.toContain("Raw user feedback");
    expect(serialized).not.toContain("user-secret");
    expect(serialized).not.toContain("generation-secret");
    expect(serialized).not.toContain("raw-template-secret");
    expect(serialized).not.toContain("raw-receipt");
    expect(serialized).not.toContain("raw-key");
    expect(serialized).not.toContain("raw-token");
    expect(serialized).not.toContain("raw-password");
    expect(serialized).not.toContain("raw-secret");
    expect(serialized).not.toContain("raw-country-token");
    expect(serialized).not.toContain("raw-category-token");
    expect(serialized).not.toContain("token=secret");
    expect(serialized).not.toContain("sig=1");
    expect(serialized).not.toContain("secret=1");
    expect(sanitized.availableCategories).toContain("Fun [redacted-url]");
    expect(sanitized.availableCategories).toContain("Internal token=[redacted]");
  });

  it("sanitizes selected query category before JSON export", () => {
    const sanitized = sanitizeTemplatesAnalyticsQueryForExport({
      category: "Fun https://cdn.example.com/category?secret=1 token=raw-query-token",
      periodDays: 30,
      templateType: "All",
      status: "All",
      access: "all",
      sort: "views",
      take: 50,
    });
    const serialized = JSON.stringify(sanitized);

    expect(serialized).toContain("[redacted-url]");
    expect(serialized).toContain("token=[redacted]");
    expect(serialized).not.toContain("secret=1");
    expect(serialized).not.toContain("raw-query-token");
  });
});
