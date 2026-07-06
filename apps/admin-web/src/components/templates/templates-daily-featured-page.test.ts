import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

import { readTemplatesDailyFeaturedPageLibrarySource } from "./templates-daily-featured-page.test-source";

const pageSource = readTemplatesDailyFeaturedPageLibrarySource();
const contentSource = readFileSync(
  new URL("./templates-daily-featured-page.content.ts", import.meta.url),
  "utf8"
);
const ruContentSource = contentSource.slice(0, contentSource.indexOf("  en: {"));
const stylesSource = readFileSync(
  new URL("./templates-daily-featured-page.module.css", import.meta.url),
  "utf8"
);

describe("templates daily featured page", () => {
  it("keeps the daily featured screen aligned with AdminOnly backend endpoints", () => {
    expect(pageSource).toContain('import { useRouter } from "next/navigation";');
    expect(pageSource).toContain(
      'import { ensureAdminSession } from "@/components/admin/admin-session";'
    );
    expect(pageSource).toContain("const router = useRouter();");
    expect(pageSource).toContain('ensureAdminSession(locale, router, { requiredRole: "Admin" });');
    expect(pageSource).toContain('session?.user.roles.includes("Admin") ?? false');
    expect(pageSource).toContain("if (!canManageTemplates) {\n        setTemplates([]);");
    expect(pageSource).toContain(
      "if (!canManageTemplates) {\n        setIsScheduleLoading(false);"
    );
    expect(pageSource).toContain("disabled={!canManageTemplates || isActionLocked}");
  });

  it("uses the admin design system instead of inline layout styles", () => {
    expect(pageSource).toContain(
      'import styles from "@/components/templates/templates-daily-featured-page.module.css"'
    );
    expect(pageSource).not.toContain("type CSSProperties");
    expect(pageSource).not.toContain("style={");
    expect(stylesSource).toContain("var(--surface-1)");
    expect(stylesSource).toContain("@media (max-width: 640px)");
  });

  it("keeps the storefront preview overlay theme-aware", () => {
    expect(stylesSource).toContain(".previewOverlay {");
    expect(stylesSource).toContain(".previewEmpty {");
    expect(stylesSource).toContain("color-mix(in srgb, var(--surface-2) 94%, var(--surface-1))");
    expect(stylesSource).not.toContain("radial-gradient");
    expect(stylesSource).toContain(
      "border-top: 1px solid color-mix(in srgb, var(--border-soft) 58%, transparent);"
    );
    expect(stylesSource).toContain("color-mix(in srgb, var(--surface-0) 86%, transparent)");
    expect(stylesSource).toContain("color: var(--text-strong);");
    expect(stylesSource).toContain(".previewOverlay p");
    expect(stylesSource).toContain("color: var(--text-soft);");
    expect(stylesSource).not.toContain("rgba(0, 0, 0, 0.76)");
    expect(stylesSource).not.toContain("rgba(255, 255, 255, 0.78)");
    expect(stylesSource).not.toContain("color: white;");
  });

  it("keeps the storefront preview title responsive without viewport-scaled type", () => {
    expect(stylesSource).toContain(".previewOverlay h3 {");
    expect(stylesSource).toContain("font-size: 1.15rem;");
    expect(stylesSource).toContain("@media (max-width: 640px)");
    expect(stylesSource).toContain("font-size: 1.05rem;");
    expect(stylesSource).not.toMatch(/font-size:\s*[^;]*vw/);
  });

  it("keeps schedule refresh separate from debounced template search", () => {
    expect(pageSource).toContain("function useDebouncedValue");
    expect(pageSource).toContain("const debouncedSearch = useDebouncedValue");
    expect(pageSource).toContain("void loadTemplateOptions(debouncedSearch, controller.signal)");
    expect(pageSource).toContain("void loadScheduleData(controller.signal)");
    expect(pageSource).not.toContain(
      "fetchTemplateOfTheDaySchedule(signal),\n        fetchCurrentTemplateOfTheDay(undefined, signal),\n        fetchAdminTemplates"
    );
  });

  it("keeps loading and error states recoverable with localized copy", () => {
    expect(pageSource).toContain("action={");
    expect(pageSource).toContain("disabled={!canManageTemplates || isActionLocked}");
    expect(pageSource).toContain("title={error}");
    expect(pageSource).toContain("text.retry");
    expect(pageSource).toContain(
      'from "@/components/templates/templates-daily-featured-page.content";'
    );
    expect(pageSource).toContain(
      "const text = useMemo(() => getTemplatesDailyFeaturedPageText(locale), [locale]);"
    );
    expect(contentSource).toContain('date: "Период"');
    expect(contentSource).toContain('formAdminOnly: "Для изменений нужна роль администратора."');
    expect(contentSource).toContain('activeTemplatesOnly: "Статус: активные"');
    expect(contentSource).toContain('autoMode: "Авторежим"');
    expect(contentSource).toContain('free: "Бесплатно"');
    expect(ruContentSource).not.toContain("Template of the Day: ручные");
    expect(ruContentSource).not.toContain("fallback-выбором");
    expect(ruContentSource).not.toContain("daily job");
    expect(pageSource).not.toContain('const isRu = locale === "ru";');
    expect(pageSource).not.toContain("Stable auto fallback uses active templates.");
    expect(pageSource).not.toContain("Search active templates");
    expect(pageSource).not.toContain("Admin role required.");
    expect(pageSource).not.toContain("<th>Date</th>");
    expect(pageSource).not.toContain("<th>Actions</th>");
  });

  it("formats daily featured date ranges with the active admin locale", () => {
    expect(contentSource).toContain('intlLocale: "ru-RU"');
    expect(contentSource).toContain('intlLocale: "en-US"');
    expect(pageSource).toContain("getTemplatesDailyFeaturedPageIntlLocale(locale)");
    expect(pageSource).toContain("formatDateRange(assignment, locale)");
    expect(pageSource).toContain("Date.UTC(year, month - 1, day)");
    expect(pageSource).toContain('timeZone: "UTC"');
    expect(pageSource).toContain(
      "<CurrentAssignmentCard current={current} text={text} locale={locale} />"
    );
    expect(pageSource).toContain("locale={locale}\n        schedule={schedule}");
    expect(pageSource).not.toContain("`${assignment.startDate} - ${assignment.endDate}`");
    expect(pageSource).not.toContain("{formatDateRange(assignment)}</td>");
    expect(pageSource).not.toContain("{formatDateRange(assignment)} ·");
  });

  it("keeps daily featured schedule data partially recoverable when one request fails", () => {
    expect(pageSource).toContain("await Promise.allSettled([");
    expect(pageSource).toContain('if (scheduleResponse.status === "fulfilled")');
    expect(pageSource).toContain('if (currentResponse.status === "fulfilled")');
    expect(pageSource).toContain('if (settingsResponse.status === "fulfilled")');
    expect(pageSource).toContain("let loadFailure: unknown = null;");
    expect(pageSource).toContain("loadFailure ??= scheduleResponse.reason;");
    expect(pageSource).toContain("loadFailure ??= currentResponse.reason;");
    expect(pageSource).toContain("loadFailure ??= settingsResponse.reason;");
    expect(pageSource).toContain("setError(getAdminErrorMessage(loadFailure, text.loadError));");
    expect(pageSource).not.toContain(
      "const [scheduleResponse, currentResponse, settingsResponse] = await Promise.all(["
    );
  });

  it("keeps template option load failures local and retryable", () => {
    expect(pageSource).toContain(
      "const [templateOptionsError, setTemplateOptionsError] = useState<string | null>(null);"
    );
    expect(pageSource).toContain("setTemplates([]);");
    expect(pageSource).toContain("setTemplateOptionsError(null);");
    expect(pageSource).toContain(
      "setTemplateOptionsError(getAdminErrorMessage(loadError, text.loadError));"
    );
    expect(pageSource).toContain(
      "await Promise.allSettled([loadScheduleData(), loadTemplateOptions(debouncedSearch)]);"
    );
    expect(pageSource).toContain("{templateOptionsError ? (");
    expect(pageSource).toContain("description={templateOptionsError}");
    expect(pageSource).toContain("disabled={!canManageTemplates || isActionLocked}");
    expect(pageSource).toContain(
      "onRetryTemplateOptions={() => void loadTemplateOptions(debouncedSearch)}"
    );
    expect(pageSource).toContain("onClick={onRetryTemplateOptions}");
    expect(pageSource).not.toContain(
      "await Promise.all([loadScheduleData(), loadTemplateOptions(debouncedSearch)]);"
    );
    expect(pageSource).not.toContain(
      'clientLogger.warn("templates.daily_featured_template_options_failed", { error: loadError });\n        setError(getAdminErrorMessage(loadError, text.loadError));'
    );
  });

  it("keeps daily featured logs and backend labels sanitized", () => {
    expect(pageSource).toContain("import { sanitizeSensitiveText }");
    expect(pageSource).toContain("function safeDisplayText");
    expect(pageSource).toContain("function safeErrorDetails");
    expect(pageSource).toContain("function safeActionContext");
    expect(pageSource).toContain('errorName: error instanceof Error ? error.name : "UnknownError"');
    expect(pageSource).toContain(
      'clientLogger.warn("templates.daily_featured_load_failed", safeErrorDetails(loadFailure));'
    );
    expect(pageSource).toContain(
      'clientLogger.warn("templates.daily_featured_load_failed", safeErrorDetails(loadError));'
    );
    expect(pageSource).toContain('clientLogger.warn("templates.daily_featured_save_failed", {');
    expect(pageSource).toContain('clientLogger.warn("templates.daily_featured_delete_failed", {');
    expect(pageSource).toContain(
      'clientLogger.warn("templates.daily_featured_auto_pick_failed", {'
    );
    expect(pageSource).toContain(
      'clientLogger.warn("templates.daily_featured_settings_save_failed", {'
    );
    expect(pageSource).toContain(
      "assignmentId: input.assignmentId ? sanitizeSensitiveText(input.assignmentId, 80) : undefined"
    );
    expect(pageSource).toContain(
      "templateId: input.templateId ? sanitizeSensitiveText(input.templateId, 80) : undefined"
    );
    expect(pageSource).toContain(
      "templateTitle: input.templateTitle ? sanitizeSensitiveText(input.templateTitle, 96) : undefined"
    );
    expect(pageSource).toContain("safeDisplayText(template.title, 120)");
    expect(pageSource).toContain("safeDisplayText(template.templateType, 32)");
    expect(pageSource).toContain("safeDisplayText(template.category, 72)");
    expect(pageSource).toContain("safeDisplayText(assignment.templateTitle, 120)");
    expect(pageSource).toContain("safeDisplayText(assignment.templateType, 32)");
    expect(pageSource).toContain("safeDisplayText(assignment.subtitleOverride, 220)");
    expect(pageSource).not.toContain("{ error: loadError }");
    expect(pageSource).not.toContain("{ error: loadFailure }");
    expect(pageSource).not.toContain(
      'clientLogger.warn("templates.daily_featured_save_failed", { error: saveError });'
    );
    expect(pageSource).not.toContain(
      'clientLogger.warn("templates.daily_featured_delete_failed", { error: deleteError });'
    );
    expect(pageSource).not.toContain(
      'clientLogger.warn("templates.daily_featured_auto_pick_failed", { error: autoPickError });'
    );
    expect(pageSource).not.toContain(
      'clientLogger.warn("templates.daily_featured_settings_save_failed", { error: settingsError });'
    );
  });

  it("warns on occupied manual dates and sends manual assignment payloads", () => {
    expect(pageSource).toContain("function dateRangesOverlap");
    expect(pageSource).toContain("dateOccupiedWarning");
    expect(pageSource).toContain("assignment.isManual");
    expect(pageSource).toContain("isManual: true");
    expect(contentSource).toContain("Версия v1 поддерживает одно ручное назначение на дату.");
    expect(contentSource).toContain("v1 supports one manual assignment per date.");
  });

  it("blocks invalid assignment date ranges before submit", () => {
    expect(pageSource).toContain("function hasInvalidDateRange");
    expect(pageSource).toContain("invalidDateRangeWarning");
    expect(contentSource).toContain("End date cannot be earlier than start date.");
    expect(contentSource).toContain("Дата окончания не может быть раньше даты начала.");
    expect(pageSource).toContain("isActionLocked || invalidDateRangeWarning");
    expect(pageSource).toContain("!form.templateId || invalidDateRangeWarning");
  });

  it("locks daily featured mutations and form edits while data is loading or submitting", () => {
    expect(pageSource).toContain("const isActionLocked = isSubmitting || isLoading;");
    expect(pageSource).toMatch(
      /if \(!canManageTemplates \|\| !form\.templateId \|\| isActionLocked \|\| invalidDateRangeWarning\)\s+return;/
    );
    expect(pageSource).toContain("if (!canManageTemplates || isActionLocked) {");
    expect(pageSource).toContain(
      "if (!canManageTemplates || isActionLocked || !isAutoPickSettingsDirty) return;"
    );
    expect(pageSource).toContain("disabled={!canManageTemplates || isActionLocked}");
    expect(pageSource).toContain("aria-busy={isActionLocked}");
    expect(pageSource).not.toContain("disabled={isActionLocked}");
    expect(pageSource).toContain(
      "isSubmitting={Boolean(assignmentPendingDelete && isActionLocked)}"
    );
    expect(pageSource).not.toContain("disabled={!canManageTemplates || isSubmitting}");
  });

  it("blocks auto-pick runs until a date is selected", () => {
    expect(contentSource).toContain(
      'autoPickDateRequired: "Выберите дату для ручного автовыбора."'
    );
    expect(contentSource).toContain(
      'autoPickDateRequired: "Select a date before running auto-pick."'
    );
    expect(pageSource).toContain(
      "const isAutoPickDateMissing = autoPick.date.trim().length === 0;"
    );
    expect(pageSource).toContain(
      "if (!canManageTemplates || isActionLocked || isAutoPickDateMissing) return;"
    );
    expect(pageSource).toContain(
      "disabled={!canManageTemplates || isActionLocked || isAutoPickDateMissing}"
    );
    expect(pageSource).toContain("description={text.autoPickDateRequired}");
    expect(pageSource).toContain("date: autoPick.date");
  });

  it("does not save auto-pick settings when nothing changed", () => {
    expect(pageSource).toContain("const isAutoPickSettingsDirty =");
    expect(pageSource).toContain("settings === null ||");
    expect(pageSource).toContain("autoPick.autoModeEnabled !== settings.autoModeEnabled");
    expect(pageSource).toContain("autoPick.allowedTypes !== settings.allowedTypes");
    expect(pageSource).toContain(
      "parseExcludeRecentDays(autoPick.excludeRecentDays) !== settings.excludeRecentDays"
    );
    expect(pageSource).toContain(
      "if (!canManageTemplates || isActionLocked || !isAutoPickSettingsDirty) return;"
    );
    expect(pageSource).toContain(
      "disabled={!canManageTemplates || isActionLocked || !isAutoPickSettingsDirty}"
    );
  });

  it("filters assignment candidates by active status, type, access, and search", () => {
    expect(pageSource).toContain("const TEMPLATE_OPTIONS_TAKE = 30;");
    expect(pageSource).toContain(
      'const [templateTypeFilter, setTemplateTypeFilter] = useState<"" | TemplateType>("")'
    );
    expect(pageSource).toContain(
      'const [templateAccessFilter, setTemplateAccessFilter] = useState<TemplateAccessFilter>("")'
    );
    expect(pageSource).toContain('status: "Active"');
    expect(pageSource).toContain("type: templateTypeFilter || undefined");
    expect(pageSource).toContain("access: templateAccessFilter || undefined");
    expect(pageSource).toContain("take: TEMPLATE_OPTIONS_TAKE");
    expect(pageSource).toContain("text.activeTemplatesOnly");
  });

  it("keeps the selected template visible when filters or search hide it", () => {
    expect(pageSource).toContain("type TemplateOption = Pick<");
    expect(pageSource).toContain(
      "const [selectedTemplateOptionSnapshot, setSelectedTemplateOptionSnapshot] =\n    useState<TemplateOption | null>(null);"
    );
    expect(pageSource).toContain("const selectedTemplateSnapshot = useMemo(() => {");
    expect(pageSource).toContain("if (!form.templateId) {\n      return null;");
    expect(pageSource).toContain("function optionFromTemplate");
    expect(pageSource).toContain("function optionFromAssignment");
    expect(pageSource).toContain(
      "if (selectedTemplateOptionSnapshot?.templateId === form.templateId)"
    );
    expect(pageSource).toContain("const templateOptions = useMemo(() => {");
    expect(pageSource).toContain("return [selectedTemplateSnapshot, ...options];");
    expect(pageSource).toContain(
      "if (selectedTemplate) {\n      return optionFromTemplate(selectedTemplate);"
    );
    expect(pageSource).toContain("if (selectedAssignment?.templateId === form.templateId)");
    expect(pageSource).toContain("const handleTemplateSelectionChange = useCallback(");
    expect(pageSource).toContain(
      "templateOptions.find((template) => template.templateId === nextTemplateId) ?? null"
    );
    expect(pageSource).toContain(
      "setSelectedTemplateOptionSnapshot(optionFromAssignment(assignment));"
    );
    expect(pageSource).toContain("setSelectedTemplateOptionSnapshot(null);");
    expect(pageSource).toContain("templateOptions.map((template) =>");
  });

  it("renders storefront preview media from the selected candidate or assignment", () => {
    expect(pageSource).toContain(
      'import { TemplateSecureMedia } from "@/components/templates/template-secure-media";'
    );
    expect(pageSource).toContain("const previewMediaUrl = getPreviewUrl(selectedTemplateSnapshot)");
    expect(pageSource).toContain(
      'const previewType = selectedTemplateSnapshot?.templateType ?? ("Image" as TemplateType);'
    );
    expect(pageSource).toContain(
      'form.titleOverride.trim() || selectedTemplateSnapshot?.title || "",'
    );
    expect(pageSource).toContain(
      'form.subtitleOverride.trim() || selectedTemplateSnapshot?.shortDescription || "",'
    );
    expect(pageSource).toContain("<TemplateSecureMedia");
    expect(pageSource).toContain('kind={isVideoTemplate(previewType) ? "video" : "image"}');
    expect(pageSource).toContain('surface: "daily-featured-preview"');
    expect(pageSource).not.toContain("<video\n                  src={previewMediaUrl}");
    expect(pageSource).not.toContain("<img src={previewMediaUrl}");
    expect(pageSource).toContain("text.previewEmptyTitle");
  });

  it("uses the shared confirmation dialog for destructive schedule actions", () => {
    expect(pageSource).toContain("import { ConfirmationDialog }");
    expect(pageSource).toContain("const [assignmentPendingDelete, setAssignmentPendingDelete]");
    expect(pageSource).toContain("const scheduleAssignmentIds = useMemo(");
    expect(pageSource).toContain("new Set(schedule.map((assignment) => assignment.id))");
    expect(pageSource).toContain("if (signal?.aborted) {\n        return;\n      }");
    expect(pageSource).toContain(
      "if (isScheduleLoading || isActionLocked) {\n      return;\n    }"
    );
    expect(pageSource).toContain(
      "const shouldResetPendingDelete =\n      assignmentPendingDelete && !scheduleAssignmentIds.has(assignmentPendingDelete.id);"
    );
    expect(pageSource).toContain(
      "const shouldResetForm = form.id && !scheduleAssignmentIds.has(form.id);"
    );
    expect(pageSource).toContain("queueMicrotask(() => {");
    expect(pageSource).toContain("let isActive = true;");
    expect(pageSource).toContain("if (!isActive) {\n        return;\n      }");
    expect(pageSource).toContain(
      "if (shouldResetPendingDelete) {\n        setAssignmentPendingDelete(null);\n      }"
    );
    expect(pageSource).toContain(
      "if (shouldResetForm) {\n        setSelectedTemplateOptionSnapshot(null);\n        setForm(emptyForm(form.startDate));\n      }"
    );
    expect(pageSource).toContain("deleteConfirmTitle");
    expect(pageSource).toContain("deleteConfirmDescription");
    expect(pageSource).toContain("editAssignmentLabel");
    expect(pageSource).toContain("deleteAssignmentLabel");
    expect(pageSource).toContain("aria-label={text.editAssignmentLabel");
    expect(pageSource).toContain("aria-label={text.deleteAssignmentLabel");
    expect(pageSource).toContain("onRequestDeleteAssignment={setAssignmentPendingDelete}");
    expect(pageSource).toContain("onClick={() => onRequestDeleteAssignment(assignment)}");
    expect(pageSource).toContain("<ConfirmationDialog");
    expect(pageSource).toContain("void handleDelete(assignmentPendingDelete).then((succeeded) =>");
    expect(pageSource).toContain("isActive = false;");
    expect(pageSource).not.toContain("window.confirm");
  });
});
