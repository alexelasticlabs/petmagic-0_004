export type TemplateType = "Image" | "Video";

export type TemplateStatus = "Draft" | "Active" | "Archived";

export type TemplateGenerationJobStatus =
  | "Queued"
  | "Processing"
  | "Completed"
  | "Failed"
  | "Cancelled"
  | "Retrying"
  | "CancellationRequested";

export type AdminGenerationStatus =
  "Pending" | "Running" | "Completed" | "Failed" | "Cancelled" | "Retrying" | "Cancelling";

export type AdminGenerationRefundState = "not_applicable" | "pending" | "exhausted" | "refunded";

export type TemplateGenerationResponse = {
  generationId: string;

  userId: string;

  templateId: string;

  status: string;

  tokenCost: number;

  refundedAtUtc?: string | null;

  canCancel: boolean;
};

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

export type TemplateMediaUploadResponse = TemplateAsset & {
  thumbnailAsset?: TemplateAsset | null;

  animatedPreviewAsset?: TemplateAsset | null;

  feedLoopLowAsset?: TemplateAsset | null;

  feedLoopMediumAsset?: TemplateAsset | null;

  detailPreviewAsset?: TemplateAsset | null;

  wasOptimized?: boolean;
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

  isQaOnly: boolean;

  tokenCost: number;

  tags: string[];

  previewAsset?: TemplateAsset;

  thumbnailAsset?: TemplateAsset | null;

  animatedPreviewAsset?: TemplateAsset | null;

  feedLoopLowAsset?: TemplateAsset | null;

  feedLoopMediumAsset?: TemplateAsset | null;

  detailPreviewAsset?: TemplateAsset | null;

  musicDescription?: string;

  referenceVideoDurationSeconds?: number;

  characterOrientation?: string;

  createdAtUtc: string;

  publishedAtUtc?: string | null;

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

  summary: AdminTemplateCatalogSummary;
};

export type AdminTemplateCatalogSummary = {
  totalTemplates: number;

  imageTemplates: number;

  videoTemplates: number;

  activeTemplates: number;

  draftTemplates: number;

  archivedTemplates: number;

  premiumTemplates: number;

  qaOnlyTemplates: number;

  missingPreviewTemplates: number;
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

  hasMore: boolean;

  generatedAtUtc: string;
};

export type TemplateOfTheDayScheduleQuery = {
  skip?: number;

  take?: number;
};

export type AdminTemplateOfTheDaySettings = {
  autoModeEnabled: boolean;

  allowedTypes: "both" | "image" | "video";

  excludeRecentDays: number;

  businessDate?: string;

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

  isQaOnly: boolean;

  tokenCost: number;

  tags: string[];

  previewAsset?: TemplateAsset;

  thumbnailAsset?: TemplateAsset | null;

  animatedPreviewAsset?: TemplateAsset | null;

  feedLoopLowAsset?: TemplateAsset | null;

  feedLoopMediumAsset?: TemplateAsset | null;

  detailPreviewAsset?: TemplateAsset | null;

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

  publishedAtUtc?: string | null;

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

  leaseOwnerUserId?: string | null;

  leaseClaimedAtUtc?: string | null;

  leaseExpiresAtUtc?: string | null;

  version?: number;
};

export type AdminModerationQueueSummary = {
  pendingCount: number;

  approvedCount: number;

  rejectedCount: number;

  pendingComplaintsCount: number;

  pendingFeedbackCount: number;

  oldestPendingAtUtc?: string | null;

  generatedAtUtc: string;
};

export type AdminModerationQueuePage = {
  items: AdminModerationQueueItem[];

  skip: number;

  take: number;

  totalCount: number;

  hasMore: boolean;

  generatedAtUtc: string;

  summary?: AdminModerationQueueSummary | null;
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

  templateIds?: string[];

  category?: string;

  status?: TemplateStatus | "All";

  access?: "all" | "free" | "premium";

  sort?: "views" | "starts" | "conversion" | "cost" | "tokens" | "updated";

  skip?: number;

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

  skip: number;

  take: number;

  totalCount: number;

  hasMore: boolean;

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

  cancellingJobs: number;

  retryingJobs: number;

  pendingRefunds: number;

  exhaustedRefunds: number;

  generatedAtUtc: string;
};

export type AdminTemplateGenerationCapacityProfile = {
  globalMaxConcurrentGenerations: number;

  imageReservedConcurrentGenerations: number;

  imageProtectedConcurrentGenerations: number;

  imageMaxConcurrentGenerations: number;

  videoReservedConcurrentGenerations: number;

  videoMaxConcurrentGenerations: number;

  videoBorrowMaxConcurrentGenerations: number;

  videoPreprocessingMaxConcurrentGenerations: number;
};

export type AdminTemplateGenerationBalanceState =
  "fresh" | "stale" | "unknown" | "low" | "critical";

export type AdminTemplateGenerationCapacityAlert = {
  alertId: string;

  statusChangedAtUtc: string;

  severity: "info" | "warning" | "critical";

  title: string;

  message: string;
};

