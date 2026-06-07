import { apiRequest } from "./api-client.core";

import type {
  AdminCurrencyPack,
  AdminEconomyLedgerItem,
  AdminEconomyPurchase,
  AdminEconomySubscription,
  AdminEconomyUserSubscriptionSummary,
  AdminPaymentProviderConfiguration,
  AdminPaymentProviderConfigurationMatch,
  AdminRedeemCode,
  AdminRedeemCodeRedemption,
  AdminRedeemRewardKind,
  AdminSubscriptionEvent,
  AdminSubscriptionPlan,
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
  return value?.trim() || undefined;
}

export function normalizeAdminEconomyPurchasesQuery(
  params: AdminEconomyPurchasesQuery = {}
): AdminEconomyPurchasesQuery {
  return {
    skip: normalizePagedValue(params.skip),
    take: normalizeTakeValue(params.take),
    status: normalizeFilterValue(params.status),
    provider: normalizeFilterValue(params.provider),
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
    status: normalizeFilterValue(params.status),
    provider: normalizeFilterValue(params.provider),
    search: normalizeFilterValue(params.search),
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
  const search = new URLSearchParams();
  if (normalizedSkip !== undefined) search.set("skip", String(normalizedSkip));
  if (normalizedTake !== undefined) search.set("take", String(normalizedTake));
  if (params?.source?.trim()) search.set("source", params.source.trim());
  if (params?.userId?.trim()) search.set("userId", params.userId.trim());

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

export async function refundAdminEconomyPurchase(
  orderId: string,
  reason?: string
): Promise<AdminEconomyPurchase> {
  return apiRequest<AdminEconomyPurchase>(`/api/admin/economy/purchases/${orderId}/refund`, {
    method: "POST",
    body: JSON.stringify({ reason: reason?.trim() || undefined }),
  });
}

export async function fetchAdminEconomyUserSubscriptionSummary(
  userId: string,
  signal?: AbortSignal
): Promise<AdminEconomyUserSubscriptionSummary> {
  return apiRequest<AdminEconomyUserSubscriptionSummary>(
    `/api/admin/economy/users/${userId}/subscription-summary`,
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
  return apiRequest<AdminEconomyUserSubscriptionSummary>(
    `/api/admin/economy/users/${userId}/premium/revoke`,
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
): Promise<
  AdminPaymentProviderConfiguration[]
> {
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
  return apiRequest<AdminPaymentProviderConfiguration>(
    `/api/admin/economy/payment-provider-configs/${configurationId}/clone`,
    {
      method: "POST",
      body: JSON.stringify(payload),
    }
  );
}

export async function deleteAdminPaymentProviderConfig(configurationId: string): Promise<void> {
  await apiRequest<void>(`/api/admin/economy/payment-provider-configs/${configurationId}`, {
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
  const search = new URLSearchParams();
  if (normalizedSkip !== undefined) search.set("skip", String(normalizedSkip));
  if (normalizedTake !== undefined) search.set("take", String(normalizedTake));
  if (params?.provider?.trim()) search.set("provider", params.provider.trim());
  if (params?.status?.trim()) search.set("status", params.status.trim());

  const query = search.size ? `?${search.toString()}` : "";
  return apiRequest<OffsetPagedResponse<AdminSubscriptionEvent>>(
    `/api/admin/economy/subscription-events${query}`,
    { method: "GET", signal }
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
  return apiRequest<AdminCurrencyPack>(`/api/admin/economy/packs/${packId}`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export async function fetchAdminRedeemCodes(signal?: AbortSignal): Promise<AdminRedeemCode[]> {
  return apiRequest<AdminRedeemCode[]>("/api/admin/economy/redeem-codes", {
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
  const normalizedSkip = normalizePagedValue(params?.skip);
  const normalizedTake = normalizeTakeValue(params?.take);
  const search = new URLSearchParams();
  if (normalizedSkip !== undefined) search.set("skip", String(normalizedSkip));
  if (normalizedTake !== undefined) search.set("take", String(normalizedTake));
  if (params?.userId?.trim()) search.set("userId", params.userId.trim());

  const query = search.size ? `?${search.toString()}` : "";
  return apiRequest<OffsetPagedResponse<AdminRedeemCodeRedemption>>(
    `/api/admin/economy/redeem-codes/${redeemCodeId}/activations${query}`,
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
  return apiRequest<AdminRedeemCode>(`/api/admin/economy/redeem-codes/${redeemCodeId}`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}
