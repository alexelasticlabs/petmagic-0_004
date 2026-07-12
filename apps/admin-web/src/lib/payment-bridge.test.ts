import { afterEach, describe, expect, it } from "vitest";

import { buildPaymentAppLink, resolvePaymentAppScheme } from "@/lib/payment-bridge";

const originalScheme = process.env.PETMAGIC_APP_DEEP_LINK_SCHEME;

afterEach(() => {
  if (originalScheme === undefined) {
    delete process.env.PETMAGIC_APP_DEEP_LINK_SCHEME;
  } else {
    process.env.PETMAGIC_APP_DEEP_LINK_SCHEME = originalScheme;
  }
});

describe("payment bridge", () => {
  it("passes only canonical Stripe checkout session ids to the app", () => {
    process.env.PETMAGIC_APP_DEEP_LINK_SCHEME = "petmagic";

    expect(buildPaymentAppLink("success", "cs_live_12345678")).toBe(
      "petmagic://checkout/success?session_id=cs_live_12345678"
    );
    expect(buildPaymentAppLink("success", "https://evil.example/?token=secret")).toBe(
      "petmagic://checkout/success"
    );
    expect(buildPaymentAppLink("success", ["cs_live_12345678"])).toBe(
      "petmagic://checkout/success"
    );
  });

  it("uses fixed cancel and subscription management destinations", () => {
    process.env.PETMAGIC_APP_DEEP_LINK_SCHEME = "petmagic-staging";

    expect(buildPaymentAppLink("cancel", "https://evil.example")).toBe(
      "petmagic-staging://checkout/cancel"
    );
    expect(buildPaymentAppLink("manage")).toBe("petmagic-staging://checkout/manage");
  });

  it("rejects arbitrary configured schemes", () => {
    expect(() => resolvePaymentAppScheme("javascript")).toThrow(
      "PETMAGIC_APP_DEEP_LINK_SCHEME must be petmagic or petmagic-staging."
    );
  });
});
