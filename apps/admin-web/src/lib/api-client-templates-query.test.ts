import { readFileSync } from "node:fs";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { readTemplateTestPageLibrarySource } from "@/components/templates/template-test-page.test-source";
import { clearAdminListCaches } from "@/lib/api-client.core";
import {
  cancelAdminTemplateGeneration,
  createTemplateOfTheDay,
  decideAdminModerationItem,
  fetchAdminModerationQueue,
  fetchAdminTemplateStatistics,
  fetchAdminTemplateGenerationMetrics,
  fetchAdminTemplates,
  fetchAdminTemplatesAnalyticsOverview,
  fetchAdminTemplateFeedback,
  fetchAdminTemplateRecentGenerations,
  fetchAdminTemplateTest,
  fetchAdminTemplateTestHistory,
  GENERATION_PROVIDER_FILTER_MAX_LENGTH,
  GENERATION_SEARCH_FILTER_MAX_LENGTH,
  GENERATION_USER_FILTER_MAX_LENGTH,
  fetchTemplateOfTheDaySettings,
  MODERATION_DECISION_REASON_MAX_LENGTH,
  MODERATION_SEARCH_MAX_LENGTH,
  normalizeAdminTemplateCatalogQuery,
  normalizeAdminModerationQueueQuery,
  normalizeAdminTemplateGenerationsQuery,
  normalizeAdminTemplatesAnalyticsQuery,
  retryAdminTemplateGeneration,
  TEMPLATE_CATALOG_SEARCH_MAX_LENGTH,
  TEMPLATE_FEEDBACK_SEARCH_MAX_LENGTH,
  updateImageTemplate,
  updateTemplateOfTheDaySettings,
} from "@/lib/api-client.templates";

function readSource(relativePath: string): string {
  return readFileSync(path.join(process.cwd(), "src", relativePath), "utf8");
}

