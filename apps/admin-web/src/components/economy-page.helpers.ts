import { type Dispatch, type SetStateAction } from "react";

import {
  type AdminCurrencyPack,
  type AdminEconomyPurchase,
  type AdminEconomySubscription,
  type AdminPaymentProviderConfiguration,
  type AdminSubscriptionPlan,
} from "@/lib/api-client";

export type PackDraft = {
  displayName: string;
  priceAmount: string;
  grantedSpark: string;
  bonusSpark: string;
  sortOrder: string;
  isActive: boolean;
};

export type SubscriptionPlanDraft = {
  name: string;
  priceAmount: string;
  currencyCode: string;
  monthlyTokenLimit: string;
  isRecommended: boolean;
  isActive: boolean;
  appleProductId: string;
  googleProductId: string;
  stripePriceId: string;
  displayOrder: string;
};

export type ProviderConfigDraft = {
  region: string;
  isEnabled: boolean;
  isRecommended: boolean;
  isSelectedByDefault: boolean;
  requiresExternalWarning: boolean;
  requiresStoreDisclosure: boolean;
  allowedFromAppVersion: string;
  externalCheckoutAllowed: boolean;
  bonusTokensPercent: string;
  displayLabel: string;
  displaySubtitle: string;
  warningTitle: string;
  warningMessage: string;
  mode: string;
  notes: string;
};

export type ProviderConfigCreateDraft = ProviderConfigDraft & {
  provider: string;
  platform: string;
};

export type ProviderConfigMatchDraft = {
  provider: string;
  platform: string;
  country: string;
  appVersion: string;
};

export type EconomyValidationText = {
  invalidPackNumbers: string;
  invalidPlanNumbers: string;
  invalidProviderConfigCreate: string;
  invalidProviderConfigMatch: string;
  invalidProviderConfig: string;
};

export const ECONOMY_PACK_DISPLAY_NAME_MAX_LENGTH = 80;
export const ECONOMY_PACK_PRICE_MAX_LENGTH = 10;
export const ECONOMY_PACK_INTEGER_MAX_LENGTH = 9;
export const ECONOMY_PLAN_NAME_MAX_LENGTH = 80;
export const ECONOMY_PLAN_PRODUCT_ID_MAX_LENGTH = 160;
export const ECONOMY_PROVIDER_CODE_MAX_LENGTH = 48;
export const ECONOMY_PROVIDER_REGION_MAX_LENGTH = 16;
export const ECONOMY_PROVIDER_VERSION_MAX_LENGTH = 32;
export const ECONOMY_PROVIDER_LABEL_MAX_LENGTH = 80;
export const ECONOMY_PROVIDER_SUBTITLE_MAX_LENGTH = 160;
export const ECONOMY_PROVIDER_WARNING_TITLE_MAX_LENGTH = 120;
export const ECONOMY_PROVIDER_MESSAGE_MAX_LENGTH = 800;
export const ECONOMY_PROVIDER_NOTES_MAX_LENGTH = 240;
export const ECONOMY_PROVIDER_BONUS_PERCENT_MAX_LENGTH = 3;

export const paymentProviderOptions = ["stripe", "app_store", "google_play"] as const;
export const paymentPlatformOptions = ["ios", "android", "web", "iphone", "ipad"] as const;
export const paymentRouteModeOptions = ["test", "live"] as const;

export function canRefundPurchase(purchase: AdminEconomyPurchase): boolean {
  return purchase.canRefund === true;
}

export function canCancelSubscription(subscription: AdminEconomySubscription): boolean {
  const status = subscription.status.toLowerCase();
  return (
    subscription.provider.toLowerCase() === "stripe" &&
    (status === "active" || status === "trialing") &&
    !subscription.cancelAtPeriodEnd
  );
}

