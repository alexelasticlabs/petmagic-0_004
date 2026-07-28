import { describe, expect, it } from "vitest";

import { getAdminNavItems } from "./admin-navigation";
import { getAdminNavigationAreas } from "./admin-navigation-areas";

describe("admin navigation areas", () => {
  it("groups admin routes into six localized work areas without changing links", () => {
    const areas = getAdminNavigationAreas("en", ["Admin"]);

    expect(areas.map((area) => area.label)).toEqual([
      "Command Center",
      "Customers & Access",
      "Operations Desk",
      "Content Studio",
      "Revenue & Risk",
      "Growth & Rewards",
    ]);
    expect(
      areas.map((area) => ({
        area: area.key,
        items: area.items.map((item) => item.key),
      }))
    ).toEqual([
      { area: "command-center", items: ["dashboard"] },
      { area: "customers-access", items: ["users", "role-management"] },
      {
        area: "operations-desk",
        items: ["generations", "generation-capacity", "feedback", "support", "moderation", "audit"],
      },
      { area: "content-studio", items: ["templates"] },
      { area: "revenue-risk", items: ["economy"] },
      { area: "growth-rewards", items: ["promo-codes", "gamification"] },
    ]);
    expect(areas.flatMap((area) => area.items.map((item) => item.key)).sort()).toEqual(
      getAdminNavItems("en", ["Admin"])
        .map((item) => item.key)
        .sort()
    );
    expect(areas.flatMap((area) => area.items).find((item) => item.key === "dashboard")?.href).toBe(
      "/en/dashboard"
    );
    expect(areas.flatMap((area) => area.items).find((item) => item.key === "economy")?.href).toBe(
      "/en/economy"
    );
  });

  it("localizes area labels for Russian UI", () => {
    expect(getAdminNavigationAreas("ru", ["Admin"]).map((area) => area.label)).toEqual([
      "Командный центр",
      "Клиенты и доступ",
      "Операционный центр",
      "Контент-студия",
      "Выручка и риски",
      "Рост и награды",
    ]);
  });

  it("keeps RBAC filtering inside each area", () => {
    const moderatorAreas = getAdminNavigationAreas("en", ["Moderator"]);
    const keys = moderatorAreas.flatMap((area) => area.items.map((item) => item.key));

    expect(keys).toContain("support");
    expect(keys).toContain("moderation");
    expect(keys).toContain("templates");
    expect(keys).not.toContain("dashboard");
    expect(keys).not.toContain("users");
    expect(keys).not.toContain("economy");
    expect(moderatorAreas.every((area) => area.items.length > 0)).toBe(true);
  });
});
