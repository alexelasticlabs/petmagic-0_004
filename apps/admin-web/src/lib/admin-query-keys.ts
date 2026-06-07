const supportInboxRoot = ["admin", "support", "inbox"] as const;

export const adminQueryKeys = {
  usersRoot: ["admin", "users"] as const,
  users: (query: unknown) => ["admin", "users", query] as const,
  userDetail: (userId: string) => ["admin", "users", userId, "detail"] as const,
  userDetailDisabled: ["admin", "users", "detail", "disabled"] as const,
  userAnalytics: (userId: string) => ["admin", "users", userId, "analytics"] as const,
  userAnalyticsDisabled: ["admin", "users", "analytics", "disabled"] as const,
  economyLedger: (source: string, statusUserKey: string) =>
    ["admin", "economy", "ledger", source, statusUserKey] as const,
  economyPurchases: (query: unknown) => ["admin", "economy", "purchases", query] as const,
  economySubscriptions: (query: unknown) =>
    ["admin", "economy", "subscriptions", query] as const,
  economyUserSubscriptionSummary: (userId: string) =>
    ["admin", "economy", "users", userId, "subscription-summary"] as const,
  economyUserSubscriptionSummaryDisabled: [
    "admin",
    "economy",
    "users",
    "subscription-summary",
    "disabled",
  ] as const,
  economySubscriptionPlans: ["admin", "economy", "subscription-plans"] as const,
  economyPaymentProviderConfigs: ["admin", "economy", "payment-provider-configs"] as const,
  economySubscriptionEvents: (provider: string, status: string) =>
    ["admin", "economy", "subscription-events", provider, status] as const,
  economyPacks: ["admin", "economy", "packs"] as const,
  economyRedeemCodes: ["admin", "economy", "redeem-codes"] as const,
  economyRedeemCodeActivations: (redeemCodeId: string, skip: number, take: number) =>
    ["admin", "economy", "redeem-codes", redeemCodeId, "activations", skip, take] as const,
  supportInboxRoot,
  supportInbox: (
    status: string,
    assignment: string,
    options?: { search?: string; page?: number; pageSize?: number }
  ) =>
    [
      ...supportInboxRoot,
      status,
      assignment,
      options?.search?.trim() || "",
      options?.page ?? 1,
      options?.pageSize ?? 50,
    ] as const,
  supportConversation: (conversationId: string) =>
    ["admin", "support", conversationId, "detail"] as const,
  supportTemplates: ["admin", "support", "templates"] as const,
  templateCategories: (includeArchived: boolean) =>
    ["admin", "templates", "categories", includeArchived ? "all" : "active"] as const,
  templateCatalog: (templateType: string) =>
    ["admin", "templates", templateType, "catalog"] as const,
  templateCatalogAnalyticsRows: (templateType: string) =>
    ["admin", "templates", templateType, "catalog-analytics"] as const,
  templateAnalyticsPrimary: (templateId: string) =>
    ["admin", "templates", templateId, "analytics-primary"] as const,
  templateAnalyticsSecondary: (templateId: string, previewTake?: number) =>
    ["admin", "templates", templateId, "analytics-secondary", previewTake ?? "default"] as const,
  templateAnalyticsFeedback: (templateId: string, feedbackType: string, search: string) =>
    ["admin", "templates", templateId, "analytics-feedback", feedbackType, search] as const,
  templateGenerations: (query: unknown) => ["admin", "templates", "generations", query] as const,
  moderationQueue: (query: unknown) => ["admin", "moderation", query] as const,
};
