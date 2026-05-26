export type UserProfile = {
  userId: string;
  email: string;
  displayName?: string;
  isPremium: boolean;
  emailConfirmed: boolean;
  roles: string[];
  avatar?: UserAvatar | null;
};

export type UserAvatar = {
  url: string;
  fileName: string;
  contentType: string;
  fileSizeBytes?: number | null;
  updatedAtUtc?: string | null;
};

export type AuthSession = {
  accessToken: string;
  refreshToken?: string;
  expiresAtUtc: string;
  user: UserProfile;
};

export type UserListItem = {
  userId: string;
  email: string;
  displayName?: string;
  isPremium: boolean;
  isActive: boolean;
  emailConfirmed: boolean;
  roles: string[];
  createdAtUtc: string;
  avatar?: UserAvatar | null;
};

export type AdminUserDetail = {
  userId: string;
  email: string;
  displayName?: string;
  isPremium: boolean;
  isActive: boolean;
  emailConfirmed: boolean;
  roles: string[];
  createdAtUtc: string;
  avatar?: UserAvatar | null;
};

export type AdminUserAnalyticsSummary = {
  walletBalance: number;
  totalTokensCredited: number;
  totalTokensSpent: number;
  manualTokensGranted: number;
  manualTokensDebited: number;
  totalPurchases: number;
  successfulPurchases: number;
  totalPurchasedSpark: number;
  lastPurchaseAtUtc?: string | null;
  totalGenerations: number;
  completedGenerations: number;
  failedGenerations: number;
  lastGenerationAtUtc?: string | null;
  totalViews: number;
  totalVideoViews: number;
  successfulLogins: number;
  failedLogins: number;
  lastLoginAtUtc?: string | null;
  templateAnalyticsEvents: number;
  auditEvents: number;
  lastActivityAtUtc?: string | null;
};

export type AdminUserActivityItem = {
  kind: string;
  title: string;
  details?: string | null;
  occurredAtUtc: string;
};

export type AdminUserAuditEvent = {
  auditEventId: string;
  action: string;
  details: string;
  occurredAtUtc: string;
};

export type AdminUserPurchase = {
  orderId: string;
  status: string;
  priceAmount: number;
  currencyCode: string;
  sparkToGrant: number;
  paymentProvider: string;
  createdAtUtc: string;
  confirmedAtUtc?: string | null;
};

export type AdminUserGeneration = {
  generationId: string;
  templateId: string;
  templateTitle: string;
  templateType: TemplateType;
  status: string;
  tokenCost: number;
  failureCode?: string | null;
  failureMessage?: string | null;
  outputUrl?: string | null;
  createdAtUtc: string;
  completedAtUtc?: string | null;
};

export type AdminUserTemplateEvent = {
  eventId: string;
  templateId: string;
  templateTitle: string;
  eventType: string;
  source: string;
  deviceClass: string;
  countryCode: string;
  generationId?: string | null;
  feedbackMessage?: string | null;
  createdAtUtc: string;
};

export type AdminUserFailureBreakdownItem = {
  failureCode: string;
  count: number;
  lastOccurredAtUtc?: string | null;
};

export type AdminUserWalletLedgerItem = {
  entryId: string;
  delta: number;
  balanceAfter: number;
  source: string;
  reason: string;
  createdAtUtc: string;
};

export type AdminUserWalletOperation = {
  userId: string;
  operation: "credit" | "debit";
  delta: number;
  newBalance: number;
  source: string;
  reason: string;
  occurredAtUtc: string;
};

export type AdminUserAnalytics = {
  summary: AdminUserAnalyticsSummary;
  recentActivity: AdminUserActivityItem[];
  recentAuditEvents: AdminUserAuditEvent[];
  recentPurchases: AdminUserPurchase[];
  recentGenerations: AdminUserGeneration[];
  recentTemplateEvents: AdminUserTemplateEvent[];
  recentWalletLedger: AdminUserWalletLedgerItem[];
  failureBreakdown: AdminUserFailureBreakdownItem[];
};

export type OffsetPagedResponse<T> = {
  items: T[];
  skip: number;
  take: number;
  hasMore: boolean;
};

