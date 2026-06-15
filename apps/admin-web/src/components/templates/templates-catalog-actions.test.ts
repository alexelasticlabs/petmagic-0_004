import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const catalogViewPath = fileURLToPath(new URL("./templates-catalog-view.tsx", import.meta.url));
const catalogCssPath = fileURLToPath(new URL("./templates-catalog.module.css", import.meta.url));

describe("templates catalog actions", () => {
  it("confirms archive changes and sanitizes backend action errors", () => {
    const source = readFileSync(catalogViewPath, "utf8");
    const styles = readFileSync(catalogCssPath, "utf8");

    expect(source).toContain("import { getAdminErrorMessage }");
    expect(source).toContain("const isTemplateActionLocked = busyTemplateId !== null;");
    expect(source).toContain("if (isTemplateActionLocked) {\n      return false;");
    expect(source).toContain("async function handleStatusChange(templateId: string, status: TemplateStatus): Promise<boolean>");
    expect(source).toContain("async function handleDelete(templateId: string): Promise<boolean>");
    expect(source).toContain("setActionError(getAdminErrorMessage(error, text.errorSavingTemplate))");
    expect(source).toContain("setActionError(getAdminErrorMessage(error, text.errorDeletingTemplate))");
    expect(source).toContain("function assertCanManageTemplates(): boolean");
    expect(source).toContain("setActionError(copy.templateActionsAdminOnly)");
    expect(source).toContain("if (!assertCanManageTemplates()) {\n      return false;");
    expect(source).toContain("if (!assertCanManageTemplates()) {\n      return;");
    expect(source).toContain("const [templatePendingArchiveId, setTemplatePendingArchiveId]");
    expect(source).toContain("function requestStatusChange(templateId: string, status: TemplateStatus)");
    expect(source).toContain("function requestDeleteTemplate(templateId: string)");
    expect(source).toContain("setTemplatePendingArchiveId(templateId)");
    expect(source).toContain("if (isTemplateActionLocked) {\n      return;\n    }");
    expect(source).toContain("setTemplatePendingDeleteId(templateId)");
    expect(source).toContain("open={templatePendingArchiveId !== null}");
    expect(source).toContain("const isBusy = isTemplateActionLocked;");
    expect(source).toContain("const isBusy = busyTemplateId !== null;");
    expect(source).toContain("isSubmitting={Boolean(templatePendingArchiveId && isTemplateActionLocked)}");
    expect(source).toContain("isSubmitting={Boolean(templatePendingDeleteId && isTemplateActionLocked)}");
    expect(source).toContain("if (!isTemplateActionLocked) {\n            setTemplatePendingArchiveId(null);");
    expect(source).toContain("if (!isTemplateActionLocked) {\n            setTemplatePendingDeleteId(null);");
    expect(source).toContain("function formatTemplateActionLabel(");
    expect(source).toContain("return sanitizeSensitiveText(template?.title ?? templateId, 96);");
    expect(source).toContain("function formatTemplateId(templateId: string, maxLength: number)");
    expect(source).toContain("ID: {formatTemplateId(template.templateId, 12)}");
    expect(source).toContain("if (!session || isLoading)");
    expect(source).toContain("disabled={!session || isFetching}");
    expect(source).toContain(
      "if (!session) {\n                  return;\n                }\n\n                void refresh().catch(() => undefined);"
    );
    expect(source).toContain("totalCount");
    expect(source).toContain("shownStart");
    expect(source).toContain("shownEnd");
    expect(source).toContain("hasSecondaryError,");
    expect(source).toContain("title={copy.analyticsUnavailableTitle}");
    expect(source).toContain("description={copy.analyticsUnavailableDescription}");
    expect(source).toContain("analyticsUnavailableTitle:");
    expect(source).toContain("analyticsUnavailableDescription:");
    expect(source).toContain("Page ${currentPage}: showing ${shownStart}-${shownEnd} of ${totalCount}");
    expect(source).toContain("currentPage >= totalPages");
    expect(source).toContain("if (!isFetching && currentPage > totalPages)");
    expect(source).toContain("queueMicrotask(() => setPage(totalPages));");
    expect(source).toContain("}, [currentPage, isFetching, totalPages]);");
    expect(source).toContain("const TEMPLATE_CATALOG_SEARCH_MAX_LENGTH = 120;");
    expect(source).toContain(
      "setSearch(event.target.value.slice(0, TEMPLATE_CATALOG_SEARCH_MAX_LENGTH))"
    );
    expect(source).toContain("maxLength={TEMPLATE_CATALOG_SEARCH_MAX_LENGTH}");
    expect(source).toContain("href={`${analyticsBasePath}/${encodeURIComponent(template.templateId)}`}");
    expect(source).toContain(
      "href={`${editorBasePath}?templateId=${encodeURIComponent(template.templateId)}`}"
    );
    expect(source).toContain("href={`${testBasePath}/${encodeURIComponent(template.templateId)}`}");
    expect(source).toContain("isBusy ? ` ${styles.cardActionIconButtonDisabled}` : \"\"");
    expect(source).toContain("aria-disabled={isBusy}");
    expect(source).toContain("tabIndex={isBusy ? -1 : undefined}");
    expect(source).toContain("event.preventDefault();");
    expect(styles).toContain(".cardActionIconButtonDisabled,");
    expect(styles).toContain('.cardActionIconButton[aria-disabled="true"]');
    expect(styles).toContain("pointer-events: none;");
    expect(source).toContain("value: formatAnalyticsInteger(analytics?.views, locale),");
    expect(source).toContain("value: formatAnalyticsInteger(analytics?.generationStarts, locale),");
    expect(source).toContain("value: formatAnalyticsInteger(analytics?.failedGenerations, locale),");
    expect(source).toContain('new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US")');
    expect(source).toContain("formatPercentMetric(\n                              analytics?.generationStarts ? analytics.conversionPercent : null,\n                              locale");
    expect(source).toContain("formatPercentMetric(getSuccessRatePercent(analytics), locale)");
    expect(source).toContain("{formatAnalyticsInteger(analytics?.views, locale)}");
    expect(source).toContain("{formatAnalyticsInteger(analytics?.generationStarts, locale)}");
    expect(source).toContain("{formatAnalyticsInteger(template.tokenCost, locale)}");
    expect(source).toContain("void handleStatusChange(templatePendingArchiveId, \"Archived\").then((succeeded) => {");
    expect(source).toContain("if (succeeded) {\n              setTemplatePendingArchiveId(null);");
    expect(source).toContain("void handleDelete(templatePendingDeleteId).then((succeeded) => {");
    expect(source).toContain("if (succeeded) {\n              setTemplatePendingDeleteId(null);");
    expect(source).not.toContain("ID: {template.templateId.slice(0, 12)}");
    expect(source).not.toContain("templates.find((template) => template.templateId === templatePendingArchiveId)?.title ?? templatePendingArchiveId");
    expect(source).not.toContain("templates.find((template) => template.templateId === templatePendingDeleteId)?.title ?? templatePendingDeleteId");
    expect(source).not.toContain("onDeleteTemplate={setTemplatePendingDeleteId}");
    expect(source).not.toContain("onClick={() => setTemplatePendingDeleteId(template.templateId)}");
    expect(source).not.toContain("setTemplatePendingArchiveId(template.templateId)");
    expect(source).not.toContain("if (busyTemplateId === templateId) {\n      return false;");
    expect(source).not.toContain("if (busyTemplateId === templateId) {\n      return;");
    expect(source).not.toContain("isSubmitting={templatePendingArchiveId === busyTemplateId}");
    expect(source).not.toContain("isSubmitting={templatePendingDeleteId === busyTemplateId}");
    expect(source).not.toContain("href={`${analyticsBasePath}/${template.templateId}`}");
    expect(source).not.toContain("href={`${editorBasePath}?templateId=${template.templateId}`}");
    expect(source).not.toContain("href={`${testBasePath}/${template.templateId}`}");
    expect(source).not.toContain("value: formatAnalyticsInteger(analytics?.views ?? 0)");
    expect(source).not.toContain("value: formatAnalyticsInteger(analytics?.generationStarts ?? 0)");
    expect(source).not.toContain("value: formatAnalyticsInteger(analytics?.failedGenerations ?? 0)");
    expect(source).not.toContain('new Intl.NumberFormat("ru-RU").format(value)');
    expect(source).not.toContain("return `${value.toFixed(1)}%`;");
    expect(source).not.toContain("setActionError(text.errorSavingTemplate);");
    expect(source).not.toContain("setActionError(text.errorDeletingTemplate);");
  });
});
