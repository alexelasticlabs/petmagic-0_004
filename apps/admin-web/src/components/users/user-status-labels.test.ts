import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const userDetailPath = fileURLToPath(new URL("./user-detail-page.tsx", import.meta.url));
const userInlineAnalyticsPath = fileURLToPath(
  new URL("./user-inline-analytics.tsx", import.meta.url)
);

describe("user status labels", () => {
  it("uses status labels instead of action labels for blocked users", () => {
    const userDetailSource = readFileSync(userDetailPath, "utf8");
    const userInlineAnalyticsSource = readFileSync(userInlineAnalyticsPath, "utf8");

    expect(userDetailSource).toContain("text.activeLabel : text.blockedLabel");
    expect(userInlineAnalyticsSource).toContain("text.activeLabel : text.blockedLabel");
    expect(userDetailSource).not.toContain("text.activeLabel : text.deactivate");
    expect(userInlineAnalyticsSource).not.toContain("text.activeLabel : text.deactivate");
  });
});
