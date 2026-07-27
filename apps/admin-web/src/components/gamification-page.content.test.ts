import { describe, expect, it } from "vitest";

import {
  getGamificationText,
  type GamificationPageText,
} from "@/components/gamification-page.content";
import { type Locale } from "@/lib/i18n";

const locales: Locale[] = ["ru", "en"];

describe("getGamificationText", () => {
  it.each(locales)("returns complete non-placeholder copy for %s", (locale) => {
    const text = getGamificationText(locale);

    for (const value of Object.values(text)) {
      expect(typeof value).toBe("string");
      expect(value.trim().length).toBeGreaterThan(0);
      expect(value).not.toMatch(/\b(?:lorem|todo|tbd|mock data)\b/i);
    }
  });

  it("keeps the ru and en contracts aligned", () => {
    const ru = getGamificationText("ru");
    const en = getGamificationText("en");

    expect(Object.keys(ru).sort()).toEqual(Object.keys(en).sort());
    expect(ru.description).not.toBe(en.description);
    expect(ru.invalidUserId).toContain("2");
    expect(en.invalidUserId).toContain("2");
    expect(ru.openUser360Action).toContain("User 360");
    expect(en.openUser360Action).toContain("User 360");
    expect(ru.reasonTooLong).toContain("500");
    expect(en.reasonTooLong).toContain("500");
  });

  it("returns copy required by diagnostics and audited reset flows", () => {
    const expectedKeys: Array<keyof GamificationPageText> = [
      "lookupPrompt",
      "lookupError",
      "diagnosticsEmptyStreakDescription",
      "dialogReasonLabel",
      "reasonRequired",
      "reasonTooLong",
      "resetDialogDescription",
      "resetSuccess",
      "resetError",
    ];

    for (const locale of locales) {
      const text = getGamificationText(locale);
      for (const key of expectedKeys) {
        expect(text[key].trim().length).toBeGreaterThan(0);
      }
    }
  });
});
