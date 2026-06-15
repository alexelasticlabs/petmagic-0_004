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

    expect(hubSource).toContain("const hasBlockingError = overviewQuery.isError && !overview;");
    expect(hubSource).toContain("const hasPartialError = overviewQuery.isError && Boolean(overview);");
    expect(hubSource).toContain("if (hasBlockingError || !overview)");
    expect(hubSource).toContain("title={text.loadError}");
    expect(hubSource).toContain("title={text.partialErrorTitle}");
    expect(hubSource).toContain("description={text.partialErrorDescription}");
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
    expect(feedbackHookSource).toContain("placeholderData: keepPreviousData,");
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
      "if (!enabled) {\n        return;\n      }\n\n      const primaryResult = await primaryQuery.refetch();"
    );
    expect(overviewHookSource).toContain("if (primaryResult.isError) {\n        return;\n      }");
    expect(overviewHookSource).toContain("await secondaryQuery.refetch();");
    expect(overviewHookSource).not.toContain(
      "await Promise.all([primaryQuery.refetch(), secondaryQuery.refetch()]);"
    );
    expect(catalogHookSource).toContain(
      "if (!enabled) {\n      return templatesQuery;\n    }\n\n    const templatesResult = await templatesQuery.refetch();"
    );
    expect(catalogHookSource).toContain(
      "void analyticsRowsQuery.refetch().catch(() => undefined);"
    );
    expect(catalogHookSource).not.toContain("await analyticsRowsQuery.refetch();");
    expect(optionsHookSource).toContain(
      "if (!enabled) {\n      return templatesQuery;\n    }\n\n    const result = await templatesQuery.refetch();"
    );
    expect(categoriesHookSource).toContain(
      "if (!enabled) {\n      return categoriesQuery;\n    }\n\n    return categoriesQuery.refetch();"
    );
    expect(categoriesHookSource).not.toContain("refresh: categoriesQuery.refetch");
  });

  it("keeps template analytics secondary widgets partially recoverable", () => {
    const overviewHookSource = readFileSync(overviewHookPath, "utf8");
    const pageSource = readFileSync(templateAnalyticsPagePath, "utf8");

    expect(overviewHookSource).toContain("const results = await Promise.allSettled([");
    expect(overviewHookSource).toContain(
      "hasPartialSecondaryFailure: hasRejectedResult(results),"
    );
    expect(overviewHookSource).toContain(
      "eventAnalytics: readSettledValue(eventAnalytics, EMPTY_EVENT_ANALYTICS),"
    );
    expect(overviewHookSource).toContain("failureBreakdown: readSettledValue(failureBreakdown, []),");
    expect(overviewHookSource).toContain("recentRunsPreview: readSettledValue(recentRunsPreview, []),");
    expect(overviewHookSource).toContain("trendPoints: readSettledValue(trendPoints, []),");
    expect(overviewHookSource).toContain(
      "hasSecondaryPartialError: secondaryQuery.data?.hasPartialSecondaryFailure ?? false,"
    );
    expect(overviewHookSource).not.toContain(
      "const [trendPoints, recentRunsPreview, failureBreakdown, eventAnalytics] = await Promise.all(["
    );

    expect(pageSource).toContain("hasSecondaryPartialError,");
    expect(pageSource).toContain("{hasSecondaryPartialError ? (");
    expect(pageSource).toContain("title={text.secondaryPartialErrorTitle}");
    expect(pageSource).toContain("description={text.secondaryPartialErrorDescription}");
    expect(pageSource).toContain("disabled={!session || isFetching}");
  });

  it("keeps template option lists visible during background refetches", () => {
    const optionsHookSource = readFileSync(optionsHookPath, "utf8");

    expect(optionsHookSource).toContain("isFetching: templatesQuery.isFetching,");
    expect(optionsHookSource).toContain("isLoading: templatesQuery.isLoading,");
    expect(optionsHookSource).not.toContain(
      "isLoading: templatesQuery.isLoading || templatesQuery.isFetching"
    );
  });

  it("keeps template feedback results visible during background refetches", () => {
    const feedbackHookSource = readFileSync(feedbackHookPath, "utf8");

    expect(feedbackHookSource).toContain("import { keepPreviousData, useQuery }");
    expect(feedbackHookSource).toContain("placeholderData: keepPreviousData,");
    expect(feedbackHookSource).toContain("isFetching: feedbackQuery.isFetching,");
    expect(feedbackHookSource).toContain("isLoading: feedbackQuery.isLoading,");
    expect(feedbackHookSource).not.toContain(
      "isLoading: feedbackQuery.isLoading || feedbackQuery.isFetching"
    );
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
