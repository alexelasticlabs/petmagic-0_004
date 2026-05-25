"use client";

import { useSyncExternalStore } from "react";

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

const AUTH_KEY = "petmagic_admin_auth";
const AUTH_SESSION_EVENT = "petmagic_admin_auth_changed";
const ADMIN_LIST_CACHE_TTL_MS = 120_000;
const API_REQUEST_TIMEOUT_MS = 15_000;

function getApiBaseUrl(): string {
  if (typeof window === "undefined") {
    return (
      process.env.INTERNAL_API_BASE_URL ??
      process.env.NEXT_PUBLIC_API_BASE_URL ??
      "http://localhost:5000"
    );
  }

  return process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:5000";
}

type ApiError = Error & {
  status?: number;
  detail?: string;
  code?: string;
  validationErrors?: string[];
};
type AuthSessionSnapshot = AuthSession | null | undefined;

let cachedAuthRaw: string | null | undefined;
let cachedAuthSession: AuthSession | null = null;
let volatileRefreshToken: string | null = null;
const cachedUsersLists = new Map<string, { value: UserListItem[]; expiresAt: number }>();
const cachedAdminUserDetails = new Map<string, { value: AdminUserDetail; expiresAt: number }>();
const cachedAdminUserAnalytics = new Map<
  string,
  { value: AdminUserAnalytics; expiresAt: number }
>();
const cachedSupportInbox = new Map<
  string,
  { value: AdminSupportConversationSummary[]; expiresAt: number }
>();
const cachedSupportConversations = new Map<
  string,
  { value: AdminSupportConversation; expiresAt: number }
>();
const cachedSupportTemplates = new Map<
  string,
  { value: AdminSupportReplyTemplate[]; expiresAt: number }
>();
const cachedTemplateLists = new Map<
  string,
  { value: AdminTemplateListItem[]; expiresAt: number }
>();
const cachedTemplateCategories = new Map<
  string,
  { value: AdminTemplateCategory[]; expiresAt: number }
>();
const cachedTemplatesAnalyticsOverview = new Map<
  string,
  { value: AdminTemplatesAnalyticsOverview; expiresAt: number }
>();
const cachedAdminTemplateDetails = new Map<string, { value: AdminTemplate; expiresAt: number }>();
const cachedAdminTemplateStatistics = new Map<
  string,
  { value: AdminTemplateStatistics; expiresAt: number }
>();
const cachedAdminTemplateTrends = new Map<
  string,
  { value: AdminTemplateTrendPoint[]; expiresAt: number }
>();
const cachedAdminTemplateRecentGenerations = new Map<
  string,
  { value: AdminTemplateRecentGeneration[]; expiresAt: number }
>();
const cachedAdminTemplateFailureBreakdowns = new Map<
  string,
  { value: AdminTemplateFailureBreakdownItem[]; expiresAt: number }
>();
const cachedAdminTemplateEventAnalytics = new Map<
  string,
  { value: AdminTemplateEventAnalytics; expiresAt: number }
>();
const inflightGetRequests = new Map<string, Promise<unknown>>();

function clearAdminListCaches(): void {
  cachedUsersLists.clear();
  cachedAdminUserDetails.clear();
  cachedAdminUserAnalytics.clear();
  cachedSupportInbox.clear();
  cachedSupportConversations.clear();
  cachedSupportTemplates.clear();
  cachedTemplateLists.clear();
  cachedTemplateCategories.clear();
  cachedTemplatesAnalyticsOverview.clear();
  cachedAdminTemplateDetails.clear();
  cachedAdminTemplateStatistics.clear();
  cachedAdminTemplateTrends.clear();
  cachedAdminTemplateRecentGenerations.clear();
  cachedAdminTemplateFailureBreakdowns.clear();
  cachedAdminTemplateEventAnalytics.clear();
  inflightGetRequests.clear();
}

function getTemplateListCacheKey(type?: TemplateType): string {
  return type ?? "all";
}

function getAnalyticsOverviewCacheKey(query: AdminTemplatesAnalyticsQuery): string {
  return JSON.stringify({
    periodDays: query.periodDays ?? null,
    templateType: query.templateType ?? null,
    category: query.category ?? null,
    status: query.status ?? null,
    access: query.access ?? null,
    sort: query.sort ?? null,
    take: query.take ?? null,
  });
}

function getTemplateRecentGenerationsCacheKey(templateId: string, take?: number): string {
  return `${templateId}:${take ?? "default"}`;
}

