import { describe, expect, it } from "vitest";

import {
  getIncidentActionRequirements,
  isIncidentActionAmountValid,
  parseIncidentActionAmount,
} from "@/components/economy-page-incidents-section";

describe("incident action form requirements", () => {
  it("requires a positive amount for grants and revokes", () => {
    for (const action of ["manual_bonus_grant", "manual_revoke"]) {
      expect(getIncidentActionRequirements(action).requiresAmount).toBe(true);
      expect(isIncidentActionAmountValid(action, parseIncidentActionAmount(""))).toBe(false);
      expect(isIncidentActionAmountValid(action, parseIncidentActionAmount("-1"))).toBe(false);
      expect(isIncidentActionAmountValid(action, parseIncidentActionAmount("0"))).toBe(false);
      expect(isIncidentActionAmountValid(action, parseIncidentActionAmount("1"))).toBe(true);
    }
  });

  it("allows a signed non-zero amount only for wallet corrections", () => {
    const requirements = getIncidentActionRequirements("manual_wallet_correction");

    expect(requirements).toMatchObject({ requiresAmount: true, allowsSignedAmount: true });
    expect(
      isIncidentActionAmountValid("manual_wallet_correction", parseIncidentActionAmount("-75"))
    ).toBe(true);
    expect(
      isIncidentActionAmountValid("manual_wallet_correction", parseIncidentActionAmount("0"))
    ).toBe(false);
  });

  it("requires an external reference only for manual refund marks", () => {
    expect(getIncidentActionRequirements("manual_refund_mark").requiresExternalReference).toBe(
      true
    );
    expect(getIncidentActionRequirements("manual_settle").requiresExternalReference).toBe(false);
  });

  it("rejects ambiguous or out-of-range integer input without coercing it", () => {
    expect(parseIncidentActionAmount("1--2")).toBeNull();
    expect(parseIncidentActionAmount("1.5")).toBeNull();
    expect(parseIncidentActionAmount("1e3")).toBeNull();
    expect(parseIncidentActionAmount("2147483648")).toBeNull();
  });
});
