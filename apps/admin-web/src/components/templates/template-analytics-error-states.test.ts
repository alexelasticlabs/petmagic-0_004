import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const templateAnalyticsPagePath = fileURLToPath(
  new URL("./template-analytics-page.tsx", import.meta.url)
);
const templatesAnalyticsHubPagePath = fileURLToPath(
  new URL("./templates-analytics-hub-page.tsx", import.meta.url)
);
const overviewHookPath = fileURLToPath(
  new URL("./use-admin-template-analytics-overview.ts", import.meta.url)
);
const catalogHookPath = fileURLToPath(new URL("./use-admin-template-catalog.ts", import.meta.url));
const categoriesHookPath = fileURLToPath(
  new URL("./use-admin-template-categories.ts", import.meta.url)
);
const optionsHookPath = fileURLToPath(new URL("./use-admin-template-options.ts", import.meta.url));
const detailSectionsPath = fileURLToPath(
  new URL("./template-analytics-detail-sections.tsx", import.meta.url)
);
const feedbackHookPath = fileURLToPath(new URL("./use-admin-template-feedback.ts", import.meta.url));

describe("template analytics error states", () => {
  it("keeps template analytics detail and hub failures retryable", () => {
    const detailSource = readFileSync(templateAnalyticsPagePath, "utf8");
    const hubSource = readFileSync(templatesAnalyticsHubPagePath, "utf8");
    const overviewHookSource = readFileSync(overviewHookPath, "utf8");

    expect(overviewHookSource).toContain("isFetching: primaryQuery.isFetching || secondaryQuery.isFetching");

    expect(detailSource).toContain("title={error ?? text.loadError}");
    expect(detailSource).toContain("disabled={!session || isFetching}");
    expect(detailSource).toContain(
      "if (!session) {\n                  return;\n                }\n\n                void refresh().catch(() => undefined);"
    );
    expect(detailSource).toContain("{text.retryAction}");

    expect(hubSource).toContain("title={error ?? text.loadError}");
    expect(hubSource).toContain("disabled={!session || overviewQuery.isFetching}");
    expect(hubSource).toContain(
      "if (!session) {\n                  return;\n                }\n\n                void overviewQuery.refetch().catch(() => undefined);"
    );
    expect(hubSource).toContain("{text.retryAction}");
  });

  it("bounds template feedback search through UI state and query keys", () => {
    const pageSource = readFileSync(templateAnalyticsPagePath, "utf8");
    const detailSectionsSource = readFileSync(detailSectionsPath, "utf8");
    const feedbackHookSource = readFileSync(feedbackHookPath, "utf8");

    expect(pageSource).toContain("TEMPLATE_FEEDBACK_SEARCH_MAX_LENGTH,");
    expect(pageSource).toContain(
      "feedbackSearchInput.trim().slice(0, TEMPLATE_FEEDBACK_SEARCH_MAX_LENGTH)"
    );
    expect(pageSource).toContain(
      "setFeedbackSearchInput(value.slice(0, TEMPLATE_FEEDBACK_SEARCH_MAX_LENGTH))"
    );
    expect(detailSectionsSource).toContain("maxLength={TEMPLATE_FEEDBACK_SEARCH_MAX_LENGTH}");
    expect(detailSectionsSource).toContain(
      "event.target.value.slice(0, TEMPLATE_FEEDBACK_SEARCH_MAX_LENGTH)"
    );
    expect(feedbackHookSource).toContain(
      "const normalizedSearch = search.trim().slice(0, TEMPLATE_FEEDBACK_SEARCH_MAX_LENGTH);"
    );
    expect(feedbackHookSource).toContain(
      "adminQueryKeys.templateAnalyticsFeedback(templateId, filter, normalizedSearch)"
    );
    expect(feedbackHookSource).toContain("search: normalizedSearch || undefined");
    expect(pageSource).not.toContain("setFeedbackSearch(feedbackSearchInput.trim());");
    expect(pageSource).not.toContain("onFeedbackSearchChange={setFeedbackSearchInput}");
    expect(detailSectionsSource).not.toContain("onFeedbackSearchChange(event.target.value)");
  });

  it("keeps template manual refresh paths disabled until auth session is restored", () => {
    const overviewHookSource = readFileSync(overviewHookPath, "utf8");
    const catalogHookSource = readFileSync(catalogHookPath, "utf8");
    const categoriesHookSource = readFileSync(categoriesHookPath, "utf8");
    const optionsHookSource = readFileSync(optionsHookPath, "utf8");

    expect(overviewHookSource).toContain(
      "if (!enabled) {\n        return;\n      }\n\n      await Promise.all([primaryQuery.refetch(), secondaryQuery.refetch()]);"
    );
    expect(catalogHookSource).toContain(
      "if (!enabled) {\n      return templatesQuery;\n    }\n\n    const templatesResult = await templatesQuery.refetch();"
    );
    expect(optionsHookSource).toContain(
      "if (!enabled) {\n      return templatesQuery;\n    }\n\n    const result = await templatesQuery.refetch();"
    );
    expect(categoriesHookSource).toContain(
      "if (!enabled) {\n      return categoriesQuery;\n    }\n\n    return categoriesQuery.refetch();"
    );
    expect(categoriesHookSource).not.toContain("refresh: categoriesQuery.refetch");
  });

  it("keeps manual recent-run expansion disabled until auth session is restored", () => {
    const pageSource = readFileSync(templateAnalyticsPagePath, "utf8");
    const detailSectionsSource = readFileSync(detailSectionsPath, "utf8");

    expect(pageSource).toContain("canLoadRecentRuns={Boolean(session)}");
    expect(pageSource).toContain(
      "if (!session) {\n      recentRunsAbortControllerRef.current?.abort();\n      setIsRecentRunsLoading(false);\n      setRecentRunsMode(\"latest\");\n      return;\n    }"
    );
    expect(detailSectionsSource).toContain("canLoadRecentRuns: boolean;");
    expect(detailSectionsSource).toContain("disabled={isLoading || !canLoadRecentRuns}");
    expect(pageSource).not.toContain(
      "setRecentRunsMode(mode);\n    if (allRecentRuns || isRecentRunsLoading || !canShowAllRecentRuns)"
    );
  });
});
