import { describe, expect, it } from "vitest";

import { getSupportUnreadCount } from "@/lib/support-unread-count";

describe("getSupportUnreadCount", () => {
  it("prefers aggregate metrics payloads", () => {
    expect(
      getSupportUnreadCount({
        unreadForAdminConversations: 7,
      })
    ).toBe(7);
  });

  it("returns zero for unsupported payloads", () => {
    expect(getSupportUnreadCount(null)).toBe(0);
    expect(getSupportUnreadCount([])).toBe(0);
    expect(getSupportUnreadCount({})).toBe(0);
  });
});
