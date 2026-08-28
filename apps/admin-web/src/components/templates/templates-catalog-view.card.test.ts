import { describe, expect, it } from "vitest";

import { formatUsdEstimate } from "@/components/templates/templates-catalog-view.card";

describe("formatUsdEstimate", () => {
  it("shows customer-facing cost with at most two decimal places", () => {
    expect(formatUsdEstimate(0.219, "en")).toBe("$0.22");
    expect(formatUsdEstimate(2, "en")).toBe("$2.00");
  });

  it("uses the active admin locale", () => {
    expect(formatUsdEstimate(0.219, "ru")).toContain("0,22");
  });
});
