import { apiRequest, encodePathSegment } from "./api-client.core";

import type {
  AdminCurrencyPack,
  AdminEconomyDashboardMetrics,
  AdminEconomyIncidentAction,
  AdminEconomyIncidentDetail,
  AdminEconomyIncident,
  AdminEconomyLedgerItem,
  AdminEconomyPurchase,
  AdminEconomySubscription,
  AdminEconomyUserSubscriptionSummary,
  AdminPaymentProviderConfiguration,
  AdminPaymentProviderConfigurationMatch,
  AdminRedeemCode,
  AdminRedeemCodeMetrics,
  AdminRedeemCodeRedemption,
  AdminRedeemCodesPage,
  AdminRedeemRewardKind,
  AdminSubscriptionEvent,
  AdminSubscriptionPlan,
  EconomyReconciliationRun,
  OffsetPagedResponse,
} from "./api-client.types";

export type AdminEconomyPurchasesQuery = {
  skip?: number;
  take?: number;
  status?: string;
  provider?: string;
  search?: string;
  userId?: string;
};

export type AdminEconomySubscriptionsQuery = {
  skip?: number;
  take?: number;
  status?: string;
  provider?: string;
  search?: string;
};

export type AdminEconomyIncidentsQuery = {
  skip?: number;
  take?: number;
  status?: string;
  type?: string;
  category?: string;
  userId?: string;
};

export type AdminRedeemCodesQuery = {
  skip?: number;
  take?: number;
  search?: string;
  status?: string;
  rewardKind?: string;
  sort?: string;
};

export const ECONOMY_QUERY_FILTER_MAX_LENGTH = 120;
export const ECONOMY_REFUND_REASON_MAX_LENGTH = 240;
export const ECONOMY_INCIDENT_REASON_MAX_LENGTH = 1000;

const ECONOMY_PAYMENT_PROVIDERS = ["stripe", "app_store", "google_play"] as const;
const ECONOMY_PURCHASE_STATUSES = ["pending", "succeeded", "failed", "refunded"] as const;
const ECONOMY_SUBSCRIPTION_STATUSES = [
  "active",
  "trialing",
  "past_due",
  "canceled",
  "expired",
] as const;
const ECONOMY_SUBSCRIPTION_EVENT_STATUSES = [
  "active",
  "canceled",
  "expired",
  "processed",
  "failed",
] as const;
const ECONOMY_INCIDENT_STATUSES = ["open", "resolved", "suppressed"] as const;
const ECONOMY_INCIDENT_CATEGORIES = [
  "pending",
  "failed",
  "disputed",
  "refund_pending",
  "settlement_failed",
  "webhook_failed",
  "reconciliation_required",
  "manual_review_required",
  "resolved",
] as const;
const REDEEM_CODE_STATUSES = [
  "draft",
  "scheduled",
  "active",
  "paused",
  "exhausted",
  "expired",
  "archived",
] as const;
const REDEEM_CODE_REWARD_KINDS = ["spark"] as const;
const REDEEM_CODE_SORTS = ["updated", "usage", "reward", "code", "expiry"] as const;

function normalizePagedValue(value: number | undefined): number | undefined {
  return typeof value === "number" && Number.isFinite(value)
    ? Math.max(0, Math.floor(value))
    : undefined;
}

function normalizeTakeValue(value: number | undefined): number | undefined {
  return typeof value === "number" && Number.isFinite(value) && value > 0
    ? Math.min(Math.floor(value), 200)
    : undefined;
}

function normalizeFilterValue(value: string | undefined): string | undefined {
  return value?.trim().slice(0, ECONOMY_QUERY_FILTER_MAX_LENGTH) || undefined;
}

function normalizeAllowedFilter<const T extends string>(
  value: string | undefined,
  allowed: readonly T[],
  omitted: readonly string[] = ["all"]
): T | undefined {
  const normalized = value?.trim().toLowerCase();
  if (!normalized || omitted.includes(normalized)) {
    return undefined;
  }

  return allowed.includes(normalized as T) ? (normalized as T) : undefined;
}

export function normalizeAdminEconomyPurchasesQuery(
  params: AdminEconomyPurchasesQuery = {}
): AdminEconomyPurchasesQuery {
  return {
    skip: normalizePagedValue(params.skip),
    take: normalizeTakeValue(params.take),
    status: normalizeAllowedFilter(params.status, ECONOMY_PURCHASE_STATUSES),
    provider: normalizeAllowedFilter(params.provider, ECONOMY_PAYMENT_PROVIDERS),
    search: normalizeFilterValue(params.search),
    userId: normalizeFilterValue(params.userId),
  };
}

