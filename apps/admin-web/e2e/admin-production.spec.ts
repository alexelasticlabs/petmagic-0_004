import { expect, test, type Page, type Route } from "@playwright/test";

const apiOrigin = "https://api.petmagic.app";
const adminUserId = "11111111-1111-1111-1111-111111111111";
const moderatorUserId = "22222222-2222-2222-2222-222222222222";
const conversationId = "33333333-3333-3333-3333-333333333333";
const generationId = "44444444-4444-4444-4444-444444444444";

function createSession(role: "Admin" | "Moderator") {
  return {
    accessToken: `${role.toLowerCase()}-access-token`,
    refreshToken: `${role.toLowerCase()}-refresh-token`,
    expiresAtUtc: "2099-01-01T00:00:00Z",
    user: {
      userId: role === "Admin" ? adminUserId : moderatorUserId,
      email: `${role.toLowerCase()}@petmagic.test`,
      displayName: `${role} Operator`,
      isPremium: false,
      emailConfirmed: true,
      roles: [role],
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

async function fulfillJson(route: Route, body: unknown, status = 200) {
  const requestOrigin = route.request().headers().origin;
  await route.fulfill({
    status,
    contentType: "application/json",
    headers: {
      "Access-Control-Allow-Origin": requestOrigin ?? "http://127.0.0.1",
      "Access-Control-Allow-Credentials": "true",
    },
    body: JSON.stringify(body),
  });
}

async function installBaseApiMocks(page: Page, role: "Admin" | "Moderator") {
  const session = createSession(role);
  let refreshCalls = 0;

  await page.route(`${apiOrigin}/api/**`, async (route) => {
    const url = new URL(route.request().url());
    if (url.pathname === "/api/auth/login" || url.pathname === "/api/auth/refresh") {
      if (url.pathname.endsWith("/refresh")) refreshCalls++;
      await fulfillJson(route, session);
      return;
    }

    if (url.pathname === "/api/auth/logout") {
      await fulfillJson(route, {});
      return;
    }

    await fulfillJson(route, {
      items: [],
      totalCount: 0,
      page: 1,
      pageSize: 25,
      hasMore: false,
      generatedAtUtc: "2026-07-09T00:00:00Z",
    });
  });

  return { session, getRefreshCalls: () => refreshCalls };
}

async function login(page: Page, role: "Admin" | "Moderator") {
  await page.goto("/en");
  await page.locator("#login-email").fill(`${role.toLowerCase()}@petmagic.test`);
  await page.locator("#login-password").fill("production-ready-password");
  await page.locator('form button[type="submit"]').click();
  await expect(page).toHaveURL(role === "Admin" ? /\/en\/dashboard$/ : /\/en\/support$/);
}

test("admin login, session restore, RBAC navigation, nonce CSP and API error", async ({ page }) => {
  const mocks = await installBaseApiMocks(page, "Admin");
  const firstResponse = await page.goto("/en");
  const firstPolicy = firstResponse?.headers()["content-security-policy"] ?? "";
  expect(firstPolicy).toContain("'nonce-");
  expect(firstPolicy).not.toMatch(/script-src[^;]*'unsafe-inline'/);
  expect(firstPolicy).not.toMatch(/style-src[^-][^;]*'unsafe-inline'/);
  expect(firstPolicy).toContain("style-src-attr 'unsafe-inline'");
  expect(firstPolicy).toContain("img-src 'self' data: blob:");
  expect(firstPolicy).toContain("media-src 'self' blob:");
  expect(firstPolicy).toContain("https://cdn.petmagic.app");

  await page.locator("#login-email").fill("admin@petmagic.test");
  await page.locator("#login-password").fill("production-ready-password");
  await page.locator('form button[type="submit"]').click();
  await expect(page).toHaveURL(/\/en\/dashboard$/);
  await expect(page.locator('a[href="/en/users"]')).toBeVisible();
  await expect(page.locator('a[href="/en/economy"]')).toBeVisible();

  const restoredResponse = await page.reload();
  await expect(page).toHaveURL(/\/en\/dashboard$/);
  await expect.poll(mocks.getRefreshCalls).toBeGreaterThan(0);
  const restoredPolicy = restoredResponse?.headers()["content-security-policy"] ?? "";
  expect(restoredPolicy).not.toBe(firstPolicy);

  await page.unroute(`${apiOrigin}/api/**`);
  await page.route(`${apiOrigin}/api/**`, async (route) => {
    const url = new URL(route.request().url());
    if (url.pathname === "/api/auth/refresh") {
      await fulfillJson(route, mocks.session);
      return;
    }

    await fulfillJson(route, { code: "test.api_failure", title: "test.api_failure" }, 503);
  });
  await page.goto("/en/users");
  await expect(page.getByText(/failed|не удалось/i).first()).toBeVisible();
});

test("moderator RBAC and support claim/unassign ownership", async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  const session = createSession("Moderator");
  let assigned = false;
  const conversation = () => ({
    conversationId,
    initiatorUserId: "55555555-5555-5555-5555-555555555555",
    userEmail: "user@petmagic.test",
    userDisplayName: "Test User",
    assignedAdminId: assigned ? moderatorUserId : null,
    assignedAdminDisplayName: assigned ? "Moderator Operator" : null,
    status: assigned ? "InProgress" : "New",
    priority: "Normal",
    tags: [],
    source: "MobileChat",
    userUnreadCount: 0,
    adminUnreadCount: 0,
    createdAtUtc: "2026-07-09T00:00:00Z",
    updatedAtUtc: "2026-07-09T00:00:00Z",
    waitingMinutes: 1,
    isReadOnly: false,
    canReopen: false,
    availableActions: [],
    hasOlderMessages: false,
    messages: [],
  });

  await page.route(`${apiOrigin}/api/**`, async (route) => {
    const url = new URL(route.request().url());
    if (url.pathname === "/api/auth/login" || url.pathname === "/api/auth/refresh") {
      await fulfillJson(route, session);
    } else if (url.pathname.endsWith("/assign-to-me")) {
      assigned = true;
      await fulfillJson(route, conversation());
    } else if (url.pathname.endsWith("/unassign")) {
      assigned = false;
      await fulfillJson(route, conversation());
    } else if (url.pathname === `/api/admin/support/tickets/${conversationId}`) {
      await fulfillJson(route, conversation());
    } else if (url.pathname === "/api/admin/support/tickets/metrics") {
      await fulfillJson(route, {
        totalConversations: 1,
        openConversations: 1,
        closedConversations: 0,
        unassignedConversations: assigned ? 0 : 1,
        unreadForAdminConversations: 0,
      });
    } else if (url.pathname === "/api/admin/support/tickets") {
      await fulfillJson(route, {
        items: [conversation()],
        page: 1,
        pageSize: 25,
        totalCount: 1,
        hasMore: false,
      });
    } else if (url.pathname === "/api/admin/support/templates") {
      await fulfillJson(route, []);
    } else {
      await fulfillJson(route, {});
    }
  });

  await login(page, "Moderator");
  await expect(page.locator('a[href="/en/users"]')).toHaveCount(0);
  await expect(page.locator('a[href="/en/economy"]')).toHaveCount(0);
  await page.goto(`/en/support/${conversationId}`);
  await expect(page.getByRole("button", { name: "Claim ticket" })).toBeVisible();
  await expect(page.getByPlaceholder("Write a reply to the user...")).toBeDisabled();

  await page.getByRole("button", { name: "Claim ticket" }).click();
  await expect(page.getByRole("button", { name: "Unassign ticket" })).toBeVisible();
  await expect(page.getByPlaceholder("Write a reply to the user...")).toBeEnabled();

  await page.getByRole("button", { name: "Unassign ticket" }).click();
  await expect(page.getByRole("button", { name: "Claim ticket" })).toBeVisible();
});

test("running generation cancellation becomes pending and polls", async ({ page }) => {
  const session = createSession("Admin");
  let status: "Running" | "Cancelling" = "Running";
  let listRequests = 0;
  const generation = () => ({
    generationId,
    userId: "55555555-5555-5555-5555-555555555555",
    templateId: "66666666-6666-6666-6666-666666666666",
    templateTitle: "FAL generation",
    templateType: "Image",
    status,
    provider: "fal-ai",
    model: "fal-ai/test-model",
    tokenCost: 3,
    attemptCount: 1,
    createdAtUtc: "2026-07-09T00:00:00Z",
    updatedAtUtc: "2026-07-09T00:00:00Z",
    isWatermarkRequired: false,
    isWatermarkRemoved: false,
    inputSourceType: "user_upload",
    generationMode: "normal",
    childCount: 0,
    canCancel: status === "Running",
    canRetry: false,
  });

  await page.route(`${apiOrigin}/api/**`, async (route) => {
    const url = new URL(route.request().url());
    if (url.pathname === "/api/auth/login" || url.pathname === "/api/auth/refresh") {
      await fulfillJson(route, session);
    } else if (url.pathname.endsWith(`/${generationId}/cancel`)) {
      status = "Cancelling";
      await fulfillJson(
        route,
        { generationId, status: "CancellationRequested", canCancel: false },
        202
      );
    } else if (url.pathname === "/api/admin/templates/generations/metrics") {
      await fulfillJson(route, {
        totalJobs: 1,
        generationsToday: 1,
        generationsThisWeek: 1,
        generationsThisMonth: 1,
        failedGenerationsToday: 0,
        failedGenerationsThisWeek: 0,
        failedGenerationsThisMonth: 0,
        pendingJobs: 0,
        runningJobs: status === "Running" ? 1 : 0,
        completedJobs: 0,
        failedJobs: 0,
        cancelledJobs: 0,
        cancellingJobs: status === "Cancelling" ? 1 : 0,
        retryingJobs: 0,
        generatedAtUtc: "2026-07-09T00:00:00Z",
      });
    } else if (url.pathname === "/api/admin/templates/generations") {
      listRequests++;
      await fulfillJson(route, {
        items: [generation()],
        totalCount: 1,
        skip: 0,
        take: 25,
        hasMore: false,
        generatedAtUtc: "2026-07-09T00:00:00Z",
      });
    } else {
      await fulfillJson(route, { items: [] });
    }
  });

  await login(page, "Admin");
  await page.goto("/en/generations");
  await page.getByRole("button", { name: /Cancel:/ }).click();
  await page.getByRole("button", { name: "Cancel generation", exact: true }).click();
  await expect(page.getByText("Cancelling", { exact: true }).first()).toBeVisible();
  await expect.poll(() => listRequests).toBeGreaterThan(1);
});

test("legacy Gamification delivery requires an audited decision before replay", async ({
  page,
}) => {
  const session = createSession("Admin");
  let legacyReviewRequired = true;
  let resolutionRequest: unknown = null;
  const generation = () => ({
    generationId,
    userId: "55555555-5555-5555-5555-555555555555",
    templateId: "66666666-6666-6666-6666-666666666666",
    templateTitle: "Historical generation",
    templateType: "Image",
    status: "Completed",
    tokenCost: 3,
    attemptCount: 0,
    createdAtUtc: "2026-07-09T00:00:00Z",
    updatedAtUtc: "2026-07-09T00:00:00Z",
    completedAtUtc: "2026-07-09T00:01:00Z",
    isWatermarkRequired: false,
    isWatermarkRemoved: false,
    inputSourceType: "user_upload",
    generationMode: "normal",
    childCount: 0,
    canCancel: false,
    canRetry: false,
    gamificationLegacyReviewRequired: legacyReviewRequired,
  });

  await page.route(`${apiOrigin}/api/**`, async (route) => {
    const url = new URL(route.request().url());
    if (url.pathname === "/api/auth/login" || url.pathname === "/api/auth/refresh") {
      await fulfillJson(route, session);
    } else if (url.pathname.endsWith(`/${generationId}/resolve-legacy-gamification`)) {
      resolutionRequest = route.request().postDataJSON();
      legacyReviewRequired = false;
      await fulfillJson(route, {
        generationId,
        action: "replay",
        replayQueued: true,
        resolvedAtUtc: "2026-07-10T00:00:00Z",
      });
    } else if (url.pathname === "/api/admin/templates/generations/metrics") {
      await fulfillJson(route, {
        totalJobs: 1,
        generationsToday: 0,
        generationsThisWeek: 0,
        generationsThisMonth: 0,
        failedGenerationsToday: 0,
        failedGenerationsThisWeek: 0,
        failedGenerationsThisMonth: 0,
        pendingJobs: 0,
        runningJobs: 0,
        completedJobs: 1,
        failedJobs: 0,
        cancelledJobs: 0,
        cancellingJobs: 0,
        retryingJobs: 0,
        generatedAtUtc: "2026-07-10T00:00:00Z",
      });
    } else if (url.pathname === "/api/admin/templates/generations") {
      await fulfillJson(route, {
        items: [generation()],
        totalCount: 1,
        skip: 0,
        take: 25,
        hasMore: false,
        generatedAtUtc: "2026-07-10T00:00:00Z",
      });
    } else {
      await fulfillJson(route, { items: [] });
    }
  });

  await login(page, "Admin");
  await page.goto("/en/generations");
  await page.getByRole("button", { name: /Review Gamification:/ }).click();
  await expect(page.getByRole("button", { name: "Confirm decision", exact: true })).toBeDisabled();
  await page.getByLabel("Verified action").selectOption("replay");
  await page.getByLabel("Review reason and evidence source").fill("Ledger confirms no delivery");
  await page.getByRole("button", { name: "Confirm decision", exact: true }).click();

  await expect
    .poll(() => resolutionRequest)
    .toEqual({
      action: "replay",
      reason: "Ledger confirms no delivery",
    });
  await expect(page.getByRole("button", { name: /Review Gamification:/ })).toHaveCount(0);
});

test("mobile login layout has no horizontal overflow", async ({ page }) => {
  await installBaseApiMocks(page, "Admin");
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/en");
  const dimensions = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    clientWidth: document.documentElement.clientWidth,
  }));
  expect(dimensions.scrollWidth).toBeLessThanOrEqual(dimensions.clientWidth);
  await expect(page.locator("#login-email")).toBeVisible();
});
