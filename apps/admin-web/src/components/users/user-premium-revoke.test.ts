import { describe, expect, it } from "vitest";

import { resolvePremiumRevokeEligibility } from "@/components/users/user-premium-revoke";

const activeStripeSubscription = {
  cancelAtPeriodEnd: false,
  isPremium: true,
  provider: "stripe",
  status: "Active",
};

describe("resolvePremiumRevokeEligibility", () => {
  it("allows only active or trialing Stripe subscriptions", () => {
    expect(resolvePremiumRevokeEligibility(activeStripeSubscription)).toEqual({
      kind: "cancellable",
      provider: "stripe",
      status: "active",
    });
    expect(
      resolvePremiumRevokeEligibility({
        ...activeStripeSubscription,
        provider: " Stripe ",
        status: " TRIALING ",
      })
    ).toEqual({
      kind: "cancellable",
      provider: "stripe",
      status: "trialing",
    });
  });

  it("keeps App Store and Google Play subscriptions read-only", () => {
    expect(
      resolvePremiumRevokeEligibility({
        ...activeStripeSubscription,
        provider: "app_store",
      }).kind
    ).toBe("store-managed");
    expect(
      resolvePremiumRevokeEligibility({
        ...activeStripeSubscription,
        provider: "google_play",
      }).kind
    ).toBe("store-managed");
  });

  it("blocks Stripe cancellation that is scheduled or no longer active", () => {
    expect(
      resolvePremiumRevokeEligibility({
        ...activeStripeSubscription,
        cancelAtPeriodEnd: true,
      }).kind
    ).toBe("cancellation-scheduled");

    for (const status of ["Canceled", "Expired", "GracePeriod", "PastDue"]) {
      expect(
        resolvePremiumRevokeEligibility({
          ...activeStripeSubscription,
          status,
        }).kind
      ).toBe("inactive");
    }
  });

  it("keeps an interrupted admin revocation retryable after Premium is already locally expired", () => {
    expect(
      resolvePremiumRevokeEligibility({
        ...activeStripeSubscription,
        hasPendingAdminRevocation: true,
        isPremium: false,
        status: "Expired",
      })
    ).toEqual({
      kind: "recovery-pending",
      provider: "stripe",
      status: "expired",
    });
  });

  it("fails closed for missing, non-premium, and unsupported subscription data", () => {
    expect(resolvePremiumRevokeEligibility().kind).toBe("unavailable");
    expect(
      resolvePremiumRevokeEligibility({
        ...activeStripeSubscription,
        isPremium: false,
      }).kind
    ).toBe("inactive");
    expect(
      resolvePremiumRevokeEligibility({
        ...activeStripeSubscription,
        provider: "manual",
      }).kind
    ).toBe("unsupported-provider");
  });
});