export function normalizeAdminEconomySubscriptionsQuery(
  params: AdminEconomySubscriptionsQuery = {}
): AdminEconomySubscriptionsQuery {
  return {
    skip: normalizePagedValue(params.skip),
    take: normalizeTakeValue(params.take),
    status: normalizeAllowedFilter(params.status, ECONOMY_SUBSCRIPTION_STATUSES),
    provider: normalizeAllowedFilter(params.provider, ECONOMY_PAYMENT_PROVIDERS),
    search: normalizeFilterValue(params.search),
  };
}

export function normalizeAdminEconomyIncidentsQuery(
  params: AdminEconomyIncidentsQuery = {}
): AdminEconomyIncidentsQuery {
  return {
    skip: normalizePagedValue(params.skip),
    take: normalizeTakeValue(params.take),
    status: normalizeAllowedFilter(params.status, ECONOMY_INCIDENT_STATUSES),
    type: normalizeFilterValue(params.type),
    category: normalizeAllowedFilter(params.category, ECONOMY_INCIDENT_CATEGORIES),
    userId: normalizeFilterValue(params.userId),
  };
}

export function normalizeAdminRedeemCodesQuery(
  params: AdminRedeemCodesQuery = {}
): AdminRedeemCodesQuery {
  return {
    skip: normalizePagedValue(params.skip),
    take: normalizeTakeValue(params.take),
    search: normalizeFilterValue(params.search),
    status: normalizeAllowedFilter(params.status, REDEEM_CODE_STATUSES),
    rewardKind: normalizeAllowedFilter(params.rewardKind, REDEEM_CODE_REWARD_KINDS),
    sort: normalizeAllowedFilter(params.sort, REDEEM_CODE_SORTS, []),
  };
}

export async function fetchAdminEconomyLedger(
  params?: {
    skip?: number;
    take?: number;
    source?: string;
    userId?: string;
  },
  signal?: AbortSignal
): Promise<OffsetPagedResponse<AdminEconomyLedgerItem>> {
  const normalizedSkip = normalizePagedValue(params?.skip);
  const normalizedTake = normalizeTakeValue(params?.take);
  const normalizedSource = normalizeFilterValue(params?.source);
  const normalizedUserId = normalizeFilterValue(params?.userId);
  const search = new URLSearchParams();
  if (normalizedSkip !== undefined) search.set("skip", String(normalizedSkip));
  if (normalizedTake !== undefined) search.set("take", String(normalizedTake));
  if (normalizedSource) search.set("source", normalizedSource);
  if (normalizedUserId) search.set("userId", normalizedUserId);

  const query = search.size ? `?${search.toString()}` : "";
  return apiRequest<OffsetPagedResponse<AdminEconomyLedgerItem>>(
    `/api/admin/economy/ledger${query}`,
    { method: "GET", signal }
  );
}

export async function fetchAdminEconomyPurchases(
  params?: AdminEconomyPurchasesQuery,
  signal?: AbortSignal
): Promise<OffsetPagedResponse<AdminEconomyPurchase>> {
  const normalizedParams = normalizeAdminEconomyPurchasesQuery(params);
  const search = new URLSearchParams();
  if (normalizedParams.skip !== undefined) search.set("skip", String(normalizedParams.skip));
  if (normalizedParams.take !== undefined) search.set("take", String(normalizedParams.take));
  if (normalizedParams.status) search.set("status", normalizedParams.status);
  if (normalizedParams.provider) search.set("provider", normalizedParams.provider);
  if (normalizedParams.search) search.set("search", normalizedParams.search);
  if (normalizedParams.userId) search.set("userId", normalizedParams.userId);

  const query = search.size ? `?${search.toString()}` : "";
  return apiRequest<OffsetPagedResponse<AdminEconomyPurchase>>(
    `/api/admin/economy/purchases${query}`,
    { method: "GET", signal }
  );
}

export async function fetchAdminEconomyDashboardMetrics(
  signal?: AbortSignal
): Promise<AdminEconomyDashboardMetrics> {
  return apiRequest<AdminEconomyDashboardMetrics>("/api/admin/economy/dashboard/metrics", {
    method: "GET",
    signal,
  });
}

