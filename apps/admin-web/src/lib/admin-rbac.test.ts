import { readdirSync } from "node:fs";
import { join, relative, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import {
  canAccessAdminPath,
  canAccessAdminSection,
  getAdminPanelRole,
  getDefaultAdminPath,
  hasAdminPanelAccess,
} from "./admin-rbac";

describe("admin-rbac", () => {
  const localeAppRoot = fileURLToPath(new URL("../app/[locale]", import.meta.url));
  const concreteAdminRoutes = [
    "/audit",
    "/dashboard",
    "/economy",
    "/email-broadcasts",
    "/feedback",
    "/gamification",
    "/generations",
    "/image-templates",
    "/moderation",
    "/notifications",
    "/promo-codes",
    "/roles",
    "/support",
    "/support/conversation-1",
    "/templates",
    "/templates/analytics",
    "/templates/categories",
    "/templates/daily-featured",
    "/templates/discovery",
    "/templates/image",
    "/templates/image/analytics/template-1",
    "/templates/image/editor",
    "/templates/image/test/template-1",
    "/templates/video",
    "/templates/video/analytics/template-1",
    "/templates/video/editor",
    "/templates/video/test/template-1",
    "/users",
    "/users/user-1",
    "/video-templates",
  ];

  it("treats Premium as non-admin metadata, not an admin role", () => {
    expect(hasAdminPanelAccess(["Premium"])).toBe(false);
    expect(getAdminPanelRole(["Premium", "User"])).toBeNull();
  });

  it("grants admins full access", () => {
    expect(canAccessAdminSection(["Admin"], "users")).toBe(true);
    expect(canAccessAdminSection(["Admin"], "audit")).toBe(true);

    for (const route of concreteAdminRoutes) {
      expect(canAccessAdminPath(["Admin"], route)).toBe(true);
    }
  });

  it("limits moderators to permitted operational sections", () => {
    expect(canAccessAdminSection(["Moderator"], "audit")).toBe(false);
    expect(canAccessAdminPath(["Moderator"], "/support/abc")).toBe(true);
    expect(canAccessAdminPath(["Moderator"], "/feedback")).toBe(true);
    expect(canAccessAdminPath(["Moderator"], "/email-broadcasts")).toBe(false);
    expect(canAccessAdminPath(["Moderator"], "/moderation")).toBe(true);
    expect(canAccessAdminPath(["Moderator"], "/templates/video")).toBe(true);
    expect(canAccessAdminPath(["Moderator"], "/templates/daily-featured")).toBe(false);
    expect(canAccessAdminPath(["Moderator"], "/templates/image/analytics/template-1")).toBe(true);
    expect(canAccessAdminPath(["Moderator"], "/templates/video/analytics/template-1")).toBe(true);
    expect(canAccessAdminPath(["Moderator"], "/templates/image/editor")).toBe(false);
    expect(canAccessAdminPath(["Moderator"], "/templates/video/editor")).toBe(false);
    expect(canAccessAdminPath(["Moderator"], "/templates/image/test/template-1")).toBe(false);
    expect(canAccessAdminPath(["Moderator"], "/templates/video/test/template-1")).toBe(false);
    expect(canAccessAdminPath(["Moderator"], "/users")).toBe(false);
    expect(canAccessAdminPath(["Moderator"], "/users/user-1")).toBe(false);
    expect(canAccessAdminPath(["Moderator"], "/economy")).toBe(false);
    expect(canAccessAdminPath(["Moderator"], "/gamification")).toBe(false);
    expect(canAccessAdminPath(["Moderator"], "/generations")).toBe(false);
    expect(canAccessAdminPath(["Moderator"], "/roles")).toBe(false);
    expect(canAccessAdminPath(["Moderator"], "/audit")).toBe(false);
    expect(canAccessAdminPath(["Moderator"], "/notifications")).toBe(true);
  });

  it("denies protected admin routes when roles are absent or non-admin", () => {
    for (const route of concreteAdminRoutes) {
      expect(canAccessAdminPath(undefined, route)).toBe(false);
      expect(canAccessAdminPath(["Premium", "User"], route)).toBe(false);
    }
  });

  it("uses a role-aware default landing page", () => {
    expect(getDefaultAdminPath("en", ["Admin"])).toBe("/en/dashboard");
    expect(getDefaultAdminPath("ru", ["Moderator"])).toBe("/ru/support");
    expect(getDefaultAdminPath("en", ["Premium", "User"])).toBe("/en");
    expect(getDefaultAdminPath("ru")).toBe("/ru");
  });

  it("keeps protected route coverage aligned with locale admin pages", () => {
    expect(collectLocaleAdminRoutes(localeAppRoot).sort()).toEqual([...concreteAdminRoutes].sort());
  });
});

function collectLocaleAdminRoutes(root: string): string[] {
  const routes: string[] = [];

  function visit(directory: string): void {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      const entryPath = join(directory, entry.name);
      if (entry.isDirectory()) {
        visit(entryPath);
        continue;
      }

      if (entry.name !== "page.tsx") {
        continue;
      }

      const route = normalizePageRoute(relative(root, entryPath));
      if (route !== "/") {
        routes.push(route);
      }
    }
  }

  visit(root);
  return routes;
}

function normalizePageRoute(relativePagePath: string): string {
  const route = relativePagePath
    .split(sep)
    .join("/")
    .replace(/\/page\.tsx$/, "")
    .replace(/^page\.tsx$/, "")
    .replace(/\[conversationId\]/g, "conversation-1")
    .replace(/\[templateId\]/g, "template-1")
    .replace(/\[userId\]/g, "user-1");

  return route ? `/${route}` : "/";
}
