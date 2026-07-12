export type PaymentBridgeOutcome = "success" | "cancel" | "manage";

const STRIPE_CHECKOUT_SESSION_ID = /^cs_(?:test|live)_[A-Za-z0-9_]{8,255}$/;
const ALLOWED_APP_SCHEMES = new Set(["petmagic", "petmagic-staging"]);

export function resolvePaymentAppScheme(
  configuredScheme = process.env.PETMAGIC_APP_DEEP_LINK_SCHEME
): string {
  const scheme = configuredScheme?.trim().toLowerCase() || "petmagic";
  if (!ALLOWED_APP_SCHEMES.has(scheme)) {
    throw new Error("PETMAGIC_APP_DEEP_LINK_SCHEME must be petmagic or petmagic-staging.");
  }

  return scheme;
}

export function buildPaymentAppLink(
  outcome: PaymentBridgeOutcome,
  rawSessionId?: string | string[]
): string {
  const scheme = resolvePaymentAppScheme();
  const path = outcome === "manage" ? "manage" : outcome;
  const sessionId = typeof rawSessionId === "string" ? rawSessionId.trim() : "";
  const safeSessionId =
    outcome === "success" && STRIPE_CHECKOUT_SESSION_ID.test(sessionId) ? sessionId : null;

  return `${scheme}://checkout/${path}${
    safeSessionId ? `?session_id=${encodeURIComponent(safeSessionId)}` : ""
  }`;
}
