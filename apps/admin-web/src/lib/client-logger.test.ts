import { afterEach, describe, expect, it, vi } from "vitest";

import { clientLogger } from "@/lib/client-logger";

describe("clientLogger", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("masks sensitive values inside nested context and errors", () => {
    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});

    clientLogger.warn("unit.sensitive_context", {
      error: new Error('Request failed: {"refreshToken":"refresh-secret"}'),
      nested: {
        authorization: "Bearer access-secret",
        callbackUrl: "https://cdn.example.com/file.png?X-Amz-Signature=abc123",
        message: "token=inline-secret",
        userEmail: "alice@example.com",
        phoneNumber: "+1 (555) 111-2233",
      },
    });

    expect(warnSpy).toHaveBeenCalledOnce();
    const [, payload] = warnSpy.mock.calls[0] ?? [];
    const serialized = JSON.stringify(payload);

    expect(serialized).not.toContain("refresh-secret");
    expect(serialized).not.toContain("access-secret");
    expect(serialized).not.toContain("abc123");
    expect(serialized).not.toContain("inline-secret");
    expect(serialized).not.toContain("alice@example.com");
    expect(serialized).not.toContain("+1 (555) 111-2233");
    expect(serialized).toContain("Bearer ***");
    expect(serialized).toContain("[redacted]");
    expect(serialized).toContain("al***@e***.com");
    expect(serialized).toContain("15***33");
  });

  it("sanitizes sensitive values embedded in API paths and query strings", () => {
    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});

    clientLogger.warn("api.request_failed", {
      path: "/api/admin/users?search=alice@example.com&receipt=ios-secret&card_number=4242424242424242",
    });

    expect(warnSpy).toHaveBeenCalledOnce();
    const [, payload] = warnSpy.mock.calls[0] ?? [];
    const serialized = JSON.stringify(payload);

    expect(serialized).not.toContain("alice@example.com");
    expect(serialized).not.toContain("ios-secret");
    expect(serialized).not.toContain("4242424242424242");
    expect(serialized).toContain("[redacted]");

    clientLogger.warn("api.request_failed", {
      path: "/api/admin/users?search=alice@example.com",
    });

    const [, secondPayload] = warnSpy.mock.calls[1] ?? [];
    const secondSerialized = JSON.stringify(secondPayload);
    expect(secondSerialized).not.toContain("alice@example.com");
    expect(secondSerialized).toContain("al***@e***.com");

    clientLogger.warn("api.request_failed", {
      path: "/support-attachments/file.png?Signature=raw-signature&Expires=9999999999",
    });

    const [, thirdPayload] = warnSpy.mock.calls[2] ?? [];
    const thirdSerialized = JSON.stringify(thirdPayload);
    expect(thirdSerialized).not.toContain("raw-signature");
    expect(thirdSerialized).not.toContain("9999999999");
    expect(thirdSerialized).toContain("[redacted]");
  });

  it("sanitizes sensitive Error stack content before writing console payloads", () => {
    const errorSpy = vi.spyOn(console, "error").mockImplementation(() => {});
    const error = new Error("Failed for token=raw-secret");
    error.stack =
      "Error: Failed for token=raw-secret\n    at https://cdn.example.com/file.png?X-Amz-Signature=abc123";

    clientLogger.error("unit.error_stack", { error });

    expect(errorSpy).toHaveBeenCalledOnce();
    const [, payload] = errorSpy.mock.calls[0] ?? [];
    const serialized = JSON.stringify(payload);

    expect(serialized).not.toContain("raw-secret");
    expect(serialized).not.toContain("abc123");
    expect(serialized).not.toContain("X-Amz-Signature=abc123");
  });

  it("masks session cookies, JWTs, credentials, and signatures by field name", () => {
    const warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});

    clientLogger.warn("unit.structured_secret_context", {
      cookie: "sessionid=raw-cookie-secret",
      setCookie: "admin=raw-set-cookie-secret; HttpOnly",
      jwt: "eyJhbGciOi.raw.payload",
      sessionId: "raw-session-id",
      credential: "AKIA-raw-credential",
      requestSignature: "raw-signature",
    });

    expect(warnSpy).toHaveBeenCalledOnce();
    const [, payload] = warnSpy.mock.calls[0] ?? [];
    const serialized = JSON.stringify(payload);

    expect(serialized).not.toContain("raw-cookie-secret");
    expect(serialized).not.toContain("raw-set-cookie-secret");
    expect(serialized).not.toContain("eyJhbGciOi.raw.payload");
    expect(serialized).not.toContain("raw-session-id");
    expect(serialized).not.toContain("AKIA-raw-credential");
    expect(serialized).not.toContain("raw-signature");
  });
});
