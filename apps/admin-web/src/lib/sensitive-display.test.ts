import { describe, expect, it } from "vitest";

import {
  getAdminUserDisplayName,
  maskEmail,
  maskPhone,
  maskSignedUrl,
  sanitizeSensitiveText,
  shortIdentifier,
} from "@/lib/sensitive-display";

describe("sensitive-display", () => {
  it("masks email local and domain parts", () => {
    expect(maskEmail("alex.petmagic@example.com")).toBe("al***@e***.com");
    expect(maskEmail("a@b.io")).toBe("a***@b***.io");
  });

  it("masks phone numbers while keeping minimal lookup hints", () => {
    expect(maskPhone("+1 (415) 555-0199")).toBe("14***99");
  });

  it("removes query strings from signed URLs", () => {
    expect(maskSignedUrl("https://cdn.example.com/file.png?sig=secret&expires=1")).toBe(
      "https://cdn.example.com/***"
    );
  });

  it("builds user display labels without exposing raw email fallback", () => {
    expect(
      getAdminUserDisplayName({
        userId: "9f495f82-1234",
        email: "nora@example.com",
        displayName: "",
      })
    ).toBe("no***@e***.com");
    expect(shortIdentifier("9f495f82-1234")).toBe("9f495f82");
  });

  it("sanitizes mixed sensitive text for audit and feedback display", () => {
    const sanitized = sanitizeSensitiveText(
      [
        "Changed email alex.petmagic@example.com",
        "url=https://cdn.example.com/file.png?sig=secret",
        "Authorization: Bearer eyJhbGciOi.fake.payload",
        "receipt=ios-receipt-data",
        "card_number=4242 4242 4242 4242",
        "+1 (415) 555-0199",
      ].join(" "),
      500
    );

    expect(sanitized).toContain("al***@e***.com");
    expect(sanitized).toContain("https://cdn.example.com/***");
    expect(sanitized).toContain("Authorization=[redacted]");
    expect(sanitized).toContain("receipt=[redacted]");
    expect(sanitized).toContain("card_number=[redacted]");
    expect(sanitized).toContain("14***99");
    expect(sanitized).not.toContain("alex.petmagic@example.com");
    expect(sanitized).not.toContain("sig=secret");
    expect(sanitized).not.toContain("ios-receipt-data");
    expect(sanitized).not.toContain("4242 4242 4242 4242");
  });
});