export type AdminEconomyLedgerItem = {
  entryId: string;
  userId: string;
  delta: number;
  balanceAfter: number;
  source: string;
  reason: string;
  createdAtUtc: string;
};

export type AdminEconomyPurchase = {
  orderId: string;
  userId: string;
  packId: string;
  packCode: string;
  packDisplayName: string;
  paymentProvider: string;
  status: string;
  priceAmount: number;
  currencyCode: string;
  sparkToGrant: number;
  externalPaymentId?: string | null;
  createdAtUtc: string;
  confirmedAtUtc?: string | null;
};

export type AdminEconomySubscription = {
  subscriptionId: string;
  userId: string;
  provider: string;
  purchaseChannel: string;
  region: string;
  planId: string;
  planName?: string | null;
  status: string;
  currentPeriodStartUtc?: string | null;
  currentPeriodEndUtc?: string | null;
  cancelAtPeriodEnd: boolean;
  monthlyTokenLimit: number;
  monthlyTokensGranted: number;
  lastTokenGrantAtUtc?: string | null;
  createdAtUtc: string;
  updatedAtUtc: string;
};

export type AdminSubscriptionPlan = {
  planId: string;
  name: string;
  billingPeriod: string;
  priceAmount: number;
  currencyCode: string;
  monthlyTokenLimit: number;
  isRecommended: boolean;
  isActive: boolean;
  appleProductId?: string | null;
  googleProductId?: string | null;
  stripePriceId?: string | null;
  displayOrder: number;
  updatedAtUtc: string;
};

export type AdminPaymentProviderConfiguration = {
  configurationId: string;
  provider: string;
  platform: string;
  region: string;
  isEnabled: boolean;
  isRecommended: boolean;
  isSelectedByDefault: boolean;
  requiresExternalWarning: boolean;
  requiresStoreDisclosure: boolean;
  allowedFromAppVersion: string;
  externalCheckoutAllowed: boolean;
  bonusTokensPercent: number;
  displayLabel?: string | null;
  displaySubtitle?: string | null;
  warningTitle?: string | null;
  warningMessage?: string | null;
  mode: string;
  notes?: string | null;
  updatedAtUtc: string;
};

export type AdminPaymentProviderConfigurationMatch = {
  provider: string;
  platform: string;
  country: string;
  normalizedRegion: string;
  isEuRegion: boolean;
  appVersion: string;
  matchFound: boolean;
  allowedForCheckout: boolean;
  stripeModeConfigured: boolean;
  decisionCode: string;
  decisionMessage: string;
  matchedConfiguration?: AdminPaymentProviderConfiguration | null;
};

export type AdminSubscriptionEvent = {
  eventId: string;
  userId?: string | null;
  userSubscriptionId?: string | null;
  provider: string;
  eventType: string;
  status: string;
  externalEventId?: string | null;
  externalSubscriptionId?: string | null;
  createdAtUtc: string;
  processedAtUtc?: string | null;
};

export type AdminCurrencyPack = {
  packId: string;
  code: string;
  displayName: string;
  currencyCode: string;
  priceAmount: number;
  grantedSpark: number;
  bonusSpark: number;
  totalSpark: number;
  isActive: boolean;
  sortOrder: number;
};

export type AdminRedeemRewardKind = "spark" | "premium_days";

export type AdminRedeemCodeRedemption = {
  redemptionId: string;
  userId: string;
  rewardKind: AdminRedeemRewardKind;
  rewardValue: number;
  walletLedgerEntryId?: string | null;
  premiumExpiresAtUtc?: string | null;
  redeemedAtUtc: string;
};

export type AdminRedeemCode = {
  redeemCodeId: string;
  code: string;
  codePrefix: string;
  description: string;
  campaignName?: string | null;
  campaignChannel?: string | null;
  minimumSuccessfulPurchases: number;
  createdBy?: string | null;
  rewardKind: AdminRedeemRewardKind;
  rewardValue: number;
  maxRedemptions: number;
  maxRedemptionsPerUser: number;
  redeemedCount: number;
  isActive: boolean;
  startsAtUtc?: string | null;
  expiresAtUtc?: string | null;
  createdAtUtc: string;
  updatedAtUtc: string;
  lastRedeemedAtUtc?: string | null;
  redemptions: AdminRedeemCodeRedemption[];
};

