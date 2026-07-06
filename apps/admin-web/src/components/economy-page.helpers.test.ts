import { describe, expect, it } from "vitest";

import {
  canCancelSubscription,
  canRefundPurchase,
  createDefaultProviderConfigDraft,
  isPackDraftDirty,
  isProviderConfigDraftDirty,
  isSubscriptionPlanDraftDirty,
  normalizeEconomyCurrencyInput,
  normalizeEconomyIntegerInput,
  normalizeEconomyPackDisplayNameInput,
  normalizeEconomyPercentInput,
  normalizeEconomyPlanNameInput,
  normalizeEconomyPlanProductIdInput,
  normalizeEconomyPriceInput,
  toDraft,
  toCurrencyPackPayload,
  toProviderConfigCreatePayload,
  toProviderConfigMatchPayload,
  toProviderConfigPayload,
  toProviderConfigDraft,
  toSubscriptionPlanDraft,
  toSubscriptionPlanPayload,
  type EconomyValidationText,
} from "@/components/economy-page.helpers";
import type {
  AdminCurrencyPack,
  AdminEconomyPurchase,
  AdminEconomySubscription,
  AdminPaymentProviderConfiguration,
  AdminSubscriptionPlan,
} from "@/lib/api-client";

function createPurchase(patch: Partial<AdminEconomyPurchase> = {}): AdminEconomyPurchase {
  return {
    orderId: "order-1",
    userId: "user-1",
    packId: "pack-1",
    packCode: "starter",
    packDisplayName: "Starter",
    paymentProvider: "stripe",
    status: "succeeded",
    priceAmount: 9.99,
    currencyCode: "USD",
    sparkToGrant: 100,
    canRefund: true,
    createdAtUtc: "2026-06-06T12:00:00Z",
    ...patch,
  };
}

function createSubscription(
  patch: Partial<AdminEconomySubscription> = {}
): AdminEconomySubscription {
  return {
    subscriptionId: "subscription-1",
    userId: "user-1",
    provider: "stripe",
    purchaseChannel: "web",
    region: "US",
    planId: "plan-1",
    planName: "Premium",
    status: "active",
    cancelAtPeriodEnd: false,
    monthlyTokenLimit: 100,
    monthlyTokensGranted: 10,
    createdAtUtc: "2026-06-06T12:00:00Z",
    updatedAtUtc: "2026-06-06T12:00:00Z",
    ...patch,
  };
}

function createCurrencyPack(patch: Partial<AdminCurrencyPack> = {}): AdminCurrencyPack {
  return {
    packId: "pack-1",
    code: "starter",
    displayName: "Starter",
    currencyCode: "USD",
    priceAmount: 9.99,
    grantedSpark: 100,
    bonusSpark: 10,
    totalSpark: 110,
    isActive: true,
    sortOrder: 1,
    ...patch,
  };
}

function createSubscriptionPlan(patch: Partial<AdminSubscriptionPlan> = {}): AdminSubscriptionPlan {
  return {
    planId: "plan-1",
    name: "Premium",
    billingPeriod: "month",
    priceAmount: 19.99,
    currencyCode: "USD",
    monthlyTokenLimit: 1000,
    isRecommended: true,
    isActive: true,
    appleProductId: "apple-premium",
    googleProductId: "google-premium",
    stripePriceId: "price_premium",
    displayOrder: 1,
    updatedAtUtc: "2026-06-06T12:00:00Z",
    ...patch,
  };
}

function createProviderConfig(
  patch: Partial<AdminPaymentProviderConfiguration> = {}
): AdminPaymentProviderConfiguration {
  return {
    configurationId: "config-1",
    provider: "stripe",
    platform: "web",
    region: "US",
    isEnabled: true,
    isRecommended: false,
    isSelectedByDefault: true,
    requiresExternalWarning: false,
    requiresStoreDisclosure: false,
    allowedFromAppVersion: "1.0.0",
    externalCheckoutAllowed: true,
    bonusTokensPercent: 10,
    displayLabel: "Stripe",
    displaySubtitle: "Card checkout",
    warningTitle: null,
    warningMessage: null,
    mode: "live",
    notes: null,
    updatedAtUtc: "2026-06-06T12:00:00Z",
    ...patch,
  };
}