export async function refundAdminEconomyPurchase(
  orderId: string,
  reason?: string
): Promise<AdminEconomyPurchase> {
  const encodedOrderId = encodePathSegment(orderId);
  const normalizedReason = reason?.trim().slice(0, ECONOMY_REFUND_REASON_MAX_LENGTH) || undefined;
  return apiRequest<AdminEconomyPurchase>(`/api/admin/economy/purchases/${encodedOrderId}/refund`, {
    method: "POST",
    body: JSON.stringify({ reason: normalizedReason }),
  });
}

export async function fetchAdminEconomyUserSubscriptionSummary(
  userId: string,
  signal?: AbortSignal
): Promise<AdminEconomyUserSubscriptionSummary> {
  const encodedUserId = encodePathSegment(userId);
  return apiRequest<AdminEconomyUserSubscriptionSummary>(
    `/api/admin/economy/users/${encodedUserId}/subscription-summary`,
    { method: "GET", signal }
  );
}

export async function fetchAdminEconomySubscriptions(
  params?: AdminEconomySubscriptionsQuery,
  signal?: AbortSignal
): Promise<OffsetPagedResponse<AdminEconomySubscription>> {
  const normalizedParams = normalizeAdminEconomySubscriptionsQuery(params);
  const search = new URLSearchParams();
  if (normalizedParams.skip !== undefined) search.set("skip", String(normalizedParams.skip));
  if (normalizedParams.take !== undefined) search.set("take", String(normalizedParams.take));
  if (normalizedParams.status) search.set("status", normalizedParams.status);
  if (normalizedParams.provider) search.set("provider", normalizedParams.provider);
  if (normalizedParams.search) search.set("search", normalizedParams.search);

  const query = search.size ? `?${search.toString()}` : "";
  return apiRequest<OffsetPagedResponse<AdminEconomySubscription>>(
    `/api/admin/economy/subscriptions${query}`,
    { method: "GET", signal }
  );
}

export async function adminCancelPremiumSubscription(
  userId: string,
  paymentProvider = "stripe"
): Promise<AdminEconomyUserSubscriptionSummary> {
  const encodedUserId = encodePathSegment(userId);
  return apiRequest<AdminEconomyUserSubscriptionSummary>(
    `/api/admin/economy/users/${encodedUserId}/premium/revoke`,
    {
      method: "PUT",
      body: JSON.stringify({ paymentProvider }),
    }
  );
}

export async function fetchAdminSubscriptionPlans(
  signal?: AbortSignal
): Promise<AdminSubscriptionPlan[]> {
  return apiRequest<AdminSubscriptionPlan[]>("/api/admin/economy/subscription-plans", {
    method: "GET",
    signal,
  });
}

export async function fetchAdminPaymentProviderConfigs(
  signal?: AbortSignal
): Promise<AdminPaymentProviderConfiguration[]> {
  return apiRequest<AdminPaymentProviderConfiguration[]>(
    "/api/admin/economy/payment-provider-configs",
    { method: "GET", signal }
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
  const encodedPlanId = encodePathSegment(planId);
  return apiRequest<AdminSubscriptionPlan>(
    `/api/admin/economy/subscription-plans/${encodedPlanId}`,
    {
      method: "PUT",
      body: JSON.stringify(payload),
    }
  );
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
  const encodedConfigurationId = encodePathSegment(configurationId);
  return apiRequest<AdminPaymentProviderConfiguration>(
    `/api/admin/economy/payment-provider-configs/${encodedConfigurationId}`,
    {
      method: "PUT",
      body: JSON.stringify(payload),
    }
  );
}

export async function createAdminPaymentProviderConfig(
  payload: Pick<
    AdminPaymentProviderConfiguration,
    | "provider"
    | "platform"
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
    "/api/admin/economy/payment-provider-configs",
    {
      method: "POST",
      body: JSON.stringify(payload),
    }
  );
}

export async function cloneAdminPaymentProviderConfig(
  configurationId: string,
  payload: { region: string }
): Promise<AdminPaymentProviderConfiguration> {
  const encodedConfigurationId = encodePathSegment(configurationId);
  return apiRequest<AdminPaymentProviderConfiguration>(
    `/api/admin/economy/payment-provider-configs/${encodedConfigurationId}/clone`,
    {
      method: "POST",
      body: JSON.stringify(payload),
    }
  );
}

export async function deleteAdminPaymentProviderConfig(configurationId: string): Promise<void> {
  const encodedConfigurationId = encodePathSegment(configurationId);
  await apiRequest<void>(`/api/admin/economy/payment-provider-configs/${encodedConfigurationId}`, {
    method: "DELETE",
  });
}

