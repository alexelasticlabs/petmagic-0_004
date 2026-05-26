import { type Dispatch, type SetStateAction } from "react";

import {
  type AdminCurrencyPack,
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
  invalidPlanNumbers: string;
  invalidProviderConfigCreate: string;
  invalidProviderConfigMatch: string;
  invalidProviderConfig: string;
};

export function toDraft(pack: AdminCurrencyPack): PackDraft {
  return {
    displayName: pack.displayName,
    priceAmount: pack.priceAmount.toString(),
    grantedSpark: pack.grantedSpark.toString(),
    bonusSpark: pack.bonusSpark.toString(),
    sortOrder: pack.sortOrder.toString(),
    isActive: pack.isActive,
  };
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

export function toSubscriptionPlanDraft(plan: AdminSubscriptionPlan): SubscriptionPlanDraft {
  return {
    name: plan.name,
    priceAmount: plan.priceAmount.toString(),
    currencyCode: plan.currencyCode,
    monthlyTokenLimit: plan.monthlyTokenLimit.toString(),
    isRecommended: plan.isRecommended,
    isActive: plan.isActive,
    appleProductId: plan.appleProductId ?? "",
    googleProductId: plan.googleProductId ?? "",
    stripePriceId: plan.stripePriceId ?? "",
    displayOrder: plan.displayOrder.toString(),
  };
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
  const priceAmount = Number(draft.priceAmount);
  const monthlyTokenLimit = Number(draft.monthlyTokenLimit);
  const displayOrder = Number(draft.displayOrder);
  const currencyCode = draft.currencyCode.trim().toUpperCase();

  if (
    !draft.name.trim() ||
    !Number.isFinite(priceAmount) ||
    priceAmount <= 0 ||
    !Number.isFinite(monthlyTokenLimit) ||
    monthlyTokenLimit <= 0 ||
    !Number.isFinite(displayOrder) ||
    displayOrder < 0 ||
    currencyCode.length !== 3
  ) {
    throw new Error(text.invalidPlanNumbers);
  }

  return {
    name: draft.name.trim(),
    priceAmount,
    currencyCode,
    monthlyTokenLimit,
    isRecommended: draft.isRecommended,
    isActive: draft.isActive,
    appleProductId: optionalText(draft.appleProductId),
    googleProductId: optionalText(draft.googleProductId),
    stripePriceId: optionalText(draft.stripePriceId),
    displayOrder,
  };
}

export function createDefaultProviderConfigDraft(): ProviderConfigCreateDraft {
  return {
    provider: "stripe",
    platform: "web",
    region: "*",
    isEnabled: true,
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
    mode: "test",
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

export function toProviderConfigCreatePayload(
  draft: ProviderConfigCreateDraft,
  text: EconomyValidationText
) {
  const provider = draft.provider.trim().toLowerCase();
  const platform = draft.platform.trim().toLowerCase();

  if (!provider || !platform) {
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

  if (!provider || !platform || !country || !appVersion) {
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
        mode: "test",
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
  const bonusTokensPercent = Number(draft.bonusTokensPercent);

  if (
    !region ||
    !allowedFromAppVersion ||
    !mode ||
    !Number.isFinite(bonusTokensPercent) ||
    bonusTokensPercent < 0 ||
    bonusTokensPercent > 100
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
    displayLabel: optionalText(draft.displayLabel),
    displaySubtitle: optionalText(draft.displaySubtitle),
    warningTitle: optionalText(draft.warningTitle),
    warningMessage: optionalText(draft.warningMessage),
    mode,
    notes: optionalText(draft.notes),
  };
}

function optionalText(value: string) {
  const normalized = value.trim();
  return normalized ? normalized : null;
}
