import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import {
  buildLocaleSwitchPath,
  getAdminNavItems,
  getAdminPageMeta,
  matchesAdminPath,
  stripLocalePrefix,
} from "./admin-navigation";
import { getDictionary } from "./i18n";

const adminNavigationPath = fileURLToPath(new URL("./admin-navigation.ts", import.meta.url));
const adminNavigationContentPath = fileURLToPath(
  new URL("./admin-navigation.content.ts", import.meta.url)
);

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
    const items = getAdminNavItems("ru", ["Admin"]);
    const templateGroup = items.find((item) => item.type === "group" && item.key === "templates");

    expect(templateGroup).toBeDefined();
    expect(templateGroup?.type).toBe("group");

    if (templateGroup?.type === "group") {
      expect(templateGroup.items.length).toBeGreaterThanOrEqual(4);
    }
  });

  it("does not expose navigation entries when roles are missing", () => {
    expect(getAdminNavItems("en")).toEqual([]);
    expect(getAdminNavItems("ru", null)).toEqual([]);
  });

  it("hides admin-only sections for moderators", () => {
    const items = getAdminNavItems("en", ["Moderator"]);
    const keys = items.map((item) => item.key);
    const templateGroup = items.find((item) => item.type === "group" && item.key === "templates");
    const templateKeys =
      templateGroup?.type === "group" ? templateGroup.items.map((item) => item.key) : [];

    expect(keys).toContain("support");
    expect(keys).toContain("moderation");
    expect(keys).toContain("templates");
    expect(templateKeys).toContain("template-analytics");
    expect(templateKeys).toContain("template-categories");
    expect(templateKeys).not.toContain("template-daily-featured");
    expect(keys).not.toContain("dashboard");
    expect(keys).not.toContain("economy");
    expect(keys).not.toContain("promo-codes");
    expect(keys).not.toContain("users");
    expect(keys).not.toContain("generations");
    expect(keys).not.toContain("role-management");
  });

  it("shows admin-only operations navigation for admins only", () => {
    const adminKeys = getAdminNavItems("en", ["Admin"]).map((item) => item.key);
    const userKeys = getAdminNavItems("en", ["User"]).map((item) => item.key);

    expect(adminKeys).toContain("generations");
    expect(adminKeys).toContain("role-management");
    expect(userKeys).not.toContain("generations");
    expect(userKeys).not.toContain("role-management");
  });

  it("keeps Russian sidebar section labels localized", () => {
    const text = getDictionary("ru");

    expect([
      text.navSectionOverview,
      text.navSectionGrowth,
      text.navSectionContent,
      text.navSectionUsers,
    ]).toEqual(["Обзор", "Рост", "Контент", "Пользователи"]);
  });

  it("keeps Russian page meta free of editorial English labels", () => {
    expect(getAdminPageMeta("ru", "/generations", "Admin").description).toBe(
      "Очередь и история генераций с фильтрами по статусу, провайдеру, пользователю и job id."
    );
    expect(getAdminPageMeta("ru", "/roles", "Admin").description).toBe(
      "Списки Admin и Moderator, назначение и снятие Moderator с журналом аудита."
    );
    expect(getAdminPageMeta("ru", "/moderation", "Admin").description).toBe(
      "Очередь жалоб и обратной связи по шаблонам с решением одобрить или отклонить."
    );
  });

  it("sources admin page meta copy from a centralized content module", () => {
    const source = readFileSync(adminNavigationPath, "utf8");
    const contentSource = readFileSync(adminNavigationContentPath, "utf8");

    expect(source).toContain('import { getAdminPageMetaCopy } from "@/lib/admin-navigation.content";');
    expect(source).toContain("const copy = getAdminPageMetaCopy(locale);");
    expect(contentSource).toContain('title: "Дашборд"');
    expect(contentSource).toContain('title: "Dashboard"');
    expect(contentSource).toContain('fallbackAdministratorName: "администратор"');
    expect(contentSource).toContain('fallbackAdministratorName: "administrator"');
    expect(source).not.toContain('title: locale === "ru" ? "Дашборд" : "Dashboard"');
    expect(source).not.toContain('title: locale === "ru" ? "Экономика" : "Economy"');
  });
});
