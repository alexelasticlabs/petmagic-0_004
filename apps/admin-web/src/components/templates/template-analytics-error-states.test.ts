import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import { readTemplatesAnalyticsHubPageLibrarySource } from "./templates-analytics-hub-page.test-source";

const templateAnalyticsPagePath = fileURLToPath(
  new URL("./template-analytics-page.tsx", import.meta.url)
);
const templateAnalyticsStylesPath = fileURLToPath(
  new URL("./template-analytics-page.module.css", import.meta.url)
);
const templateAnalyticsCopyPath = fileURLToPath(
  new URL("./template-analytics-copy.ts", import.meta.url)
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
const feedbackHookPath = fileURLToPath(
  new URL("./use-admin-template-feedback.ts", import.meta.url)
);
const analyticsUtilsPath = fileURLToPath(new URL("./template-analytics-utils.ts", import.meta.url));

describe("template analytics error states", () => {
  it("keeps detail recent-runs tables scrollable inside narrow layouts", () => {
    const stylesSource = readFileSync(templateAnalyticsStylesPath, "utf8");

    expect(stylesSource).toContain(".tableWrap {\n  position: relative;");
    expect(stylesSource).toContain("width: 100%;");
    expect(stylesSource).toContain("min-width: 0;");
    expect(stylesSource).toContain("overflow-x: auto;");
    expect(stylesSource).toContain("overscroll-behavior-inline: contain;");
    expect(stylesSource).toContain("scrollbar-width: thin;");
    expect(stylesSource).toContain(".tableWrap::-webkit-scrollbar");
    expect(stylesSource).toContain(".recentTable {\n  width: 100%;\n  min-width: 61rem;");
  });

  it("keeps template analytics detail and hub failures retryable", () => {
    const detailSource = readFileSync(templateAnalyticsPagePath, "utf8");
    const copySource = readFileSync(templateAnalyticsCopyPath, "utf8");
    const hubSource = readTemplatesAnalyticsHubPageLibrarySource();
    const overviewHookSource = readFileSync(overviewHookPath, "utf8");

    expect(overviewHookSource).toContain(
      "isFetching: primaryQuery.isFetching || secondaryQuery.isFetching"
    );

    expect(detailSource).toContain(
      'import { getTemplateAnalyticsCopy } from "@/components/templates/template-analytics-copy";'
    );
    expect(detailSource).toContain(
      "const text = useMemo(() => getTemplateAnalyticsCopy(locale), [locale]);"
    );
    expect(copySource).toContain("const templateAnalyticsCopy = {");
    expect(copySource).toContain('pageTitle: "Аналитика"');
    expect(copySource).toContain('pageTitle: "Analytics"');
    expect(copySource).toContain("export type TemplateAnalyticsCopy = {");
    expect(copySource).toContain("return templateAnalyticsCopy[locale] as TemplateAnalyticsCopy;");
    expect(copySource).not.toContain('const isRu = locale === "ru";');
    expect(copySource).not.toContain('pageTitle: isRu ? "Аналитика" : "Analytics"');

    expect(detailSource).toContain("title={error ?? text.loadError}");
    expect(detailSource).toContain(
      'const canViewTemplateAnalytics =\n    sessionRoles.includes("Admin") || sessionRoles.includes("Moderator");'
    );
    expect(detailSource).toContain("enabled: canViewTemplateAnalytics");
    expect(detailSource).toContain("ensureAdminSession(locale, router);");
    expect(detailSource).toContain("disabled={!canViewTemplateAnalytics || isFetching}");
    expect(detailSource).toContain("function requestAnalyticsRetry()");
    expect(detailSource).toContain(
      "if (!canViewTemplateAnalytics || isFetching) {\n      return;\n    }"
    );
    expect(detailSource).toContain("onClick={requestAnalyticsRetry}");
    expect(detailSource).not.toContain(
      "onClick={() => {\n                if (!canViewTemplateAnalytics)"
    );
    expect(detailSource).toContain("{text.retryAction}");
    expect(detailSource).toContain(
      'clientLogger.warn("templates.analytics_recent_runs_load_failed"'
    );
    expect(detailSource).toContain("templateId: sanitizeSensitiveText(templateId, 80)");
    expect(detailSource).toContain(
      'errorName: error instanceof Error ? error.name : "UnknownError"'
    );
    expect(detailSource).not.toContain("error,");

    expect(hubSource).toContain(
      "const isOverviewRefreshing = overviewQuery.isFetching && overviewQuery.isPlaceholderData;"
    );
    expect(hubSource).toContain(
      "const overview = overviewQuery.isPlaceholderData ? null : (overviewQuery.data ?? null);"
    );
    expect(hubSource).toContain(
      "const isLoading = (overviewQuery.isPending && !overview) || isOverviewRefreshing;"
    );
    expect(hubSource).toContain("const hasBlockingError = overviewQuery.isError && !overview;");
    expect(hubSource).toContain(
      "const hasPartialError = overviewQuery.isError && Boolean(overview);"
    );
    expect(hubSource).toContain('clientLogger.error("templates.analytics_hub_load_failed"');
    expect(hubSource).toContain("query: sanitizeTemplatesAnalyticsQueryForExport(query)");
    expect(hubSource).toContain(
      'errorName: overviewQuery.error instanceof Error ? overviewQuery.error.name : "UnknownError"'
    );
    expect(hubSource).toContain('"digest" in overviewQuery.error');
    expect(hubSource).toContain("sanitizeSensitiveText(");
    expect(hubSource).toContain(
      'String((overviewQuery.error as { digest?: unknown }).digest ?? "")'
    );
    expect(hubSource).toContain("80");
    expect(hubSource).not.toContain("error: overviewQuery.error");
    expect(hubSource).not.toContain("message: overviewQuery.error");
    expect(hubSource).toContain("if (hasBlockingError || !overview)");
    expect(hubSource).toContain("title={text.loadError}");
    expect(hubSource).toContain("title={text.partialErrorTitle}");
    expect(hubSource).toContain("description={text.partialErrorDescription}");
    expect(hubSource).toContain(
      'const canViewTemplateAnalytics =\n    sessionRoles.includes("Admin") || sessionRoles.includes("Moderator");'
    );
    expect(hubSource).toContain("enabled: canViewTemplateAnalytics");
    expect(hubSource).toContain("ensureAdminSession(locale, router);");
    expect(hubSource).toContain("disabled={!canViewTemplateAnalytics || overviewQuery.isFetching}");
    expect(hubSource).toContain("const isHubControlsLocked = overviewQuery.isFetching;");
    expect(hubSource).toContain("disabled={isHubControlsLocked}");
    expect(hubSource).toContain("function requestOverviewRetry()");
    expect(hubSource).toContain(
      "if (!canViewTemplateAnalytics || overviewQuery.isFetching) {\n      return;\n    }"
    );
    expect(hubSource).toContain("onClick={requestOverviewRetry}");
    expect(hubSource).toContain("{text.retryAction}");
    expect(hubSource).not.toContain(
      "onClick={() => {\n                if (!canViewTemplateAnalytics)"
    );
  });

  it("sanitizes template analytics detail identifiers and feedback summary labels", () => {
    const pageSource = readFileSync(templateAnalyticsPagePath, "utf8");
    const copySource = readFileSync(templateAnalyticsCopyPath, "utf8");
    const utilsSource = readFileSync(analyticsUtilsPath, "utf8");

    expect(utilsSource).toContain(
      'const safeValue = sanitizeSensitiveText(value, 48).replace(/\\s/g, "");'
    );
    expect(utilsSource).toContain('return "-";');
    expect(utilsSource).toContain(
      "return safeValue.length > 13 ? `${safeValue.slice(0, 8)}...${safeValue.slice(-4)}` : safeValue;"
    );
    expect(utilsSource).not.toContain("return value.length > 13");
    expect(pageSource).toContain("title={text.feedbackSummaryTitle}");
    expect(pageSource).toContain("label: text.feedbackSummaryPositive,");
    expect(pageSource).toContain("label: text.feedbackSummaryNeutral,");
    expect(pageSource).toContain("label: text.feedbackSummaryNegative,");
    expect(pageSource).toContain("label: text.feedbackSummaryTopIssues,");
    expect(copySource).toContain('feedbackSummaryTitle: "Сводка feedback"');
    expect(copySource).toContain('feedbackSummaryTitle: "Feedback summary"');
    expect(copySource).toContain('feedbackSummaryPositive: "Позитив"');
    expect(copySource).toContain('feedbackSummaryNegative: "Negative"');
    expect(pageSource).toContain(
      ".map((issue) => `${sanitizeSensitiveText(issue.category, 80)}: ${issue.count}`)"
    );
    expect(pageSource).not.toContain('title={isRu ? "Сводка feedback" : "Feedback summary"}');
    expect(pageSource).not.toContain(".map((issue) => `${issue.category}: ${issue.count}`)");
  });

  it("keeps template analytics JSON exports stable after download clicks", () => {
    const detailSource = readFileSync(templateAnalyticsPagePath, "utf8");
    const hubSource = readTemplatesAnalyticsHubPageLibrarySource();

    for (const source of [detailSource, hubSource]) {
      expect(source).toContain("document.body.append(link);");
      expect(source).toContain("link.remove();");
      expect(source).toContain("window.setTimeout(() => URL.revokeObjectURL(url), 1000);");
      expect(source).not.toContain("link.click();\n    URL.revokeObjectURL(url);");
    }
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
    expect(overviewHookSource).toContain("hasPartialSecondaryFailure: hasRejectedResult(results),");
    expect(overviewHookSource).toContain(
      "eventAnalytics: readSettledValue(eventAnalytics, EMPTY_EVENT_ANALYTICS),"
    );
    expect(overviewHookSource).toContain(
      "failureBreakdown: readSettledValue(failureBreakdown, []),"
    );
    expect(overviewHookSource).toContain(
      "recentRunsPreview: readSettledValue(recentRunsPreview, []),"
    );
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
    expect(pageSource).toContain("disabled={!canViewTemplateAnalytics || isFetching}");
  });

  it("locks detail analytics toolbar controls during overview refreshes", () => {
    const pageSource = readFileSync(templateAnalyticsPagePath, "utf8");

    expect(pageSource).toContain(
      "const isAnalyticsToolbarLocked = isFetching || isSecondaryLoading;"
    );
    expect(pageSource).toContain("disabled={isAnalyticsToolbarLocked}");
    expect(pageSource).not.toContain("disabled={isSecondaryLoading}");
  });

  it("keeps template option lists visible during background refetches", () => {
    const optionsHookSource = readFileSync(optionsHookPath, "utf8");

    expect(optionsHookSource).toContain("isFetching: templatesQuery.isFetching,");
    expect(optionsHookSource).toContain("isLoading: templatesQuery.isLoading,");
    expect(optionsHookSource).not.toContain(
      "isLoading: templatesQuery.isLoading || templatesQuery.isFetching"
    );
  });

  it("does not expose stale template feedback rows while search or filters refresh", () => {
    const feedbackHookSource = readFileSync(feedbackHookPath, "utf8");

    expect(feedbackHookSource).toContain("import { keepPreviousData, useQuery }");
    expect(feedbackHookSource).toContain("placeholderData: keepPreviousData,");
    expect(feedbackHookSource).toContain(
      "const isRefreshingWithPlaceholder = feedbackQuery.isFetching && feedbackQuery.isPlaceholderData;"
    );
    expect(feedbackHookSource).toContain(
      "const visibleItems = feedbackQuery.isPlaceholderData ? [] : (feedbackQuery.data ?? []);"
    );
    expect(feedbackHookSource).toContain("isFetching: feedbackQuery.isFetching,");
    expect(feedbackHookSource).toContain(
      "isLoading: feedbackQuery.isLoading || isRefreshingWithPlaceholder,"
    );
    expect(feedbackHookSource).toContain("items: visibleItems,");
    expect(feedbackHookSource).not.toContain(
      "isLoading: feedbackQuery.isLoading || feedbackQuery.isFetching"
    );
    expect(feedbackHookSource).not.toContain("items: feedbackQuery.data ?? []");
  });

  it("keeps manual recent-run expansion disabled until auth session is restored", () => {
    const pageSource = readFileSync(templateAnalyticsPagePath, "utf8");
    const detailSectionsSource = readFileSync(detailSectionsPath, "utf8");

    expect(pageSource).toContain("canLoadRecentRuns={canViewTemplateAnalytics}");
    expect(pageSource).toContain(
      'if (!canViewTemplateAnalytics) {\n      recentRunsAbortControllerRef.current?.abort();\n      setIsRecentRunsLoading(false);\n      setRecentRunsMode("latest");\n      return;\n    }'
    );
    expect(detailSectionsSource).toContain("canLoadRecentRuns: boolean;");
    expect(detailSectionsSource).toContain(
      'disabled={mode === "latest" || isLoading || !canLoadRecentRuns}'
    );
    expect(detailSectionsSource).toContain(
      'disabled={mode === "all" || isLoading || !canLoadRecentRuns}'
    );
    expect(detailSectionsSource).toContain(
      'disabled={mode === "failed" || isLoading || !canLoadRecentRuns}'
    );
    expect(detailSectionsSource).not.toContain("disabled={isLoading || !canLoadRecentRuns}");
    expect(pageSource).not.toContain(
      "setRecentRunsMode(mode);\n    if (allRecentRuns || isRecentRunsLoading || !canShowAllRecentRuns)"
    );
  });

  it("clears expanded recent-run cache when the preview refreshes", () => {
    const pageSource = readFileSync(templateAnalyticsPagePath, "utf8");

    expect(pageSource).toContain(
      'const recentRunsPreviewSignature = useMemo(\n    () => recentRunsPreview.map((run) => run.generationId).join("|")'
    );
    expect(pageSource).toContain("recentRunsAbortControllerRef.current?.abort();");
    expect(pageSource).toContain("recentRunsAbortControllerRef.current = null;");
    expect(pageSource).toContain("queueMicrotask(() => {");
    expect(pageSource).toContain("setIsRecentRunsLoading(false);");
    expect(pageSource).toContain("setAllRecentRuns(null);");
    expect(pageSource).toContain("setRecentRunsError(null);");
    expect(pageSource).toContain(
      'setRecentRunsMode((current) => (current === "latest" ? current : "latest"));'
    );
    expect(pageSource).toContain("}, [recentRunsPreviewSignature]);");
  });
});
