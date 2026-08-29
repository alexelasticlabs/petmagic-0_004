import { expect, test, type Page, type Route } from "@playwright/test";

const apiOrigin = "https://api.petmagic.test";
const adminUserId = "11111111-1111-4111-8111-111111111111";
const criticalId = "22222222-2222-4222-8222-222222222222";
const supportId = "33333333-3333-4333-8333-333333333333";

function session() {
  return {
    accessToken: "compact-operations-access-token",
    refreshToken: "compact-operations-refresh-token",
    expiresAtUtc: "2099-01-01T00:00:00Z",
    user: {
      userId: adminUserId,
      email: "operator@petmagic.test",
      displayName: "Operations Admin",
      isPremium: false,
      emailConfirmed: true,
      roles: ["Admin"],
      legalAcceptance: {
        termsOfUseAccepted: true,
        privacyPolicyAccepted: true,
        currentTermsOfUseVersion: "1",
        currentPrivacyPolicyVersion: "1",
        requiresAcceptance: false,
      },
    },
  };
}

function notificationItems(acknowledged: boolean) {
  return [
    {
      notificationId: criticalId,
      type: "economy.incident.detected",
      schemaVersion: 1,
      payload: { incidentId: "incident-reconciliation-2026-07-29" },
      category: "economy",
      priority: "critical",
      href: "/economy?section=incidents",
      source: "economy-reconciliation",
      createdAtUtc: "2026-07-29T10:00:00Z",
      readAtUtc: null,
      archivedAtUtc: null,
      acknowledgement: acknowledged
        ? {
            actorUserId: adminUserId,
            acknowledgedAtUtc: "2026-07-29T10:10:00Z",
            reason: "Provider ledger was reconciled and verified.",
          }
        : null,
      version: acknowledged ? 2 : 1,
    },
    {
      notificationId: supportId,
      type: "support.message.received",
      schemaVersion: 1,
      payload: { conversationId: "44444444-4444-4444-8444-444444444444" },
      category: "support",
      priority: "normal",
      href: "/support/44444444-4444-4444-8444-444444444444",
      source: "support-chat",
      createdAtUtc: "2026-07-29T09:30:00Z",
      readAtUtc: null,
      archivedAtUtc: null,
      acknowledgement: null,
      version: 1,
    },
  ];
}

async function fulfillJson(route: Route, body: unknown, status = 200) {
  await route.fulfill({
    status,
    contentType: "application/json",
    headers: {
      "Access-Control-Allow-Origin": route.request().headers().origin ?? "http://127.0.0.1",
      "Access-Control-Allow-Credentials": "true",
      "Access-Control-Allow-Headers": "Authorization, Content-Type, If-Match",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    },
    body: JSON.stringify(body),
  });
}

async function installMocks(page: Page, acknowledgementMode: "success" | "conflict" = "success") {
  let acknowledged = false;
  let acknowledgementReason = "";
  await page.route(`${apiOrigin}/api/**`, async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    if (request.method() === "OPTIONS") {
      await route.fulfill({ status: 204 });
      return;
    }
    if (url.pathname === "/api/auth/login" || url.pathname === "/api/auth/refresh") {
      await fulfillJson(route, session());
      return;
    }
    if (url.pathname === "/api/auth/logout") {
      await fulfillJson(route, {});
      return;
    }
    if (url.pathname === `/api/admin/notifications/${criticalId}/acknowledge`) {
      expect(request.headers()["if-match"]).toBe('"1"');
      acknowledgementReason = String(request.postDataJSON().reason);
      acknowledged = true;
      if (acknowledgementMode === "conflict") {
        await fulfillJson(
          route,
          {
            code: "admin_notifications.acknowledgement_conflict",
            current: notificationItems(true)[0],
          },
          409
        );
      } else {
        await fulfillJson(route, notificationItems(true)[0]);
      }
      return;
    }
    if (url.pathname === "/api/admin/notifications") {
      await fulfillJson(route, {
        items: notificationItems(acknowledged),
        nextCursor: null,
        unreadCount: 2,
        criticalUnacknowledgedCount: acknowledged ? 0 : 1,
        asOfUtc: "2026-07-29T10:05:00Z",
      });
      return;
    }
    if (url.pathname.includes("/api/admin/notifications/") && request.method() === "POST") {
      await fulfillJson(route, notificationItems(acknowledged)[0]);
      return;
    }
    await fulfillJson(route, {
      items: [],
      totalCount: 0,
      page: 1,
      pageSize: 25,
      hasMore: false,
      generatedAtUtc: "2026-07-29T10:05:00Z",
    });
  });
  return { getAcknowledgementReason: () => acknowledgementReason };
}

async function login(page: Page) {
  await page.goto("/en");
  await page.locator("#login-email").fill("operator@petmagic.test");
  await page.locator("#login-password").fill("production-ready-password");
  await page.locator('form button[type="submit"]').click();
  await expect(page).toHaveURL(/\/en\/dashboard$/);
}

function collectRuntimeErrors(page: Page) {
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(`pageerror: ${error.message}`));
  page.on("console", (message) => {
    if (message.type() === "error") errors.push(`console: ${message.text()}`);
  });
  return errors;
}

