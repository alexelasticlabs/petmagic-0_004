import type { UserAvatar } from "./api-client.types.auth";
import type { OffsetPagedResponse } from "./api-client.types.shared";
import type { TemplateType } from "./api-client.types.templates";

export type UserListItem = {
  userId: string;
  email: string;
  displayName?: string;
  isPremium: boolean;
  isActive: boolean;
  emailConfirmed: boolean;
  roles: string[];
  createdAtUtc: string;
  lastActivityAtUtc?: string | null;
  avatar?: UserAvatar | null;
};

export type UserListPage = OffsetPagedResponse<UserListItem> & {
  totalCount: number;
};

export type AdminEmailBroadcastStatus =
  "legacy" | "queued" | "processing" | "completed" | "partially-failed" | "failed";

export type AdminEmailBroadcastAccepted = {
  broadcastId: string;
  recipientCount: number;
  status: AdminEmailBroadcastStatus;
  createdAtUtc: string;
};

export type AdminEmailBroadcastListItem = {
  broadcastId: string;
  audience: string;
  subject?: string | null;
  status: AdminEmailBroadcastStatus;
  recipientCount: number;
  pendingCount: number;
  sentCount: number;
  failedCount: number;
  createdAtUtc: string;
  updatedAtUtc: string;
  completedAtUtc?: string | null;
};

export type AdminEmailBroadcastsPage = OffsetPagedResponse<AdminEmailBroadcastListItem> & {
  totalCount: number;
};

export type AdminEmailBroadcastDetail = AdminEmailBroadcastListItem & {
  retryableFailedCount: number;
};

export type AdminEmailBroadcastRetryResult = {
  broadcastId: string;
  retriedCount: number;
  status: AdminEmailBroadcastStatus;
  pendingCount: number;
  sentCount: number;
  failedCount: number;
  updatedAtUtc: string;
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
  termsOfUseAccepted: boolean;
  privacyPolicyAccepted: boolean;
  marketingEmailsEnabled: boolean;
  legalAcceptance: AdminUserLegalAcceptance;
  roles: string[];
  createdAtUtc: string;
  avatar?: UserAvatar | null;
};

export type AdminUserSessionStatus = "active" | "expired" | "revoked";

export type AdminUserSession = {
  sessionId: string;
  status: AdminUserSessionStatus;
  canRevoke: boolean;
  createdAtUtc: string;
  expiresAtUtc: string;
  revokedAtUtc?: string | null;
};

export type AdminUserSessions = {
  items: AdminUserSession[];
  totalCount: number;
  activeCount: number;
  hasMore: boolean;
};

export type AdminUserSessionRevokeResponse = {
  userId: string;
  sessionId?: string | null;
  revokedCount: number;
  occurredAtUtc: string;
  replayed: boolean;
};

export type AdminUserLegalAcceptance = {
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
