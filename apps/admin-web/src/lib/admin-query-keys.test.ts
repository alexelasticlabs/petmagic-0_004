import { describe, expect, it } from "vitest";

import { adminQueryKeys } from "./admin-query-keys";

describe("admin-query-keys", () => {
  it("provides a stable system status key", () => {
    expect(adminQueryKeys.systemStatus).toEqual(["admin", "system", "status"]);
  });

  it("keeps notification filters under one invalidation root", () => {
    const query = { state: "unread", priority: "critical", take: 24 };

    expect(adminQueryKeys.notificationsRoot).toEqual(["admin", "notifications"]);
    expect(adminQueryKeys.notifications(query)).toEqual(["admin", "notifications", query]);
  });

  it("provides a stable template category diagnostics key", () => {
    expect(adminQueryKeys.templateCategoryDiagnostics).toEqual([
      "admin",
      "templates",
      "categories",
      "diagnostics",
    ]);
  });

  it("keeps generation control separate from generation list polling", () => {
    expect(adminQueryKeys.templateGenerationControl).toEqual([
      "admin",
      "templates",
      "generation-control",
    ]);
    expect(adminQueryKeys.templateGenerationControl).not.toEqual(
      adminQueryKeys.templateGenerations({ status: "Running" })
    );
    expect(adminQueryKeys.templateGenerationProviderRecoveryRoot).toEqual([
      "admin",
      "templates",
      "generation-control",
      "provider-recovery",
    ]);
    expect(adminQueryKeys.templateGenerationProviderRecovery(0, 25)).toEqual([
      "admin",
      "templates",
      "generation-control",
      "provider-recovery",
      0,
      25,
    ]);
  });

  it("builds audit event list and detail keys", () => {
    const query = { actor: "admin-1", eventType: "WalletAdjusted", page: 2 };

    expect(adminQueryKeys.auditEvents(query)).toEqual(["admin", "audit", "events", query]);
    expect(adminQueryKeys.auditEvent("audit-123")).toEqual([
      "admin",
      "audit",
      "events",
      "audit-123",
    ]);
  });

  it("provides stable support inbox root key", () => {
    expect(adminQueryKeys.supportInboxRoot).toEqual(["admin", "support", "inbox"]);
    expect(adminQueryKeys.supportInbox("New", "mine")).toEqual([
      "admin",
      "support",
      "inbox",
      "New",
      "mine",
      "",
      "all",
      "default",
      "all",
      1,
      50,
    ]);
    expect(
      adminQueryKeys.supportInbox("New", "mine", {
        search: " user ",
        priority: "High",
        sort: "waiting",
        queue: "waiting_for_support",
        page: 2,
        pageSize: 25,
      })
    ).toEqual([
      "admin",
      "support",
      "inbox",
      "New",
      "mine",
      "user",
      "High",
      "waiting",
      "waiting_for_support",
      2,
      25,
    ]);
  });

  it("provides explicit disabled keys for users queries", () => {
    expect(adminQueryKeys.userDetailDisabled).toEqual(["admin", "users", "detail", "disabled"]);
    expect(adminQueryKeys.userAnalyticsDisabled).toEqual([
      "admin",
      "users",
      "analytics",
      "disabled",
    ]);
  });

  it("builds user keys by userId", () => {
    expect(adminQueryKeys.commandUsers("  Alice@Example.COM ")).toEqual([
      "admin",
      "users",
      "command-palette",
      "alice@example.com",
    ]);
    expect(adminQueryKeys.userDetail("user-123")).toEqual(["admin", "users", "user-123", "detail"]);
    expect(adminQueryKeys.userAnalytics("user-123")).toEqual([
      "admin",
      "users",
      "user-123",
      "analytics",
    ]);
  });

  it("keeps Gamification queries under one invalidation root", () => {
    expect(adminQueryKeys.gamificationRoot).toEqual(["admin", "gamification"]);
    expect(adminQueryKeys.gamificationDashboardMetrics).toEqual([
      "admin",
      "gamification",
      "dashboard",
      "metrics",
    ]);
    expect(adminQueryKeys.gamificationUser("user-123")).toEqual([
      "admin",
      "gamification",
      "users",
      "user-123",
    ]);
    expect(adminQueryKeys.gamificationUserDisabled).toEqual([
      "admin",
      "gamification",
      "users",
      "disabled",
    ]);
  });

  it("separates catalog analytics cache entries by visible template ids", () => {
    expect(
      adminQueryKeys.templateCatalogAnalyticsRows("all", ["template-a", "template-b"])
    ).toEqual(["admin", "templates", "all", "catalog-analytics", ["template-a", "template-b"]]);
    expect(adminQueryKeys.templateCatalogAnalyticsRows("Video", ["template-c"])).not.toEqual(
      adminQueryKeys.templateCatalogAnalyticsRows("Video", ["template-d"])
    );
  });
});
