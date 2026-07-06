import { describe, expect, it } from "vitest";

import { resolveAdminApiBaseUrl } from "@/lib/admin-api-base-url";

describe("resolveAdminApiBaseUrl", () => {
  it("rejects localhost public API URLs for production by default", () => {
    expect(() =>
      resolveAdminApiBaseUrl({
        publicApiBaseUrl: "http://localhost:5000",
        isServer: false,
        nodeEnv: "production",
      })
    ).toThrow("Admin production API base URL cannot point to local or private hosts.");
  });

  it("allows local public API URLs for opted-in local production builds", () => {
    expect(
      resolveAdminApiBaseUrl({
        publicApiBaseUrl: "http://localhost:5000",
        isServer: false,
        nodeEnv: "production",
        allowLocalApiBaseUrlInProduction: true,
      })
    ).toBe("http://localhost:5000");
  });

  it("allows compose backend API URLs only for opted-in local production builds", () => {
    expect(
      resolveAdminApiBaseUrl({
        internalApiBaseUrl: "http://backend:5000",
        isServer: true,
        nodeEnv: "production",
        allowLocalApiBaseUrlInProduction: true,
      })
    ).toBe("http://backend:5000");
  });

  it("still rejects non-local HTTP API URLs in production even with opt-in", () => {
    expect(() =>
      resolveAdminApiBaseUrl({
        publicApiBaseUrl: "http://api.example.com",
        isServer: false,
        nodeEnv: "production",
        allowLocalApiBaseUrlInProduction: true,
      })
    ).toThrow("Admin production API base URL must use HTTPS.");
  });
});

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
    ).toThrow(/local or private/);
  });

  it("rejects local and private production URLs by default", () => {
    for (const publicApiBaseUrl of [
      "https://[::1]:5000",
      "https://[fd00::1]:5000",
      "https://0.0.0.0:5000",
      "https://10.0.2.2:5000",
      "https://172.20.0.5:5000",
      "https://192.168.1.20:5000",
      "https://host.docker.internal:5000",
      "https://backend:5000",
    ]) {
      expect(() =>
        resolveAdminApiBaseUrl({
          isServer: false,
          publicApiBaseUrl,
          nodeEnv: "production",
        })
      ).toThrow(/local or private/);
    }
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

  it("rejects placeholder production API URLs", () => {
    expect(() =>
      resolveAdminApiBaseUrl({
        isServer: false,
        publicApiBaseUrl: "https://api.example.com",
        nodeEnv: "production",
      })
    ).toThrow(/placeholder/);
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
        internalApiBaseUrl: "https://internal-api.petmagic.app/",
        publicApiBaseUrl: "https://api.petmagic.app",
        nodeEnv: "production",
      })
    ).toBe("https://internal-api.petmagic.app");
  });
});