async function cachedGet<TResponse>(
  cacheKey: string,
  cache: Map<string, { value: TResponse; expiresAt: number }>,
  request: () => Promise<TResponse>
): Promise<TResponse> {
  const now = Date.now();
  const cached = cache.get(cacheKey);
  if (cached && cached.expiresAt > now) {
    return cached.value;
  }

  const inflight = inflightGetRequests.get(cacheKey) as Promise<TResponse> | undefined;
  if (inflight) {
    return inflight;
  }

  const promise = request()
    .then((value) => {
      cache.set(cacheKey, { value, expiresAt: Date.now() + ADMIN_LIST_CACHE_TTL_MS });
      return value;
    })
    .finally(() => {
      inflightGetRequests.delete(cacheKey);
    });

  inflightGetRequests.set(cacheKey, promise);
  return promise;
}

export function getSession(): AuthSession | null {
  if (typeof window === "undefined") {
    return null;
  }

  const raw = window.sessionStorage.getItem(AUTH_KEY);
  if (raw === cachedAuthRaw) {
    return cachedAuthSession;
  }

  cachedAuthRaw = raw;
  if (!raw) {
    cachedAuthSession = null;
    return null;
  }

  try {
    const parsed = JSON.parse(raw) as AuthSession;
    if (typeof parsed.refreshToken === "string" && parsed.refreshToken.trim().length > 0) {
      volatileRefreshToken = parsed.refreshToken;
    }

    cachedAuthSession = parsed;
    return cachedAuthSession;
  } catch {
    cachedAuthSession = null;
    return null;
  }
}

export function isAuthSessionExpired(session: AuthSession | null | undefined): boolean {
  if (!session?.expiresAtUtc) {
    return true;
  }

  const expiresAtMs = Date.parse(session.expiresAtUtc);
  return Number.isNaN(expiresAtMs) || expiresAtMs <= Date.now();
}

function notifyAuthSessionChanged(): void {
  cachedAuthRaw = undefined;

  if (typeof window !== "undefined") {
    window.dispatchEvent(new Event(AUTH_SESSION_EVENT));
  }
}

function subscribeAuthSession(onStoreChange: () => void): () => void {
  if (typeof window === "undefined") {
    return () => {};
  }

  function handleStorage(event: StorageEvent) {
    if (event.key === AUTH_KEY) {
      cachedAuthRaw = undefined;
      onStoreChange();
    }
  }

  window.addEventListener("storage", handleStorage);
  window.addEventListener(AUTH_SESSION_EVENT, onStoreChange);
  return () => {
    window.removeEventListener("storage", handleStorage);
    window.removeEventListener(AUTH_SESSION_EVENT, onStoreChange);
  };
}

function getAuthSessionSnapshot(): AuthSessionSnapshot {
  return getSession();
}

function getServerAuthSessionSnapshot(): AuthSessionSnapshot {
  return undefined;
}

export function useAuthSession(): AuthSessionSnapshot {
  return useSyncExternalStore(
    subscribeAuthSession,
    getAuthSessionSnapshot,
    getServerAuthSessionSnapshot
  );
}

export function clearSession(): void {
  clearAdminListCaches();
  volatileRefreshToken = null;

  if (typeof window !== "undefined") {
    window.sessionStorage.removeItem(AUTH_KEY);
    notifyAuthSessionChanged();
  }
}

function sanitizeSessionForStorage(session: AuthSession): AuthSession {
  return { ...session, refreshToken: undefined };
}

function saveSession(session: AuthSession): void {
  clearAdminListCaches();
  volatileRefreshToken = session.refreshToken?.trim() ? session.refreshToken : null;

  if (typeof window !== "undefined") {
    window.sessionStorage.setItem(AUTH_KEY, JSON.stringify(sanitizeSessionForStorage(session)));
    notifyAuthSessionChanged();
  }
}

