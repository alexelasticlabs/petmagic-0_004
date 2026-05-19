export const adminQueryKeys = {
  users: ["admin", "users"] as const,
  userDetail: (userId: string) => ["admin", "users", userId, "detail"] as const,
  userAnalytics: (userId: string) => ["admin", "users", userId, "analytics"] as const,
  templateCategories: (includeArchived: boolean) => ["admin", "templates", "categories", includeArchived ? "all" : "active"] as const,
  templateCatalog: (templateType: string) => ["admin", "templates", templateType, "catalog"] as const,
  templateCatalogAnalyticsRows: (templateType: string) => ["admin", "templates", templateType, "catalog-analytics"] as const,
  templateAnalyticsPrimary: (templateId: string) => ["admin", "templates", templateId, "analytics-primary"] as const,
  templateAnalyticsSecondary: (templateId: string, previewTake?: number) => ["admin", "templates", templateId, "analytics-secondary", previewTake ?? "default"] as const,
  templateAnalyticsFeedback: (templateId: string, feedbackType: string, search: string) => ["admin", "templates", templateId, "analytics-feedback", feedbackType, search] as const,
};
