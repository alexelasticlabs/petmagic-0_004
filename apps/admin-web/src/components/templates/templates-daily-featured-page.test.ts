import { readFileSync } from "node:fs";

import { describe, expect, it } from "vitest";

const pageSource = readFileSync(
  new URL("./templates-daily-featured-page.tsx", import.meta.url),
  "utf8"
);
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
    expect(pageSource).toContain("disabled={!canManageTemplates || isLoading}");
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
    expect(pageSource).toContain("disabled={!canManageTemplates || isLoading}");
    expect(pageSource).toContain("title={error}");
    expect(pageSource).toContain("text.retry");
    expect(pageSource).toContain('date: isRu ? "Период" : "Date"');
    expect(pageSource).toContain("formAdminOnly: isRu");
    expect(pageSource).toContain('"Для изменений нужна роль Admin."');
    expect(pageSource).not.toContain("Stable auto fallback uses active templates.");
    expect(pageSource).not.toContain("Search active templates");
    expect(pageSource).not.toContain("Admin role required.");
    expect(pageSource).not.toContain("<th>Date</th>");
    expect(pageSource).not.toContain("<th>Actions</th>");
  });

  it("warns on occupied manual dates and sends manual assignment payloads", () => {
    expect(pageSource).toContain("function dateRangesOverlap");
    expect(pageSource).toContain("dateOccupiedWarning");
    expect(pageSource).toContain("assignment.isManual");
    expect(pageSource).toContain("isManual: true");
    expect(pageSource).toContain("v1 supports one manual assignment per date.");
  });

  it("blocks invalid assignment date ranges before submit", () => {
    expect(pageSource).toContain("function hasInvalidDateRange");
    expect(pageSource).toContain("invalidDateRangeWarning");
    expect(pageSource).toContain("End date cannot be earlier than start date.");
    expect(pageSource).toContain("Дата окончания не может быть раньше даты начала.");
    expect(pageSource).toContain("isSubmitting || invalidDateRangeWarning");
    expect(pageSource).toContain("!form.templateId || invalidDateRangeWarning");
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
      "const [selectedTemplateSnapshot, setSelectedTemplateSnapshot] = useState<TemplateOption | null>(null)"
    );
    expect(pageSource).toContain("function optionFromTemplate");
    expect(pageSource).toContain("function optionFromAssignment");
    expect(pageSource).toContain("const templateOptions = useMemo(() => {");
    expect(pageSource).toContain("return [selectedTemplateSnapshot, ...options];");
    expect(pageSource).toContain("if (selectedTemplate) {\n      setSelectedTemplateSnapshot");
    expect(pageSource).toContain("if (selectedAssignment?.templateId === form.templateId)");
    expect(pageSource).toContain("templateOptions.map((template) =>");
  });

  it("renders storefront preview media from the selected candidate or assignment", () => {
    expect(pageSource).toContain(
      "const previewMediaUrl = getPreviewUrl(selectedTemplate ?? selectedAssignment)"
    );
    expect(pageSource).toContain("isVideoTemplate(previewType) ? (");
    expect(pageSource).toContain("<video");
    expect(pageSource).toContain("<img src={previewMediaUrl}");
    expect(pageSource).toContain("text.previewEmptyTitle");
  });

  it("uses the shared confirmation dialog for destructive schedule actions", () => {
    expect(pageSource).toContain("import { ConfirmationDialog }");
    expect(pageSource).toContain("const [assignmentPendingDelete, setAssignmentPendingDelete]");
    expect(pageSource).toContain("deleteConfirmTitle");
    expect(pageSource).toContain("deleteConfirmDescription");
    expect(pageSource).toContain("setAssignmentPendingDelete(assignment)");
    expect(pageSource).toContain("<ConfirmationDialog");
    expect(pageSource).toContain("void handleDelete(assignmentPendingDelete).then((succeeded) =>");
    expect(pageSource).not.toContain("window.confirm");
  });
});