async function apiRequest<TResponse>(
  path: string,
  init: RequestInit,
  options: { requireAuth?: boolean; allowRefresh?: boolean } = {}
): Promise<TResponse> {
  const requireAuth = options.requireAuth ?? true;
  const allowRefresh = options.allowRefresh ?? true;
  const session = getSession();

  const headers = new Headers(init.headers);
  if (typeof init.body !== "undefined" && !(init.body instanceof FormData)) {
    headers.set("Content-Type", "application/json");
  }

  if (requireAuth && session?.accessToken) {
    headers.set("Authorization", `Bearer ${session.accessToken}`);
  }

  const abortController = new AbortController();
  let isTimedOut = false;
  const abortHandler = () => {
    abortController.abort();
  };

  if (init.signal) {
    if (init.signal.aborted) {
      abortController.abort();
    } else {
      init.signal.addEventListener("abort", abortHandler, { once: true });
    }
  }

  const timeoutId = globalThis.setTimeout(() => {
    isTimedOut = true;
    abortController.abort();
  }, API_REQUEST_TIMEOUT_MS);

  let response: Response;

  try {
    response = await fetch(`${getApiBaseUrl()}${path}`, {
      ...init,
      headers,
      credentials: "include",
      signal: abortController.signal,
    });
  } catch (error) {
    if (isTimedOut) {
      const timeoutError = new Error("API request timed out") as ApiError;
      timeoutError.code = "request.timeout";
      timeoutError.detail = `Request exceeded ${API_REQUEST_TIMEOUT_MS / 1000} seconds.`;
      throw timeoutError;
    }

    throw error;
  } finally {
    globalThis.clearTimeout(timeoutId);

    if (init.signal) {
      init.signal.removeEventListener("abort", abortHandler);
    }
  }

  if (response.status === 401 && allowRefresh && requireAuth) {
    const refreshed = await refreshSession();
    if (refreshed) {
      return apiRequest<TResponse>(path, init, { requireAuth, allowRefresh: false });
    }
  }

  if (!response.ok) {
    const error = new Error(`API request failed with status ${response.status}`) as ApiError;
    error.status = response.status;

    try {
      const problem = (await response.json()) as {
        title?: string;
        detail?: string;
        errors?: Record<string, string[]>;
      };
      error.code = problem.title;
      error.detail = problem.detail;
      const validationErrors = Object.values(problem.errors ?? {})
        .flat()
        .map((value) => value.trim())
        .filter(Boolean);

      if (validationErrors.length > 0) {
        error.validationErrors = validationErrors;
      }

      if (problem.detail) {
        error.message = problem.detail;
      } else if (validationErrors.length > 0) {
        error.message = validationErrors.join(" ");
      } else if (problem.title) {
        error.message = problem.title;
      }
    } catch {
      // Ignore invalid or empty error payloads and fall back to the generic message.
    }

    throw error;
  }

  if (response.status === 204) {
    return undefined as TResponse;
  }

  return (await response.json()) as TResponse;
}

async function refreshSession(): Promise<boolean> {
  const body = volatileRefreshToken?.trim()
    ? JSON.stringify({ refreshToken: volatileRefreshToken })
    : undefined;

  try {
    const refreshed = await apiRequest<AuthSession>(
      "/api/auth/refresh",
      {
        method: "POST",
        body,
      },
      {
        requireAuth: false,
        allowRefresh: false,
      }
    );

    saveSession(refreshed);
    return true;
  } catch {
    clearSession();
    return false;
  }
}

export async function login(email: string, password: string): Promise<AuthSession> {
  const session = await apiRequest<AuthSession>(
    "/api/auth/login",
    {
      method: "POST",
      body: JSON.stringify({ email, password }),
    },
    {
      requireAuth: false,
      allowRefresh: false,
    }
  );

  saveSession(session);
  return session;
}

export async function logout(): Promise<void> {
  const session = getSession();
  const refreshToken = volatileRefreshToken?.trim() ? volatileRefreshToken : null;

  clearSession();

  if (session?.accessToken || refreshToken) {
    const headers = new Headers();
    const requestBody = refreshToken ? JSON.stringify({ refreshToken }) : undefined;

    if (requestBody) {
      headers.set("Content-Type", "application/json");
    }

    if (session?.accessToken) {
      headers.set("Authorization", `Bearer ${session.accessToken}`);
    }

    void fetch(`${getApiBaseUrl()}/api/auth/logout`, {
      method: "POST",
      headers,
      body: requestBody,
      credentials: "include",
    }).catch(() => {
      // Logout must stay locally instant even when the API is slow or unavailable.
    });
  }
}

export async function fetchUsers(): Promise<UserListItem[]> {
  return cachedGet("users", cachedUsersLists, () =>
    apiRequest<UserListItem[]>("/api/admin/users/", { method: "GET" })
  );
}

export async function fetchAdminUser(userId: string): Promise<AdminUserDetail> {
  return cachedGet(`admin-user:${userId}`, cachedAdminUserDetails, () =>
    apiRequest<AdminUserDetail>(`/api/admin/users/${userId}`, { method: "GET" })
  );
}

export async function fetchAdminUserAnalytics(userId: string): Promise<AdminUserAnalytics> {
  return cachedGet(`admin-user-analytics:${userId}`, cachedAdminUserAnalytics, () =>
    apiRequest<AdminUserAnalytics>(`/api/admin/users/${userId}/analytics`, { method: "GET" })
  );
}

export async function adjustAdminUserWallet(
  userId: string,
  operation: "credit" | "debit",
  amount: number,
  reason: string
): Promise<AdminUserWalletOperation> {
  const result = await apiRequest<AdminUserWalletOperation>(`/api/admin/users/${userId}/wallet`, {
    method: "POST",
    body: JSON.stringify({ operation, amount, reason }),
  });

  cachedUsersLists.clear();
  cachedAdminUserDetails.delete(`admin-user:${userId}`);
  cachedAdminUserAnalytics.delete(`admin-user-analytics:${userId}`);
  return result;
}