export function toDraft(pack: AdminCurrencyPack): PackDraft {
  return {
    displayName: normalizeEconomyPackDisplayNameInput(pack.displayName),
    priceAmount: pack.priceAmount.toString(),
    grantedSpark: pack.grantedSpark.toString(),
    bonusSpark: pack.bonusSpark.toString(),
    sortOrder: pack.sortOrder.toString(),
    isActive: pack.isActive,
  };
}

export function isPackDraftDirty(pack: AdminCurrencyPack, draft: PackDraft): boolean {
  const originalDraft = toDraft(pack);
  return (
    draft.displayName !== originalDraft.displayName ||
    draft.priceAmount !== originalDraft.priceAmount ||
    draft.grantedSpark !== originalDraft.grantedSpark ||
    draft.bonusSpark !== originalDraft.bonusSpark ||
    draft.sortOrder !== originalDraft.sortOrder ||
    draft.isActive !== originalDraft.isActive
  );
}

export function isPackDraftInvalid(draft: PackDraft): boolean {
  return (
    !isBoundedRequiredText(draft.displayName, ECONOMY_PACK_DISPLAY_NAME_MAX_LENGTH) ||
    parsePackDecimal(draft.priceAmount) === null ||
    parsePackInteger(draft.grantedSpark, 1) === null ||
    parsePackInteger(draft.bonusSpark, 0) === null ||
    parsePackInteger(draft.sortOrder, 0) === null
  );
}

export function updateDraft(
  setDrafts: Dispatch<SetStateAction<Record<string, PackDraft>>>,
  packId: string,
  patch: Partial<PackDraft>
) {
  setDrafts((current) => ({
    ...current,
    [packId]: {
      ...(current[packId] ?? {
        displayName: "",
        priceAmount: "0",
        grantedSpark: "0",
        bonusSpark: "0",
        sortOrder: "0",
        isActive: false,
      }),
      ...patch,
    },
  }));
}

export function toCurrencyPackPayload(draft: PackDraft, text: EconomyValidationText) {
  const displayName = draft.displayName.trim();
  const priceAmount = parsePackDecimal(draft.priceAmount);
  const grantedSpark = parsePackInteger(draft.grantedSpark, 1);
  const bonusSpark = parsePackInteger(draft.bonusSpark, 0);
  const sortOrder = parsePackInteger(draft.sortOrder, 0);

  if (
    isPackDraftInvalid(draft) ||
    priceAmount === null ||
    grantedSpark === null ||
    bonusSpark === null ||
    sortOrder === null
  ) {
    throw new Error(text.invalidPackNumbers);
  }

  return {
    displayName,
    priceAmount,
    grantedSpark,
    bonusSpark,
    isActive: draft.isActive,
    sortOrder,
  };
}

export function toSubscriptionPlanDraft(plan: AdminSubscriptionPlan): SubscriptionPlanDraft {
  return {
    name: normalizeEconomyPlanNameInput(plan.name),
    priceAmount: plan.priceAmount.toString(),
    currencyCode: plan.currencyCode,
    monthlyTokenLimit: plan.monthlyTokenLimit.toString(),
    isRecommended: plan.isRecommended,
    isActive: plan.isActive,
    appleProductId: normalizeEconomyPlanProductIdInput(plan.appleProductId ?? ""),
    googleProductId: normalizeEconomyPlanProductIdInput(plan.googleProductId ?? ""),
    stripePriceId: normalizeEconomyPlanProductIdInput(plan.stripePriceId ?? ""),
    displayOrder: plan.displayOrder.toString(),
  };
}

export function isSubscriptionPlanDraftDirty(
  plan: AdminSubscriptionPlan,
  draft: SubscriptionPlanDraft
): boolean {
  const originalDraft = toSubscriptionPlanDraft(plan);
  return (
    draft.name !== originalDraft.name ||
    draft.priceAmount !== originalDraft.priceAmount ||
    draft.currencyCode !== originalDraft.currencyCode ||
    draft.monthlyTokenLimit !== originalDraft.monthlyTokenLimit ||
    draft.isRecommended !== originalDraft.isRecommended ||
    draft.isActive !== originalDraft.isActive ||
    draft.appleProductId !== originalDraft.appleProductId ||
    draft.googleProductId !== originalDraft.googleProductId ||
    draft.stripePriceId !== originalDraft.stripePriceId ||
    draft.displayOrder !== originalDraft.displayOrder
  );
}

