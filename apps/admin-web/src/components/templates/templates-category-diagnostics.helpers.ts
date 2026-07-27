import type {
  AdminTemplateCategoryDiagnosticItem,
  AdminTemplateCategoryDiagnosticIssueKind,
} from "@/lib/api-client.types.template-category-diagnostics";
import type { Locale } from "@/lib/i18n";

export type TemplateCategoryDiagnosticFilter = "all" | AdminTemplateCategoryDiagnosticIssueKind;

export function buildTemplateCategoryEditorPath(
  locale: Locale,
  item: Pick<AdminTemplateCategoryDiagnosticItem, "templateId" | "templateType">
): string {
  const editorType = item.templateType.toLowerCase() === "video" ? "video" : "image";
  return `/${locale}/templates/${editorType}/editor?templateId=${encodeURIComponent(item.templateId)}`;
}

export function filterTemplateCategoryDiagnosticItems(
  items: AdminTemplateCategoryDiagnosticItem[],
  issueFilter: TemplateCategoryDiagnosticFilter,
  rawSearch: string
): AdminTemplateCategoryDiagnosticItem[] {
  const search = rawSearch.trim().toLocaleLowerCase();

  return items.filter((item) => {
    if (issueFilter !== "all" && item.issueKind !== issueFilter) {
      return false;
    }

    if (!search) {
      return true;
    }

    return [item.title, item.category, item.normalizedCategory, item.templateType]
      .join(" ")
      .toLocaleLowerCase()
      .includes(search);
  });
}
