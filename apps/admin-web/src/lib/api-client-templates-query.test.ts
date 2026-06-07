import { readFileSync } from "node:fs";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { clearAdminListCaches } from "@/lib/api-client.core";
import {
  fetchAdminTemplateRecentGenerations,
  fetchAdminTemplateTestHistory,
  normalizeAdminModerationQueueQuery,
  normalizeAdminTemplateGenerationsQuery,
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
    expect(
      normalizeAdminTemplateGenerationsQuery({
        status: "All",
        provider: " fal ",
        user: "  ",
        search: " job-123 ",
        skip: -25.5,
        take: 500.8,
      })
    ).toEqual({
      status: undefined,
      provider: "fal",
      user: undefined,
      search: "job-123",
      skip: 0,
      take: 100,
    });
  });

  it("normalizes moderation queue filters for stable cache keys and requests", () => {
    expect(
      normalizeAdminModerationQueueQuery({
        status: "all",
        search: " template title ",
        skip: -1.5,
        take: 500.2,
      })
    ).toEqual({
      status: undefined,
      search: "template title",
      skip: 0,
      take: 100,
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
    const fetchMock = vi.fn(async () => Response.json([]));
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

  it("propagates AbortSignal through template GET helpers", () => {
    const source = readSource("lib/api-client.templates.ts");

    expect(source).toContain("export async function fetchAdminTemplates(\n  type?: TemplateType,\n  signal?: AbortSignal");
    expect(source).toContain("export async function fetchAdminTemplateCategories(\n  includeArchived = true,\n  signal?: AbortSignal");
    expect(source).toContain("export async function fetchAdminTemplate(\n  templateId: string,\n  signal?: AbortSignal");
    expect(source).toContain("export async function fetchAdminTemplateStatistics(\n  templateId: string,\n  signal?: AbortSignal");
    expect(source).toContain("export async function fetchAdminTemplatesAnalyticsOverview(\n  query: AdminTemplatesAnalyticsQuery = {},\n  signal?: AbortSignal");
    expect(source).toContain("export async function fetchAdminTemplateTest(\n  generationId: string,\n  signal?: AbortSignal");
    expect(source).toContain("export async function fetchAdminTemplateTestHistory(\n  templateId: string,\n  take?: number,\n  signal?: AbortSignal");
    expect(source).toContain("{ method: \"GET\", signal }");
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

    expect(catalogSource).toContain("queryFn: ({ signal }) => fetchAdminTemplates(templateType, signal)");
    expect(catalogSource).toContain("fetchAdminTemplatesAnalyticsOverview(");
    expect(catalogSource).toContain("signal");
    expect(overviewSource).toContain("queryFn: async ({ signal }) =>");
    expect(overviewSource).toContain("fetchAdminTemplate(templateId, signal)");
    expect(overviewSource).toContain("fetchAdminTemplateRecentGenerations(templateId, previewTake, signal)");
    expect(feedbackSource).toContain("queryFn: ({ signal }) =>");
    expect(feedbackSource).toContain("}, signal)");
    expect(optionsSource).toContain("queryFn: ({ signal }) => fetchAdminTemplates(templateType, signal)");
    expect(categoriesSource).toContain(
      "queryFn: ({ signal }) => fetchAdminTemplateCategories(includeArchived, signal)"
    );
    expect(hubSource).toContain(
      "queryFn: ({ signal }) => fetchAdminTemplatesAnalyticsOverview(query, signal)"
    );
  });

  it("aborts template editor/test page manual loads and polling", () => {
    const editorSource = readSource("components/templates/use-template-editor-controller.ts");
    const testPageSource = readSource("components/templates/template-test-page.tsx");
    const analyticsPageSource = readSource("components/templates/template-analytics-page.tsx");

    expect(editorSource).toContain("const controller = new AbortController();");
    expect(editorSource).toContain("fetchAdminTemplate(initialTemplateId, controller.signal)");
    expect(editorSource).toContain("controller.abort();");
    expect(testPageSource).toContain("fetchAdminTemplate(templateId, controller.signal)");
    expect(testPageSource).toContain("fetchAdminTemplateTestHistory(");
    expect(testPageSource).toContain("controller.signal");
    expect(testPageSource).toContain("fetchAdminTemplateTest(run.generationId, controller.signal)");
    expect(testPageSource).toContain("controller.abort();");
    expect(analyticsPageSource).toContain("recentRunsAbortControllerRef.current?.abort()");
    expect(analyticsPageSource).toContain("fetchAdminTemplateRecentGenerations(");
    expect(analyticsPageSource).toContain("controller.signal");
  });
});