export function isSubscriptionPlanDraftInvalid(draft: SubscriptionPlanDraft): boolean {
  const currencyCode = draft.currencyCode.trim().toUpperCase();
  const appleProductId = draft.appleProductId.trim();
  const googleProductId = draft.googleProductId.trim();
  const stripePriceId = draft.stripePriceId.trim();

  return (
    !isBoundedRequiredText(draft.name, ECONOMY_PLAN_NAME_MAX_LENGTH) ||
    parsePackDecimal(draft.priceAmount) === null ||
    parsePackInteger(draft.monthlyTokenLimit, 1) === null ||
    parsePackInteger(draft.displayOrder, 0) === null ||
    currencyCode.length !== 3 ||
    appleProductId.length > ECONOMY_PLAN_PRODUCT_ID_MAX_LENGTH ||
    googleProductId.length > ECONOMY_PLAN_PRODUCT_ID_MAX_LENGTH ||
    stripePriceId.length > ECONOMY_PLAN_PRODUCT_ID_MAX_LENGTH ||
    (draft.isActive && (!stripePriceId || !appleProductId || !googleProductId))
  );
}

export function updateSubscriptionPlanDraft(
  setPlanDrafts: Dispatch<SetStateAction<Record<string, SubscriptionPlanDraft>>>,
  planId: string,
  patch: Partial<SubscriptionPlanDraft>
) {
  setPlanDrafts((current) => ({
    ...current,
    [planId]: {
      ...(current[planId] ?? {
        name: "",
        priceAmount: "0",
        currencyCode: "USD",
        monthlyTokenLimit: "0",
        isRecommended: false,
        isActive: false,
        appleProductId: "",
        googleProductId: "",
        stripePriceId: "",
        displayOrder: "0",
      }),
      ...patch,
    },
  }));
}

export function toSubscriptionPlanPayload(
  draft: SubscriptionPlanDraft,
  text: EconomyValidationText
) {
  const name = draft.name.trim();
  const priceAmount = parsePackDecimal(draft.priceAmount);
  const monthlyTokenLimit = parsePackInteger(draft.monthlyTokenLimit, 1);
  const displayOrder = parsePackInteger(draft.displayOrder, 0);
  const currencyCode = draft.currencyCode.trim().toUpperCase();

  if (
    isSubscriptionPlanDraftInvalid(draft) ||
    priceAmount === null ||
    monthlyTokenLimit === null ||
    displayOrder === null ||
    currencyCode.length !== 3
  ) {
    throw new Error(text.invalidPlanNumbers);
  }

  return {
    name,
    priceAmount,
    currencyCode,
    monthlyTokenLimit,
    isRecommended: draft.isRecommended,
    isActive: draft.isActive,
    appleProductId: optionalBoundedPlanText(draft.appleProductId, text),
    googleProductId: optionalBoundedPlanText(draft.googleProductId, text),
    stripePriceId: optionalBoundedPlanText(draft.stripePriceId, text),
    displayOrder,
  };
}

export function createDefaultProviderConfigDraft(): ProviderConfigCreateDraft {
  return {
    provider: "stripe",
    platform: "web",
    region: "*",
    isEnabled: false,
    isRecommended: false,
    isSelectedByDefault: false,
    requiresExternalWarning: false,
    requiresStoreDisclosure: false,
    allowedFromAppVersion: "0.0.0",
    externalCheckoutAllowed: true,
    bonusTokensPercent: "0",
    displayLabel: "",
    displaySubtitle: "",
    warningTitle: "",
    warningMessage: "",
    mode: "live",
    notes: "",
  };
}

