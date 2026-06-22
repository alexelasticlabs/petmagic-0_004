import { describe, expect, it } from "vitest";

import { apiImageRemotePatterns } from "../../next.config";

describe("apiImageRemotePatterns", () => {
  it("rejects localhost API origins for production by default", () => {
    expect(() => apiImageRemotePatterns("http://localhost:5000", "production")).toThrow(
      "Admin production API base URL cannot point to localhost."
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
