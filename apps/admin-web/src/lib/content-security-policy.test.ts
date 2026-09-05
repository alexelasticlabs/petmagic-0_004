import { describe, expect, it } from "vitest";

import { buildNonceContentSecurityPolicy } from "@/lib/content-security-policy";

describe("buildNonceContentSecurityPolicy", () => {
  it("uses a nonce without unsafe-inline in production", () => {
    const policy = buildNonceContentSecurityPolicy(
      "nonce-value_123",
      "https://api.petgpt.app",
      "production",
      "https://cdn.petgpt.app",
      false,
      "https://pub-123.r2.dev/templates-media"
    );

    expect(policy).toContain("script-src 'self' 'nonce-nonce-value_123' 'strict-dynamic'");
    expect(policy).toContain("style-src 'self' 'nonce-nonce-value_123'");
    expect(policy).toContain("style-src-attr 'unsafe-inline'");
    expect(policy).toContain(
      "connect-src 'self' https://api.petgpt.app https://cdn.petgpt.app https://pub-123.r2.dev"
    );
    expect(policy).toContain(
      "media-src 'self' blob: https://api.petgpt.app https://cdn.petgpt.app https://pub-123.r2.dev"
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

  it("allows an explicit local Compose API origin in production", () => {
    const policy = buildNonceContentSecurityPolicy(
      "local-compose-nonce",
      "http://localhost:5000",
      "production",
      undefined,
      true
    );

    expect(policy).toContain("connect-src 'self' http://localhost:5000");
  });

  it("rejects unsafe nonce values", () => {
    expect(() =>
      buildNonceContentSecurityPolicy("unsafe'; script-src *", undefined, "production")
    ).toThrow("CSP nonce contains unsupported characters.");
  });

  it("rejects unsafe production media origins", () => {
    for (const mediaOrigin of [
      "http://cdn.petgpt.app",
      "https://user:password@cdn.petgpt.app",
      "https://cdn.petgpt.app/private",
      "https://127.0.0.1",
      "https://cdn.example.com",
    ]) {
      expect(() =>
        buildNonceContentSecurityPolicy(
          "nonce-value",
          "https://api.petgpt.app",
          "production",
          mediaOrigin
        )
      ).toThrow();
    }
  });

  it("uses only the origin from a path-based R2 public URL", () => {
    const policy = buildNonceContentSecurityPolicy(
      "nonce-value",
      "https://api.petgpt.app",
      "production",
      "https://cdn.petgpt.app",
      false,
      "https://media.petgpt.app/r2/templates"
    );

    expect(policy).toContain(
      "img-src 'self' data: blob: https://api.petgpt.app https://cdn.petgpt.app https://media.petgpt.app"
    );
    expect(policy).not.toContain("https://media.petgpt.app/r2/templates");
  });

  it("rejects an unsafe production R2 public URL", () => {
    expect(() =>
      buildNonceContentSecurityPolicy(
        "nonce-value",
        "https://api.petgpt.app",
        "production",
        "https://cdn.petgpt.app",
        false,
        "https://127.0.0.1/private"
      )
    ).toThrow("TEMPLATES_R2_PUBLIC_BASE_URL cannot target local, private, or placeholder hosts.");
  });

  it("rejects unsafe production API origins", () => {
    for (const apiOrigin of [
      "http://api.petgpt.app",
      "https://user:password@api.petgpt.app",
      "https://127.0.0.1",
      "https://api.example.com",
    ]) {
      expect(() =>
        buildNonceContentSecurityPolicy("nonce-value", apiOrigin, "production")
      ).toThrow();
    }
  });

  it("keeps non-local HTTP API origins forbidden with the local Compose opt-in", () => {
    expect(() =>
      buildNonceContentSecurityPolicy(
        "nonce-value",
        "http://api.petgpt.app",
        "production",
        undefined,
        true
      )
    ).toThrow("NEXT_PUBLIC_API_BASE_URL must use HTTPS in production.");
  });
});

describe("private generation media CSP", () => {
  it("allows only the configured R2 account for signed files", () => {
    const origin = "https://" + "a".repeat(32) + ".r2.cloudflarestorage.com";
    const policy = buildNonceContentSecurityPolicy(
      "nonce",
      "https://api.petgpt.app",
      "production",
      "https://cdn.petgpt.app",
      false,
      undefined,
      "a".repeat(32)
    );
    for (const directive of ["img-src", "media-src", "connect-src"]) {
      expect(policy.split("; ").find((value) => value.startsWith(directive))).toContain(origin);
    }
    expect(policy).not.toContain("*.r2.cloudflarestorage.com");
    expect(policy.split("; ").find((value) => value.startsWith("script-src"))).not.toContain(
      origin
    );
  });
  it("rejects account values that could inject CSP directives", () => {
    expect(() =>
      buildNonceContentSecurityPolicy(
        "nonce",
        "https://api.petgpt.app",
        "production",
        undefined,
        false,
        undefined,
        "abc; img-src *"
      )
    ).toThrow("TEMPLATES_R2_ACCOUNT_ID");
  });
});
