const supportInboxRoot = ["admin", "support", "inbox"] as const;

export const adminQueryKeys = {
  dashboard: (locale: string, commercePeriodDays = 7) =>
    ["admin", "dashboard", locale, commercePeriodDays] as const,
  systemStatus: ["admin", "system", "status"] as const,
  operationsStatus: ["admin", "system", "operations"] as const,
  operationsProblems: (source: string) =>
    ["admin", "system", "operations", "problems", source] as const,
  notificationsRoot: ["admin", "notifications"] as const,
  notifications: (query: unknown) => ["admin", "notifications", query] as const,
  auditEvents: (query: unknown) => ["admin", "audit", "events", query] as const,
  auditEvent: (id: string) => ["admin", "audit", "events", id] as const,
  usersRoot: ["admin", "users"] as const,
  users: (query: unknown) => ["admin", "users", query] as const,
  commandUsers: (search: string) =>
    ["admin", "users", "command-palette", search.trim().toLowerCase()] as const,
  userDashboardMetrics: ["admin", "users", "dashboard-metrics"] as const,
  emailBroadcastsRoot: ["admin", "users", "email-broadcasts"] as const,
  emailBroadcasts: (query: unknown) =>
    ["admin", "users", "email-broadcasts", "list", query] as const,
  emailBroadcast: (broadcastId: string) =>
    ["admin", "users", "email-broadcasts", broadcastId, "detail"] as const,
  userDetail: (userId: string) => ["admin", "users", userId, "detail"] as const,
  userDetailDisabled: ["admin", "users", "detail", "disabled"] as const,
  userAnalytics: (userId: string) => ["admin", "users", userId, "analytics"] as const,
  userSessions: (userId: string) => ["admin", "users", userId, "sessions"] as const,
  userRowAnalytics: (userIds: readonly string[]) =>
    ["admin", "users", "row-analytics", userIds] as const,
  userAnalyticsDisabled: ["admin", "users", "analytics", "disabled"] as const,
  economyLedger: (query: unknown) => ["admin", "economy", "ledger", query] as const,
  economyDashboardMetrics: ["admin", "economy", "dashboard", "metrics"] as const,
  economyDashboardMetricsPeriod: (periodDays = 7) =>
    ["admin", "economy", "dashboard", "metrics", periodDays] as const,
  economyPurchases: (query: unknown) => ["admin", "economy", "purchases", query] as const,
  economyPurchase: (orderId: string) =>
    ["admin", "economy", "purchases", orderId, "detail"] as const,
  economySubscriptions: (query: unknown) => ["admin", "economy", "subscriptions", query] as const,
  economyUserSubscriptionSummary: (userId: string) =>
    ["admin", "economy", "users", userId, "subscription-summary"] as const,
  economyUserSubscriptionSummaries: (userIds: readonly string[]) =>
    ["admin", "economy", "users", "subscription-summaries", userIds] as const,
  economyUserSubscriptionSummaryDisabled: [
    "admin",
    "economy",
    "users",
    "subscription-summary",
    "disabled",
  ] as const,
  economySubscriptionPlans: ["admin", "economy", "subscription-plans"] as const,
  economyPaymentProviderConfigs: ["admin", "economy", "payment-provider-configs"] as const,
  economySubscriptionEvents: (provider: string, status: string, page: number) =>
    ["admin", "economy", "subscription-events", provider, status, page] as const,
  economyIncidents: (query: unknown) => ["admin", "economy", "incidents", query] as const,
  economyIncident: (incidentId: string) =>
    ["admin", "economy", "incidents", incidentId, "detail"] as const,
  economyPacks: ["admin", "economy", "packs"] as const,
  economyRedeemCodesRoot: ["admin", "economy", "redeem-codes"] as const,
  economyRedeemCodes: (query: unknown) => ["admin", "economy", "redeem-codes", query] as const,
  economyRedeemCodeMetrics: (query: unknown) =>
    ["admin", "economy", "redeem-codes", "metrics", query] as const,
  economyRedeemCodeActivations: (redeemCodeId: string, skip: number, take: number) =>
    ["admin", "economy", "redeem-codes", redeemCodeId, "activations", skip, take] as const,
  gamificationRoot: ["admin", "gamification"] as const,
  gamificationDashboardMetrics: ["admin", "gamification", "dashboard", "metrics"] as const,
  gamificationAchievements: ["admin", "gamification", "achievements"] as const,
  gamificationChallenges: ["admin", "gamification", "challenges", "current"] as const,
  gamificationUser: (userId: string) => ["admin", "gamification", "users", userId] as const,
  gamificationUserDisabled: ["admin", "gamification", "users", "disabled"] as const,
  supportInboxRoot,
  supportInboxMetrics: [...supportInboxRoot, "metrics"] as const,
  supportInbox: (
    status: string,
    assignment: string,
    options?: {
      search?: string;
      priority?: string;
      sort?: string;
      queue?: string;
      page?: number;
      pageSize?: number;
    }
  ) =>
    [
      ...supportInboxRoot,
      status,
      assignment,
      options?.search?.trim() || "",
      options?.priority?.trim() || "all",
      options?.sort?.trim() || "default",
      options?.queue?.trim() || "all",
      options?.page ?? 1,
      options?.pageSize ?? 50,
    ] as const,
  supportConversation: (conversationId: string) =>
    ["admin", "support", conversationId, "detail"] as const,
  supportTemplates: ["admin", "support", "templates"] as const,
  supportTemplateList: (includeDisabled: boolean) =>
    ["admin", "support", "templates", includeDisabled ? "all" : "enabled"] as const,
  supportTemplateVersions: (templateId: string) =>
    ["admin", "support", "templates", templateId, "versions"] as const,
  templateCategories: (includeArchived: boolean) =>
    ["admin", "templates", "categories", includeArchived ? "all" : "active"] as const,
  templateCategoryDiagnostics: ["admin", "templates", "categories", "diagnostics"] as const,
  templateCatalogRoot: ["admin", "templates", "catalog"] as const,
  templateCatalog: (query: unknown) => ["admin", "templates", "catalog", query] as const,
  templateCatalogAnalyticsRows: (templateType: string, templateIds: readonly string[]) =>
    ["admin", "templates", templateType, "catalog-analytics", templateIds] as const,
  templateAnalyticsPrimary: (templateId: string) =>
    ["admin", "templates", templateId, "analytics-primary"] as const,
  templateAnalyticsSecondary: (templateId: string, previewTake?: number) =>
    ["admin", "templates", templateId, "analytics-secondary", previewTake ?? "default"] as const,
  templateAnalyticsFeedback: (templateId: string, feedbackType: string, search: string) =>
    ["admin", "templates", templateId, "analytics-feedback", feedbackType, search] as const,
  templateGenerationMetrics: ["admin", "templates", "generations", "metrics"] as const,
  templateGenerationControl: ["admin", "templates", "generation-control"] as const,
  templateGenerationProviderRecoveryRoot: [
    "admin",
    "templates",
    "generation-control",
    "provider-recovery",
  ] as const,
  templateGenerationProviderRecovery: (skip: number, take: number) =>
    ["admin", "templates", "generation-control", "provider-recovery", skip, take] as const,
  templateGenerations: (query: unknown) => ["admin", "templates", "generations", query] as const,
  templateGenerationDetail: (generationId: string) =>
    ["admin", "templates", "generations", generationId, "detail"] as const,
  templateWatermarkSettings: ["admin", "templates", "monetization", "watermark"] as const,
  moderationQueue: (query: unknown) => ["admin", "moderation", query] as const,
  feedback: (query: unknown) => ["admin", "feedback", query] as const,
  feedbackDetails: (feedbackId: string) => ["admin", "feedback", feedbackId] as const,
  templateFeedbackSummary: (templateId: string) =>
    ["admin", "templates", templateId, "feedback-summary"] as const,
};