export type AdminTemplateGenerationControl = {
  revision: number;

  admissionEnabled: boolean;

  confirmedFalConcurrencyLimit: number;

  confirmedAtUtc?: string | null;

  reservedHeadroom: number;

  applicationHardCeiling: number;

  effectiveGlobalLimit: number;

  policy: AdminTemplateGenerationCapacityProfile;

  effectiveProfile: AdminTemplateGenerationCapacityProfile;

  balance: {
    state: AdminTemplateGenerationBalanceState;
    currentBalanceUsd?: number | null;
    checkedAtUtc?: string | null;
    lastSuccessfulAtUtc?: string | null;
  };

  queue: {
    totalDepth: number;
    imageDepth: number;
    videoDepth: number;
    oldestQueuedAtUtc?: string | null;
    stages: Array<{
      stage: string;
      count: number;
      oldestAtUtc?: string | null;
    }>;
  };

  lanes: {
    inFlightTotal: number;
    imageInFlight: number;
    videoInFlight: number;
    videoPreprocessingInFlight: number;
    nativeSlotsInUse: number;
    borrowedSlotsInUse: number;
    reservedSlotsAvailable: number;
    submissionUnknownCount: number;
  };

  worker: {
    instanceCount: number;
    heartbeatAtUtc?: string | null;
    lastProgressAtUtc?: string | null;
    appliedPolicyRevision?: number | null;
    schedulerV2Enabled: boolean | null;
    dispatchConcurrency: number | null;
    reconciliationConcurrency: number | null;
    mediaImportConcurrency: number | null;
    maintenanceConcurrency: number | null;
  };

  alerts: AdminTemplateGenerationCapacityAlert[];

  generatedAtUtc: string;
};

export type AdminTemplateGenerationProviderRefresh = {
  outcome: "refreshed" | "coalesced" | "failed";

  checkedAtUtc?: string | null;

  lastSuccessfulAtUtc?: string | null;

  errorCode?: string | null;

  control: AdminTemplateGenerationControl;
};

export type UpdateAdminTemplateGenerationControlPolicy = {
  expectedRevision: number;

  reason: string;

  admissionEnabled: boolean;

  confirmedFalConcurrencyLimit: number;

  reservedHeadroom: number;

  applicationHardCeiling: number;

  confirmFalConcurrencyLimit: boolean;

  idempotencyKey: string;
};

export type ResolveAdminTemplateProviderAttempt = {
  attemptId: string;

  expectedAttemptVersion: number;

  resolution: "correlated_accepted" | "confirmed_not_found";

  reason: string;

  evidenceReference: string;

  providerRequestId?: string | null;

  providerStatusUrl?: string | null;

  providerResponseUrl?: string | null;

  providerCancelUrl?: string | null;

  idempotencyKey: string;
};

export type AdminTemplateProviderAttemptResolution = {
  providerAttemptId: string;

  generationId: string;

  resolution: "correlated_accepted" | "confirmed_not_found";

  attemptState: string;

  attemptVersion: number;

  refundScheduled: boolean;

  resolvedAtUtc: string;
};

export type AdminTemplateProviderAttemptRecoveryItem = {
  attemptId: string;

  generationId: string;

  stage: string;

  ordinal: number;

  state: string;

  attemptVersion: number;

  providerRequestId?: string | null;

  createdAtUtc: string;

  updatedAtUtc: string;

  submittedAtUtc?: string | null;

  submissionDeadlineAtUtc: string;

  processingDeadlineAtUtc: string;

  reconciliationDeadlineAtUtc: string;

  errorCode?: string | null;

  evidenceNeeded: string;
};

export type AdminTemplateProviderAttemptRecoveryPage = {
  items: AdminTemplateProviderAttemptRecoveryItem[];

  totalCount: number;

  skip: number;

  take: number;

  hasMore: boolean;

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

  chargedAtUtc?: string | null;

  refundState: AdminGenerationRefundState;

  refundAttemptCount: number;

  refundAttemptLimit: number;

  refundLastAttemptedAtUtc?: string | null;

  refundLastErrorCode?: string | null;

  canRetryRefund: boolean;

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

  canCancel: boolean;

  canRetry: boolean;

  gamificationLegacyReviewRequired?: boolean;
};

export type AdminGamificationLegacyDeliveryResolutionAction = "mark_delivered" | "replay";

export type AdminGamificationLegacyDeliveryResolutionResponse = {
  generationId: string;

  action: AdminGamificationLegacyDeliveryResolutionAction;

  replayQueued: boolean;

  resolvedAtUtc: string;
};

export type AdminTemplateGenerationsQuery = {
  status?: AdminGenerationStatus | "All";

  refundState?: AdminGenerationRefundState | "all";

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

export type AdminGenerationDetail = {
  generation: AdminTemplateGenerationListItem;

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

  isQaOnly?: boolean;

  tokenCost: number;

  previewAsset?: TemplateAssetInput;

  keepPreviewAsset?: boolean;

  thumbnailAsset?: TemplateAssetInput;

  animatedPreviewAsset?: TemplateAssetInput;

  feedLoopLowAsset?: TemplateAssetInput;

  feedLoopMediumAsset?: TemplateAssetInput;

  detailPreviewAsset?: TemplateAssetInput;

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

  isQaOnly?: boolean;

  tokenCost: number;

  musicDescription: string;

  previewAsset?: TemplateAssetInput;

  keepPreviewAsset?: boolean;

  thumbnailAsset?: TemplateAssetInput;

  animatedPreviewAsset?: TemplateAssetInput;

  feedLoopLowAsset?: TemplateAssetInput;

  feedLoopMediumAsset?: TemplateAssetInput;

  detailPreviewAsset?: TemplateAssetInput;

  referenceMotionAsset?: TemplateAssetInput;

  keepReferenceMotionAsset?: boolean;

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