describe("api-client.templates query normalization", () => {
  const originalPublicApiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL;
  const originalInternalApiBaseUrl = process.env.INTERNAL_API_BASE_URL;

  beforeEach(() => {
    process.env.NEXT_PUBLIC_API_BASE_URL = "https://api.example.com";
    process.env.INTERNAL_API_BASE_URL = "https://api.example.com";
    clearAdminListCaches();
  });

  afterEach(() => {
    clearAdminListCaches();
    vi.unstubAllGlobals();
    process.env.NEXT_PUBLIC_API_BASE_URL = originalPublicApiBaseUrl;
    process.env.INTERNAL_API_BASE_URL = originalInternalApiBaseUrl;
  });

  it("normalizes generation list filters for stable cache keys and requests", () => {
    const overlongProvider = "p".repeat(GENERATION_PROVIDER_FILTER_MAX_LENGTH + 12);
    const overlongUser = "u".repeat(GENERATION_USER_FILTER_MAX_LENGTH + 12);
    const overlongSearch = "g".repeat(GENERATION_SEARCH_FILTER_MAX_LENGTH + 12);

    expect(
      normalizeAdminTemplateGenerationsQuery({
        status: "All",
        provider: ` ${overlongProvider} `,
        user: ` ${overlongUser} `,
        search: ` ${overlongSearch} `,
        skip: -25.5,
        take: 500.8,
      })
    ).toEqual({
      status: undefined,
      provider: "p".repeat(GENERATION_PROVIDER_FILTER_MAX_LENGTH),
      user: "u".repeat(GENERATION_USER_FILTER_MAX_LENGTH),
      search: "g".repeat(GENERATION_SEARCH_FILTER_MAX_LENGTH),
      skip: 0,
      take: 100,
    });
  });

  it("normalizes moderation queue filters for stable cache keys and requests", () => {
    const overlongSearch = "m".repeat(MODERATION_SEARCH_MAX_LENGTH + 20);

    expect(
      normalizeAdminModerationQueueQuery({
        status: "all",
        search: ` ${overlongSearch} `,
        skip: -1.5,
        take: 500.2,
      })
    ).toEqual({
      status: undefined,
      search: "m".repeat(MODERATION_SEARCH_MAX_LENGTH),
      skip: 0,
      take: 100,
    });
  });

  it("normalizes template catalog filters for backend pagination requests", () => {
    const overlongSearch = "t".repeat(TEMPLATE_CATALOG_SEARCH_MAX_LENGTH + 20);

    expect(
      normalizeAdminTemplateCatalogQuery({
        type: "Image",
        status: "not_archived",
        search: ` ${overlongSearch} `,
        category: " Portrait ",
        access: "premium",
        sort: "title",
        skip: -4.5,
        take: 500.2,
      })
    ).toEqual({
      type: "Image",
      status: "not_archived",
      search: "t".repeat(TEMPLATE_CATALOG_SEARCH_MAX_LENGTH),
      category: "Portrait",
      access: "premium",
      sort: "title",
      skip: 0,
      take: 100,
    });
  });

  it("drops unsupported template catalog enum filters before backend requests", () => {
    expect(
      normalizeAdminTemplateCatalogQuery({
        type: "Document" as never,
        status: "Deleted" as never,
        search: " portrait ",
        category: " Featured ",
        access: "vip" as never,
        sort: "random" as never,
        skip: 2.9,
        take: 24.8,
      })
    ).toEqual({
      type: undefined,
      status: undefined,
      search: "portrait",
      category: "Featured",
      access: undefined,
      sort: undefined,
      skip: 2,
      take: 24,
    });
  });

  it("normalizes template analytics filters before cache keys and URLs", () => {
    const overlongCategory = "a".repeat(TEMPLATE_CATALOG_SEARCH_MAX_LENGTH + 20);

    expect(
      normalizeAdminTemplatesAnalyticsQuery({
        periodDays: 5000.9,
        templateType: "Document" as never,
        category: ` ${overlongCategory} `,
        status: "Deleted" as never,
        access: "vip" as never,
        sort: "random" as never,
        take: 500.2,
      })
    ).toEqual({
      periodDays: 3650,
      templateType: undefined,
      category: "a".repeat(TEMPLATE_CATALOG_SEARCH_MAX_LENGTH),
      status: undefined,
      access: undefined,
      sort: undefined,
      take: 200,
    });
  });

  it("normalizes template pagination values to finite integers", () => {
    expect(
      normalizeAdminTemplateGenerationsQuery({
        skip: 12.8,
        take: 25.4,
      })
    ).toEqual({
      status: undefined,
      provider: undefined,
      user: undefined,
      search: undefined,
      skip: 12,
      take: 25,
    });

    expect(
      normalizeAdminModerationQueueQuery({
        skip: Number.NaN,
        take: Number.POSITIVE_INFINITY,
      })
    ).toEqual({
      status: undefined,
      search: undefined,
      skip: undefined,
      take: undefined,
    });
  });

  it("normalizes template take-only request URLs", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () => Response.json([]));
    vi.stubGlobal("fetch", fetchMock);

    await fetchAdminTemplateRecentGenerations("template-recent", 25.8);
    await fetchAdminTemplateTestHistory("template-tests", 500.5);
    await fetchAdminTemplateTestHistory("template-tests-no-take", Number.POSITIVE_INFINITY);

    expect(fetchMock.mock.calls.map((call) => String(call[0]))).toEqual([
      "https://api.example.com/api/admin/templates/template-recent/statistics/recent?take=25",
      "https://api.example.com/api/admin/templates/template-tests/tests?take=100",
      "https://api.example.com/api/admin/templates/template-tests-no-take/tests",
    ]);
  });

  it("preserves canonical completed statuses for admin template tests", async () => {
    const fetchMock = vi.fn<typeof fetch>(async (input) => {
      const url = String(input);
      if (url.includes("/tests?")) {
        return Response.json([
          {
            generationId: "generation-history",
            status: "Completed",
            tokenCost: 10,
            attemptCount: 1,
            createdAtUtc: "2026-06-14T12:00:00Z",
            updatedAtUtc: "2026-06-14T12:01:00Z",
            userMediaExpired: false,
          },
        ]);
      }

      return Response.json({
        generationId: "generation-single",
        status: "Completed",
        tokenCost: 10,
        attemptCount: 1,
        createdAtUtc: "2026-06-14T12:00:00Z",
        updatedAtUtc: "2026-06-14T12:01:00Z",
        userMediaExpired: false,
      });
    });
    vi.stubGlobal("fetch", fetchMock);

    const single = await fetchAdminTemplateTest("generation-single");
    const history = await fetchAdminTemplateTestHistory("template-tests", 5);

    expect(single.status).toBe("Completed");
    expect(history[0]?.status).toBe("Completed");
  });

  it("sends template catalog search and filters to the backend", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({
        items: [],
        skip: 12,
        take: 24,
        hasMore: false,
      })
    );
    vi.stubGlobal("fetch", fetchMock);

    await fetchAdminTemplates({
      type: "Video",
      status: "not_archived",
      search: " dance ",
      category: "Fun",
      access: "free",
      sort: "tokens",
      skip: 12.9,
      take: 24.2,
    });

    expect(fetchMock.mock.calls.map((call) => String(call[0]))).toEqual([
      "https://api.example.com/api/admin/templates/?type=Video&status=not_archived&search=dance&category=Fun&access=free&sort=tokens&skip=12&take=24",
    ]);
  });

  it("preserves moderation queue totalCount for dashboard KPI counts", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({
        items: [],
        skip: 0,
        take: 1,
        totalCount: 42,
        hasMore: true,
        generatedAtUtc: "2026-06-07T00:00:00Z",
      })
    );
    vi.stubGlobal("fetch", fetchMock);

    const response = await fetchAdminModerationQueue({ status: "pending", take: 1 });

    expect(response.totalCount).toBe(42);
    expect(fetchMock.mock.calls.map((call) => String(call[0]))).toEqual([
      "https://api.example.com/api/admin/templates/moderation?status=pending&take=1",
    ]);
  });

  it("requests backend generation dashboard metrics with abort support", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({
        totalJobs: 12,
        generationsToday: 3,
        generationsThisWeek: 8,
        generationsThisMonth: 11,
        failedGenerationsToday: 1,
        failedGenerationsThisWeek: 2,
        failedGenerationsThisMonth: 4,
        pendingJobs: 2,
        runningJobs: 1,
        completedJobs: 5,
        failedJobs: 3,
        cancelledJobs: 1,
        retryingJobs: 1,
        generatedAtUtc: "2026-06-07T00:00:00Z",
      })
    );
    const controller = new AbortController();
    vi.stubGlobal("fetch", fetchMock);

    const response = await fetchAdminTemplateGenerationMetrics(controller.signal);

    expect(response.totalJobs).toBe(12);
    expect(response.failedJobs).toBe(3);
    const [url, init] = fetchMock.mock.calls[0] ?? [];
    expect(String(url)).toBe("https://api.example.com/api/admin/templates/generations/metrics");
    expect(init?.method).toBe("GET");
    expect(init?.signal).toBeInstanceOf(AbortSignal);
  });

  it("uses a stable cache key for equivalent template catalog queries", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({
        items: [],
        skip: 0,
        take: 24,
        totalCount: 42,
        hasMore: false,
      })
    );
    vi.stubGlobal("fetch", fetchMock);

    const firstResponse = await fetchAdminTemplates({
      type: "Image",
      search: " portrait ",
      skip: 0,
      take: 24,
    });
    const secondResponse = await fetchAdminTemplates({
      type: "Image",
      search: "portrait",
      skip: 0.5,
      take: 24.9,
    });

    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(firstResponse.totalCount).toBe(42);
    expect(secondResponse.totalCount).toBe(42);
  });

  it("bounds template feedback search before request URLs", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () => Response.json([]));
    const overlongSearch = "f".repeat(TEMPLATE_FEEDBACK_SEARCH_MAX_LENGTH + 20);
    vi.stubGlobal("fetch", fetchMock);

    await fetchAdminTemplateFeedback("template-feedback", {
      search: ` ${overlongSearch} `,
      take: 50,
      type: "feedback",
    });

    expect(fetchMock.mock.calls.map((call) => String(call[0]))).toEqual([
      `https://api.example.com/api/admin/templates/template-feedback/statistics/feedback?take=50&type=feedback&search=${"f".repeat(TEMPLATE_FEEDBACK_SEARCH_MAX_LENGTH)}`,
    ]);
  });

  it("drops unsupported template feedback filters before request URLs", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () => Response.json([]));
    vi.stubGlobal("fetch", fetchMock);

    await fetchAdminTemplateFeedback("template-feedback", {
      search: " useful ",
      take: 500.8,
      type: "other" as never,
    });

    expect(fetchMock.mock.calls.map((call) => String(call[0]))).toEqual([
      "https://api.example.com/api/admin/templates/template-feedback/statistics/feedback?take=100&search=useful",
    ]);
  });

  it("sends normalized template analytics filters to the backend", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({
        summary: {
          totalTemplates: 0,
          videoTemplates: 0,
          imageTemplates: 0,
          activeTemplates: 0,
          premiumTemplates: 0,
          totalViews: 0,
          totalGenerationStarts: 0,
          completedGenerations: 0,
          failedGenerations: 0,
          conversionPercent: 0,
          totalTokenCost: 0,
          averageTokenCost: 0,
          totalProviderCostUsd: 0,
          complaintCount: 0,
        },
        trend: [],
        topTemplates: [],
        categories: [],
        templateTypes: [],
        sources: [],
        devices: [],
        geography: [],
        feedback: [],
        funnel: {
          views: 0,
          starts: 0,
          completed: 0,
          failed: 0,
          complaints: 0,
        },
        templates: [],
        availableCategories: [],
        generatedAtUtc: "2026-06-15T00:00:00.000Z",
      })
    );
    vi.stubGlobal("fetch", fetchMock);

    await fetchAdminTemplatesAnalyticsOverview({
      periodDays: 30.8,
      templateType: "Document" as never,
      category: " Premium ",
      status: "Deleted" as never,
      access: "vip" as never,
      sort: "random" as never,
      take: 250.4,
    });

    expect(fetchMock.mock.calls.map((call) => String(call[0]))).toEqual([
      "https://api.example.com/api/admin/templates/analytics?periodDays=30&category=Premium&take=200",
    ]);
  });

  it("reads and updates Template of the Day auto-mode settings", async () => {
    const fetchMock = vi.fn<typeof fetch>(async (input) => {
      if (String(input).endsWith("/settings")) {
        return Response.json({
          autoModeEnabled: true,
          allowedTypes: "video",
          excludeRecentDays: 14,
          updatedAtUtc: "2026-06-14T12:00:00Z",
        });
      }

      return Response.json({});
    });
    vi.stubGlobal("fetch", fetchMock);

    const settings = await fetchTemplateOfTheDaySettings();
    await updateTemplateOfTheDaySettings({
      autoModeEnabled: false,
      allowedTypes: "image",
      excludeRecentDays: 0,
    });

    expect(settings.allowedTypes).toBe("video");
    expect(fetchMock.mock.calls.map((call) => String(call[0]))).toEqual([
      "https://api.example.com/api/admin/template-of-the-day/settings",
      "https://api.example.com/api/admin/template-of-the-day/settings",
    ]);
    expect(fetchMock.mock.calls[1]?.[1]?.method).toBe("PUT");
    expect(JSON.parse(String(fetchMock.mock.calls[1]?.[1]?.body))).toEqual({
      autoModeEnabled: false,
      allowedTypes: "image",
      excludeRecentDays: 0,
    });
  });

  it("creates Template of the Day assignments on the no-trailing-slash collection route", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({
        id: "assignment-1",
        templateId: "template-1",
        templateTitle: "Daily Portrait",
        templateType: "Image",
        category: "Portrait",
        templateStatus: "Active",
        isPremium: false,
        previewAsset: null,
        startDate: "2026-06-14",
        endDate: null,
        isActive: true,
        isManual: true,
        priority: 10,
        titleOverride: "Featured",
        subtitleOverride: null,
        badgeTextOverride: null,
        createdAtUtc: "2026-06-14T00:00:00Z",
        updatedAtUtc: "2026-06-14T00:00:00Z",
      })
    );
    vi.stubGlobal("fetch", fetchMock);

    await createTemplateOfTheDay({
      templateId: "template-1",
      startDate: "2026-06-14",
      endDate: null,
      isActive: true,
      isManual: true,
      priority: 10,
      titleOverride: "Featured",
      subtitleOverride: null,
      badgeTextOverride: null,
    });

    expect(fetchMock.mock.calls.map((call) => String(call[0]))).toEqual([
      "https://api.example.com/api/admin/template-of-the-day",
    ]);
    expect(fetchMock.mock.calls[0]?.[1]?.method).toBe("POST");
  });

  it("encodes template ids before placing them in API path segments", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () => Response.json([]));
    vi.stubGlobal("fetch", fetchMock);

    await fetchAdminTemplateRecentGenerations("template/one two?x", 25);
    await fetchAdminTemplateTest("generation/one two?x");
    await cancelAdminTemplateGeneration("generation/one two?x");
    await retryAdminTemplateGeneration("generation/one two?x");
    await decideAdminModerationItem("event/one two?x", {
      action: "reject",
      reason: "Policy",
    });

    expect(fetchMock.mock.calls.map((call) => String(call[0]))).toEqual([
      "https://api.example.com/api/admin/templates/template%2Fone%20two%3Fx/statistics/recent?take=25",
      "https://api.example.com/api/admin/templates/tests/generation%2Fone%20two%3Fx",
      "https://api.example.com/api/admin/templates/generations/generation%2Fone%20two%3Fx/cancel",
      "https://api.example.com/api/admin/templates/generations/generation%2Fone%20two%3Fx/retry",
      "https://api.example.com/api/admin/templates/moderation/event%2Fone%20two%3Fx/decision",
    ]);
    expect(fetchMock.mock.calls[2]?.[1]?.method).toBe("POST");
    expect(fetchMock.mock.calls[3]?.[1]?.method).toBe("POST");
  });

  it("bounds moderation decision reasons before sending audit payloads", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () => Response.json({}));
    const overlongReason = "r".repeat(MODERATION_DECISION_REASON_MAX_LENGTH + 20);
    vi.stubGlobal("fetch", fetchMock);

    await decideAdminModerationItem("event-1", {
      action: "reject",
      reason: ` ${overlongReason} `,
    });

    const [, init] = fetchMock.mock.calls[0] ?? [];
    expect(String(fetchMock.mock.calls[0]?.[0])).toBe(
      "https://api.example.com/api/admin/templates/moderation/event-1/decision"
    );
    expect(JSON.parse(String(init?.body))).toEqual({
      action: "reject",
      reason: "r".repeat(MODERATION_DECISION_REASON_MAX_LENGTH),
    });
  });

  it("invalidates cached template analytics after template mutations", async () => {
    const fetchMock = vi.fn<typeof fetch>(async (input) => {
      const url = String(input);
      if (url.endsWith("/api/admin/templates/template-analytics/statistics")) {
        return Response.json({ templateId: "template-analytics", totalRuns: 1 });
      }
      if (url.endsWith("/api/admin/templates/image/template-analytics")) {
        return Response.json({ templateId: "template-analytics" });
      }
      return Response.json({});
    });
    vi.stubGlobal("fetch", fetchMock);

    await fetchAdminTemplateStatistics("template-analytics");
    await fetchAdminTemplateStatistics("template-analytics");
    await updateImageTemplate(
      "template-analytics",
      {} as Parameters<typeof updateImageTemplate>[1]
    );
    await fetchAdminTemplateStatistics("template-analytics");

    const statisticsRequests = fetchMock.mock.calls.filter((call) =>
      String(call[0]).endsWith("/api/admin/templates/template-analytics/statistics")
    );
    expect(statisticsRequests).toHaveLength(2);
  });

  it("propagates AbortSignal through template GET helpers", () => {
    const source = readSource("lib/api-client.templates.ts");

    expect(source).toContain(
      "export async function fetchAdminTemplates(\n  query: AdminTemplateCatalogQuery = {},\n  signal?: AbortSignal"
    );
    expect(source).toContain(
      "export async function fetchAdminTemplateCategories(\n  includeArchived = true,\n  signal?: AbortSignal"
    );
    expect(source).toContain(
      "export async function fetchAdminTemplate(\n  templateId: string,\n  signal?: AbortSignal"
    );
    expect(source).toContain(
      "export async function fetchAdminTemplateStatistics(\n  templateId: string,\n  signal?: AbortSignal"
    );
    expect(source).toContain(
      "export async function fetchAdminTemplatesAnalyticsOverview(\n  query: AdminTemplatesAnalyticsQuery = {},\n  signal?: AbortSignal"
    );
    expect(source).toContain(
      "export async function fetchAdminTemplateTest(\n  generationId: string,\n  signal?: AbortSignal"
    );
    expect(source).toContain(
      "export async function fetchAdminTemplateTestHistory(\n  templateId: string,\n  take?: number,\n  signal?: AbortSignal"
    );
    expect(source).toContain('{ method: "GET", signal }');
  });

  it("uses React Query AbortSignal in template catalog and analytics hooks", () => {
    const catalogSource = readSource("components/templates/use-admin-template-catalog.ts");
    const overviewSource = readSource(
      "components/templates/use-admin-template-analytics-overview.ts"
    );
    const feedbackSource = readSource("components/templates/use-admin-template-feedback.ts");
    const optionsSource = readSource("components/templates/use-admin-template-options.ts");
    const categoriesSource = readSource("components/templates/use-admin-template-categories.ts");
    const hubSource = readSource("components/templates/templates-analytics-hub-page.tsx");

    expect(catalogSource).toContain(
      "queryFn: ({ signal }) => fetchAdminTemplates(normalizedQuery, signal)"
    );
    expect(catalogSource).toContain("fetchAdminTemplatesAnalyticsOverview(");
    expect(catalogSource).toContain("signal");
    expect(overviewSource).toContain("queryFn: async ({ signal }) =>");
    expect(overviewSource).toContain("fetchAdminTemplate(templateId, signal)");
    expect(overviewSource).toContain(
      "fetchAdminTemplateRecentGenerations(templateId, previewTake, signal)"
    );
    expect(feedbackSource).toContain("queryFn: ({ signal }) =>");
    expect(feedbackSource).toContain("fetchAdminTemplateFeedback(");
    expect(feedbackSource).toContain("signal");
    expect(optionsSource).toContain("queryFn: ({ signal }) => fetchAdminTemplates(query, signal)");
    expect(categoriesSource).toContain(
      "queryFn: ({ signal }) => fetchAdminTemplateCategories(includeArchived, signal)"
    );
    expect(hubSource).toContain(
      "queryFn: ({ signal }) => fetchAdminTemplatesAnalyticsOverview(query, signal)"
    );
  });

  it("aborts template editor/test page manual loads and polling", () => {
    const editorSource = readSource("components/templates/use-template-editor-controller.ts");
    const testPageSource = readTemplateTestPageLibrarySource();
    const analyticsPageSource = readSource("components/templates/template-analytics-page.tsx");

    expect(editorSource).toContain("const controller = new AbortController();");
    expect(editorSource).toContain("fetchAdminTemplate(initialTemplateId, controller.signal)");
    expect(editorSource).toContain("controller.abort();");
    expect(testPageSource).toContain("fetchAdminTemplate(templateId, controller.signal)");
    expect(testPageSource).toContain("fetchAdminTemplateTestHistory(");
    expect(testPageSource).toContain("controller.signal");
    expect(testPageSource).toContain("const activeRun = run;");
    expect(testPageSource).toContain(
      "fetchAdminTemplateTest(activeRun.generationId, controller.signal)"
    );
    expect(testPageSource).toContain("controller.abort();");
    expect(analyticsPageSource).toContain("recentRunsAbortControllerRef.current?.abort()");
    expect(analyticsPageSource).toContain("fetchAdminTemplateRecentGenerations(");
    expect(analyticsPageSource).toContain("controller.signal");
    expect(testPageSource).toContain(
      "const editorPath = `/${locale}/templates/${templateSlug}/editor?templateId=${encodeURIComponent(templateId)}`;"
    );
    expect(analyticsPageSource).toContain(
      "const editorPath = `/${locale}/templates/${templateSlug}/editor?templateId=${encodeURIComponent(templateId)}`;"
    );
    expect(testPageSource).not.toContain("editor?templateId=${templateId}");
    expect(analyticsPageSource).not.toContain("editor?templateId=${templateId}");
  });
});