export function toProviderConfigDraft(
  config: AdminPaymentProviderConfiguration
): ProviderConfigDraft {
  return {
    region: config.region,
    isEnabled: config.isEnabled,
    isRecommended: config.isRecommended,
    isSelectedByDefault: config.isSelectedByDefault,
    requiresExternalWarning: config.requiresExternalWarning,
    requiresStoreDisclosure: config.requiresStoreDisclosure,
    allowedFromAppVersion: config.allowedFromAppVersion,
    externalCheckoutAllowed: config.externalCheckoutAllowed,
    bonusTokensPercent: config.bonusTokensPercent.toString(),
    displayLabel: config.displayLabel ?? "",
    displaySubtitle: config.displaySubtitle ?? "",
    warningTitle: config.warningTitle ?? "",
    warningMessage: config.warningMessage ?? "",
    mode: config.mode,
    notes: config.notes ?? "",
  };
}

export function isProviderConfigDraftDirty(
  config: AdminPaymentProviderConfiguration,
  draft: ProviderConfigDraft
): boolean {
  const originalDraft = toProviderConfigDraft(config);
  return (
    draft.region !== originalDraft.region ||
    draft.isEnabled !== originalDraft.isEnabled ||
    draft.isRecommended !== originalDraft.isRecommended ||
    draft.isSelectedByDefault !== originalDraft.isSelectedByDefault ||
    draft.requiresExternalWarning !== originalDraft.requiresExternalWarning ||
    draft.requiresStoreDisclosure !== originalDraft.requiresStoreDisclosure ||
    draft.allowedFromAppVersion !== originalDraft.allowedFromAppVersion ||
    draft.externalCheckoutAllowed !== originalDraft.externalCheckoutAllowed ||
    draft.bonusTokensPercent !== originalDraft.bonusTokensPercent ||
    draft.displayLabel !== originalDraft.displayLabel ||
    draft.displaySubtitle !== originalDraft.displaySubtitle ||
    draft.warningTitle !== originalDraft.warningTitle ||
    draft.warningMessage !== originalDraft.warningMessage ||
    draft.mode !== originalDraft.mode ||
    draft.notes !== originalDraft.notes
  );
}

export function toProviderConfigCreatePayload(
  draft: ProviderConfigCreateDraft,
  text: EconomyValidationText
) {
  const provider = draft.provider.trim().toLowerCase();
  const platform = draft.platform.trim().toLowerCase();

  if (!isSupportedProvider(provider) || !isSupportedPlatform(platform)) {
    throw new Error(text.invalidProviderConfigCreate);
  }

  return {
    provider,
    platform,
    ...toProviderConfigPayload(draft, text),
  };
}

export function toProviderConfigMatchPayload(
  draft: ProviderConfigMatchDraft,
  text: EconomyValidationText
) {
  const provider = draft.provider.trim().toLowerCase();
  const platform = draft.platform.trim().toLowerCase();
  const country = draft.country.trim().toUpperCase();
  const appVersion = draft.appVersion.trim();

  if (
    !isSupportedProvider(provider) ||
    !isSupportedPlatform(platform) ||
    !isValidCountry(country) ||
    !isValidAppVersion(appVersion)
  ) {
    throw new Error(text.invalidProviderConfigMatch);
  }

  return {
    provider,
    platform,
    country,
    appVersion,
  };
}

export function updateProviderConfigDraft(
  setProviderConfigDrafts: Dispatch<SetStateAction<Record<string, ProviderConfigDraft>>>,
  configurationId: string,
  patch: Partial<ProviderConfigDraft>
) {
  setProviderConfigDrafts((current) => ({
    ...current,
    [configurationId]: {
      ...(current[configurationId] ?? {
        region: "*",
        isEnabled: false,
        isRecommended: false,
        isSelectedByDefault: false,
        requiresExternalWarning: false,
        requiresStoreDisclosure: false,
        allowedFromAppVersion: "0.0.0",
        externalCheckoutAllowed: false,
        bonusTokensPercent: "0",
        displayLabel: "",
        displaySubtitle: "",
        warningTitle: "",
        warningMessage: "",
        mode: "live",
        notes: "",
      }),
      ...patch,
    },
  }));
}