export type SupportConversationStatus = "Open" | "InProgress" | "Resolved" | "Closed";

export type SupportConversationPriority = "Low" | "Normal" | "High";

export type SupportInboxAssignmentScope = "all" | "mine" | "unassigned";

export type AdminSupportMessage = {
  messageId: string;
  conversationId: string;
  senderUserId: string;
  senderDisplayName: string;
  isFromAdmin: boolean;
  body: string;
  attachmentUrl?: string | null;
  attachmentFileName?: string | null;
  attachmentContentType?: string | null;
  attachmentFileSizeBytes?: number | null;
  attachmentUploadStatus?: string | null;
  attachmentUploadErrorCode?: string | null;
  isRead: boolean;
  readAtUtc?: string | null;
  createdAtUtc: string;
};

export type AdminSupportConversationSummary = {
  conversationId: string;
  initiatorUserId: string;
  userEmail: string;
  userDisplayName?: string;
  assignedAdminId?: string | null;
  assignedAdminDisplayName?: string | null;
  status: SupportConversationStatus;
  priority: SupportConversationPriority;
  lastMessagePreview?: string | null;
  lastMessageAtUtc?: string | null;
  userUnreadCount: number;
  adminUnreadCount: number;
  createdAtUtc: string;
  updatedAtUtc: string;
};

export type AdminSupportConversation = {
  conversationId: string;
  initiatorUserId: string;
  userEmail: string;
  userDisplayName?: string;
  assignedAdminId?: string | null;
  assignedAdminDisplayName?: string | null;
  status: SupportConversationStatus;
  priority: SupportConversationPriority;
  userUnreadCount: number;
  adminUnreadCount: number;
  createdAtUtc: string;
  updatedAtUtc: string;
  lastMessageAtUtc?: string | null;
  messages: AdminSupportMessage[];
};

export type AdminSupportReplyTemplate = {
  templateId: string;
  title: string;
  body: string;
  isEnabled: boolean;
  sortOrder: number;
  createdAtUtc: string;
  updatedAtUtc: string;
};

export type TemplateType = "Image" | "Video";

export type TemplateStatus = "Draft" | "Active" | "Archived";

export type TemplateGenerationJobStatus = "Queued" | "Processing" | "Completed" | "Failed";

export type TemplatePromoBadgeMode = "Auto" | "New" | "Trending" | "Popular" | "Funny";

export type TemplateAssetInput = {
  url: string;
  fileName: string;
  contentType: string;
  fileSizeBytes?: number;
  durationSeconds?: number;
};

export type TemplateAsset = {
  url: string;
  fileName: string;
  contentType: string;
  fileSizeBytes?: number;
  durationSeconds?: number;
};

export type TemplateAssetKind = "Preview" | "ReferenceMotion";

export type AdminTemplateListItem = {
  templateId: string;
  templateType: TemplateType;
  title: string;
  shortDescription: string;
  petPhotoRequirements?: string[];
  category: string;
  status: TemplateStatus;
  promoBadgeMode: TemplatePromoBadgeMode;
  effectivePromoBadge?: Exclude<TemplatePromoBadgeMode, "Auto">;
  isPremium: boolean;
  tokenCost: number;
  tags: string[];
  previewAsset?: TemplateAsset;
  musicDescription?: string;
  referenceVideoDurationSeconds?: number;
  characterOrientation?: string;
  createdAtUtc: string;
  updatedAtUtc: string;
  estimatedCostUsd?: number;
};

export type AdminTemplateCategory = {
  categoryId: string;
  name: string;
  isArchived: boolean;
  totalTemplates: number;
  videoTemplates: number;
  imageTemplates: number;
  activeTemplates: number;
  draftTemplates: number;
  archivedTemplates: number;
  premiumTemplates: number;
  tags: string[];
  createdAtUtc: string;
  updatedAtUtc: string;
};

