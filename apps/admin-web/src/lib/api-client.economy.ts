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
  userId?: string;
}): Promise<OffsetPagedResponse<AdminEconomyPurchase>> {
  const search = new URLSearchParams();
  if (params?.skip) search.set("skip", String(params.skip));
  if (params?.take) search.set("take", String(params.take));
  if (params?.status) search.set("status", params.status);
  if (params?.userId) search.set("userId", params.userId);

  const query = search.size ? `?${search.toString()}` : "";
  return apiRequest<OffsetPagedResponse<AdminEconomyPurchase>>(
    `/api/admin/economy/purchases${query}`,
    { method: "GET" }
  );
}

export async function fetchAdminEconomyUserSubscriptionSummary(
  userId: string
): Promise<AdminEconomyUserSubscriptionSummary> {
  return apiRequest<AdminEconomyUserSubscriptionSummary>(
    `/api/admin/economy/users/${userId}/subscription-summary`,
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