describe("economy action guards", () => {
  it("detects whether a pack draft differs from the backend pack", () => {
    const pack = createCurrencyPack();

    expect(isPackDraftDirty(pack, toDraft(pack))).toBe(false);
    expect(isPackDraftDirty(pack, { ...toDraft(pack), displayName: "Starter plus" })).toBe(true);
    expect(isPackDraftDirty(pack, { ...toDraft(pack), priceAmount: "10.99" })).toBe(true);
    expect(isPackDraftDirty(pack, { ...toDraft(pack), isActive: false })).toBe(true);
  });

  it("detects whether a subscription plan draft differs from the backend plan", () => {
    const plan = createSubscriptionPlan();

    expect(isSubscriptionPlanDraftDirty(plan, toSubscriptionPlanDraft(plan))).toBe(false);
    expect(
      isSubscriptionPlanDraftDirty(plan, { ...toSubscriptionPlanDraft(plan), name: "Premium plus" })
    ).toBe(true);
    expect(
      isSubscriptionPlanDraftDirty(plan, { ...toSubscriptionPlanDraft(plan), priceAmount: "24.99" })
    ).toBe(true);
    expect(
      isSubscriptionPlanDraftDirty(plan, { ...toSubscriptionPlanDraft(plan), isRecommended: false })
    ).toBe(true);
  });

  it("detects whether a provider config draft differs from the backend config", () => {
    const config = createProviderConfig();

    expect(isProviderConfigDraftDirty(config, toProviderConfigDraft(config))).toBe(false);
    expect(
      isProviderConfigDraftDirty(config, { ...toProviderConfigDraft(config), region: "DE" })
    ).toBe(true);
    expect(
      isProviderConfigDraftDirty(config, {
        ...toProviderConfigDraft(config),
        externalCheckoutAllowed: false,
      })
    ).toBe(true);
    expect(
      isProviderConfigDraftDirty(config, { ...toProviderConfigDraft(config), notes: "QA route" })
    ).toBe(true);
  });

  it("allows refunds only when backend marks the purchase refundable", () => {
    expect(canRefundPurchase(createPurchase({ canRefund: true }))).toBe(true);
    expect(canRefundPurchase(createPurchase({ canRefund: false }))).toBe(false);
    expect(canRefundPurchase(createPurchase({ canRefund: undefined }))).toBe(false);
  });

  it("allows subscription cancellation only for active stripe subscriptions not already ending", () => {
    expect(canCancelSubscription(createSubscription())).toBe(true);
    expect(canCancelSubscription(createSubscription({ status: "trialing" }))).toBe(true);
    expect(canCancelSubscription(createSubscription({ status: "canceled" }))).toBe(false);
    expect(canCancelSubscription(createSubscription({ provider: "apple" }))).toBe(false);
    expect(canCancelSubscription(createSubscription({ cancelAtPeriodEnd: true }))).toBe(false);
  });
});

const validationText: EconomyValidationText = {
  invalidPackNumbers: "invalid pack",
  invalidPlanNumbers: "invalid plan",
  invalidProviderConfigCreate: "invalid provider create",
  invalidProviderConfigMatch: "invalid provider match",
  invalidProviderConfig: "invalid provider config",
};

describe("currency pack payloads", () => {
  it("trims and validates bounded pack payload values", () => {
    const payload = toCurrencyPackPayload(
      {
        displayName: " Starter pack ",
        priceAmount: "9.99",
        grantedSpark: "100",
        bonusSpark: "10",
        sortOrder: "2",
        isActive: true,
      },
      validationText
    );

    expect(payload).toEqual({
      displayName: "Starter pack",
      priceAmount: 9.99,
      grantedSpark: 100,
      bonusSpark: 10,
      sortOrder: 2,
      isActive: true,
    });
  });

  it("normalizes currency pack inputs and rejects exponent or oversized values", () => {
    expect(normalizeEconomyPriceInput("1e2.345")).toBe("12.345");
    expect(normalizeEconomyIntegerInput("1e2.5abc999999999")).toBe("125999999");
    expect(normalizeEconomyPackDisplayNameInput(` ${"p".repeat(90)} `)).toHaveLength(80);
    expect(
      toDraft(createCurrencyPack({ displayName: ` ${"p".repeat(90)} ` })).displayName
    ).toHaveLength(80);

    expect(() =>
      toCurrencyPackPayload(
        {
          displayName: "Starter",
          priceAmount: "1e2",
          grantedSpark: "100",
          bonusSpark: "0",
          sortOrder: "1",
          isActive: true,
        },
        validationText
      )
    ).toThrow(validationText.invalidPackNumbers);

    expect(() =>
      toCurrencyPackPayload(
        {
          displayName: "x".repeat(81),
          priceAmount: "9.99",
          grantedSpark: "100",
          bonusSpark: "0",
          sortOrder: "1",
          isActive: true,
        },
        validationText
      )
    ).toThrow(validationText.invalidPackNumbers);

    expect(() =>
      toCurrencyPackPayload(
        {
          displayName: "Starter",
          priceAmount: "9.99",
          grantedSpark: "0",
          bonusSpark: "0",
          sortOrder: "1",
          isActive: true,
        },
        validationText
      )
    ).toThrow(validationText.invalidPackNumbers);
  });
});

