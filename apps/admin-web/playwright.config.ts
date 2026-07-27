import { defineConfig, devices } from "@playwright/test";

const e2ePort = Number.parseInt(process.env.PLAYWRIGHT_PORT ?? "3100", 10);
if (!Number.isInteger(e2ePort) || e2ePort < 1024 || e2ePort > 65535) {
  throw new Error("PLAYWRIGHT_PORT must be a valid unprivileged TCP port.");
}

const e2eBaseUrl = `http://127.0.0.1:${e2ePort}`;
const usesExternalServer = process.env.PLAYWRIGHT_EXTERNAL_SERVER === "1";
// Keep the build output isolated from the normal production build. A parallel
// QA job can supply NEXT_E2E_DIST_DIR, which the launcher and web server share.
const e2eBuildDirectory = process.env.NEXT_E2E_DIST_DIR?.trim() || ".next-e2e";
// Start Next directly so Playwright owns the actual server process. On Windows,
// `npm run start` inserts an npm.cmd wrapper and can leave its Next child alive
// after the test runner exits.
const nextStartCommand = `"${process.execPath}" ./node_modules/next/dist/bin/next start --hostname 127.0.0.1 --port ${e2ePort}`;

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: false,
  workers: 1,
  retries: process.env.CI ? 2 : 0,
  reporter: process.env.CI ? [["github"], ["list"]] : "list",
  use: {
    baseURL: e2eBaseUrl,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
  webServer: usesExternalServer
    ? undefined
    : {
        command: nextStartCommand,
        url: `${e2eBaseUrl}/en`,
        reuseExistingServer: false,
        timeout: 120_000,
        env: {
          NEXT_E2E_DIST_DIR: e2eBuildDirectory,
          NEXT_DIST_DIR: e2eBuildDirectory,
          NEXT_PUBLIC_API_BASE_URL: "https://api.petmagic.test",
          ADMIN_MEDIA_ORIGINS: "https://cdn.petmagic.app",
        },
      },
});
