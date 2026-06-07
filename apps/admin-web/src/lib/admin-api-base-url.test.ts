import { describe, expect, it } from "vitest";

import { resolveAdminApiBaseUrl } from "@/lib/admin-api-base-url";

describe("admin-api-base-url", () => {
  it("uses localhost only outside production when no URL is configured", () => {
    expect(
      resolveAdminApiBaseUrl({
        isServer: false,
        publicApiBaseUrl: undefined,
        nodeEnv: "development",
      })
    ).toBe("http://localhost:5000");
  });

  it("requires an explicit public URL for production browser requests", () => {
    expect(() =>
      resolveAdminApiBaseUrl({
        isServer: false,
        publicApiBaseUrl: undefined,
        nodeEnv: "production",
      })
    ).toThrow(/NEXT_PUBLIC_API_BASE_URL/);
  });

  it("rejects localhost production URLs", () => {
    expect(() =>
      resolveAdminApiBaseUrl({
        isServer: false,
        publicApiBaseUrl: "http://localhost:5000",
        nodeEnv: "production",
      })
    ).toThrow(/localhost/);
  });

  it("rejects IPv6 loopback and wildcard production URLs", () => {
    expect(() =>
      resolveAdminApiBaseUrl({
        isServer: false,
        publicApiBaseUrl: "https://[::1]:5000",
        nodeEnv: "production",
      })
    ).toThrow(/localhost/);

    expect(() =>
      resolveAdminApiBaseUrl({
        isServer: false,
        publicApiBaseUrl: "https://0.0.0.0:5000",
        nodeEnv: "production",
      })
    ).toThrow(/localhost/);
  });

  it("rejects non-HTTPS production API URLs", () => {
    expect(() =>
      resolveAdminApiBaseUrl({
        isServer: false,
        publicApiBaseUrl: "http://api.example.com",
        nodeEnv: "production",
      })
    ).toThrow(/HTTPS/);
  });

  it("rejects credentials, query strings, and fragments in configured API URLs", () => {
    expect(() =>
      resolveAdminApiBaseUrl({
        isServer: false,
        publicApiBaseUrl: "https://user:password@api.example.com",
        nodeEnv: "development",
      })
    ).toThrow(/credentials/);

    expect(() =>
      resolveAdminApiBaseUrl({
        isServer: false,
        publicApiBaseUrl: "https://api.example.com?token=secret",
        nodeEnv: "development",
      })
    ).toThrow(/query strings/);

    expect(() =>
      resolveAdminApiBaseUrl({
        isServer: false,
        publicApiBaseUrl: "https://api.example.com#admin",
        nodeEnv: "development",
      })
    ).toThrow(/fragments/);
  });

  it("prefers the server-only URL for server requests", () => {
    expect(
      resolveAdminApiBaseUrl({
        isServer: true,
        internalApiBaseUrl: "https://internal-api.example.com/",
        publicApiBaseUrl: "https://api.example.com",
        nodeEnv: "production",
      })
    ).toBe("https://internal-api.example.com");
  });
});