export function toProviderConfigPayload(draft: ProviderConfigDraft, text: EconomyValidationText) {
  const region = draft.region.trim().toUpperCase();
  const allowedFromAppVersion = draft.allowedFromAppVersion.trim();
  const mode = draft.mode.trim().toLowerCase();
  const bonusTokensPercent = parseBonusTokensPercent(draft.bonusTokensPercent);

  if (
    !isValidRegion(region) ||
    !isValidAppVersion(allowedFromAppVersion) ||
    !isRouteMode(mode) ||
    bonusTokensPercent === null
  ) {
    throw new Error(text.invalidProviderConfig);
  }

  return {
    region,
    isEnabled: draft.isEnabled,
    isRecommended: draft.isRecommended,
    isSelectedByDefault: draft.isSelectedByDefault,
    requiresExternalWarning: draft.requiresExternalWarning,
    requiresStoreDisclosure: draft.requiresStoreDisclosure,
    allowedFromAppVersion,
    externalCheckoutAllowed: draft.externalCheckoutAllowed,
    bonusTokensPercent,
    displayLabel: optionalBoundedText(draft.displayLabel, ECONOMY_PROVIDER_LABEL_MAX_LENGTH, text),
    displaySubtitle: optionalBoundedText(
      draft.displaySubtitle,
      ECONOMY_PROVIDER_SUBTITLE_MAX_LENGTH,
      text
    ),
    warningTitle: optionalBoundedText(
      draft.warningTitle,
      ECONOMY_PROVIDER_WARNING_TITLE_MAX_LENGTH,
      text
    ),
    warningMessage: optionalBoundedText(
      draft.warningMessage,
      ECONOMY_PROVIDER_MESSAGE_MAX_LENGTH,
      text
    ),
    mode,
    notes: optionalBoundedText(draft.notes, ECONOMY_PROVIDER_NOTES_MAX_LENGTH, text),
  };
}

export function isProviderConfigCreateDraftInvalid(draft: ProviderConfigCreateDraft) {
  return (
    !isSupportedProvider(draft.provider.trim().toLowerCase()) ||
    !isSupportedPlatform(draft.platform.trim().toLowerCase()) ||
    isProviderConfigDraftInvalid(draft)
  );
}

export function isProviderConfigMatchDraftInvalid(draft: ProviderConfigMatchDraft) {
  return (
    !isSupportedProvider(draft.provider.trim().toLowerCase()) ||
    !isSupportedPlatform(draft.platform.trim().toLowerCase()) ||
    !isValidCountry(draft.country.trim().toUpperCase()) ||
    !isValidAppVersion(draft.appVersion.trim())
  );
}

export function isProviderConfigDraftInvalid(draft: ProviderConfigDraft) {
  return (
    !isValidRegion(draft.region.trim().toUpperCase()) ||
    !isRouteMode(draft.mode.trim().toLowerCase()) ||
    !isValidAppVersion(draft.allowedFromAppVersion.trim()) ||
    parseBonusTokensPercent(draft.bonusTokensPercent) === null
  );
}

export function normalizeEconomyPercentInput(value: string): string {
  return value.replace(/\D+/g, "").slice(0, ECONOMY_PROVIDER_BONUS_PERCENT_MAX_LENGTH);
}

export function normalizeEconomyIntegerInput(value: string): string {
  return value.replace(/\D+/g, "").slice(0, ECONOMY_PACK_INTEGER_MAX_LENGTH);
}

export function normalizeEconomyPriceInput(value: string): string {
  let hasDecimal = false;
  const normalized = Array.from(value)
    .filter((character) => {
      if (/\d/.test(character)) {
        return true;
      }

      if (character === "." && !hasDecimal) {
        hasDecimal = true;
        return true;
      }

      return false;
    })
    .join("");

  return normalized.slice(0, ECONOMY_PACK_PRICE_MAX_LENGTH);
}

