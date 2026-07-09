import { describe, expect, it } from "vitest";

import { buildNonceContentSecurityPolicy } from "@/lib/content-security-policy";

describe("buildNonceContentSecurityPolicy", () => {
  it("uses a nonce without unsafe-inline in production", () => {
    const policy = buildNonceContentSecurityPolicy(
      "nonce-value_123",
      "https://api.petmagic.app",
      "production"
    );

    expect(policy).toContain("script-src 'self' 'nonce-nonce-value_123' 'strict-dynamic'");
    expect(policy).toContain("style-src 'self' 'nonce-nonce-value_123'");
    expect(policy).toContain("connect-src 'self' https://api.petmagic.app");
    expect(policy).not.toContain("'unsafe-inline'");
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
});