test("notification inbox, collapsed rail and mobile sheet stay compact", async ({
  page,
}, testInfo) => {
  const api = await installMocks(page);
  const runtimeErrors = collectRuntimeErrors(page);
  await page.setViewportSize({ width: 1440, height: 960 });
  await login(page);

  const menuButton = page.getByRole("button", { name: /navigation/i });
  await menuButton.click();
  await expect
    .poll(() => page.evaluate(() => localStorage.getItem("petmagic.admin.sidebar.v1")))
    .toBe("collapsed");
  await page.reload();
  await expect
    .poll(() => page.evaluate(() => localStorage.getItem("petmagic.admin.sidebar.v1")))
    .toBe("collapsed");

  const switchToDark = page.getByRole("button", { name: "Switch to dark theme", exact: true });
  if (await switchToDark.isVisible()) await switchToDark.click();
  await expect.poll(() => page.evaluate(() => document.documentElement.dataset.theme)).toBe("dark");

  await page.getByRole("button", { name: "Open notifications", exact: true }).click();
  const popover = page.getByRole("dialog", { name: "Notifications", exact: true });
  await expect(popover).toBeVisible();
  await expect(popover.getByText("Economy incident detected", { exact: true })).toBeVisible();
  await page.screenshot({
    path: testInfo.outputPath("notifications-popover-desktop-dark.png"),
    fullPage: false,
  });
  await popover.locator('summary[aria-label="More actions"]').click();
  await expect(popover.getByRole("button", { name: "Clear read", exact: true })).toBeDisabled();
  await popover.getByRole("link", { name: "Full history", exact: true }).click();
  await expect(page).toHaveURL(/\/en\/notifications$/);
  await expect(
    page.getByRole("banner").getByRole("heading", { name: "Notifications" })
  ).toBeVisible();
  await expect(page.getByRole("main").getByRole("heading", { name: "Notifications" })).toHaveCount(
    0
  );
  await expect(page.getByRole("list", { name: "Operational notifications" })).toHaveCount(0);
  await expect(page.getByRole("region", { name: "Operational notifications" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Mark all read", exact: true })).toBeVisible();
  const supportRow = page.locator("article").filter({ hasText: "New support message" });
  await expect(supportRow.getByRole("button", { name: "Archive", exact: true })).toBeHidden();
  await supportRow.getByText("More", { exact: true }).click();
  await expect(supportRow.getByRole("button", { name: "Mark read", exact: true })).toBeVisible();
  await expect(supportRow.getByRole("button", { name: "Archive", exact: true })).toBeVisible();
  await page.screenshot({
    path: testInfo.outputPath("notifications-desktop-dark.png"),
    fullPage: true,
  });

  await page.getByRole("button", { name: "Acknowledge", exact: true }).click();
  await page
    .getByLabel("Acknowledgement reason", { exact: true })
    .fill("Provider ledger was reconciled and verified.");
  await page.getByRole("button", { name: "Confirm acknowledgement", exact: true }).click();
  await expect
    .poll(api.getAcknowledgementReason)
    .toBe("Provider ledger was reconciled and verified.");
  await expect(page.getByText(/Acknowledged .*Provider ledger was reconciled/)).toBeVisible();

  await page.setViewportSize({ width: 390, height: 844 });
  await page.getByRole("button", { name: "Open notifications", exact: true }).click();
  await expect(popover).toBeVisible();
  await expect(popover).toBeFocused();
  await expect(
    popover.getByRole("button", { name: "Close notifications", exact: true })
  ).toBeVisible();
  const mobile = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));
  expect(mobile.scrollWidth).toBeLessThanOrEqual(mobile.clientWidth);
  await page.screenshot({
    path: testInfo.outputPath("notifications-mobile-sheet-390.png"),
    fullPage: false,
  });
  await page.keyboard.press("Escape");

  await page.setViewportSize({ width: 320, height: 844 });
  const narrow = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));
  expect(narrow.scrollWidth).toBeLessThanOrEqual(narrow.clientWidth);
  expect(runtimeErrors).toEqual([]);
});

test("notification acknowledgement conflict refreshes the authoritative state without unhandled errors", async ({
  page,
}) => {
  const api = await installMocks(page, "conflict");
  const runtimeErrors = collectRuntimeErrors(page);
  await page.setViewportSize({ width: 1024, height: 768 });
  await login(page);
  await page.goto("/en/notifications");

  await page.getByRole("button", { name: "Acknowledge", exact: true }).click();
  await page
    .getByLabel("Acknowledgement reason", { exact: true })
    .fill("Provider ledger was reconciled and verified.");
  await page.getByRole("button", { name: "Confirm acknowledgement", exact: true }).click();

  await expect
    .poll(api.getAcknowledgementReason)
    .toBe("Provider ledger was reconciled and verified.");
  await expect(
    page.getByText(
      "Another operator already changed this event. The latest state has been loaded.",
      { exact: true }
    )
  ).toBeVisible();
  await expect(page.getByText(/Acknowledged .*Provider ledger was reconciled/)).toBeVisible();
  await expect(page.getByRole("button", { name: "Acknowledge", exact: true })).toHaveCount(0);
  expect(runtimeErrors).toContain(
    "console: Failed to load resource: the server responded with a status of 409 (Conflict)"
  );
  expect(runtimeErrors.filter((error) => !error.includes("status of 409 (Conflict)"))).toEqual([]);
});
