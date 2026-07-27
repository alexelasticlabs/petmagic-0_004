export type AdminTemplateCategoryDiagnosticIssueKind =
  "empty_category" | "archived_category" | "missing_category";

export type AdminTemplateCategoryDiagnosticItem = {
  templateId: string;
  issueKind: AdminTemplateCategoryDiagnosticIssueKind;
  title: string;
  category: string;
  normalizedCategory: string;
  templateType: string;
  status: string;
  updatedAtUtc: string;
};

export type AdminTemplateCategoryDiagnostics = {
  totalActiveTemplates: number;
  noncanonicalTemplates: number;
  noncanonicalPercent: number;
  items: AdminTemplateCategoryDiagnosticItem[];
  generatedAtUtc: string;
};
