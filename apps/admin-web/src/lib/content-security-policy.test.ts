import { describe, expect, it } from "vitest";

import { buildNonceContentSecurityPolicy } from "@/lib/content-security-policy";

describe("buildNonceContentSecurityPolicy", () => {
  it("uses a nonce without unsafe-inline in production", () => {
    const policy = buildNonceContentSecurityPolicy(
      "nonce-value_123",
      "https://api.petmagic.app",
      "production",
      "https://cdn.petmagic.app, https://pub-123.r2.dev"
    );

    expect(policy).toContain("script-src 'self' 'nonce-nonce-value_123' 'strict-dynamic'");
    expect(policy).toContain("style-src 'self' 'nonce-nonce-value_123'");
    expect(policy).toContain("style-src-attr 'unsafe-inline'");
    expect(policy).toContain(
      "connect-src 'self' https://api.petmagic.app https://cdn.petmagic.app https://pub-123.r2.dev"
    );
    expect(policy).toContain(
      "media-src 'self' blob: https://api.petmagic.app https://cdn.petmagic.app https://pub-123.r2.dev"
    );
    expect(policy).not.toContain("style-src 'self' 'unsafe-inline'");
    expect(policy).not.toContain("'unsafe-eval'");
  });

  it("keeps development-only script and style exceptions", () => {
    const policy = buildNonceContentSecurityPolicy("dev-nonce", undefined, "development");

    expect(policy).toContain("'unsafe-eval'");
    expect(policy).toContain("'unsafe-inline'");
    expect(policy).toContain("http://localhost:5000");
  });

  it("rejects unsafe nonce values", () => {
    expect(() =>
      buildNonceContentSecurityPolicy("unsafe'; script-src *", undefined, "production")
    ).toThrow("CSP nonce contains unsupported characters.");
  });

  it("rejects unsafe production media origins", () => {
    for (const mediaOrigin of [
      "http://cdn.petmagic.app",
      "https://user:password@cdn.petmagic.app",
      "https://cdn.petmagic.app/private",
      "https://127.0.0.1",
      "https://cdn.example.com",
    ]) {
      expect(() =>
        buildNonceContentSecurityPolicy(
          "nonce-value",
          "https://api.petmagic.app",
          "production",
          mediaOrigin
        )
      ).toThrow();
    }
  });

  it("rejects unsafe production API origins", () => {
    for (const apiOrigin of [
      "http://api.petmagic.app",
      "https://user:password@api.petmagic.app",
      "https://127.0.0.1",
      "https://api.example.com",
    ]) {
      expect(() =>
        buildNonceContentSecurityPolicy("nonce-value", apiOrigin, "production")
      ).toThrow();
    }
  });
});
