import { defineConfig, devices } from "@playwright/test";

const e2ePort = Number.parseInt(process.env.PLAYWRIGHT_PORT ?? "3100", 10);
if (!Number.isInteger(e2ePort) || e2ePort < 1024 || e2ePort > 65535) {
  throw new Error("PLAYWRIGHT_PORT must be a valid unprivileged TCP port.");
}

const e2eBaseUrl = `http://127.0.0.1:${e2ePort}`;

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
  webServer: {
    command: `npm run start -- --hostname 127.0.0.1 --port ${e2ePort}`,
    url: `${e2eBaseUrl}/en`,
    reuseExistingServer: false,
    timeout: 120_000,
    env: {
      NEXT_PUBLIC_API_BASE_URL: "https://api.petmagic.app",
      ADMIN_MEDIA_ORIGINS: "https://cdn.petmagic.app",
    },
  },
});
