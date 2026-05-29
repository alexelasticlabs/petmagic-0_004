import { describe, expect, it } from "vitest";

import {
  isActionableAdminNotification,
  shouldCreateSupportRealtimeNotification,
} from "@/lib/admin-notification-policy";

describe("isActionableAdminNotification", () => {
  it("keeps support realtime notifications even with info tone", () => {
    expect(isActionableAdminNotification({ source: "support-realtime", tone: "info" })).toBe(
      true
    );
  });

  it("keeps errors and warnings for non-realtime sources", () => {
    expect(isActionableAdminNotification({ source: "templates-editor", tone: "error" })).toBe(
      true
    );
    expect(isActionableAdminNotification({ source: "templates-editor", tone: "warning" })).toBe(
      true
    );
  });

  it("drops success and info for non-realtime sources", () => {
    expect(isActionableAdminNotification({ source: "support-workspace", tone: "success" })).toBe(
      false
    );
    expect(isActionableAdminNotification({ source: "users-admin", tone: "info" })).toBe(false);
  });
});

describe("shouldCreateSupportRealtimeNotification", () => {
  it("returns false when the same conversation is already visible and focused", () => {
    expect(
      shouldCreateSupportRealtimeNotification({
        currentPath: "/support/abc",
        conversationId: "abc",
        isDocumentVisible: true,
        isWindowFocused: true,
      })
    ).toBe(false);
  });

  it("returns true for other conversations", () => {
    expect(
      shouldCreateSupportRealtimeNotification({
        currentPath: "/support/abc",
        conversationId: "xyz",
        isDocumentVisible: true,
        isWindowFocused: true,
      })
    ).toBe(true);
  });

  it("returns true when same conversation is open but tab is hidden or unfocused", () => {
    expect(
      shouldCreateSupportRealtimeNotification({
        currentPath: "/support/abc",
        conversationId: "abc",
        isDocumentVisible: false,
        isWindowFocused: true,
      })
    ).toBe(true);

    expect(
      shouldCreateSupportRealtimeNotification({
        currentPath: "/support/abc",
        conversationId: "abc",
        isDocumentVisible: true,
        isWindowFocused: false,
      })
    ).toBe(true);
  });
});