export async function fetchAdminEconomyLedger(params?: {
  skip?: number;
  take?: number;
  source?: string;
  userId?: string;
}): Promise<OffsetPagedResponse<AdminEconomyLedgerItem>> {
  const search = new URLSearchParams();
  if (params?.skip) search.set("skip", String(params.skip));
  if (params?.take) search.set("take", String(params.take));
  if (params?.source) search.set("source", params.source);
  if (params?.userId) search.set("userId", params.userId);

  const query = search.size ? `?${search.toString()}` : "";
  return apiRequest<OffsetPagedResponse<AdminEconomyLedgerItem>>(
    `/api/admin/economy/ledger${query}`,
    { method: "GET" }
  );
}

export async function fetchAdminEconomyPurchases(params?: {
  skip?: number;
  take?: number;
  status?: string;
}): Promise<OffsetPagedResponse<AdminEconomyPurchase>> {
  const search = new URLSearchParams();
  if (params?.skip) search.set("skip", String(params.skip));
  if (params?.take) search.set("take", String(params.take));
  if (params?.status) search.set("status", params.status);

  const query = search.size ? `?${search.toString()}` : "";
  return apiRequest<OffsetPagedResponse<AdminEconomyPurchase>>(
    `/api/admin/economy/purchases${query}`,
    { method: "GET" }
  );
}

export async function fetchAdminEconomySubscriptions(params?: {
  skip?: number;
  take?: number;
  status?: string;
  provider?: string;
}): Promise<OffsetPagedResponse<AdminEconomySubscription>> {
  const search = new URLSearchParams();
  if (params?.skip) search.set("skip", String(params.skip));
  if (params?.take) search.set("take", String(params.take));
  if (params?.status) search.set("status", params.status);
  if (params?.provider) search.set("provider", params.provider);

  const query = search.size ? `?${search.toString()}` : "";
  return apiRequest<OffsetPagedResponse<AdminEconomySubscription>>(
    `/api/admin/economy/subscriptions${query}`,
    { method: "GET" }
  );
}

export async function fetchAdminSubscriptionPlans(): Promise<AdminSubscriptionPlan[]> {
  return apiRequest<AdminSubscriptionPlan[]>("/api/admin/economy/subscription-plans", {
    method: "GET",
  });
}

export async function fetchAdminPaymentProviderConfigs(): Promise<
  AdminPaymentProviderConfiguration[]
> {
  return apiRequest<AdminPaymentProviderConfiguration[]>(
    "/api/admin/economy/payment-provider-configs",
    { method: "GET" }
  );
}