export type AdminTemplate = {
  templateId: string;
  templateType: TemplateType;
  title: string;
  shortDescription: string;
  petPhotoRequirements?: string[];
  category: string;
  status: TemplateStatus;
  promoBadgeMode: TemplatePromoBadgeMode;
  effectivePromoBadge?: Exclude<TemplatePromoBadgeMode, "Auto">;
  isPremium: boolean;
  tokenCost: number;
  tags: string[];
  previewAsset?: TemplateAsset;
  musicDescription?: string;
  referenceMotionAsset?: TemplateAsset;
  referenceVideoDurationSeconds?: number;
  characterOrientation?: string;
  imageModel?: string;
  imagePrompt?: string;
  preprocessingModel?: string;
  preprocessingPrompt?: string;
  klingModel?: string;
  klingPrompt?: string;
  keepOriginalSound?: boolean;
  estimatedProviderCostUsd?: number;
  createdAtUtc: string;
  updatedAtUtc: string;
};

export type AdminTemplateStatistics = {
  templateId: string;
  totalRuns: number;
  queuedRuns: number;
  processingRuns: number;
  completedRuns: number;
  failedRuns: number;
  successRatePercent: number;
  totalTokenCost: number;
  averageTokenCost: number;
  totalProviderCostUsd: number;
  averageProviderCostUsd: number;
  lastRunAtUtc?: string | null;
  lastCompletedAtUtc?: string | null;
  averageGenerationSeconds?: number | null;
};

export type AdminTemplateTrendPoint = {
  dateUtc: string;
  totalRuns: number;
  queuedRuns: number;
  processingRuns: number;
  completedRuns: number;
  failedRuns: number;
  successRatePercent: number;
  totalTokenCost: number;
  totalProviderCostUsd: number;
  averageGenerationSeconds?: number | null;
};

export type AdminTemplateRecentGeneration = {
  generationId: string;
  userId: string;
  status: TemplateGenerationJobStatus;
  tokenCost: number;
  attemptCount: number;
  usedPreprocessingModel?: string | null;
  usedKlingModel?: string | null;
  motionProviderCostUsd?: number | null;
  failureCode?: string | null;
  failureMessage?: string | null;
  outputUrl?: string | null;
  createdAtUtc: string;
  startedAtUtc?: string | null;
  completedAtUtc?: string | null;
};

export type AdminTemplateFailureBreakdownItem = {
  failureCode: string;
  count: number;
  lastOccurredAtUtc?: string | null;
};

export type AdminTemplateAnalyticsDimension = {
  key: string;
  label: string;
  count: number;
  sharePercent: number;
};

export type AdminTemplateEventAnalytics = {
  totalViews: number;
  totalVideoViews: number;
  totalComplaints: number;
  sources: AdminTemplateAnalyticsDimension[];
  devices: AdminTemplateAnalyticsDimension[];
  geography: AdminTemplateAnalyticsDimension[];
};

export type AdminTemplateFeedbackItem = {
  eventId: string;
  eventType: string;
  feedbackMessage?: string | null;
  source: string;
  deviceClass: string;
  countryCode: string;
  userId?: string | null;
  generationId?: string | null;
  createdAtUtc: string;
};

export type AdminTemplateFeedbackQuery = {
  take?: number;
  type?: "complaint" | "feedback";
  search?: string;
};

export type AdminTemplatesAnalyticsFeedbackItem = {
  eventId: string;
  templateId: string;
  templateTitle: string;
  templateType: TemplateType;
  eventType: string;
  feedbackMessage?: string | null;
  source: string;
  deviceClass: string;
  countryCode: string;
  userId?: string | null;
  generationId?: string | null;
  createdAtUtc: string;
};

export type AdminTemplatesAnalyticsQuery = {
  periodDays?: number;
  templateType?: TemplateType | "All";
  category?: string;
  status?: TemplateStatus | "All";
  access?: "all" | "free" | "premium";
  sort?: "views" | "starts" | "conversion" | "cost" | "tokens" | "updated";
  take?: number;
};

export type AdminTemplatesAnalyticsSummary = {
  totalTemplates: number;
  videoTemplates: number;
  imageTemplates: number;
  activeTemplates: number;
  premiumTemplates: number;
  totalViews: number;
  totalGenerationStarts: number;
  completedGenerations: number;
  failedGenerations: number;
  conversionPercent: number;
  totalTokenCost: number;
  averageTokenCost: number;
  totalProviderCostUsd: number;
  totalComplaints: number;
};

