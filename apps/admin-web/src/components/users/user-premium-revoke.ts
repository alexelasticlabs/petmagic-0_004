import type { AdminEconomyUserSubscriptionSummary } from "@/lib/api-client.types.economy";

export const PREMIUM_REVOKE_REASON_MAX_LENGTH = 500;

type PremiumSubscriptionSnapshot = Pick<
  AdminEconomyUserSubscriptionSummary,
  "cancelAtPeriodEnd" | "hasPendingAdminRevocation" | "isPremium" | "provider" | "status"
>;

export type PremiumRevokeEligibility =
  | {
      kind: "cancellable";
      provider: "stripe";
      status: "active" | "trialing";
    }
  | {
      kind: "recovery-pending";
      provider: "stripe";
      status: string;
    }
  | {
      kind:
        | "cancellation-scheduled"
        | "inactive"
        | "store-managed"
        | "unavailable"
        | "unsupported-provider";
      provider: string;
      status: string;
    };

const cancellableStripeStatuses = new Set(["active", "trialing"]);
const storeManagedProviders = new Set(["app_store", "google_play"]);

function normalizeSubscriptionValue(value?: string | null): string {
  return value?.trim().toLowerCase() ?? "";
}

export function resolvePremiumRevokeEligibility(
  summary?: PremiumSubscriptionSnapshot | null
): PremiumRevokeEligibility {
  if (!summary) {
    return { kind: "unavailable", provider: "", status: "" };
  }

  const provider = normalizeSubscriptionValue(summary.provider);
  const status = normalizeSubscriptionValue(summary.status);

  if (summary.hasPendingAdminRevocation) {
    return { kind: "recovery-pending", provider: "stripe", status };
  }

  if (!summary.isPremium) {
    return { kind: "inactive", provider, status };
  }

  if (storeManagedProviders.has(provider)) {
    return { kind: "store-managed", provider, status };
  }

  if (provider !== "stripe") {
    return { kind: "unsupported-provider", provider, status };
  }

  if (summary.cancelAtPeriodEnd) {
    return { kind: "cancellation-scheduled", provider, status };
  }

  if (!cancellableStripeStatuses.has(status)) {
    return { kind: "inactive", provider, status };
  }

  return {
    kind: "cancellable",
    provider: "stripe",
    status: status as "active" | "trialing",
  };
}
