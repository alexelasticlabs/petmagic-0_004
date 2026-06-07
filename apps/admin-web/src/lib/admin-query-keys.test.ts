import { describe, expect, it } from "vitest";

import { adminQueryKeys } from "./admin-query-keys";

describe("admin-query-keys", () => {
  it("provides stable support inbox root key", () => {
    expect(adminQueryKeys.supportInboxRoot).toEqual(["admin", "support", "inbox"]);
    expect(adminQueryKeys.supportInbox("New", "mine")).toEqual([
      "admin",
      "support",
      "inbox",
      "New",
      "mine",
      "",
      1,
      50,
    ]);
    expect(adminQueryKeys.supportInbox("New", "mine", { search: " user ", page: 2, pageSize: 25 })).toEqual([
      "admin",
      "support",
      "inbox",
      "New",
      "mine",
      "user",
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
    expect(adminQueryKeys.userDetail("user-123")).toEqual(["admin", "users", "user-123", "detail"]);
    expect(adminQueryKeys.userAnalytics("user-123")).toEqual([
      "admin",
      "users",
      "user-123",
      "analytics",
    ]);
  });
});
