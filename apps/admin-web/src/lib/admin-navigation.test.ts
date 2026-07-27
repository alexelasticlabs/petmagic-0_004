import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import {
  buildLocaleSwitchPath,
  filterAdminCommandItems,
  getAdminCommandItems,
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

  it("preserves direct-link query state when changing locale", () => {
    expect(
      buildLocaleSwitchPath("en", "/ru/users/160156be", "tab=wallet&action=adjust-balance")
    ).toBe("/en/users/160156be?tab=wallet&action=adjust-balance");
    expect(buildLocaleSwitchPath("ru", "/en/support", "?status=open")).toBe(
      "/ru/support?status=open"
    );
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
    expect(keys).not.toContain("gamification");
    expect(keys).not.toContain("promo-codes");
    expect(keys).not.toContain("users");
    expect(keys).not.toContain("generations");
    expect(keys).not.toContain("role-management");
    expect(keys).not.toContain("audit");
  });

  it("shows admin-only operations navigation for admins only", () => {
    const adminKeys = getAdminNavItems("en", ["Admin"]).map((item) => item.key);
    const userKeys = getAdminNavItems("en", ["User"]).map((item) => item.key);

    expect(adminKeys).toContain("generations");
    expect(adminKeys).toContain("gamification");
    expect(adminKeys).toContain("role-management");
    expect(adminKeys).toContain("audit");
    expect(userKeys).not.toContain("generations");
    expect(userKeys).not.toContain("gamification");
    expect(userKeys).not.toContain("role-management");
    expect(userKeys).not.toContain("audit");
  });

  it("builds a searchable command list from RBAC-filtered navigation", () => {
    const adminCommands = getAdminCommandItems("ru", ["Admin"]);
    const moderatorCommands = getAdminCommandItems("ru", ["Moderator"]);

    expect(adminCommands.some((item) => item.key === "dashboard")).toBe(true);
    expect(adminCommands.some((item) => item.key === "users")).toBe(true);
    expect(adminCommands.some((item) => item.key === "audit")).toBe(true);
    expect(adminCommands.find((item) => item.key === "template-categories")?.groupLabel).toBe(
      "Шаблоны"
    );
    expect(moderatorCommands.some((item) => item.key === "dashboard")).toBe(false);
    expect(moderatorCommands.some((item) => item.key === "users")).toBe(false);
    expect(moderatorCommands.some((item) => item.key === "audit")).toBe(false);
    expect(moderatorCommands.some((item) => item.key === "template-categories")).toBe(true);

    expect(
      filterAdminCommandItems(adminCommands, "  ПОЛЬЗОВАТЕЛИ  ").map((item) => item.key)
    ).toEqual(["users"]);
    expect(filterAdminCommandItems(adminCommands, "шаблоны").map((item) => item.key)).toEqual(
      expect.arrayContaining([
        "video-templates",
        "image-templates",
        "template-analytics",
        "template-daily-featured",
        "template-categories",
      ])
    );
  });

  it("keeps Russian sidebar section labels localized", () => {
    const text = getDictionary("ru");

    expect([
      text.navSectionOverview,
      text.navSectionGrowth,
      text.navSectionContent,
      text.navSectionUsers,
      text.navSectionOperations,
    ]).toEqual(["Обзор", "Рост", "Контент", "Пользователи и доступ", "Операции"]);
  });

  it("keeps Russian page meta free of editorial English labels", () => {
    expect(getAdminPageMeta("ru", "/users/160156be", "Admin")).toEqual({
      title: "Профиль пользователя",
      description: "",
    });
    expect(getAdminPageMeta("ru", "/feedback", "Admin").title).toBe("Фидбек");
    expect(getAdminPageMeta("ru", "/feedback", "Admin").description).toBe(
      "Обратная связь по генерациям, багам, оплате и предложениям со статусами и возвратом кредитов."
    );
    expect(getAdminPageMeta("ru", "/generations", "Admin").description).toBe(
      "Очередь и история генераций с фильтрами по статусу, провайдеру, пользователю и ID задания."
    );
    expect(getAdminPageMeta("ru", "/gamification", "Admin")).toEqual({
      title: "Геймификация",
      description:
        "Метрики вовлечённости, недельные задания, достижения и диагностика прогресса пользователей.",
    });
    expect(getAdminPageMeta("ru", "/roles", "Admin").description).toBe(
      "Поиск и управление доступом модераторов."
    );
    expect(getAdminPageMeta("ru", "/moderation", "Admin").description).toBe(
      "Очередь жалоб и обратной связи по шаблонам с решением одобрить или отклонить."
    );
    expect(getAdminPageMeta("ru", "/audit", "Admin")).toEqual({
      title: "Журнал действий",
      description:
        "История административных действий с фильтрами по исполнителю, типу события и объекту.",
    });
    expect(getAdminPageMeta("ru", "/templates/daily-featured", "Admin").description).toBe(
      "Ручные назначения и автоматический выбор шаблона дня."
    );
  });

  it("sources admin page meta copy from a centralized content module", () => {
    const source = readFileSync(adminNavigationPath, "utf8");
    const contentSource = readFileSync(adminNavigationContentPath, "utf8");
    const ruContentSource = contentSource.slice(
      contentSource.indexOf("  ru: {"),
      contentSource.indexOf("  en: {")
    );

    expect(source).toContain(
      'import { getAdminPageMetaCopy } from "@/lib/admin-navigation.content";'
    );
    expect(source).toContain("const copy = getAdminPageMetaCopy(locale);");
    expect(contentSource).toContain('title: "Дашборд"');
    expect(contentSource).toContain('title: "Dashboard"');
    expect(contentSource).toContain('title: "Фидбек"');
    expect(contentSource).toContain('title: "Журнал действий"');
    expect(contentSource).toContain('title: "Audit trail"');
    expect(ruContentSource).not.toContain('title: "Feedback",');
    expect(ruContentSource).not.toContain("auto-pick для Template of the Day");
    expect(contentSource).toContain('fallbackAdministratorName: "администратор"');
    expect(contentSource).toContain('fallbackAdministratorName: "administrator"');
    expect(source).not.toContain('title: locale === "ru" ? "Дашборд" : "Dashboard"');
    expect(source).not.toContain('title: locale === "ru" ? "Экономика" : "Economy"');
  });
});