export type AdminTemplatesAnalyticsTrendPoint = {
  dateUtc: string;
  totalViews: number;
  totalGenerationStarts: number;
  completedGenerations: number;
  failedGenerations: number;
  totalTokenCost: number;
  totalProviderCostUsd: number;
};

export type AdminTemplatesAnalyticsTemplateRow = {
  templateId: string;
  templateType: TemplateType;
  title: string;
  category: string;
  status: TemplateStatus;
  isPremium: boolean;
  tokenCost: number;
  previewAsset?: TemplateAsset | null;
  views: number;
  generationStarts: number;
  completedGenerations: number;
  failedGenerations: number;
  conversionPercent: number;
  totalTokenCost: number;
  totalProviderCostUsd: number;
  updatedAtUtc: string;
};

export type AdminTemplatesAnalyticsBreakdown = {
  key: string;
  label: string;
  templateCount: number;
  views: number;
  generationStarts: number;
  completedGenerations: number;
  conversionPercent: number;
  totalTokenCost: number;
  totalProviderCostUsd: number;
};

export type AdminTemplatesAnalyticsFunnel = {
  views: number;
  generationStarts: number;
  completedGenerations: number;
  failedGenerations: number;
  complaints: number;
};

export type AdminTemplatesAnalyticsOverview = {
  summary: AdminTemplatesAnalyticsSummary;
  trendPoints: AdminTemplatesAnalyticsTrendPoint[];
  topTemplates: AdminTemplatesAnalyticsTemplateRow[];
  categories: AdminTemplatesAnalyticsBreakdown[];
  templateTypes: AdminTemplatesAnalyticsBreakdown[];
  sources: AdminTemplateAnalyticsDimension[];
  devices: AdminTemplateAnalyticsDimension[];
  geography: AdminTemplateAnalyticsDimension[];
  feedbackItems: AdminTemplatesAnalyticsFeedbackItem[];
  conversionFunnel: AdminTemplatesAnalyticsFunnel;
  templates: AdminTemplatesAnalyticsTemplateRow[];
  availableCategories: string[];
  generatedAtUtc: string;
};

export type AdminTemplateTestRun = {
  generationId: string;
  userId: string;
  templateId: string;
  status: TemplateGenerationJobStatus;
  tokenCost: number;
  sourceImageAsset?: TemplateAsset;
  normalizedImageUrl?: string | null;
  referenceMotionUrl?: string | null;
  outputUrl?: string | null;
  attemptCount: number;
  usedPreprocessingModel?: string | null;
  usedKlingModel?: string | null;
  preprocessingProviderRequestId?: string | null;
  preprocessingInferenceTimeSeconds?: number | null;
  motionProviderRequestId?: string | null;
  motionInferenceTimeSeconds?: number | null;
  outputVideoDurationSeconds?: number | null;
  motionProviderCostUsd?: number | null;
  failureCode?: string | null;
  failureMessage?: string | null;
  createdAtUtc: string;
  updatedAtUtc: string;
  startedAtUtc?: string | null;
  preprocessingCompletedAtUtc?: string | null;
  motionGenerationCompletedAtUtc?: string | null;
  mediaImportCompletedAtUtc?: string | null;
  completedAtUtc?: string | null;
  userMediaExpired: boolean;
};

export type ImageTemplatePayload = {
  title: string;
  shortDescription: string;
  petPhotoRequirements: string[];
  category: string;
  status: TemplateStatus;
  promoBadgeMode: TemplatePromoBadgeMode;
  tags: string[];
  isPremium: boolean;
  tokenCost: number;
  previewAsset?: TemplateAssetInput;
  imageModel: string;
  imagePrompt: string;
};

export type VideoTemplatePayload = {
  title: string;
  shortDescription: string;
  petPhotoRequirements: string[];
  category: string;
  status: TemplateStatus;
  promoBadgeMode: TemplatePromoBadgeMode;
  tags: string[];
  isPremium: boolean;
  tokenCost: number;
  musicDescription: string;
  previewAsset?: TemplateAssetInput;
  referenceMotionAsset?: TemplateAssetInput;
  preprocessingModel: string;
  preprocessingPrompt: string;
  klingModel: string;
  klingPrompt: string;
  keepOriginalSound: boolean;
};

export type TemplateCategoryPayload = {
  name: string;
};
