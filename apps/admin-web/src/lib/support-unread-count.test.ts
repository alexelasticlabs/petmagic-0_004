import { describe, expect, it } from "vitest";

import { getSupportUnreadCount } from "@/lib/support-unread-count";

describe("getSupportUnreadCount", () => {
  it("prefers aggregate metrics payloads", () => {
    expect(
      getSupportUnreadCount({
        unreadForAdminConversations: 7,
        items: [{ unreadForAdmin: false }],
      })
    ).toBe(7);
  });

  it("supports legacy array payloads", () => {
    expect(
      getSupportUnreadCount([
        { unreadForAdmin: true },
        { unreadForAdmin: false },
        { unreadForAdmin: true },
      ])
    ).toBe(2);
  });

  it("supports paged inbox payloads", () => {
    expect(
      getSupportUnreadCount({
        items: [{ unreadForAdmin: false }, { unreadForAdmin: true }],
      })
    ).toBe(1);
  });

  it("returns zero for unsupported payloads", () => {
    expect(getSupportUnreadCount(null)).toBe(0);
    expect(getSupportUnreadCount({})).toBe(0);
  });
});
