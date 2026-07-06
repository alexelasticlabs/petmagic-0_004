import type { OffsetPagedResponse } from "./api-client.types.shared";

export type AdminEconomyLedgerItem = {
  entryId: string;
  userId: string;
  delta: number;
  balanceAfter: number;
  source: string;
  reason: string;
  createdAtUtc: string;
  sourceProvider?: string | null;
  sourceTransactionId?: string | null;
  tokenKind?: string | null;
  operationKind?: string | null;
  tokenBucketId?: string | null;
  bucketDeltasJson?: string | null;
  expiresAtUtc?: string | null;
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
  createdAtUtc: string;
  processedAtUtc?: string | null;
};

export type AdminEconomyIncident = {
  incidentId: string;
  type: string;
  category: string;
  severity: string;
  status: string;
  userId?: string | null;
  purchaseOrderId?: string | null;
  userSubscriptionId?: string | null;
  provider?: string | null;
  externalReferenceId?: string | null;
  summary: string;
  detectionCount: number;
  retryCount: number;
  autoFixApplied: boolean;
  firstDetectedAtUtc: string;
  lastDetectedAtUtc: string;
  nextRetryAtUtc?: string | null;
  resolvedAtUtc?: string | null;
  resolutionNote?: string | null;
  lastError?: string | null;
};

export type AdminEconomyIncidentWallet = {
  userId: string;
  balance: number;
  updatedAtUtc: string;
};

export type AdminEconomyIncidentWebhookSnapshot = {
  eventId: string;
  userId?: string | null;
  userSubscriptionId?: string | null;
  provider: string;
  eventType: string;
  status: string;
  externalEventId?: string | null;
  payloadSnapshotJson?: string | null;
  createdAtUtc: string;
  processedAtUtc?: string | null;
};

export type AdminEconomyIncidentGeneration = {
  generationId: string;
  userId: string;
  tokenCost: number;
  status: string;
  createdAtUtc: string;
  updatedAtUtc: string;
  chargedAtUtc?: string | null;
  refundedAtUtc?: string | null;
  refundAttemptCount: number;
  refundLastErrorCode?: string | null;
  refundLastAttemptedAtUtc?: string | null;
  completedAtUtc?: string | null;
  lastErrorCode?: string | null;
  idempotencyKey?: string | null;
  requestHash?: string | null;
};

export type AdminEconomyIncidentAuditEntry = {
  auditEntryId: string;
  action: string;
  reason: string;
  oldStatus?: string | null;
  newStatus?: string | null;
  detailsJson?: string | null;
  createdAtUtc: string;
};

export type AdminEconomyIncidentDetail = {
  incident: AdminEconomyIncident;
  purchaseOrder?: AdminEconomyPurchase | null;
  subscription?: AdminEconomySubscription | null;
  wallet?: AdminEconomyIncidentWallet | null;
  generation?: AdminEconomyIncidentGeneration | null;
  ledgerEntries: AdminEconomyLedgerItem[];
  webhookEvents: AdminEconomyIncidentWebhookSnapshot[];
  auditTrail: AdminEconomyIncidentAuditEntry[];
};

export type AdminEconomyIncidentAction = {
  incident: AdminEconomyIncident;
  action: string;
  message: string;
};

export type EconomyReconciliationRun = {
  startedAtUtc: string;
  completedAtUtc: string;
  checksRun: number;
  incidentsCreated: number;
  incidentsUpdated: number;
  incidentsResolved: number;
  autoFixesApplied: number;
  manualReviewRequired: number;
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