export async function testAdminPaymentProviderConfigMatch(payload: {
  provider: string;
  platform: string;
  country: string;
  appVersion: string;
}): Promise<AdminPaymentProviderConfigurationMatch> {
  return apiRequest<AdminPaymentProviderConfigurationMatch>(
    "/api/admin/economy/payment-provider-configs/test-match",
    {
      method: "POST",
      body: JSON.stringify(payload),
    }
  );
}

export async function fetchAdminSubscriptionEvents(
  params?: {
    skip?: number;
    take?: number;
    provider?: string;
    status?: string;
  },
  signal?: AbortSignal
): Promise<OffsetPagedResponse<AdminSubscriptionEvent>> {
  const normalizedSkip = normalizePagedValue(params?.skip);
  const normalizedTake = normalizeTakeValue(params?.take);
  const normalizedProvider = normalizeAllowedFilter(params?.provider, ECONOMY_PAYMENT_PROVIDERS);
  const normalizedStatus = normalizeAllowedFilter(
    params?.status,
    ECONOMY_SUBSCRIPTION_EVENT_STATUSES
  );
  const search = new URLSearchParams();
  if (normalizedSkip !== undefined) search.set("skip", String(normalizedSkip));
  if (normalizedTake !== undefined) search.set("take", String(normalizedTake));
  if (normalizedProvider) search.set("provider", normalizedProvider);
  if (normalizedStatus) search.set("status", normalizedStatus);

  const query = search.size ? `?${search.toString()}` : "";
  return apiRequest<OffsetPagedResponse<AdminSubscriptionEvent>>(
    `/api/admin/economy/subscription-events${query}`,
    { method: "GET", signal }
  );
}

export async function fetchAdminEconomyIncidents(
  params?: AdminEconomyIncidentsQuery,
  signal?: AbortSignal
): Promise<OffsetPagedResponse<AdminEconomyIncident>> {
  const normalizedParams = normalizeAdminEconomyIncidentsQuery(params);
  const search = new URLSearchParams();
  if (normalizedParams.skip !== undefined) search.set("skip", String(normalizedParams.skip));
  if (normalizedParams.take !== undefined) search.set("take", String(normalizedParams.take));
  if (normalizedParams.status) search.set("status", normalizedParams.status);
  if (normalizedParams.type) search.set("type", normalizedParams.type);
  if (normalizedParams.category) search.set("category", normalizedParams.category);
  if (normalizedParams.userId) search.set("userId", normalizedParams.userId);

  const query = search.size ? `?${search.toString()}` : "";
  return apiRequest<OffsetPagedResponse<AdminEconomyIncident>>(
    `/api/admin/economy/incidents${query}`,
    { method: "GET", signal }
  );
}

export async function fetchAdminEconomyIncidentDetail(
  incidentId: string,
  signal?: AbortSignal
): Promise<AdminEconomyIncidentDetail> {
  const encodedIncidentId = encodePathSegment(incidentId);
  return apiRequest<AdminEconomyIncidentDetail>(
    `/api/admin/economy/incidents/${encodedIncidentId}`,
    { method: "GET", signal }
  );
}

export async function runAdminEconomyReconciliation(): Promise<EconomyReconciliationRun> {
  return apiRequest<EconomyReconciliationRun>("/api/admin/economy/reconciliation/run", {
    method: "POST",
  });
}

export async function resolveAdminEconomyIncident(
  incidentId: string,
  resolutionNote?: string
): Promise<AdminEconomyIncident> {
  const encodedIncidentId = encodePathSegment(incidentId);
  const normalizedResolutionNote =
    resolutionNote?.trim().slice(0, ECONOMY_INCIDENT_REASON_MAX_LENGTH) || undefined;
  return apiRequest<AdminEconomyIncident>(
    `/api/admin/economy/incidents/${encodedIncidentId}/resolve`,
    {
      method: "POST",
      body: JSON.stringify({ resolutionNote: normalizedResolutionNote }),
    }
  );
}

export async function reopenAdminEconomyIncident(
  incidentId: string,
  reason: string
): Promise<AdminEconomyIncident> {
  const encodedIncidentId = encodePathSegment(incidentId);
  const normalizedReason = reason.trim().slice(0, ECONOMY_INCIDENT_REASON_MAX_LENGTH);
  return apiRequest<AdminEconomyIncident>(
    `/api/admin/economy/incidents/${encodedIncidentId}/reopen`,
    {
      method: "POST",
      body: JSON.stringify({ reason: normalizedReason }),
    }
  );
}