describe("subscription plan payloads", () => {
  it("trims and validates bounded premium plan payload values", () => {
    const payload = toSubscriptionPlanPayload(
      {
        name: " Premium monthly ",
        priceAmount: "19.99",
        currencyCode: " usd ",
        monthlyTokenLimit: "1000",
        isRecommended: true,
        isActive: true,
        appleProductId: " apple-premium ",
        googleProductId: " google-premium ",
        stripePriceId: " price_premium ",
        displayOrder: "1",
      },
      validationText
    );

    expect(payload).toEqual({
      name: "Premium monthly",
      priceAmount: 19.99,
      currencyCode: "USD",
      monthlyTokenLimit: 1000,
      isRecommended: true,
      isActive: true,
      appleProductId: "apple-premium",
      googleProductId: "google-premium",
      stripePriceId: "price_premium",
      displayOrder: 1,
    });
  });

  it("normalizes currency codes and rejects exponent or oversized plan values", () => {
    expect(normalizeEconomyCurrencyInput(" u-s$d1 ")).toBe("USD");
    expect(normalizeEconomyPlanNameInput(` ${"p".repeat(90)} `)).toHaveLength(80);
    expect(normalizeEconomyPlanProductIdInput(` ${"i".repeat(170)} `)).toHaveLength(160);
    expect(
      toSubscriptionPlanDraft(
        createSubscriptionPlan({
          name: ` ${"p".repeat(90)} `,
          appleProductId: ` ${"a".repeat(170)} `,
          googleProductId: ` ${"g".repeat(170)} `,
          stripePriceId: ` ${"s".repeat(170)} `,
        })
      )
    ).toMatchObject({
      name: "p".repeat(80),
      appleProductId: "a".repeat(160),
      googleProductId: "g".repeat(160),
      stripePriceId: "s".repeat(160),
    });

    expect(() =>
      toSubscriptionPlanPayload(
        {
          name: "Premium",
          priceAmount: "1e2",
          currencyCode: "USD",
          monthlyTokenLimit: "1000",
          isRecommended: false,
          isActive: false,
          appleProductId: "",
          googleProductId: "",
          stripePriceId: "",
          displayOrder: "0",
        },
        validationText
      )
    ).toThrow(validationText.invalidPlanNumbers);

    expect(() =>
      toSubscriptionPlanPayload(
        {
          name: "Premium",
          priceAmount: "19.99",
          currencyCode: "USD",
          monthlyTokenLimit: "1000",
          isRecommended: false,
          isActive: false,
          appleProductId: "x".repeat(161),
          googleProductId: "",
          stripePriceId: "",
          displayOrder: "0",
        },
        validationText
      )
    ).toThrow(validationText.invalidPlanNumbers);
  });
});

describe("provider config payloads", () => {
  it("uses live mode for new production payment routes by default", () => {
    expect(createDefaultProviderConfigDraft().mode).toBe("live");
  });

  it("trims and normalizes payment route create payloads", () => {
    const payload = toProviderConfigCreatePayload(
      {
        ...createDefaultProviderConfigDraft(),
        provider: " Stripe ",
        platform: " WEB ",
        region: " us ",
        allowedFromAppVersion: " 1.2.3 ",
        mode: " LIVE ",
        displayLabel: " Premium checkout ",
        displaySubtitle: " ",
        warningTitle: "",
        warningMessage: " ",
        notes: "  ",
      },
      validationText
    );

    expect(payload).toMatchObject({
      provider: "stripe",
      platform: "web",
      region: "US",
      allowedFromAppVersion: "1.2.3",
      mode: "live",
      displayLabel: "Premium checkout",
      displaySubtitle: null,
      warningTitle: null,
      warningMessage: null,
      notes: null,
    });
  });

  it("normalizes and validates bounded payment route fields", () => {
    expect(normalizeEconomyPercentInput("1e2.5abc999")).toBe("125");

    expect(() =>
      toProviderConfigCreatePayload(
        {
          ...createDefaultProviderConfigDraft(),
          provider: "x".repeat(49),
        },
        validationText
      )
    ).toThrow(validationText.invalidProviderConfigCreate);

    expect(() =>
      toProviderConfigMatchPayload(
        {
          provider: "stripe",
          platform: "web",
          country: "US",
          appVersion: "1".repeat(33),
        },
        validationText
      )
    ).toThrow(validationText.invalidProviderConfigMatch);

    expect(() =>
      toProviderConfigPayload(
        {
          ...createDefaultProviderConfigDraft(),
          bonusTokensPercent: "1e2",
        },
        validationText
      )
    ).toThrow(validationText.invalidProviderConfig);

    expect(() =>
      toProviderConfigPayload(
        {
          ...createDefaultProviderConfigDraft(),
          warningMessage: "x".repeat(241),
        },
        validationText
      )
    ).toThrow(validationText.invalidProviderConfig);
  });
});
