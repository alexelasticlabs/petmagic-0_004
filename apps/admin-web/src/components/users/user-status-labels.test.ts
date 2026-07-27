import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const userDetailPath = fileURLToPath(new URL("./user-detail-page.tsx", import.meta.url));
const userInlineAnalyticsPath = fileURLToPath(
  new URL("./user-inline-analytics.tsx", import.meta.url)
);
const userAccessControlPanelPath = fileURLToPath(
  new URL("./user-access-control-panel.tsx", import.meta.url)
);
const usersTablePath = fileURLToPath(
  new URL("../users-management-users-card.table.tsx", import.meta.url)
);
const userHelpersPath = fileURLToPath(
  new URL("../users-management-page.helpers.ts", import.meta.url)
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
    const userAccessControlPanelSource = readFileSync(userAccessControlPanelPath, "utf8");

    expect(userDetailSource).toContain("text.activeLabel : text.blockedLabel");
    expect(userInlineAnalyticsSource).toContain("text.activeLabel : text.blockedLabel");
    expect(userAccessControlPanelSource).toContain("text.activeLabel : text.blockedLabel");
    expect(userDetailSource).not.toContain("text.activeLabel : text.deactivate");
    expect(userInlineAnalyticsSource).not.toContain("text.activeLabel : text.deactivate");
    expect(userAccessControlPanelSource).not.toContain("text.activeLabel : text.deactivate");
  });

  it("uses shared localized role labels in the registry and dossier", () => {
    const userDetailSource = readFileSync(userDetailPath, "utf8");
    const userAccessControlPanelSource = readFileSync(userAccessControlPanelPath, "utf8");
    const usersTableSource = readFileSync(usersTablePath, "utf8");
    const helpersSource = readFileSync(userHelpersPath, "utf8");

    expect(userDetailSource).toContain("getUserRoleLabel(role, text)");
    expect(userAccessControlPanelSource).toContain("getUserRoleLabel(role, text)");
    expect(usersTableSource).toContain("getUserRoleLabel(role, text)");
    expect(helpersSource).toContain("? text.userRoleAdmin");
    expect(helpersSource).toContain("? text.userRoleModerator");
    expect(helpersSource).toContain("? text.userRoleUser");
  });

  it("uses localized monetization labels instead of hardcoded spark strings", () => {
    const userDetailSource = readFileSync(userDetailPath, "utf8");
    const userInlineAnalyticsSource = readFileSync(userInlineAnalyticsPath, "utf8");
    const formatterSource = readFileSync(monetizationFormatPath, "utf8");
    const enDictionarySource = readFileSync(enDictionaryPath, "utf8");
    const ruDictionarySource = readFileSync(ruDictionaryPath, "utf8");

    expect(formatterSource).toContain(
      "export function formatLabeledMetric(label: string, value: number): string"
    );
    expect(userDetailSource).toContain(
      "formatLabeledMetric(text.purchasedSparkLabel, purchase.sparkToGrant)"
    );
    expect(userInlineAnalyticsSource).toContain(
      "formatLabeledMetric(text.purchasedSparkLabel, purchase.sparkToGrant)"
    );
    expect(userDetailSource).toContain(
      "formatLabeledMetric(text.tokenCostLabel, generation.tokenCost)"
    );
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
