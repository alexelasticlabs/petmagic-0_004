import { describe, expect, it } from "vitest";

import { getDictionary, isLocale, locales } from "./i18n";

describe("i18n", () => {
  it("validates supported locales", () => {
    expect(isLocale("ru")).toBe(true);
    expect(isLocale("en")).toBe(true);
    expect(isLocale("de")).toBe(false);
    expect(locales).toEqual(["ru", "en"]);
  });

  it("returns dictionary with required keys", () => {
    const ru = getDictionary("ru");
    const en = getDictionary("en");

    expect(ru.navDashboard.length).toBeGreaterThan(0);
    expect(en.navDashboard.length).toBeGreaterThan(0);
    expect(ru.promoCodesTitle.length).toBeGreaterThan(0);
    expect(en.promoCodesTitle.length).toBeGreaterThan(0);
  });
});
