import { describe, expect, it } from "vitest";

import { apiImageRemotePatterns } from "../../next.config";

describe("apiImageRemotePatterns", () => {
  it("rejects localhost API origins for production by default", () => {
    expect(() => apiImageRemotePatterns("http://localhost:5000", "production")).toThrow(
      "Admin production API base URL cannot point to local or private hosts."
    );
  });

  it("allows localhost API origins for opted-in local production builds", () => {
    expect(apiImageRemotePatterns("http://localhost:5000", "production", true)).toEqual([
      {
        protocol: "http",
        hostname: "localhost",
        port: "5000",
        pathname: "/user-avatars/**",
      },
      {
        protocol: "http",
        hostname: "localhost",
        port: "5000",
        pathname: "/support-attachments/**",
      },
    ]);
  });

  it("allows compose backend API origins for opted-in local production builds", () => {
    expect(apiImageRemotePatterns("http://backend:5000", "production", true)).toEqual([
      {
        protocol: "http",
        hostname: "backend",
        port: "5000",
        pathname: "/user-avatars/**",
      },
      {
        protocol: "http",
        hostname: "backend",
        port: "5000",
        pathname: "/support-attachments/**",
      },
    ]);
  });

  it("rejects local and private API origins for production by default", () => {
    for (const apiBaseUrl of [
      "https://[::1]:5000",
      "https://[fd00::1]:5000",
      "https://0.0.0.0:5000",
      "https://10.0.2.2:5000",
      "https://172.20.0.5:5000",
      "https://192.168.1.20:5000",
      "https://host.docker.internal:5000",
      "https://backend:5000",
    ]) {
      expect(() => apiImageRemotePatterns(apiBaseUrl, "production")).toThrow(/local or private/);
    }
  });

  it("still rejects non-local HTTP API origins in production even with opt-in", () => {
    expect(() => apiImageRemotePatterns("http://api.example.com", "production", true)).toThrow(
      "Admin production API base URL must use HTTPS."
    );
  });

  it("rejects placeholder API origins in production", () => {
    expect(() => apiImageRemotePatterns("https://api.example.com", "production", true)).toThrow(
      "Admin production API base URL cannot use example.com placeholder hosts."
    );
  });
});