export async function updateAdminSubscriptionPlan(
  planId: string,
  payload: Pick<
    AdminSubscriptionPlan,
    | "name"
    | "priceAmount"
    | "currencyCode"
    | "monthlyTokenLimit"
    | "isRecommended"
    | "isActive"
    | "appleProductId"
    | "googleProductId"
    | "stripePriceId"
    | "displayOrder"
  >
): Promise<AdminSubscriptionPlan> {
  return apiRequest<AdminSubscriptionPlan>(`/api/admin/economy/subscription-plans/${planId}`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export async function updateAdminPaymentProviderConfig(
  configurationId: string,
  payload: Pick<
    AdminPaymentProviderConfiguration,
    | "region"
    | "isEnabled"
    | "isRecommended"
    | "isSelectedByDefault"
    | "requiresExternalWarning"
    | "requiresStoreDisclosure"
    | "allowedFromAppVersion"
    | "externalCheckoutAllowed"
    | "bonusTokensPercent"
    | "displayLabel"
    | "displaySubtitle"
    | "warningTitle"
    | "warningMessage"
    | "mode"
    | "notes"
  >
): Promise<AdminPaymentProviderConfiguration> {
  return apiRequest<AdminPaymentProviderConfiguration>(
    `/api/admin/economy/payment-provider-configs/${configurationId}`,
    {
      method: "PUT",
      body: JSON.stringify(payload),
    }
  );
}

export async function fetchAdminSubscriptionEvents(params?: {
  skip?: number;
  take?: number;
  provider?: string;
  status?: string;
}): Promise<OffsetPagedResponse<AdminSubscriptionEvent>> {
  const search = new URLSearchParams();
  if (params?.skip) search.set("skip", String(params.skip));
  if (params?.take) search.set("take", String(params.take));
  if (params?.provider) search.set("provider", params.provider);
  if (params?.status) search.set("status", params.status);

  const query = search.size ? `?${search.toString()}` : "";
  return apiRequest<OffsetPagedResponse<AdminSubscriptionEvent>>(
    `/api/admin/economy/subscription-events${query}`,
    { method: "GET" }
  );
}

export async function fetchAdminCurrencyPacks(): Promise<AdminCurrencyPack[]> {
  return apiRequest<AdminCurrencyPack[]>("/api/admin/economy/packs", { method: "GET" });
}

export async function updateAdminCurrencyPack(
  packId: string,
  payload: Pick<
    AdminCurrencyPack,
    "displayName" | "priceAmount" | "grantedSpark" | "bonusSpark" | "isActive" | "sortOrder"
  >
): Promise<AdminCurrencyPack> {
  return apiRequest<AdminCurrencyPack>(`/api/admin/economy/packs/${packId}`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export async function fetchAdminRedeemCodes(): Promise<AdminRedeemCode[]> {
  return apiRequest<AdminRedeemCode[]>("/api/admin/economy/redeem-codes", { method: "GET" });
}

export async function createAdminRedeemCode(payload: {
  code: string;
  description: string;
  campaignName?: string | null;
  campaignChannel?: string | null;
  minimumSuccessfulPurchases?: number;
  createdBy?: string | null;
  rewardKind: AdminRedeemRewardKind;
  rewardValue: number;
  maxRedemptions: number;
  maxRedemptionsPerUser: number;
  isActive: boolean;
  startsAtUtc?: string | null;
  expiresAtUtc?: string | null;
}): Promise<AdminRedeemCode> {
  return apiRequest<AdminRedeemCode>("/api/admin/economy/redeem-codes", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function fetchAdminRedeemCodeActivations(
  redeemCodeId: string,
  params?: {
    skip?: number;
    take?: number;
    userId?: string;
  }
): Promise<OffsetPagedResponse<AdminRedeemCodeRedemption>> {
  const search = new URLSearchParams();
  if (params?.skip) search.set("skip", String(params.skip));
  if (params?.take) search.set("take", String(params.take));
  if (params?.userId) search.set("userId", params.userId);

  const query = search.size ? `?${search.toString()}` : "";
  return apiRequest<OffsetPagedResponse<AdminRedeemCodeRedemption>>(
    `/api/admin/economy/redeem-codes/${redeemCodeId}/activations${query}`,
    { method: "GET" }
  );
}

export async function updateAdminRedeemCode(
  redeemCodeId: string,
  payload: Pick<
    AdminRedeemCode,
    | "description"
    | "campaignName"
    | "campaignChannel"
    | "minimumSuccessfulPurchases"
    | "createdBy"
    | "rewardKind"
    | "rewardValue"
    | "maxRedemptions"
    | "maxRedemptionsPerUser"
    | "isActive"
    | "startsAtUtc"
    | "expiresAtUtc"
  >
): Promise<AdminRedeemCode> {
  return apiRequest<AdminRedeemCode>(`/api/admin/economy/redeem-codes/${redeemCodeId}`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export async function assignRole(userId: string, role: string): Promise<void> {
  await apiRequest<void>(`/api/admin/users/${userId}/role`, {
    method: "PUT",
    body: JSON.stringify({ role }),
  });
  cachedUsersLists.clear();
  cachedAdminUserDetails.delete(`admin-user:${userId}`);
  cachedAdminUserAnalytics.delete(`admin-user-analytics:${userId}`);
}

export async function revokeRole(userId: string, role: string): Promise<void> {
  await apiRequest<void>(`/api/admin/users/${userId}/role`, {
    method: "DELETE",
    body: JSON.stringify({ role }),
  });
  cachedUsersLists.clear();
  cachedAdminUserDetails.delete(`admin-user:${userId}`);
  cachedAdminUserAnalytics.delete(`admin-user-analytics:${userId}`);
}

export async function setPremium(userId: string, isPremium: boolean): Promise<void> {
  await apiRequest<void>(`/api/admin/users/${userId}/premium`, {
    method: "PUT",
    body: JSON.stringify({ isPremium }),
  });
  cachedUsersLists.clear();
  cachedAdminUserDetails.delete(`admin-user:${userId}`);
  cachedAdminUserAnalytics.delete(`admin-user-analytics:${userId}`);
}

export async function setActive(userId: string, isActive: boolean): Promise<void> {
  await apiRequest<void>(`/api/admin/users/${userId}/active`, {
    method: "PUT",
    body: JSON.stringify({ isActive }),
  });
  cachedUsersLists.clear();
  cachedAdminUserDetails.delete(`admin-user:${userId}`);
  cachedAdminUserAnalytics.delete(`admin-user-analytics:${userId}`);
}

export async function fetchSupportInbox(
  status?: SupportConversationStatus,
  assignment: SupportInboxAssignmentScope = "all"
): Promise<AdminSupportConversationSummary[]> {
  const cacheKey = `support-inbox:${status ?? "all"}:${assignment}`;
  const searchParams = new URLSearchParams();
  if (status) {
    searchParams.set("status", status);
  }
  if (assignment !== "all") {
    searchParams.set("assignment", assignment);
  }

  const query = searchParams.size > 0 ? `?${searchParams.toString()}` : "";

  return cachedGet(cacheKey, cachedSupportInbox, () =>
    apiRequest<AdminSupportConversationSummary[]>(`/api/admin/support/conversations${query}`, {
      method: "GET",
    })
  );
}

export async function fetchSupportConversation(
  conversationId: string
): Promise<AdminSupportConversation> {
  return cachedGet(`support-conversation:${conversationId}`, cachedSupportConversations, () =>
    apiRequest<AdminSupportConversation>(`/api/admin/support/conversations/${conversationId}`, {
      method: "GET",
    })
  );
}

export async function sendSupportMessage(
  conversationId: string,
  body: string
): Promise<AdminSupportMessage> {
  const message = await apiRequest<AdminSupportMessage>(
    `/api/admin/support/conversations/${conversationId}/messages`,
    {
      method: "POST",
      body: JSON.stringify({ body }),
    }
  );

  clearSupportCaches(conversationId);
  return message;
}

export async function sendSupportAttachment(
  conversationId: string,
  file: File,
  body?: string
): Promise<AdminSupportMessage> {
  const formData = new FormData();
  const trimmedBody = body?.trim();
  if (trimmedBody) {
    formData.append("body", trimmedBody);
  }

  formData.append("file", file);

  const message = await apiRequest<AdminSupportMessage>(
    `/api/admin/support/conversations/${conversationId}/attachments`,
    {
      method: "POST",
      body: formData,
    }
  );

  clearSupportCaches(conversationId);
  return message;
}

export async function markSupportConversationRead(conversationId: string): Promise<void> {
  await apiRequest<void>(`/api/admin/support/conversations/${conversationId}/read`, {
    method: "POST",
  });

  clearSupportCaches(conversationId);
}

export async function updateSupportConversationStatus(
  conversationId: string,
  status: SupportConversationStatus
): Promise<AdminSupportConversation> {
  const conversation = await apiRequest<AdminSupportConversation>(
    `/api/admin/support/conversations/${conversationId}/status`,
    {
      method: "PUT",
      body: JSON.stringify({ status }),
    }
  );

  clearSupportCaches(conversationId);
  return conversation;
}

export async function assignSupportConversation(
  conversationId: string,
  assignedAdminId?: string | null
): Promise<AdminSupportConversation> {
  const conversation = await apiRequest<AdminSupportConversation>(
    `/api/admin/support/conversations/${conversationId}/assignment`,
    {
      method: "PUT",
      body: JSON.stringify({ assignedAdminId: assignedAdminId ?? null }),
    }
  );

  clearSupportCaches(conversationId);
  return conversation;
}

export async function fetchSupportReplyTemplates(): Promise<AdminSupportReplyTemplate[]> {
  return cachedGet("support-templates", cachedSupportTemplates, () =>
    apiRequest<AdminSupportReplyTemplate[]>("/api/admin/support/templates", { method: "GET" })
  );
}

export async function createSupportReplyTemplate(payload: {
  title: string;
  body: string;
  isEnabled: boolean;
  sortOrder: number;
}): Promise<AdminSupportReplyTemplate> {
  const template = await apiRequest<AdminSupportReplyTemplate>("/api/admin/support/templates", {
    method: "POST",
    body: JSON.stringify(payload),
  });

  clearSupportTemplateCaches();
  return template;
}

export async function updateSupportReplyTemplate(
  templateId: string,
  payload: {
    title: string;
    body: string;
    isEnabled: boolean;
    sortOrder: number;
  }
): Promise<AdminSupportReplyTemplate> {
  const template = await apiRequest<AdminSupportReplyTemplate>(
    `/api/admin/support/templates/${templateId}`,
    {
      method: "PUT",
      body: JSON.stringify(payload),
    }
  );

  clearSupportTemplateCaches();
  return template;
}

export async function deleteSupportReplyTemplate(templateId: string): Promise<void> {
  await apiRequest<void>(`/api/admin/support/templates/${templateId}`, {
    method: "DELETE",
  });

  clearSupportTemplateCaches();
}

export async function fetchAdminTemplates(type?: TemplateType): Promise<AdminTemplateListItem[]> {
  const cacheKey = getTemplateListCacheKey(type);
  const query = type ? `?type=${encodeURIComponent(type)}` : "";

  return cachedGet(`templates:${cacheKey}`, cachedTemplateLists, () =>
    apiRequest<AdminTemplateListItem[]>(`/api/admin/templates/${query}`, { method: "GET" })
  );
}

export async function fetchAdminTemplateCategories(
  includeArchived = true
): Promise<AdminTemplateCategory[]> {
  const cacheKey = includeArchived ? "archived" : "active";
  const query = includeArchived ? "?includeArchived=true" : "?includeArchived=false";

  return cachedGet(`template-categories:${cacheKey}`, cachedTemplateCategories, () =>
    apiRequest<AdminTemplateCategory[]>(`/api/admin/templates/categories/${query}`, {
      method: "GET",
    })
  );
}

export async function createTemplateCategory(
  payload: TemplateCategoryPayload
): Promise<AdminTemplateCategory> {
  const category = await apiRequest<AdminTemplateCategory>("/api/admin/templates/categories/", {
    method: "POST",
    body: JSON.stringify(payload),
  });
  clearAdminListCaches();
  return category;
}

export async function updateTemplateCategory(
  categoryId: string,
  payload: TemplateCategoryPayload
): Promise<AdminTemplateCategory> {
  const category = await apiRequest<AdminTemplateCategory>(
    `/api/admin/templates/categories/${categoryId}`,
    {
      method: "PUT",
      body: JSON.stringify(payload),
    }
  );
  clearAdminListCaches();
  return category;
}

export async function changeTemplateCategoryArchiveState(
  categoryId: string,
  isArchived: boolean
): Promise<AdminTemplateCategory> {
  const category = await apiRequest<AdminTemplateCategory>(
    `/api/admin/templates/categories/${categoryId}/archive`,
    {
      method: "PUT",
      body: JSON.stringify({ isArchived }),
    }
  );
  clearAdminListCaches();
  return category;
}

export async function deleteTemplateCategory(categoryId: string): Promise<void> {
  await apiRequest<void>(`/api/admin/templates/categories/${categoryId}`, {
    method: "DELETE",
  });
  clearAdminListCaches();
}

export async function fetchAdminTemplate(templateId: string): Promise<AdminTemplate> {
  return cachedGet(`admin-template:${templateId}`, cachedAdminTemplateDetails, () =>
    apiRequest<AdminTemplate>(`/api/admin/templates/${templateId}`, { method: "GET" })
  );
}

export async function fetchAdminTemplateStatistics(
  templateId: string
): Promise<AdminTemplateStatistics> {
  return cachedGet(`admin-template-statistics:${templateId}`, cachedAdminTemplateStatistics, () =>
    apiRequest<AdminTemplateStatistics>(`/api/admin/templates/${templateId}/statistics`, {
      method: "GET",
    })
  );
}

export async function fetchAdminTemplateTrends(
  templateId: string
): Promise<AdminTemplateTrendPoint[]> {
  return cachedGet(`admin-template-trends:${templateId}`, cachedAdminTemplateTrends, () =>
    apiRequest<AdminTemplateTrendPoint[]>(`/api/admin/templates/${templateId}/statistics/trends`, {
      method: "GET",
    })
  );
}

export async function fetchAdminTemplateRecentGenerations(
  templateId: string,
  take?: number
): Promise<AdminTemplateRecentGeneration[]> {
  const query = typeof take === "number" ? `?take=${encodeURIComponent(String(take))}` : "";
  return cachedGet(
    `admin-template-recent:${getTemplateRecentGenerationsCacheKey(templateId, take)}`,
    cachedAdminTemplateRecentGenerations,
    () =>
      apiRequest<AdminTemplateRecentGeneration[]>(
        `/api/admin/templates/${templateId}/statistics/recent${query}`,
        { method: "GET" }
      )
  );
}

export async function fetchAdminTemplateFailureBreakdown(
  templateId: string
): Promise<AdminTemplateFailureBreakdownItem[]> {
  return cachedGet(
    `admin-template-failures:${templateId}`,
    cachedAdminTemplateFailureBreakdowns,
    () =>
      apiRequest<AdminTemplateFailureBreakdownItem[]>(
        `/api/admin/templates/${templateId}/statistics/failures`,
        { method: "GET" }
      )
  );
}

export async function fetchAdminTemplateEventAnalytics(
  templateId: string
): Promise<AdminTemplateEventAnalytics> {
  return cachedGet(`admin-template-events:${templateId}`, cachedAdminTemplateEventAnalytics, () =>
    apiRequest<AdminTemplateEventAnalytics>(
      `/api/admin/templates/${templateId}/statistics/events`,
      { method: "GET" }
    )
  );
}

export async function fetchAdminTemplateFeedback(
  templateId: string,
  query: AdminTemplateFeedbackQuery = {}
): Promise<AdminTemplateFeedbackItem[]> {
  const params = new URLSearchParams();
  if (query.take) params.set("take", String(query.take));
  if (query.type) params.set("type", query.type);
  if (query.search?.trim()) params.set("search", query.search.trim());
  const suffix = params.size > 0 ? `?${params.toString()}` : "";
  return apiRequest<AdminTemplateFeedbackItem[]>(
    `/api/admin/templates/${templateId}/statistics/feedback${suffix}`,
    { method: "GET" }
  );
}

export async function fetchAdminTemplatesAnalyticsOverview(
  query: AdminTemplatesAnalyticsQuery = {}
): Promise<AdminTemplatesAnalyticsOverview> {
  const params = new URLSearchParams();
  if (query.periodDays) params.set("periodDays", String(query.periodDays));
  if (query.templateType && query.templateType !== "All")
    params.set("templateType", query.templateType);
  if (query.category) params.set("category", query.category);
  if (query.status && query.status !== "All") params.set("status", query.status);
  if (query.access && query.access !== "all") params.set("access", query.access);
  if (query.sort) params.set("sort", query.sort);
  if (query.take) params.set("take", String(query.take));

  const suffix = params.size > 0 ? `?${params.toString()}` : "";

  return cachedGet(
    `templates-analytics:${getAnalyticsOverviewCacheKey(query)}`,
    cachedTemplatesAnalyticsOverview,
    () =>
      apiRequest<AdminTemplatesAnalyticsOverview>(`/api/admin/templates/analytics${suffix}`, {
        method: "GET",
      })
  );
}

export async function startAdminTemplateTest(
  templateId: string,
  file: File
): Promise<AdminTemplateTestRun> {
  const formData = new FormData();
  formData.append("sourceImage", file);

  return apiRequest<AdminTemplateTestRun>(`/api/admin/templates/${templateId}/test`, {
    method: "POST",
    body: formData,
  });
}

export async function fetchAdminTemplateTest(generationId: string): Promise<AdminTemplateTestRun> {
  return apiRequest<AdminTemplateTestRun>(`/api/admin/templates/tests/${generationId}`, {
    method: "GET",
  });
}

export async function fetchAdminTemplateTestHistory(
  templateId: string,
  take?: number
): Promise<AdminTemplateTestRun[]> {
  const query = typeof take === "number" ? `?take=${encodeURIComponent(String(take))}` : "";
  return apiRequest<AdminTemplateTestRun[]>(`/api/admin/templates/${templateId}/tests${query}`, {
    method: "GET",
  });
}

export async function createImageTemplate(payload: ImageTemplatePayload): Promise<AdminTemplate> {
  const template = await apiRequest<AdminTemplate>("/api/admin/templates/image", {
    method: "POST",
    body: JSON.stringify(payload),
  });
  cachedTemplateLists.clear();
  return template;
}

export async function updateImageTemplate(
  templateId: string,
  payload: ImageTemplatePayload
): Promise<AdminTemplate> {
  const template = await apiRequest<AdminTemplate>(`/api/admin/templates/image/${templateId}`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
  cachedTemplateLists.clear();
  return template;
}

export async function createVideoTemplate(payload: VideoTemplatePayload): Promise<AdminTemplate> {
  const template = await apiRequest<AdminTemplate>("/api/admin/templates/video", {
    method: "POST",
    body: JSON.stringify(payload),
  });
  cachedTemplateLists.clear();
  return template;
}

export async function updateVideoTemplate(
  templateId: string,
  payload: VideoTemplatePayload
): Promise<AdminTemplate> {
  const template = await apiRequest<AdminTemplate>(`/api/admin/templates/video/${templateId}`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
  cachedTemplateLists.clear();
  return template;
}

export async function changeTemplateStatus(
  templateId: string,
  status: TemplateStatus
): Promise<AdminTemplate> {
  const template = await apiRequest<AdminTemplate>(`/api/admin/templates/${templateId}/status`, {
    method: "PUT",
    body: JSON.stringify({ status }),
  });
  cachedTemplateLists.clear();
  return template;
}

export async function deleteTemplate(templateId: string): Promise<void> {
  await apiRequest<void>(`/api/admin/templates/${templateId}`, {
    method: "DELETE",
  });
  cachedTemplateLists.clear();
}

export async function uploadTemplateMedia(
  file: File,
  assetKind: TemplateAssetKind
): Promise<TemplateAsset> {
  const formData = new FormData();
  formData.append("file", file);
  formData.append("assetKind", assetKind);

  return apiRequest<TemplateAsset>("/api/admin/templates/media/upload", {
    method: "POST",
    body: formData,
  });
}

function clearSupportCaches(conversationId?: string): void {
  cachedSupportInbox.clear();
  inflightGetRequests.clear();

  if (conversationId) {
    cachedSupportConversations.delete(`support-conversation:${conversationId}`);
    return;
  }

  cachedSupportConversations.clear();
}

function clearSupportTemplateCaches(): void {
  cachedSupportTemplates.clear();
  inflightGetRequests.delete("support-templates");
}
