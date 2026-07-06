import { describe, expect, it } from "vitest";

import {
  formatSafeTemplateAnalyticsExportName,
  sanitizeEventAnalyticsForExport,
  sanitizeFailureBreakdownForExport,
  sanitizeRecentRunsForExport,
  sanitizeTemplateForAnalyticsExport,
} from "@/components/templates/template-analytics-export";
import type { AdminTemplate, AdminTemplateRecentGeneration } from "@/lib/api-client";

describe("template analytics export", () => {
  it("formats safe analytics export filenames from template ids", () => {
    expect(formatSafeTemplateAnalyticsExportName(" template/one two?x ")).toBe(
      "template-template-one-two-x-analytics.json"
    );
    expect(formatSafeTemplateAnalyticsExportName("../")).toBe("template-template-analytics.json");
    expect(formatSafeTemplateAnalyticsExportName("x".repeat(120))).toBe(
      `template-${"x".repeat(80)}-analytics.json`
    );
  });

  it("omits output URLs and raw failure messages from recent run exports", () => {
    const runs: AdminTemplateRecentGeneration[] = [
      {
        generationId: "generation-1",
        userId: "user-1",
        status: "Failed",
        tokenCost: 25,
        attemptCount: 2,
        usedPreprocessingModel: "image-model",
        usedKlingModel: "video-model",
        motionProviderCostUsd: 0.12,
        failureCode: "provider.timeout token=raw-secret https://cdn.example.com/error?sig=1",
        failureMessage:
          "Raw provider payload included a signed URL https://cdn.example.com/a?sig=1",
        outputUrl: "https://cdn.example.com/output.mp4?X-Amz-Signature=secret",
        createdAtUtc: "2026-06-06T12:00:00Z",
        startedAtUtc: "2026-06-06T12:01:00Z",
        completedAtUtc: "2026-06-06T12:02:00Z",
      },
    ];

    const sanitized = sanitizeRecentRunsForExport(runs);
    const serialized = JSON.stringify(sanitized);

    expect(sanitized[0]?.hasOutput).toBe(true);
    expect(sanitized[0]?.failureCode).toContain("provider.timeout");
    expect(serialized).not.toContain("outputUrl");
    expect(serialized).not.toContain("failureMessage");
    expect(serialized).not.toContain("X-Amz-Signature");
    expect(serialized).not.toContain("raw-secret");
    expect(serialized).not.toContain("sig=1");
    expect(serialized).not.toContain("Raw provider payload");
  });

  it("omits template asset URLs and prompt text from detail exports", () => {
    const template: AdminTemplate = {
      templateId: "template-1",
      templateType: "Video",
      title: "Birthday pet https://cdn.example.com/title?token=raw-secret",
      shortDescription: "A premium card receipt=raw-receipt",
      petPhotoRequirements: ["front-facing pet api_key=raw-key"],
      category: "Celebration password=raw-password",
      status: "Active",
      promoBadgeMode: "Auto",
      isPremium: true,
      isQaOnly: false,
      tokenCost: 60,
      supportsGenerationResultInput: true,
      requiredInputMediaType: "Image",
      recommendedAfterImageGeneration: true,
      tags: ["birthday token=raw-token"],
      previewAsset: {
        url: "https://cdn.example.com/preview.mp4?X-Amz-Signature=secret",
        fileName: "preview.mp4",
        contentType: "video/mp4",
        fileSizeBytes: 1200,
      },
      referenceMotionAsset: {
        url: "https://cdn.example.com/reference.mp4?token=secret",
        fileName: "reference.mp4",
        contentType: "video/mp4",
      },
      imageModel: "image-model https://cdn.example.com/model?sig=1",
      imagePrompt: "Render with provider payload https://signed.example.com/x?sig=1",
      preprocessingModel: "preprocess-model access_token=raw-token",
      preprocessingPrompt: "Use internal preprocessing prompt",
      klingModel: "kling-v1 secret=raw-secret",
      klingPrompt: "Use internal video prompt",
      keepOriginalSound: false,
      estimatedProviderCostUsd: 0.22,
      createdAtUtc: "2026-06-06T12:00:00Z",
      updatedAtUtc: "2026-06-06T12:00:00Z",
    };

    const sanitized = sanitizeTemplateForAnalyticsExport(template);
    const serialized = JSON.stringify(sanitized);

    expect(sanitized.hasPreviewAsset).toBe(true);
    expect(sanitized.hasReferenceMotionAsset).toBe(true);
    expect(sanitized.hasImagePrompt).toBe(true);
    expect(sanitized.previewAssetContentType).toBe("video/mp4");
    expect(serialized).not.toContain("X-Amz-Signature");
    expect(serialized).not.toContain("cdn.example.com");
    expect(serialized).not.toContain("reference.mp4");
    expect(serialized).not.toContain("provider payload");
    expect(serialized).not.toContain("internal video prompt");
    expect(serialized).not.toContain("raw-secret");
    expect(serialized).not.toContain("raw-receipt");
    expect(serialized).not.toContain("raw-key");
    expect(serialized).not.toContain("raw-password");
    expect(serialized).not.toContain("raw-token");
  });

  it("sanitizes failure breakdown and event dimension text in exports", () => {
    const breakdown = sanitizeFailureBreakdownForExport([
      {
        failureCode: "provider.failed token=raw-secret https://cdn.example.com/failure?sig=1",
        count: 3,
        lastOccurredAtUtc: "2026-06-06T12:30:00Z",
      },
    ]);
    const events = sanitizeEventAnalyticsForExport({
      totalViews: 10,
      totalVideoViews: 4,
      totalComplaints: 1,
      sources: [
        {
          key: "web receipt=raw-receipt",
          label: "Web https://cdn.example.com/source?token=secret",
          count: 10,
          sharePercent: 100,
        },
      ],
      devices: [],
      geography: [],
    });
    const serialized = JSON.stringify({ breakdown, events });

    expect(breakdown[0]?.failureCode).toContain("provider.failed");
    expect(events.sources[0]?.label).toContain("Web");
    expect(serialized).not.toContain("raw-secret");
    expect(serialized).not.toContain("raw-receipt");
    expect(serialized).not.toContain("token=secret");
    expect(serialized).not.toContain("sig=1");
  });
});
