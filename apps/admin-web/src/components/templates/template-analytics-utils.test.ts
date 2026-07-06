import { describe, expect, it } from "vitest";

import {
  formatAnalyticsValue,
  formatModelSummary,
  formatModelValue,
  formatUsd,
} from "@/components/templates/template-analytics-utils";

describe("template analytics display utilities", () => {
  it("sanitizes backend supplied analytics dimensions and model labels", () => {
    expect(formatAnalyticsValue("ios_app token=raw-token")).toBe("ios app token=[redacted]");
    expect(
      formatAnalyticsValue("https://cdn.example.com/source?X-Amz-Signature=secret")
    ).not.toContain("X-Amz-Signature=secret");

    expect(formatModelValue("provider/team/model token=raw-model-secret")).toBe(
      "team/model token=[redacted]"
    );
    expect(formatModelValue("https://cdn.example.com/model?secret=1")).not.toContain("secret=1");
    expect(
      formatModelSummary(
        "image/provider/model access_token=raw-preprocess-token",
        "video/provider/kling receipt=raw-receipt"
      )
    ).toBe("provider/model access_token=[redacted] + provider/kling receipt=[redacted]");
  });

  it("formats USD analytics values with the selected admin locale", () => {
    expect(formatUsd(1234.56, "en")).toBe("$1,234.56");
    expect(formatUsd(1234.56, "ru")).toBe("1\u00a0234,56\u00a0$");
  });
});