export function normalizeEconomyCurrencyInput(value: string): string {
  return value
    .replace(/[^a-z]/gi, "")
    .toUpperCase()
    .slice(0, 3);
}

export function normalizeEconomyPackDisplayNameInput(value: string): string {
  return value.trim().slice(0, ECONOMY_PACK_DISPLAY_NAME_MAX_LENGTH);
}

export function normalizeEconomyPlanNameInput(value: string): string {
  return value.trim().slice(0, ECONOMY_PLAN_NAME_MAX_LENGTH);
}

export function normalizeEconomyPlanProductIdInput(value: string): string {
  return value.trim().slice(0, ECONOMY_PLAN_PRODUCT_ID_MAX_LENGTH);
}

function parseBonusTokensPercent(value: string): number | null {
  const trimmed = value.trim();
  if (!new RegExp(`^\\d{1,${ECONOMY_PROVIDER_BONUS_PERCENT_MAX_LENGTH}}$`).test(trimmed)) {
    return null;
  }

  const parsed = Number(trimmed);
  return Number.isInteger(parsed) && parsed >= 0 && parsed <= 100 ? parsed : null;
}

function isSupportedProvider(value: string): value is (typeof paymentProviderOptions)[number] {
  return paymentProviderOptions.includes(value as (typeof paymentProviderOptions)[number]);
}

function isSupportedPlatform(value: string): value is (typeof paymentPlatformOptions)[number] {
  return paymentPlatformOptions.includes(value as (typeof paymentPlatformOptions)[number]);
}

function isRouteMode(value: string): value is (typeof paymentRouteModeOptions)[number] {
  return paymentRouteModeOptions.includes(value as (typeof paymentRouteModeOptions)[number]);
}

function isValidRegion(value: string) {
  return value === "*" || /^[A-Z]{2}$/.test(value);
}

function isValidCountry(value: string) {
  return /^[A-Z]{2}$/.test(value);
}

function isValidAppVersion(value: string) {
  return (
    value.length > 0 &&
    value.length <= ECONOMY_PROVIDER_VERSION_MAX_LENGTH &&
    /^\d+(?:\.\d+){0,3}$/.test(value)
  );
}

function parsePackDecimal(value: string): number | null {
  const trimmed = value.trim();
  if (!new RegExp(`^\\d{1,${ECONOMY_PACK_PRICE_MAX_LENGTH - 3}}(?:\\.\\d{1,2})?$`).test(trimmed)) {
    return null;
  }

  const parsed = Number(trimmed);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

function parsePackInteger(value: string, minValue: number): number | null {
  const trimmed = value.trim();
  if (!new RegExp(`^\\d{1,${ECONOMY_PACK_INTEGER_MAX_LENGTH}}$`).test(trimmed)) {
    return null;
  }

  const parsed = Number(trimmed);
  return Number.isInteger(parsed) && parsed >= minValue ? parsed : null;
}

function isBoundedRequiredText(value: string, maxLength: number): boolean {
  const normalized = value.trim();
  return normalized.length > 0 && normalized.length <= maxLength;
}

function optionalBoundedText(
  value: string,
  maxLength: number,
  text: EconomyValidationText
): string | null {
  const normalized = value.trim();
  if (!normalized) {
    return null;
  }

  if (normalized.length > maxLength) {
    throw new Error(text.invalidProviderConfig);
  }

  return normalized;
}

function optionalBoundedPlanText(value: string, text: EconomyValidationText): string | null {
  const normalized = value.trim();
  if (!normalized) {
    return null;
  }

  if (normalized.length > ECONOMY_PLAN_PRODUCT_ID_MAX_LENGTH) {
    throw new Error(text.invalidPlanNumbers);
  }

  return normalized;
}