export async function applyAdminEconomyIncidentAction(
  incidentId: string,
  payload: {
    action: string;
    reason: string;
    amount?: number;
    externalReferenceId?: string;
  }
): Promise<AdminEconomyIncidentAction> {
  const encodedIncidentId = encodePathSegment(incidentId);
  return apiRequest<AdminEconomyIncidentAction>(
    `/api/admin/economy/incidents/${encodedIncidentId}/actions`,
    {
      method: "POST",
      body: JSON.stringify({
        action: payload.action.trim(),
        reason: payload.reason.trim().slice(0, ECONOMY_INCIDENT_REASON_MAX_LENGTH),
        amount:
          typeof payload.amount === "number" && Number.isFinite(payload.amount)
            ? Math.trunc(payload.amount)
            : undefined,
        externalReferenceId: normalizeFilterValue(payload.externalReferenceId),
      }),
    }
  );
}

export async function fetchAdminCurrencyPacks(signal?: AbortSignal): Promise<AdminCurrencyPack[]> {
  return apiRequest<AdminCurrencyPack[]>("/api/admin/economy/packs", { method: "GET", signal });
}

export async function updateAdminCurrencyPack(
  packId: string,
  payload: Pick<
    AdminCurrencyPack,
    "displayName" | "priceAmount" | "grantedSpark" | "bonusSpark" | "isActive" | "sortOrder"
  >
): Promise<AdminCurrencyPack> {
  const encodedPackId = encodePathSegment(packId);
  return apiRequest<AdminCurrencyPack>(`/api/admin/economy/packs/${encodedPackId}`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export async function fetchAdminRedeemCodes(
  params?: AdminRedeemCodesQuery,
  signal?: AbortSignal
): Promise<AdminRedeemCodesPage> {
  const normalizedParams = normalizeAdminRedeemCodesQuery(params);
  const search = new URLSearchParams();
  if (normalizedParams.skip !== undefined) search.set("skip", String(normalizedParams.skip));
  if (normalizedParams.take !== undefined) search.set("take", String(normalizedParams.take));
  if (normalizedParams.search) search.set("search", normalizedParams.search);
  if (normalizedParams.status) search.set("status", normalizedParams.status);
  if (normalizedParams.rewardKind) search.set("rewardKind", normalizedParams.rewardKind);
  if (normalizedParams.sort) search.set("sort", normalizedParams.sort);

  const query = search.size ? `?${search.toString()}` : "";
  return apiRequest<AdminRedeemCodesPage>(`/api/admin/economy/redeem-codes${query}`, {
    method: "GET",
    signal,
  });
}

export async function fetchAdminRedeemCodeMetrics(
  params?: Pick<AdminRedeemCodesQuery, "search" | "status" | "rewardKind">,
  signal?: AbortSignal
): Promise<AdminRedeemCodeMetrics> {
  const normalizedParams = normalizeAdminRedeemCodesQuery(params);
  const search = new URLSearchParams();
  if (normalizedParams.search) search.set("search", normalizedParams.search);
  if (normalizedParams.status) search.set("status", normalizedParams.status);
  if (normalizedParams.rewardKind) search.set("rewardKind", normalizedParams.rewardKind);

  const query = search.size ? `?${search.toString()}` : "";
  return apiRequest<AdminRedeemCodeMetrics>(`/api/admin/economy/redeem-codes/metrics${query}`, {
    method: "GET",
    signal,
  });
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
  },
  signal?: AbortSignal
): Promise<OffsetPagedResponse<AdminRedeemCodeRedemption>> {
  const encodedRedeemCodeId = encodePathSegment(redeemCodeId);
  const normalizedSkip = normalizePagedValue(params?.skip);
  const normalizedTake = normalizeTakeValue(params?.take);
  const normalizedUserId = normalizeFilterValue(params?.userId);
  const search = new URLSearchParams();
  if (normalizedSkip !== undefined) search.set("skip", String(normalizedSkip));
  if (normalizedTake !== undefined) search.set("take", String(normalizedTake));
  if (normalizedUserId) search.set("userId", normalizedUserId);

  const query = search.size ? `?${search.toString()}` : "";
  return apiRequest<OffsetPagedResponse<AdminRedeemCodeRedemption>>(
    `/api/admin/economy/redeem-codes/${encodedRedeemCodeId}/activations${query}`,
    { method: "GET", signal }
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
  const encodedRedeemCodeId = encodePathSegment(redeemCodeId);
  return apiRequest<AdminRedeemCode>(`/api/admin/economy/redeem-codes/${encodedRedeemCodeId}`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}
