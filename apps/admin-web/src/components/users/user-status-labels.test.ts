import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const userDetailPath = fileURLToPath(new URL("./user-detail-page.tsx", import.meta.url));
const userInlineAnalyticsPath = fileURLToPath(
  new URL("./user-inline-analytics.tsx", import.meta.url)
);
const monetizationFormatPath = fileURLToPath(
  new URL("./user-monetization-format.ts", import.meta.url)
);
const enDictionaryPath = fileURLToPath(new URL("../../lib/i18n.en.ts", import.meta.url));
const ruDictionaryPath = fileURLToPath(new URL("../../lib/i18n.ru.ts", import.meta.url));

describe("user status labels", () => {
  it("uses status labels instead of action labels for blocked users", () => {
    const userDetailSource = readFileSync(userDetailPath, "utf8");
    const userInlineAnalyticsSource = readFileSync(userInlineAnalyticsPath, "utf8");

    expect(userDetailSource).toContain("text.activeLabel : text.blockedLabel");
    expect(userInlineAnalyticsSource).toContain("text.activeLabel : text.blockedLabel");
    expect(userDetailSource).not.toContain("text.activeLabel : text.deactivate");
    expect(userInlineAnalyticsSource).not.toContain("text.activeLabel : text.deactivate");
  });

  it("uses localized monetization labels instead of hardcoded spark strings", () => {
    const userDetailSource = readFileSync(userDetailPath, "utf8");
    const userInlineAnalyticsSource = readFileSync(userInlineAnalyticsPath, "utf8");
    const formatterSource = readFileSync(monetizationFormatPath, "utf8");
    const enDictionarySource = readFileSync(enDictionaryPath, "utf8");
    const ruDictionarySource = readFileSync(ruDictionaryPath, "utf8");

    expect(formatterSource).toContain("export function formatLabeledMetric(label: string, value: number): string");
    expect(userDetailSource).toContain("formatLabeledMetric(text.purchasedSparkLabel, purchase.sparkToGrant)");
    expect(userInlineAnalyticsSource).toContain(
      "formatLabeledMetric(text.purchasedSparkLabel, purchase.sparkToGrant)"
    );
    expect(userDetailSource).toContain("formatLabeledMetric(text.tokenCostLabel, generation.tokenCost)");
    expect(userInlineAnalyticsSource).toContain(
      "formatLabeledMetric(text.tokenCostLabel, generation.tokenCost)"
    );
    expect(userDetailSource).not.toContain("purchase.sparkToGrant} spark");
    expect(userInlineAnalyticsSource).not.toContain("purchase.sparkToGrant} spark");
    expect(userDetailSource).not.toContain("generation.tokenCost} PawSpark");
    expect(enDictionarySource).toContain('purchasedSparkLabel: "Purchased PawSpark"');
    expect(ruDictionarySource).toContain('purchasedSparkLabel: "Куплено PawSpark"');
  });
});
