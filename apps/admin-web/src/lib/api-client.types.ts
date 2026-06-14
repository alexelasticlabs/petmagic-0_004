export type LegalDocumentSection = {
  heading: string;
  paragraphs: string[];
};

export type LegalDocument = {
  kind: string;
  title: string;
  version: string;
  publishedAtUtc: string;
  summary: string;
  sections: LegalDocumentSection[];
};

export type LegalDocumentsResponse = {
  termsOfUse: LegalDocument;
  privacyPolicy: LegalDocument;
};

export type LegalAcceptanceStatus = {
  termsOfUseAccepted: boolean;
  termsOfUseAcceptedVersion?: string | null;
  termsOfUseAcceptedAtUtc?: string | null;
  privacyPolicyAccepted: boolean;
  privacyPolicyAcceptedVersion?: string | null;
  privacyPolicyAcceptedAtUtc?: string | null;
  currentTermsOfUseVersion: string;
  currentPrivacyPolicyVersion: string;
  requiresAcceptance: boolean;
};

export type AcceptLegalDocumentsCommand = {
  termsOfUseVersion: string;
  privacyPolicyVersion: string;
};

export type UserProfile = {
  userId: string;
  email: string;
  displayName?: string;
  isPremium: boolean;
  emailConfirmed: boolean;
  roles: string[];
  accountStatus?: string;
  termsOfUseAccepted?: boolean;
  privacyPolicyAccepted?: boolean;
  legalAcceptance?: LegalAcceptanceStatus;
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
  accessToken?: string;
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

export type UserListPage = OffsetPagedResponse<UserListItem> & {
  totalCount: number;
};

export type AdminUserDashboardMetrics = {
  totalUsers: number;
  premiumUsers: number;
  activeUsers: number;
  blockedUsers: number;
  adminUsers: number;
  moderatorUsers: number;
  regularUsers: number;
  usersThisWeek: number;
  usersPreviousWeek: number;
  newUsersLast7Days: number;
  newUsersLast30Days: number;
  newUsersLast90Days: number;
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

export type FeedbackType =
  | "GenerationResult"
  | "GenerationFailure"
  | "BugReport"
  | "FeatureRequest"
  | "PaymentIssue"
  | "General";

export type FeedbackStatus = "New" | "InReview" | "Resolved" | "Dismissed";

export type FeedbackPriority = "Low" | "Medium" | "High" | "Critical";

export type AdminFeedbackListItem = {
  id: string;
  userId?: string | null;
  type: FeedbackType | string;
  category: string;
  rating?: number | null;
  generationId?: string | null;
  templateId?: string | null;
  templateTitle?: string | null;
  petId?: string | null;
  sourceScreen: string;
  platform?: string | null;
  status: FeedbackStatus | string;
  priority: FeedbackPriority | string;
  message?: string | null;
  previewUrl?: string | null;
  createdAtUtc: string;
};

export type AdminFeedbackPage = {
  items: AdminFeedbackListItem[];
  totalCount: number;
  skip: number;
  take: number;
  hasMore: boolean;
  generatedAtUtc: string;
};

export type AdminFeedbackGenerationContext = {
  generationId: string;
  userId: string;
  templateId: string;
  templateTitle: string;
  petId?: string | null;
  inputPreviewUrl?: string | null;
  resultPreviewUrl?: string | null;
  providerName?: string | null;
  errorCode?: string | null;
  creditsCharged: number;
  chargedAtUtc?: string | null;
  refundedAtUtc?: string | null;
};

export type CreditRefund = {
  id: string;
  userId: string;
  feedbackId?: string | null;
  generationId?: string | null;
  amount: number;
  reason: string;
  adminId: string;
  createdAtUtc: string;
};

export type AdminFeedbackDetails = {
  id: string;
  userId?: string | null;
  userEmail?: string | null;
  userPlan?: string | null;
  userCredits?: number | null;
  type: FeedbackType | string;
  category: string;
  rating?: number | null;
  message?: string | null;
  sourceScreen: string;
  appVersion?: string | null;
  platform?: string | null;
  deviceModel?: string | null;
  locale?: string | null;
  errorCode?: string | null;
  providerName?: string | null;
  status: FeedbackStatus | string;
  priority: FeedbackPriority | string;
  createdAtUtc: string;
  reviewedAtUtc?: string | null;
  reviewedByAdminId?: string | null;
  adminNote?: string | null;
  generation?: AdminFeedbackGenerationContext | null;
  canRefund: boolean;
  refund?: CreditRefund | null;
};

export type AdminFeedbackQuery = {
  status?: FeedbackStatus | "All";
  priority?: FeedbackPriority | "All";
  type?: FeedbackType | "All";
  category?: string;
  generationId?: string;
  templateId?: string;
  platform?: string;
  fromUtc?: string;
  toUtc?: string;
  userId?: string;
  skip?: number;
  take?: number;
};

export type UpdateFeedbackAdminPayload = {
  status?: FeedbackStatus;
  priority?: FeedbackPriority;
  adminNote?: string;
};

export type RefundFeedbackCreditsPayload = {
  amount?: number;
  reason?: string;
};

export type TemplateFeedbackIssue = {
  category: string;
  count: number;
};

export type TemplateFeedbackSummary = {
  templateId: string;
  positiveCount: number;
  neutralCount: number;
  negativeCount: number;
  positiveRate: number;
  neutralRate: number;
  negativeRate: number;
  topIssues: TemplateFeedbackIssue[];
  hasNegativeWarning: boolean;
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

export type AdminUserPet = {
  id: string;
  userId: string;
  name: string;
  type: string;
  breed?: string | null;
  avatarMediaAssetId?: string | null;
  avatarUrl?: string | null;
  photosCount: number;
  generationsCount: number;
  status: string;
  createdAtUtc: string;
  updatedAtUtc: string;
  isDeleted: boolean;
};

export type AdminUserPetPhoto = {
  id: string;
  petId: string;
  mediaAssetId: string;
  url: string;
  thumbnailUrl?: string | null;
  fileName: string;
  contentType: string;
  fileSizeBytes?: number | null;
  isFavorite: boolean;
  isAvatar: boolean;
  sortOrder: number;
  status: string;
  createdAtUtc: string;
  isDeleted: boolean;
};

export type AdminUserPetGeneration = {
  generationId: string;
  templateId: string;
  status: string;
  tokenCost: number;
  templateTitle?: string | null;
  templateType?: TemplateType | null;
  outputUrl?: string | null;
  failureCode?: string | null;
  failureMessage?: string | null;
  createdAtUtc: string;
  completedAtUtc?: string | null;
  petId?: string | null;
  petPhotoId?: string | null;
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
  totalCount?: number | null;
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
  canRefund?: boolean;
  productType?: string;
  tokenAmount?: number;
  refundStatus?: string;
  createdAtUtc: string;
  confirmedAtUtc?: string | null;
};

export type AdminEconomyDashboardRevenuePoint = {
  date: string;
  amount: number;
};

export type AdminEconomyDashboardMetrics = {
  purchasesThisWeek: number;
  purchasesPreviousWeek: number;
  successfulPaymentsThisWeek: number;
  successfulPaymentsPreviousWeek: number;
  failedPaymentsThisWeek: number;
  failedPaymentsPreviousWeek: number;
  revenueThisWeek: number;
  revenuePreviousWeek: number;
  totalWalletCredits: number;
  totalWalletDebits: number;
  activeSubscriptions: number;
  renewalStops: number;
  currencyCode: string;
  revenueSeries: AdminEconomyDashboardRevenuePoint[];
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
  productId?: string | null;
  autoRenewing?: boolean;
  cancelledAtUtc?: string | null;
  expiredAtUtc?: string | null;
  lastValidatedAtUtc?: string | null;
};

export type AdminEconomyUserSubscriptionSummary = {
  isPremium: boolean;
  provider?: string | null;
  purchaseChannel?: string | null;
  status: string;
  planName?: string | null;
  billingPeriod?: string | null;
  currentPeriodEndUtc?: string | null;
  cancelAtPeriodEnd: boolean;
  monthlyTokenLimit: number;
  tokensAvailable: number;
  canManageSubscription: boolean;
  manageSubscriptionAction: string;
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
  usesLast7d: number;
  grantedLast7d: number;
  maxRedeemedBySingleUser: number;
  redemptions: AdminRedeemCodeRedemption[];
};

export type AdminRedeemCodesPage = OffsetPagedResponse<AdminRedeemCode> & {
  totalCount: number;
};

export type AdminRedeemCodeMetrics = {
  totalCodes: number;
  activeCodes: number;
  totalUses: number;
  totalGranted: number;
  createdLast7d: number;
  activeTouchedLast7d: number;
  usesLast7d: number;
  grantedLast7d: number;
};

export type SupportConversationStatus = "New" | "InProgress" | "WaitingForUser" | "Closed";

export type SupportConversationSource =
  | "MobileChat"
  | "MobileAssistant"
  | "AdminCreated"
  | "System"
  | "Direct";

export type SupportConversationPriority = "Low" | "Normal" | "High";

export type SupportInboxAssignmentScope = "all" | "mine" | "unassigned";

export type AdminSupportMessageAttachment = {
  fileUrl: string;
  type: string;
  mimeType: string;
  fileName: string;
  sizeBytes: number;
  isDeleted?: boolean;
  expiresAtUtc?: string | null;
  deletedAtUtc?: string | null;
  durationSeconds?: number | null;
  width?: number | null;
  height?: number | null;
};

export type AdminSupportMessage = {
  messageId: string;
  conversationId: string;
  senderUserId: string;
  senderDisplayName: string;
  isFromAdmin: boolean;
  senderType: string;
  body: string;
  replyToMessageId?: string | null;
  replyToPreview?: string | null;
  attachmentUrl?: string | null;
  attachmentFileName?: string | null;
  attachmentContentType?: string | null;
  attachmentFileSizeBytes?: number | null;
  attachmentUploadStatus?: string | null;
  attachmentUploadErrorCode?: string | null;
  attachments?: AdminSupportMessageAttachment[] | null;
  isRead: boolean;
  readAtUtc?: string | null;
  deliveredAtUtc?: string | null;
  isInternalNote: boolean;
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
  tags?: string[];
  source: SupportConversationSource;
  assistantScenario?: string | null;
  lastMessagePreview?: string | null;
  lastMessageAtUtc?: string | null;
  lastMessageSenderType?: string | null;
  waitingSinceUtc?: string | null;
  waitingMinutes: number;
  unreadForAdmin: boolean;
  userUnreadCount: number;
  adminUnreadCount: number;
  createdAtUtc: string;
  updatedAtUtc: string;
  resolvedAtUtc?: string | null;
  reopenUntilUtc?: string | null;
  closedAtUtc?: string | null;
  closedByUserId?: string | null;
  reopenedAtUtc?: string | null;
  reopenedByUserId?: string | null;
  feedbackRating?: number | null;
  isReadOnly: boolean;
  canReopen: boolean;
};

export type AdminSupportInboxPage = {
  items: AdminSupportConversationSummary[];
  page: number;
  pageSize: number;
  totalCount: number;
  hasMore: boolean;
};

export type AdminSupportInboxMetrics = {
  totalConversations: number;
  openConversations: number;
  closedConversations: number;
  unassignedConversations: number;
  unreadForAdminConversations: number;
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
  tags?: string[];
  source: SupportConversationSource;
  assistantScenario?: string | null;
  relatedGenerationId?: string | null;
  relatedPaymentId?: string | null;
  relatedSubscriptionId?: string | null;
  userUnreadCount: number;
  adminUnreadCount: number;
  createdAtUtc: string;
  updatedAtUtc: string;
  lastMessageAtUtc?: string | null;
  lastMessagePreview?: string | null;
  lastMessageSenderType?: string | null;
  waitingSinceUtc?: string | null;
  waitingMinutes: number;
  resolvedAtUtc?: string | null;
  reopenUntilUtc?: string | null;
  closedAtUtc?: string | null;
  closedByUserId?: string | null;
  reopenedAtUtc?: string | null;
  reopenedByUserId?: string | null;
  feedbackRating?: number | null;
  feedbackComment?: string | null;
  feedbackSubmittedAtUtc?: string | null;
  isReadOnly: boolean;
  canReopen: boolean;
  availableActions: string[];
  hasOlderMessages?: boolean;
  oldestLoadedMessageCreatedAtUtc?: string | null;
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

export type TemplateGenerationJobStatus =
  | "Queued"
  | "Processing"
  | "Succeeded"
  | "Completed"
  | "Failed"
  | "Cancelled"
  | "Retrying";
export type AdminGenerationStatus =
  | "Pending"
  | "Running"
  | "Completed"
  | "Failed"
  | "Cancelled"
  | "Retrying";

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
  supportsGenerationResultInput?: boolean;
  requiredInputMediaType?: TemplateType | null;
  recommendedAfterImageGeneration?: boolean;
  supportsGenerateSimilar?: boolean;
  defaultVariationStrength?: "low" | "medium" | "high" | string;
};

export type AdminTemplateCatalogPage = {
  items: AdminTemplateListItem[];
  skip: number;
  take: number;
  totalCount: number;
  hasMore: boolean;
};

export type AdminTemplateOfTheDay = {
  id: string;
  templateId: string;
  templateTitle: string;
  templateType: TemplateType;
  category: string;
  status: TemplateStatus;
  isPremium: boolean;
  previewAsset?: TemplateAsset | null;
  startDate: string;
  endDate?: string | null;
  isActive: boolean;
  isManual: boolean;
  priority: number;
  titleOverride?: string | null;
  subtitleOverride?: string | null;
  badgeTextOverride?: string | null;
  createdAtUtc: string;
  updatedAtUtc: string;
  createdByAdminId?: string | null;
};

export type AdminTemplateOfTheDaySchedule = {
  items: AdminTemplateOfTheDay[];
  skip: number;
  take: number;
  totalCount: number;
};

export type AdminTemplateOfTheDaySettings = {
  autoModeEnabled: boolean;
  allowedTypes: "both" | "image" | "video";
  excludeRecentDays: number;
  updatedAtUtc: string;
  updatedByAdminId?: string | null;
};

export type TemplateOfTheDayPayload = {
  templateId: string;
  startDate: string;
  endDate?: string | null;
  isActive: boolean;
  isManual: boolean;
  priority: number;
  titleOverride?: string | null;
  subtitleOverride?: string | null;
  badgeTextOverride?: string | null;
};

export type TemplateOfTheDayAutoPickPayload = {
  date: string;
  allowedTypes?: "both" | "image" | "video";
  excludeRecentDays?: number;
};

export type TemplateOfTheDaySettingsPayload = {
  autoModeEnabled: boolean;
  allowedTypes?: "both" | "image" | "video";
  excludeRecentDays?: number;
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
  supportsGenerationResultInput?: boolean;
  requiredInputMediaType?: TemplateType | null;
  recommendedAfterImageGeneration?: boolean;
  supportsGenerateSimilar?: boolean;
  defaultVariationStrength?: "low" | "medium" | "high" | string;
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

export type AdminModerationStatus = "pending" | "approved" | "rejected";

export type AdminModerationQueueItem = {
  eventId: string;
  templateId: string;
  templateTitle: string;
  templateType: TemplateType;
  eventType: "complaint" | "feedback" | string;
  status: AdminModerationStatus;
  message?: string | null;
  source: string;
  deviceClass: string;
  countryCode: string;
  userId?: string | null;
  generationId?: string | null;
  moderationComment?: string | null;
  createdAtUtc: string;
  moderatedAtUtc?: string | null;
};

export type AdminModerationQueuePage = {
  items: AdminModerationQueueItem[];
  skip: number;
  take: number;
  totalCount: number;
  hasMore: boolean;
  generatedAtUtc: string;
};

export type AdminModerationQueueQuery = {
  status?: AdminModerationStatus | "all";
  search?: string;
  skip?: number;
  take?: number;
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

export type AdminTemplateGenerationDashboardMetrics = {
  totalJobs: number;
  generationsToday: number;
  generationsThisWeek: number;
  generationsThisMonth: number;
  failedGenerationsToday: number;
  failedGenerationsThisWeek: number;
  failedGenerationsThisMonth: number;
  pendingJobs: number;
  runningJobs: number;
  completedJobs: number;
  failedJobs: number;
  cancelledJobs: number;
  retryingJobs: number;
  generatedAtUtc: string;
};

export type AdminTemplateGenerationListItem = {
  generationId: string;
  userId: string;
  templateId: string;
  templateTitle: string;
  templateType: TemplateType;
  status: AdminGenerationStatus;
  provider?: string | null;
  model?: string | null;
  tokenCost: number;
  attemptCount: number;
  providerCostUsd?: number | null;
  failureCode?: string | null;
  failureMessage?: string | null;
  createdAtUtc: string;
  updatedAtUtc: string;
  startedAtUtc?: string | null;
  completedAtUtc?: string | null;
  refundedAtUtc?: string | null;
  isWatermarkRequired: boolean;
  isWatermarkRemoved: boolean;
  watermarkedMediaPath?: string | null;
  watermarkUnlockMethod?: string | null;
  watermarkUnlockedByUserId?: string | null;
  watermarkCreditsSpent?: number | null;
  watermarkUnlockedAtUtc?: string | null;
  parentGenerationId?: string | null;
  parentGenerationResultId?: string | null;
  inputSourceType: "user_upload" | "generation_result" | "pet_photo" | string;
  inputMediaAssetId?: string | null;
  resultMediaAssetId?: string | null;
  inputPreviewUrl?: string | null;
  resultPreviewUrl?: string | null;
  canCompareBeforeAfter: boolean;
  parentTemplateTitle?: string | null;
  parentTemplateType?: TemplateType | null;
  childCount: number;
  similarToGenerationId?: string | null;
  generationMode?: "normal" | "similar" | string;
  variationStrength?: "low" | "medium" | "high" | string | null;
  generationSeed?: number | null;
  promptBeforeVariation?: string | null;
  promptAfterVariation?: string | null;
  petId?: string | null;
  petPhotoId?: string | null;
};

export type AdminTemplateGenerationsQuery = {
  status?: AdminGenerationStatus | "All";
  provider?: string;
  user?: string;
  search?: string;
  skip?: number;
  take?: number;
};

export type AdminTemplateGenerationsPage = {
  items: AdminTemplateGenerationListItem[];
  totalCount: number;
  skip: number;
  take: number;
  hasMore: boolean;
  generatedAtUtc: string;
};

export type AdminWatermarkSettings = {
  enabled: boolean;
  text: string;
  logoUrl?: string | null;
  opacity: number;
  position: string;
  size: string;
  costCredits: number;
  applyToImages: boolean;
  applyToVideos: boolean;
  previewImageUrl: string;
  previewVideoFrameUrl: string;
};

export type RemoveGenerationWatermarkResponse = {
  watermarkRemoved: boolean;
  creditsSpent: number;
  remainingCredits?: number | null;
  mediaUrl?: string | null;
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
  supportsGenerationResultInput?: boolean;
  requiredInputMediaType?: TemplateType | null;
  recommendedAfterImageGeneration?: boolean;
  supportsGenerateSimilar?: boolean;
  defaultVariationStrength?: "low" | "medium" | "high" | string;
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
  supportsGenerationResultInput?: boolean;
  requiredInputMediaType?: TemplateType | null;
  recommendedAfterImageGeneration?: boolean;
  supportsGenerateSimilar?: boolean;
  defaultVariationStrength?: "low" | "medium" | "high" | string;
};

export type TemplateCategoryPayload = {
  name: string;
};
