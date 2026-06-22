import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import { apiImageRemotePatterns } from "../../next.config";

const adminDockerfilePath = fileURLToPath(new URL("../../Dockerfile", import.meta.url));
const adminEnvExamplePath = fileURLToPath(new URL("../../.env.example", import.meta.url));
const adminDevEnvExamplePath = fileURLToPath(
  new URL("../../.env.development.example", import.meta.url)
);
const adminStagingEnvExamplePath = fileURLToPath(
  new URL("../../.env.staging.example", import.meta.url)
);
const adminProductionEnvExamplePath = fileURLToPath(
  new URL("../../.env.production.example", import.meta.url)
);
const rootEnvExamplePath = fileURLToPath(new URL("../../../../.env.example", import.meta.url));
const rootDockerComposePath = fileURLToPath(new URL("../../../../docker-compose.yml", import.meta.url));

function readActiveEnvLines(path: string): string[] {
  return readFileSync(path, "utf8")
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith("#"));
}

describe("next admin env config", () => {
  it("requires a public API URL for production builds", () => {
    expect(() => apiImageRemotePatterns(undefined, "production")).toThrow(
      /NEXT_PUBLIC_API_BASE_URL/
    );
  });

  it("rejects localhost and non-HTTPS production API URLs", () => {
    expect(() => apiImageRemotePatterns("http://localhost:5000", "production")).toThrow(
      /localhost/
    );
    expect(() => apiImageRemotePatterns("https://[::1]:5000", "production")).toThrow(
      /localhost/
    );
    expect(() => apiImageRemotePatterns("https://0.0.0.0:5000", "production")).toThrow(
      /localhost/
    );
    expect(() => apiImageRemotePatterns("http://api.example.com", "production")).toThrow(/HTTPS/);
  });

  it("rejects credential-bearing and non-base API URLs in image config", () => {
    expect(() => apiImageRemotePatterns("https://user:password@api.example.com")).toThrow(
      /credentials/
    );
    expect(() => apiImageRemotePatterns("https://api.example.com?token=secret")).toThrow(
      /query strings/
    );
    expect(() => apiImageRemotePatterns("https://api.example.com#admin")).toThrow(/fragments/);
  });

  it("uses only the configured HTTPS API host in production image patterns", () => {
    expect(apiImageRemotePatterns("https://api.petmagic.app", "production")).toEqual([
      {
        protocol: "https",
        hostname: "api.petmagic.app",
        port: "",
        pathname: "/user-avatars/**",
      },
      {
        protocol: "https",
        hostname: "api.petmagic.app",
        port: "",
        pathname: "/support-attachments/**",
      },
    ]);
  });

  it("rejects placeholder production API hosts", () => {
    expect(() => apiImageRemotePatterns("https://api.example.com", "production")).toThrow(
      /placeholder/
    );
  });

  it("keeps local image hosts available outside production", () => {
    const patterns = apiImageRemotePatterns(undefined, "development");
    expect(patterns).toEqual(
      expect.arrayContaining([
        {
          protocol: "http",
          hostname: "localhost",
          port: "5000",
          pathname: "/user-avatars/**",
        },
      ])
    );
  });

  it("uses a production admin Dockerfile instead of next dev", () => {
    const dockerfile = readFileSync(adminDockerfilePath, "utf8");

    expect(dockerfile).toContain("RUN npm run build");
    expect(dockerfile).toContain('CMD ["npm", "run", "start"');
    expect(dockerfile).not.toContain("npm\", \"run\", \"dev");
    expect(dockerfile).not.toContain("next dev");
  });

  it("keeps active root env example values free of localhost frontend defaults", () => {
    const activeLines = readActiveEnvLines(rootEnvExamplePath);
    const publicFrontendLines = activeLines.filter((line) =>
      /^(NEXT_PUBLIC_API_BASE_URL|INTERNAL_API_BASE_URL|BACKEND_PUBLIC_BASE_URL|STRIPE_CHECKOUT_SUCCESS_URL|STRIPE_CHECKOUT_CANCEL_URL|STRIPE_BILLING_PORTAL_RETURN_URL)=/.test(
        line
      )
    );

    expect(publicFrontendLines.length).toBeGreaterThan(0);
    expect(publicFrontendLines.join("\n")).not.toMatch(/localhost|127\.0\.0\.1|http:\/\/backend/);
    expect(publicFrontendLines.join("\n")).toMatch(/https:\/\/.*petmagic\.app/);
  });

  it("keeps admin dev, staging, and production env examples separated", () => {
    const baseExample = readFileSync(adminEnvExamplePath, "utf8");
    const devLines = readActiveEnvLines(adminDevEnvExamplePath);
    const stagingLines = readActiveEnvLines(adminStagingEnvExamplePath);
    const productionLines = readActiveEnvLines(adminProductionEnvExamplePath);

    expect(baseExample).toContain(".env.development.example");
    expect(baseExample).toContain(".env.staging.example");
    expect(baseExample).toContain(".env.production.example");
    expect(devLines).toEqual([
      "NEXT_PUBLIC_API_BASE_URL=http://localhost:5001",
      "INTERNAL_API_BASE_URL=http://localhost:5001",
    ]);
    expect(stagingLines).toEqual([
      "NEXT_PUBLIC_API_BASE_URL=https://api-staging.petmagic.app",
      "INTERNAL_API_BASE_URL=https://api-staging.petmagic.app",
    ]);
    expect(productionLines).toEqual([
      "NEXT_PUBLIC_API_BASE_URL=https://api.petmagic.app",
      "INTERNAL_API_BASE_URL=https://api.petmagic.app",
    ]);
    expect(stagingLines.join("\n")).not.toMatch(/localhost|127\.0\.0\.1|http:\/\//);
    expect(productionLines.join("\n")).not.toMatch(/localhost|127\.0\.0\.1|http:\/\//);
    expect([...devLines, ...stagingLines, ...productionLines]).not.toEqual(
      expect.arrayContaining([expect.stringMatching(/^API_BASE_URL=/)])
    );
  });

  it("passes admin API URLs into docker build without local production defaults", () => {
    const compose = readFileSync(rootDockerComposePath, "utf8");

    expect(compose).toContain("args:");
    expect(compose).toContain("NEXT_PUBLIC_API_BASE_URL:");
    expect(compose).toContain("INTERNAL_API_BASE_URL:");
    expect(compose).not.toContain('NEXT_PUBLIC_API_BASE_URL:-http://localhost:5000');
    expect(compose).not.toContain("INTERNAL_API_BASE_URL:-http://backend:5000");
    expect(compose).not.toContain("INTERNAL_API_BASE_URL:-http://localhost:5000");
    expect(compose).not.toContain("BACKEND_PUBLIC_BASE_URL:-http://localhost:5000");
    expect(compose).toContain("BACKEND_PUBLIC_BASE_URL is required for public backend media URLs");
    expect(compose).toContain("BACKEND_PUBLIC_BASE_URL is required for public template media URLs");
  });
});
