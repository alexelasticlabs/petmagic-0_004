import { describe, expect, it } from "vitest";

import {
  getAdminUserDisplayName,
  maskEmail,
  maskPhone,
  maskSignedUrl,
  sanitizeSensitiveMultilineText,
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

  it("sanitizes explicit admin user display names", () => {
    const displayName = getAdminUserDisplayName({
      userId: "9f495f82-1234",
      email: "nora@example.com",
      displayName: "Nora receipt=ios-secret token=raw-secret nora@example.com",
    });

    expect(displayName).toContain("receipt=[redacted]");
    expect(displayName).toContain("token=[redacted]");
    expect(displayName).toContain("no***@e***.com");
    expect(displayName).not.toContain("ios-secret");
    expect(displayName).not.toContain("raw-secret");
    expect(displayName).not.toContain("nora@example.com");
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

  it("preserves logical feedback line breaks while redacting sensitive values", () => {
    const sanitized = sanitizeSensitiveMultilineText(
      "First line\nEmail alex.petmagic@example.com\nreceipt=ios-secret-data",
      500
    );

    expect(sanitized).toBe("First line\nEmail al***@e***.com\nreceipt=[redacted]");
    expect(sanitized).not.toContain("alex.petmagic@example.com");
    expect(sanitized).not.toContain("ios-secret-data");
  });

  it("redacts session cookies, JWTs, credentials, and signatures in display text", () => {
    const sanitized = sanitizeSensitiveText(
      [
        "cookie=raw-cookie-secret",
        "jwt=eyJhbGciOi.raw.payload",
        "credential=raw-credential",
        "signature=raw-signature",
        "set-cookie=raw-set-cookie",
      ].join(" "),
      500
    );

    expect(sanitized).toContain("cookie=[redacted]");
    expect(sanitized).toContain("jwt=[redacted]");
    expect(sanitized).toContain("credential=[redacted]");
    expect(sanitized).toContain("signature=[redacted]");
    expect(sanitized).toContain("set-cookie=[redacted]");
    expect(sanitized).not.toContain("raw-cookie-secret");
    expect(sanitized).not.toContain("eyJhbGciOi.raw.payload");
    expect(sanitized).not.toContain("raw-credential");
    expect(sanitized).not.toContain("raw-signature");
    expect(sanitized).not.toContain("raw-set-cookie");
  });

  it("redacts stable domain identifier assignments in display text", () => {
    const sanitized = sanitizeSensitiveText(
      [
        "userId=user-secret",
        "templateId: template-secret",
        "generation_id=generation-secret",
        "accountScope=account-scope-secret",
        "messageId=message-secret",
        "orderId=order-secret",
        "requestId=request-public",
        "correlationId=correlation-public",
      ].join(" "),
      500
    );

    expect(sanitized).toContain("userId=[redacted]");
    expect(sanitized).toContain("templateId=[redacted]");
    expect(sanitized).toContain("generation_id=[redacted]");
    expect(sanitized).toContain("accountScope=[redacted]");
    expect(sanitized).toContain("messageId=[redacted]");
    expect(sanitized).toContain("orderId=[redacted]");
    expect(sanitized).toContain("requestId=request-public");
    expect(sanitized).toContain("correlationId=correlation-public");
    expect(sanitized).not.toContain("user-secret");
    expect(sanitized).not.toContain("template-secret");
    expect(sanitized).not.toContain("generation-secret");
    expect(sanitized).not.toContain("account-scope-secret");
    expect(sanitized).not.toContain("message-secret");
    expect(sanitized).not.toContain("order-secret");
  });

  it("redacts plural domain identifiers and filenames in display text", () => {
    const sanitized = sanitizeSensitiveText(
      [
        "templateIds=template-secret,template-second",
        "generationIds: generation-secret",
        "purchaseIds=purchase-secret",
        "fileName=alice-vet-bill.pdf",
        "fileNames=passport-scan.png,home-address-dog.jpeg",
        "requestIds=request-public",
      ].join(" "),
      500
    );

    expect(sanitized).toContain("templateIds=[redacted]");
    expect(sanitized).toContain("generationIds=[redacted]");
    expect(sanitized).toContain("purchaseIds=[redacted]");
    expect(sanitized).toContain("fileName=[redacted]");
    expect(sanitized).toContain("fileNames=[redacted]");
    expect(sanitized).toContain("requestIds=request-public");
    expect(sanitized).not.toContain("template-secret");
    expect(sanitized).not.toContain("template-second");
    expect(sanitized).not.toContain("generation-secret");
    expect(sanitized).not.toContain("purchase-secret");
    expect(sanitized).not.toContain("alice-vet-bill");
    expect(sanitized).not.toContain("passport-scan");
    expect(sanitized).not.toContain("home-address-dog");
  });
});
