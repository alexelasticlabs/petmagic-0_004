import { describe, expect, it } from "vitest";

import {
  canAccessAdminPath,
  canAccessAdminSection,
  getAdminPanelRole,
  getDefaultAdminPath,
  hasAdminPanelAccess,
} from "./admin-rbac";

describe("admin-rbac", () => {
  const concreteAdminRoutes = [
    "/dashboard",
    "/economy",
    "/generations",
    "/image-templates",
    "/moderation",
    "/promo-codes",
    "/roles",
    "/support",
    "/support/conversation-1",
    "/templates",
    "/templates/analytics",
    "/templates/categories",
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

    for (const route of concreteAdminRoutes) {
      expect(canAccessAdminPath(["Admin"], route)).toBe(true);
    }
  });

  it("limits moderators to permitted operational sections", () => {
    expect(canAccessAdminPath(["Moderator"], "/support/abc")).toBe(true);
    expect(canAccessAdminPath(["Moderator"], "/moderation")).toBe(true);
    expect(canAccessAdminPath(["Moderator"], "/templates/video")).toBe(true);
    expect(canAccessAdminPath(["Moderator"], "/templates/image/analytics/template-1")).toBe(true);
    expect(canAccessAdminPath(["Moderator"], "/templates/video/analytics/template-1")).toBe(true);
    expect(canAccessAdminPath(["Moderator"], "/templates/image/editor")).toBe(false);
    expect(canAccessAdminPath(["Moderator"], "/templates/video/editor")).toBe(false);
    expect(canAccessAdminPath(["Moderator"], "/templates/image/test/template-1")).toBe(false);
    expect(canAccessAdminPath(["Moderator"], "/templates/video/test/template-1")).toBe(false);
    expect(canAccessAdminPath(["Moderator"], "/users")).toBe(false);
    expect(canAccessAdminPath(["Moderator"], "/users/user-1")).toBe(false);
    expect(canAccessAdminPath(["Moderator"], "/economy")).toBe(false);
    expect(canAccessAdminPath(["Moderator"], "/generations")).toBe(false);
    expect(canAccessAdminPath(["Moderator"], "/roles")).toBe(false);
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
  });
});
