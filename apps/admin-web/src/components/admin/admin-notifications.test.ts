import { describe, expect, it } from "vitest";

import {
  buildAdminNotificationDedupeKey,
  sanitizeAdminNotificationText,
} from "@/components/admin/admin-notifications";

describe("admin notification sanitization", () => {
  it("masks sensitive values before notifications are persisted", () => {
    const sanitized = sanitizeAdminNotificationText(
      [
        "Failed for alice@example.com",
        "https://storage.example.com/file.png?X-Amz-Signature=secret",
        "Authorization: Bearer eyJhbGciOi.fake.payload",
        "receipt=ios-receipt-data",
        "sk_live_1234567890",
        "+1 (555) 111-2233",
      ].join(" "),
      500
    );

    expect(sanitized).toContain("al***@e***.com");
    expect(sanitized).toContain("https://storage.example.com/file.png?***");
    expect(sanitized).toContain("Authorization=[redacted]");
    expect(sanitized).toContain("receipt=[redacted]");
    expect(sanitized).toContain("[redacted-secret]");
    expect(sanitized).toContain("15***33");
    expect(sanitized).not.toContain("alice@example.com");
    expect(sanitized).not.toContain("X-Amz-Signature=secret");
    expect(sanitized).not.toContain("ios-receipt-data");
    expect(sanitized).not.toContain("sk_live_1234567890");
  });

  it("collapses and limits notification text length", () => {
    const sanitized = sanitizeAdminNotificationText(`A\n\n${"x".repeat(80)}`, 24);

    expect(sanitized).toHaveLength(24);
    expect(sanitized).toBe(`A ${"x".repeat(19)}...`);
  });

  it("does not keep sensitive toast content in notification dedupe keys", () => {
    const key = buildAdminNotificationDedupeKey(
      "templates",
      "error",
      "Failed for alice@example.com https://cdn.example.com/a?sig=secret receipt=ios-secret token=raw-secret",
      "/en/templates?debug=1"
    );

    expect(key).toContain("al***@e***.com");
    expect(key).toContain("https://cdn.example.com/a?***");
    expect(key).toContain("receipt=[redacted]");
    expect(key).toContain("token=[redacted]");
    expect(key).not.toContain("alice@example.com");
    expect(key).not.toContain("sig=secret");
    expect(key).not.toContain("ios-secret");
    expect(key).not.toContain("raw-secret");
    expect(key).not.toContain("debug=1");
  });
});
