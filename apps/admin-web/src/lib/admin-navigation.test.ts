import { describe, expect, it } from "vitest";

import {
  buildLocaleSwitchPath,
  getAdminNavItems,
  matchesAdminPath,
  stripLocalePrefix,
} from "./admin-navigation";

describe("admin-navigation", () => {
  it("strips locale prefix from pathname", () => {
    expect(stripLocalePrefix("/ru/support")).toBe("/support");
    expect(stripLocalePrefix("/en")).toBe("/");
    expect(stripLocalePrefix("support")).toBe("/support");
    expect(stripLocalePrefix(undefined)).toBe("/");
  });

  it("builds locale switch path", () => {
    expect(buildLocaleSwitchPath("en", "/ru/support")).toBe("/en/support");
    expect(buildLocaleSwitchPath("ru", "/en")).toBe("/ru");
    expect(buildLocaleSwitchPath("ru", undefined)).toBe("/ru");
  });

  it("matches admin paths including nested routes", () => {
    expect(matchesAdminPath("/support", "/support")).toBe(true);
    expect(matchesAdminPath("/support/123", "/support")).toBe(true);
    expect(matchesAdminPath("/users", "/support")).toBe(false);
  });

  it("returns grouped template navigation", () => {
    const items = getAdminNavItems("ru");
    const templateGroup = items.find((item) => item.type === "group" && item.key === "templates");

    expect(templateGroup).toBeDefined();
    expect(templateGroup?.type).toBe("group");

    if (templateGroup?.type === "group") {
      expect(templateGroup.items.length).toBeGreaterThanOrEqual(4);
    }
  });
});
