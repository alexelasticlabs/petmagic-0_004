import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import { readTemplatesCatalogViewLibrarySource } from "./templates-catalog-view.test-source";

const catalogContentPath = fileURLToPath(
  new URL("./templates-catalog-view.content.ts", import.meta.url)
);
const catalogCssPath = fileURLToPath(new URL("./templates-catalog.module.css", import.meta.url));
const templatesApiClientPath = fileURLToPath(
  new URL("../../lib/api-client.templates.ts", import.meta.url)
);

describe("templates catalog actions", () => {
  it("confirms archive changes and sanitizes backend action errors", () => {
    const source = readTemplatesCatalogViewLibrarySource();
    const contentSource = readFileSync(catalogContentPath, "utf8");
    const styles = readFileSync(catalogCssPath, "utf8");

    expect(source).toContain("import { getAdminErrorMessage }");
    expect(source).toContain(
      'import { getTemplatesCatalogViewText } from "@/components/templates/templates-catalog-view.content";'
    );
    expect(source).toContain('} from "@/components/templates/templates-catalog-view.card";');
    expect(source).toContain("getTemplatesCatalogIntlLocale,");
    expect(source).toContain("type TemplatesCatalogViewText,");
    expect(source).toContain("const copy = useMemo(");
    expect(source).toContain("() => getTemplatesCatalogViewText(locale, templateType)");
    expect(source).not.toContain('const isRu = locale === "ru";');
    expect(contentSource).toContain("const templatesCatalogLocaleText = {");
    expect(contentSource).toContain(
      'templateActionsAdminOnly: "Управление шаблонами доступно только администратору."'
    );
    expect(contentSource.slice(0, contentSource.indexOf("  en: {"))).not.toContain("только Admin");
    expect(contentSource).toContain('sortNewestDescription: "Сначала свежие шаблоны"');
    expect(contentSource).toContain('tableTemplate: "Шаблон"');
    expect(contentSource).toContain("archiveConfirmDescription: (templateLabel: string) =>");
    expect(contentSource).toContain('retry: "Retry"');
    expect(contentSource).not.toContain('const isRu = locale === "ru";');

    expect(source).toContain("const isTemplateActionLocked = busyTemplateId !== null;");
    expect(source).toContain("isCatalogFetching,");
    expect(source).toContain("const isCatalogRefreshing = isCatalogFetching && !isLoading;");
    expect(source).toContain(
      "const isCatalogInteractionLocked = isTemplateActionLocked || isCatalogRefreshing;"
    );
    expect(source).toContain("if (isCatalogInteractionLocked) {\n      return false;");
    expect(source).toContain(
      "async function handleStatusChange(templateId: string, status: TemplateStatus): Promise<boolean>"
    );
    expect(source).toContain("async function handleDelete(templateId: string): Promise<boolean>");
    expect(source).toContain(
      "setActionError(getAdminErrorMessage(error, text.errorSavingTemplate))"
    );
    expect(source).toContain(
      "setActionError(getAdminErrorMessage(error, text.errorDeletingTemplate))"
    );
    expect(source).toContain("function getCatalogActionErrorDetails(error: unknown)");
    expect(source).toContain('errorName: error instanceof Error ? error.name : "UnknownError"');
    expect(source).toContain("templateId: sanitizeSensitiveText(templateId, 80)");
    expect(source).toContain("...getCatalogActionErrorDetails(error)");
    expect(source).toContain("function assertCanManageTemplates(): boolean");
    expect(source).toContain("setActionError(copy.templateActionsAdminOnly)");
    expect(source).toContain("{canManageTemplates ? (");
    expect(source).toContain("aria-pressed={showingArchived}");
    expect(source).toContain("onClick={onToggleArchive}");
    expect(source).toContain("if (!assertCanManageTemplates()) {\n      return false;");
    expect(source).toContain("if (!assertCanManageTemplates()) {\n      return;");
    expect(source).toContain("const [templatePendingArchiveId, setTemplatePendingArchiveId]");
    expect(source).toContain(
      "function requestStatusChange(templateId: string, status: TemplateStatus)"
    );
    expect(source).toContain("function requestDeleteTemplate(templateId: string)");
    expect(source).toContain("setTemplatePendingArchiveId(templateId)");
    expect(source).toContain("if (isCatalogInteractionLocked) {\n      return;\n    }");
    expect(source).toContain("setTemplatePendingDeleteId(templateId)");
    expect(source).toContain("open={templatePendingArchiveId !== null}");
    expect(source).toContain("const isBusy = isCatalogInteractionLocked;");
    expect(source).toContain("const isBusy = busyTemplateId !== null;");
    expect(source).toContain("isCatalogRefreshing ? (");
    expect(source).toContain(
      '<AdminStateCard tone="info" className={styles.empty} title={text.loading} />'
    );
    expect(source).toContain(
      'isCatalogInteractionLocked ? (busyTemplateId ?? "__refresh__") : null'
    );
    expect(source).toContain(
      "isSubmitting={Boolean(templatePendingArchiveId && isTemplateActionLocked)}"
    );
    expect(source).toContain(
      "isSubmitting={Boolean(templatePendingDeleteId && isTemplateActionLocked)}"
    );
    expect(source).toContain("if (!isTemplateActionLocked) {\n            onCancelArchive();");
    expect(source).toContain("if (!isTemplateActionLocked) {\n            onCancelDelete();");
    expect(source).toContain("function formatTemplateActionLabel(");
    expect(source).toContain("return sanitizeSensitiveText(template?.title ?? templateId, 96);");
    expect(source).toContain("function formatTemplateId(templateId: string, maxLength: number)");
    expect(source).toContain("ID: {formatTemplateId(template.templateId, 12)}");
    expect(source).toContain(
      'const canViewTemplates = sessionRoles.includes("Admin") || sessionRoles.includes("Moderator");'
    );
    expect(source).toContain("enabled: canViewTemplates");
    expect(source).toContain("ensureAdminSession(locale, router);");
    expect(source).toContain("if (!canViewTemplates || isLoading)");
    expect(source).toContain("disabled={!canViewTemplates || isFetching}");
    expect(source).toContain("function requestCatalogRetry()");
    expect(source).toContain("if (!canViewTemplates || isFetching) {\n      return;\n    }");
    expect(source).toContain("void refresh().catch(() => undefined);");
    expect(source).toContain("onClick={requestCatalogRetry}");
    expect(source).toContain("totalCount");
    expect(source).toContain("shownStart");
    expect(source).toContain("shownEnd");
    expect(source).toContain("hasSecondaryError,");
    expect(source).toContain("title={copy.analyticsUnavailableTitle}");
    expect(source).toContain("description={copy.analyticsUnavailableDescription}");
    expect(contentSource).toContain(
      'analyticsUnavailableTitle: "Метрики шаблонов временно недоступны"'
    );
    expect(contentSource).toContain(
      'videoDescription: "Каталог видео-шаблонов, статусы, категории и параметры доступа."'
    );
    expect(contentSource).toContain('qaOnlyLabel: "Только QA"');
    expect(contentSource.slice(0, contentSource.indexOf("  en: {"))).not.toContain("QA only");
    expect(contentSource.slice(0, contentSource.indexOf("  en: {"))).not.toContain(
      "motion-шаблонов"
    );
    expect(contentSource).toContain(
      'analyticsUnavailableDescription:\n      "The catalog is still available, but views, generations, and error metrics may be incomplete."'
    );
    expect(source).toContain("copy.pageSummary(currentPage, shownStart, shownEnd, totalCount)");
    expect(contentSource).toContain(
      "pageSummary: (currentPage: number, shownStart: number, shownEnd: number, totalCount: number) =>"
    );
    expect(source).toContain("currentPage >= totalPages");
    expect(source).toContain("if (!isFetching && currentPage > totalPages)");
    expect(source).toContain("let isActive = true;");
    expect(source).toContain("if (isActive) {\n          resetCatalogContext(totalPages);");
    expect(source).toContain("}, [currentPage, isFetching, resetCatalogContext, totalPages]);");
    expect(source).toContain("const resetPendingTemplateAction = useCallback(() => {");
    expect(source).toContain(
      "if (isTemplateActionLocked) {\n      return;\n    }\n\n    setTemplatePendingArchiveId(null);\n    setTemplatePendingDeleteId(null);"
    );
    expect(source).toContain("const resetCatalogContext = useCallback(");
    expect(source).toContain("resetPendingTemplateAction();\n      setPage(nextPage);");
    expect(source).toContain("resetCatalogContext();");
    expect(source).toContain(
      "const visibleTemplateIds = useMemo(\n    () => new Set(templates.map((template) => template.templateId)),"
    );
    expect(source).toContain(
      "templatePendingArchiveId !== null && !visibleTemplateIds.has(templatePendingArchiveId)"
    );
    expect(source).toContain(
      "templatePendingDeleteId !== null && !visibleTemplateIds.has(templatePendingDeleteId)"
    );
    expect(source).toContain("queueMicrotask(() => {");
    expect(source).toContain("if (!isActive) {\n        return;\n      }");
    expect(source).toContain("setTemplatePendingArchiveId(null);");
    expect(source).toContain("setTemplatePendingDeleteId(null);");
    expect(source).toContain("onClick={() => resetCatalogContext(Math.max(1, currentPage - 1))}");
    expect(source).toContain("resetCatalogContext(nextPage);");
    expect(source).toContain("onClick={() => resetCatalogContext(currentPage + 1)}");
    expect(source).toContain('showingArchived={archiveFilter === "archived"}');
    expect(source).toContain("onToggleArchive={toggleArchiveFilter}");
    expect(source).toContain('aria-pressed={viewMode === "cards"}');
    expect(source).toContain('aria-pressed={viewMode === "list"}');
    expect(source).toContain("const TEMPLATE_CATALOG_SEARCH_MAX_LENGTH = 120;");
    expect(source).toContain(
      "setSearch(event.target.value.slice(0, TEMPLATE_CATALOG_SEARCH_MAX_LENGTH))"
    );
    expect(source).toContain("maxLength={TEMPLATE_CATALOG_SEARCH_MAX_LENGTH}");
    expect(source).toContain("disabled={isCatalogInteractionLocked}");
    expect(source).toContain("onChange={(value) => {");
    expect(source).toContain(
      "`${templateBasePath}/analytics/${encodeURIComponent(template.templateId)}`"
    );
    expect(source).toContain(
      "`${templateBasePath}/editor?templateId=${encodeURIComponent(template.templateId)}`"
    );
    expect(source).toContain(
      "`${templateBasePath}/test/${encodeURIComponent(template.templateId)}`"
    );
    expect(source).toContain("<AdminActionMenu");
    expect(source).toContain("className={styles.cardActionMenu}");
    expect(styles).toContain("grid-template-columns: repeat(3, minmax(0, 1fr))");
    expect(styles).toContain("overflow: visible;");
    expect(styles).toContain('.cardActionMenu [role="menu"]');
    expect(source).toContain("className={`${styles.tablePrimaryAction}");
    expect(source).toContain('isBusy ? ` ${styles.cardActionIconButtonDisabled}` : ""');
    expect(source).toContain("aria-disabled={isBusy}");
    expect(source).toContain("tabIndex={isBusy ? -1 : undefined}");
    expect(source).toContain("event.preventDefault();");
    expect(styles).toContain(".cardActionIconButtonDisabled,");
    expect(styles).toContain('.cardActionIconButton[aria-disabled="true"]');
    expect(styles).toContain("pointer-events: none;");
    expect(source).toContain("value: formatAnalyticsInteger(analytics?.views, locale),");
    expect(source).toContain("value: formatAnalyticsInteger(analytics?.generationStarts, locale),");
    expect(source).toContain(
      "value: formatAnalyticsInteger(analytics?.failedGenerations, locale),"
    );
    expect(source).toContain("new Intl.NumberFormat(getTemplatesCatalogIntlLocale(locale))");
    expect(source).toContain("formatPercentMetric(");
    expect(source).toContain("analytics?.generationStarts ? analytics.conversionPercent : null,");
    expect(source).toContain("locale");
    expect(source).toContain("formatPercentMetric(getSuccessRatePercent(analytics), locale)");
    expect(source).toContain("{formatAnalyticsInteger(analytics?.views, locale)}");
    expect(source).toContain("{formatAnalyticsInteger(analytics?.generationStarts, locale)}");
    expect(source).toContain("{formatAnalyticsInteger(template.tokenCost, locale)}");
    expect(source).toContain(
      'void handleStatusChange(templatePendingArchiveId, "Archived").then((succeeded) => {'
    );
    expect(source).toContain("if (succeeded) {\n              setTemplatePendingArchiveId(null);");
    expect(source).toContain("void handleDelete(templatePendingDeleteId).then((succeeded) => {");
    expect(source).toContain("if (succeeded) {\n              setTemplatePendingDeleteId(null);");
    expect(source).not.toContain("ID: {template.templateId.slice(0, 12)}");
    expect(source).not.toContain(
      "templates.find((template) => template.templateId === templatePendingArchiveId)?.title ?? templatePendingArchiveId"
    );
    expect(source).not.toContain(
      "templates.find((template) => template.templateId === templatePendingDeleteId)?.title ?? templatePendingDeleteId"
    );
    expect(source).not.toContain("onDeleteTemplate={setTemplatePendingDeleteId}");
    expect(source).not.toContain("onClick={() => setTemplatePendingDeleteId(template.templateId)}");
    expect(source).not.toContain("setTemplatePendingArchiveId(template.templateId)");
    expect(source).not.toContain("if (busyTemplateId === templateId) {\n      return false;");
    expect(source).not.toContain("if (busyTemplateId === templateId) {\n      return;");
    expect(source).not.toContain("isSubmitting={templatePendingArchiveId === busyTemplateId}");
    expect(source).not.toContain("isSubmitting={templatePendingDeleteId === busyTemplateId}");
    expect(source).not.toContain("href={`${templateBasePath}/analytics/${template.templateId}`}");
    expect(source).not.toContain(
      "href={`${templateBasePath}/editor?templateId=${template.templateId}`}"
    );
    expect(source).not.toContain("href={`${templateBasePath}/test/${template.templateId}`}");
    expect(source).not.toContain("value: formatAnalyticsInteger(analytics?.views ?? 0)");
    expect(source).not.toContain("value: formatAnalyticsInteger(analytics?.generationStarts ?? 0)");
    expect(source).not.toContain(
      "value: formatAnalyticsInteger(analytics?.failedGenerations ?? 0)"
    );
    expect(source).not.toContain(
      'new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US").format(value)'
    );
    expect(source).not.toContain("return `${value.toFixed(1)}%`;");
    expect(source).not.toContain("setActionError(text.errorSavingTemplate);");
    expect(source).not.toContain("setActionError(text.errorDeletingTemplate);");
    expect(source).not.toContain("error,\n      });");
    expect(source).not.toContain("templateId,\n        status,\n        error");
  });

  it("does not expose bulk template status changes before SSE batching is implemented", () => {
    const catalogSource = readTemplatesCatalogViewLibrarySource();
    const apiClientSource = readFileSync(templatesApiClientPath, "utf8");

    expect(catalogSource).not.toContain("bulk");
    expect(catalogSource).not.toContain("selectedTemplateIds");
    expect(catalogSource).not.toContain("Promise.all(templates.map");
    expect(apiClientSource).toContain("export async function changeTemplateStatus(");
    expect(apiClientSource).toContain("`/api/admin/templates/${encodedTemplateId}/status`");
    expect(apiClientSource).not.toContain("/api/admin/templates/bulk");
    expect(apiClientSource).not.toContain("changeTemplateStatuses");
  });
});
