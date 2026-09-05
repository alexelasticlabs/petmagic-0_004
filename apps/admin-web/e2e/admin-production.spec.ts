import { expect, test, type Page, type Route } from "@playwright/test";

import { captureFigmaState, installFigmaCaptureRouting } from "./figma-capture";

test.beforeEach(async ({ page }) => installFigmaCaptureRouting(page));

const apiOrigin = "https://api.petmagic.test";

const generationControlSnapshot = {
  revision: 1,
  admissionEnabled: true,
  confirmedFalConcurrencyLimit: 6,
  confirmedAtUtc: "2026-07-27T09:30:00Z",
  reservedHeadroom: 1,
  applicationHardCeiling: 5,
  effectiveGlobalLimit: 4,
  policy: {
    globalMaxConcurrentGenerations: 4,
    imageReservedConcurrentGenerations: 3,
    imageProtectedConcurrentGenerations: 2,
    imageMaxConcurrentGenerations: 3,
    videoReservedConcurrentGenerations: 1,
    videoMaxConcurrentGenerations: 2,
    videoBorrowMaxConcurrentGenerations: 1,
    videoPreprocessingMaxConcurrentGenerations: 1,
  },
  effectiveProfile: {
    globalMaxConcurrentGenerations: 4,
    imageReservedConcurrentGenerations: 3,
    imageProtectedConcurrentGenerations: 2,
    imageMaxConcurrentGenerations: 3,
    videoReservedConcurrentGenerations: 1,
    videoMaxConcurrentGenerations: 2,
    videoBorrowMaxConcurrentGenerations: 1,
    videoPreprocessingMaxConcurrentGenerations: 1,
  },
  balance: {
    state: "fresh",
    currentBalanceUsd: 25,
    checkedAtUtc: "2026-07-27T09:30:00Z",
    lastSuccessfulAtUtc: "2026-07-27T09:30:00Z",
  },
  queue: {
    totalDepth: 0,
    imageDepth: 0,
    videoDepth: 0,
    oldestQueuedAtUtc: null,
    stages: [],
  },
  lanes: {
    inFlightTotal: 0,
    imageInFlight: 0,
    videoInFlight: 0,
    videoPreprocessingInFlight: 0,
    nativeSlotsInUse: 0,
    borrowedSlotsInUse: 0,
    reservedSlotsAvailable: 1,
    submissionUnknownCount: 0,
  },
  worker: {
    instanceCount: 1,
    heartbeatAtUtc: "2026-07-27T09:30:00Z",
    lastProgressAtUtc: "2026-07-27T09:30:00Z",
    appliedPolicyRevision: 1,
    schedulerV2Enabled: true,
    dispatchConcurrency: 4,
    reconciliationConcurrency: 1,
    mediaImportConcurrency: 1,
    maintenanceConcurrency: 1,
  },
  alerts: [],
  generatedAtUtc: "2026-07-27T09:30:00Z",
};
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
  expect(firstPolicy).toContain("https://cdn.petgpt.app");

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

test("admin command palette searches users and safely queues a selected-user email", async ({
  page,
}, testInfo) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  const session = createSession("Admin");
  const eligibleUserId = "77777777-7777-7777-7777-777777777777";
  let bulkEmailRequest: unknown = null;
  let bulkEmailIdempotencyKey: string | null = null;
  const commandUserSearchRequests: Array<{ search: string; take: number }> = [];
  const users = [
    {
      userId: eligibleUserId,
      email: "alice@petmagic.test",
      displayName: "Alice Eligible",
      isPremium: true,
      isActive: true,
      emailConfirmed: true,
      roles: ["User"],
      createdAtUtc: "2026-07-11T00:00:00Z",
      lastActivityAtUtc: "2026-07-24T12:00:00Z",
    },
    {
      userId: "88888888-8888-8888-8888-888888888888",
      email: "blocked@petmagic.test",
      displayName: "Blocked User",
      isPremium: false,
      isActive: false,
      emailConfirmed: true,
      roles: ["User"],
      createdAtUtc: "2026-07-10T00:00:00Z",
    },
    {
      userId: "99999999-9999-9999-9999-999999999999",
      email: "unconfirmed@petmagic.test",
      displayName: "Unconfirmed User",
      isPremium: false,
      isActive: true,
      emailConfirmed: false,
      roles: ["User"],
      createdAtUtc: "2026-07-09T00:00:00Z",
    },
  ];

  await page.route("**/api/**", async (route) => {
    const url = new URL(route.request().url());
    if (url.pathname === "/api/auth/login" || url.pathname === "/api/auth/refresh") {
      await fulfillJson(route, session);
      return;
    }

    if (url.pathname === "/api/auth/logout") {
      await fulfillJson(route, {});
      return;
    }

    if (url.pathname === "/api/admin/users/emails" && route.request().method() === "POST") {
      bulkEmailRequest = route.request().postDataJSON();
      bulkEmailIdempotencyKey = route.request().headers()["idempotency-key"] ?? null;
      await fulfillJson(route, {}, 202);
      return;
    }

    if (url.pathname === "/api/admin/users/dashboard/metrics") {
      await fulfillJson(route, {
        totalUsers: users.length,
        premiumUsers: 1,
        activeUsers: 2,
        blockedUsers: 1,
        adminUsers: 1,
        moderatorUsers: 0,
        regularUsers: users.length,
        usersThisWeek: 2,
        usersPreviousWeek: 1,
        newUsersLast7Days: 2,
        newUsersLast30Days: 3,
        newUsersLast90Days: 3,
      });
      return;
    }

    if (url.pathname === "/api/admin/users" && route.request().method() === "GET") {
      const search = url.searchParams.get("search")?.trim() ?? "";
      const take = Number(url.searchParams.get("take") ?? "24");
      const normalizedSearch = search.toLowerCase();
      const matchingUsers = normalizedSearch
        ? users.filter((user) =>
            `${user.displayName} ${user.email} ${user.userId}`
              .toLowerCase()
              .includes(normalizedSearch)
          )
        : users;
      if (search) {
        commandUserSearchRequests.push({ search, take });
      }

      await fulfillJson(route, {
        items: matchingUsers.slice(0, take),
        totalCount: matchingUsers.length,
        skip: Number(url.searchParams.get("skip") ?? "0"),
        take,
        hasMore: false,
      });
      return;
    }

    await fulfillJson(route, {
      items: [],
      totalCount: 0,
      page: 1,
      pageSize: 25,
      hasMore: false,
      generatedAtUtc: "2026-07-25T00:00:00Z",
    });
  });

  await login(page, "Admin");
  const dashboardUrl = page.url();
  await page.keyboard.press("Control+K");

  const commandDialog = page.getByRole("dialog", { name: "Quick navigation", exact: true });
  await expect(commandDialog).toBeVisible();
  const commandSearch = commandDialog.getByRole("combobox", {
    name: "Find a section or user",
    exact: true,
  });
  await expect(commandSearch).toBeFocused();
  await expect(commandDialog.locator('[role="option"][aria-selected="true"]')).toHaveCount(1);

  const closeCommandButton = commandDialog.getByRole("button", { name: /^Close/ });
  await closeCommandButton.focus();
  await closeCommandButton.press("Enter");
  await expect(commandDialog).toBeHidden();
  expect(page.url()).toBe(dashboardUrl);

  await page.keyboard.press("Control+K");
  await expect(commandDialog).toBeVisible();
  await expect(commandSearch).toBeFocused();
  await commandSearch.fill("A");
  await page.waitForTimeout(350);
  expect(commandUserSearchRequests).toEqual([]);
  await expect(
    commandDialog.getByText("Enter at least 2 characters to search users.", { exact: true })
  ).toBeVisible();

  await commandSearch.fill("Alice");
  await page.waitForTimeout(150);
  expect(commandUserSearchRequests).toEqual([]);
  await expect.poll(() => commandUserSearchRequests).toEqual([{ search: "Alice", take: 6 }]);

  const userCommandResult = commandDialog.getByRole("option", { name: /^Alice Eligible/ });
  await expect(userCommandResult).toBeVisible();
  await expect(userCommandResult).toHaveAttribute("aria-selected", "true");
  await expect(userCommandResult).toContainText("al***@p***.test");
  await expect(commandDialog.getByText("alice@petmagic.test", { exact: true })).toHaveCount(0);
  await captureFigmaState(page, "global-command-palette");
  await page.screenshot({
    path: testInfo.outputPath("command-palette-user-search-desktop.png"),
    fullPage: false,
  });

  await page.keyboard.press("Escape");
  await expect(commandDialog).toBeHidden();
  await page.goto("/en/users");
  await expect(page).toHaveURL(/\/en\/users$/);
  await expect(page.getByRole("columnheader", { name: "Registered", exact: true })).toBeVisible();

  const userQuickActions = page.getByRole("group", {
    name: "Quick actions: Alice Eligible",
    exact: true,
  });
  await expect(
    userQuickActions.getByRole("link", { name: "Dossier: Alice Eligible" })
  ).toBeVisible();
  await expect(
    userQuickActions.getByRole("link", { name: "Balance: Alice Eligible" })
  ).toBeVisible();
  await expect(
    userQuickActions.getByRole("link", { name: "Support: Alice Eligible" })
  ).toBeVisible();
  await captureFigmaState(page, "users-current");

  const eligibleCheckbox = page.getByRole("checkbox", {
    name: "Select recipient: Alice Eligible",
    exact: true,
  });
  await expect(eligibleCheckbox).toBeEnabled();
  await eligibleCheckbox.check();
  await expect(
    page.getByRole("checkbox", {
      name: "Only active users with confirmed email can receive this message",
      exact: true,
    })
  ).toHaveCount(2);

  const selectionTray = page.getByRole("complementary", {
    name: "Selected email recipients",
    exact: true,
  });
  await expect(selectionTray).toBeVisible();
  await expect(selectionTray.getByText("Selected: 1", { exact: true })).toBeVisible();
  await expect(selectionTray.getByText("Alice Eligible", { exact: true })).toBeVisible();
  await expect(selectionTray.getByText("Eligible for delivery", { exact: true })).toBeVisible();
  await selectionTray.getByRole("button", { name: "Email campaign", exact: true }).click();
  const composeDialog = page.getByRole("dialog", {
    name: "Prepare email campaign",
    exact: true,
  });
  await expect(composeDialog.getByRole("radio", { name: /Selected users/ })).toBeChecked();
  await captureFigmaState(page, "users-bulk-email-dialog");
  await composeDialog.getByLabel("Email subject", { exact: true }).fill("Service update");
  await composeDialog
    .getByLabel("Email body", { exact: true })
    .fill("Scheduled maintenance starts tomorrow at 10:00 UTC.");
  await composeDialog
    .getByRole("checkbox", {
      name: "I reviewed the audience and confirm that this content matches the campaign purpose.",
      exact: true,
    })
    .check();
  await composeDialog.getByRole("button", { name: "Review", exact: true }).click();

  expect(bulkEmailRequest).toBeNull();
  const reviewDialog = page.getByRole("dialog", {
    name: "Review email campaign",
    exact: true,
  });
  await expect(reviewDialog.getByText("Alice Eligible", { exact: false })).toHaveCount(0);
  await expect(reviewDialog.getByText("Selected users (1)", { exact: true })).toBeVisible();
  await reviewDialog.getByRole("button", { name: "Queue delivery", exact: true }).click();
  await expect
    .poll(() => bulkEmailRequest)
    .toEqual({
      audience: "selected",
      subject: "Service update",
      body: "Scheduled maintenance starts tomorrow at 10:00 UTC.",
      userIds: [eligibleUserId],
    });
  expect(bulkEmailIdempotencyKey).toMatch(/^bulk-email:/);
  await expect(page.getByText("Email campaign was queued.", { exact: true })).toBeVisible();

  await page.setViewportSize({ width: 390, height: 844 });
  await page.keyboard.press("Control+K");
  await expect(commandDialog).toBeVisible();
  await commandSearch.fill("Alice");
  await expect(commandDialog.getByRole("option", { name: /^Alice Eligible/ })).toBeVisible();
  const mobileDialogBox = await commandDialog.boundingBox();
  expect(mobileDialogBox?.width).toBe(390);
  const mobileDimensions = await page.evaluate(() => {
    const dialog = document.querySelector<HTMLElement>('[role="dialog"]');
    if (!dialog) {
      throw new Error("Command palette dialog is missing.");
    }

    return {
      clientWidth: document.documentElement.clientWidth,
      dialogClientWidth: dialog.clientWidth,
      dialogScrollWidth: dialog.scrollWidth,
      scrollWidth: document.documentElement.scrollWidth,
    };
  });
  expect(mobileDimensions.scrollWidth).toBeLessThanOrEqual(mobileDimensions.clientWidth);
  expect(mobileDimensions.dialogScrollWidth).toBeLessThanOrEqual(
    mobileDimensions.dialogClientWidth
  );
  await page.screenshot({
    path: testInfo.outputPath("command-palette-user-search-mobile.png"),
    fullPage: false,
  });
});

test("command palette keeps moderator user lookup disabled and restores focus", async ({
  page,
}) => {
  await page.setViewportSize({ width: 1280, height: 800 });
  const session = createSession("Moderator");
  let moderatorUserSearchRequests = 0;

  await page.route(`${apiOrigin}/api/**`, async (route) => {
    const url = new URL(route.request().url());
    if (url.pathname === "/api/auth/login" || url.pathname === "/api/auth/refresh") {
      await fulfillJson(route, session);
      return;
    }

    if (url.pathname === "/api/admin/users" && route.request().method() === "GET") {
      moderatorUserSearchRequests += 1;
      await fulfillJson(route, {
        items: [],
        totalCount: 0,
        skip: 0,
        take: 6,
        hasMore: false,
      });
      return;
    }

    await fulfillJson(route, {
      items: [],
      totalCount: 0,
      page: 1,
      pageSize: 25,
      hasMore: false,
      generatedAtUtc: "2026-07-26T00:00:00Z",
    });
  });

  await login(page, "Moderator");
  const commandTrigger = page.getByRole("button", {
    name: "Search sections and commands",
    exact: true,
  });
  await commandTrigger.click();

  const commandDialog = page.getByRole("dialog", { name: "Quick navigation", exact: true });
  const commandSearch = commandDialog.getByRole("combobox", {
    name: "Find a section",
    exact: true,
  });
  await expect(commandSearch).toBeFocused();
  await commandSearch.fill("alice");
  await page.waitForTimeout(450);
  expect(moderatorUserSearchRequests).toBe(0);
  await expect(commandDialog.getByText("No results", { exact: true })).toBeVisible();

  await page.keyboard.press("Escape");
  await expect(commandDialog).toBeHidden();
  await expect(commandTrigger).toBeFocused();
});

test("admin assigns and revokes a moderator from the roles workspace", async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  const session = createSession("Admin");
  const candidateUserId = "55555555-5555-5555-5555-555555555555";
  const adminUser = {
    userId: adminUserId,
    email: "admin@petmagic.test",
    displayName: "Admin Operator",
    isPremium: false,
    isActive: true,
    emailConfirmed: true,
    roles: ["Admin"],
    createdAtUtc: "2026-07-09T00:00:00Z",
  };
  let isModeratorAssigned = false;
  let assignRequest: unknown = null;
  let revokeRequest: unknown = null;
  const searchRequests: string[] = [];
  const candidateUser = () => ({
    userId: candidateUserId,
    email: "candidate@petmagic.test",
    displayName: "Candidate User",
    isPremium: false,
    isActive: true,
    emailConfirmed: true,
    roles: isModeratorAssigned ? ["Moderator"] : [],
    createdAtUtc: "2026-07-10T00:00:00Z",
  });
  const pagedUsers = Array.from({ length: 21 }, (_, index) => ({
    userId: `60000000-0000-0000-0000-${String(index + 1).padStart(12, "0")}`,
    email: `paged-${index + 1}@petmagic.test`,
    displayName: `Paged User ${index + 1}`,
    isPremium: false,
    isActive: true,
    emailConfirmed: true,
    roles: [],
    createdAtUtc: "2026-07-10T00:00:00Z",
  }));
  const userPage = (
    items: unknown[],
    skip = 0,
    take = 50,
    totalCount = items.length,
    hasMore = false
  ) => ({
    items,
    skip,
    take,
    totalCount,
    hasMore,
  });

  await page.route(`${apiOrigin}/api/**`, async (route) => {
    const url = new URL(route.request().url());
    if (url.pathname === "/api/auth/login" || url.pathname === "/api/auth/refresh") {
      await fulfillJson(route, session);
      return;
    }

    if (url.pathname === "/api/admin/users" && route.request().method() === "GET") {
      const searchTerm = url.searchParams.get("search");
      if (searchTerm) {
        searchRequests.push(searchTerm);
      }

      if (url.searchParams.get("role") === "Admin") {
        await fulfillJson(route, userPage([adminUser]));
        return;
      }

      if (url.searchParams.get("role") === "Moderator") {
        await fulfillJson(route, userPage(isModeratorAssigned ? [candidateUser()] : []));
        return;
      }

      if (searchTerm === "paged") {
        const skip = Number(url.searchParams.get("skip") ?? "0");
        const take = Number(url.searchParams.get("take") ?? "20");
        const pageItems = pagedUsers.slice(skip, skip + take);
        await fulfillJson(
          route,
          userPage(pageItems, skip, take, pagedUsers.length, skip + take < pagedUsers.length)
        );
        return;
      }

      if (searchTerm) {
        await fulfillJson(route, userPage([candidateUser()]));
        return;
      }
    }

    if (
      url.pathname === `/api/admin/users/${candidateUserId}/role` &&
      route.request().method() === "PUT"
    ) {
      assignRequest = route.request().postDataJSON();
      isModeratorAssigned = true;
      await route.fulfill({ status: 204 });
      return;
    }

    if (
      url.pathname === `/api/admin/users/${candidateUserId}/role` &&
      route.request().method() === "DELETE"
    ) {
      revokeRequest = route.request().postDataJSON();
      isModeratorAssigned = false;
      await route.fulfill({ status: 204 });
      return;
    }

    await fulfillJson(route, {});
  });

  await login(page, "Admin");
  await page.goto("/en/roles");

  await expect(
    page.getByRole("banner").getByRole("heading", { name: "Role Management", exact: true })
  ).toBeVisible();
  await expect(page.getByText("No moderators yet", { exact: true })).toBeVisible();

  const desktopDimensions = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));
  expect(desktopDimensions.scrollWidth).toBeLessThanOrEqual(desktopDimensions.clientWidth);

  const searchInput = page.getByLabel("Find a user", { exact: true });
  await expect(searchInput).toBeVisible();

  await searchInput.fill("c");
  await expect(page.locator("#role-search-status")).toHaveText("Enter at least 2 characters.");
  expect(searchRequests).toEqual([]);

  await searchInput.fill("ca");
  expect(searchRequests).toEqual([]);
  await expect.poll(() => searchRequests).toContain("ca");
  await expect(
    page.getByRole("button", {
      name: "Assign Moderator to Candidate User",
      exact: true,
    })
  ).toHaveCount(1);

  const clearSearchButton = page.getByRole("button", { name: "Clear search", exact: true });
  await expect(clearSearchButton).toBeVisible();
  await clearSearchButton.click();
  await expect(searchInput).toHaveValue("");
  await expect(
    page.getByRole("button", {
      name: "Assign Moderator to Candidate User",
      exact: true,
    })
  ).toHaveCount(0);

  await searchInput.fill("paged");
  await expect(page.getByText("Showing 1–20 of 21", { exact: true })).toBeVisible();
  await page.getByRole("button", { name: "Next page", exact: true }).click();
  await expect(page.getByText("Showing 21–21 of 21", { exact: true })).toBeVisible();
  await expect(page.getByText("Paged User 21", { exact: true })).toBeVisible();

  await searchInput.fill("candidate");

  await captureFigmaState(page, "roles-current");

  const assignButton = page.getByRole("button", {
    name: "Assign Moderator to Candidate User",
    exact: true,
  });
  await expect(assignButton).toHaveCount(1);
  await assignButton.click();

  const assignDialog = page.getByRole("dialog", { name: "Assign Moderator?", exact: true });
  await expect(assignDialog).toBeVisible();
  await captureFigmaState(page, "roles-assign-dialog");
  await assignDialog.getByRole("button", { name: "Assign Moderator", exact: true }).click();
  await expect.poll(() => assignRequest).toEqual({ role: "Moderator" });

  const moderatorsSection = page.locator('section[aria-labelledby="role-moderators-title"]');
  await expect(
    moderatorsSection.getByRole("link", { name: "Open user profile: Candidate User", exact: true })
  ).toHaveAttribute("href", `/en/users/${candidateUserId}`);

  const revokeButton = page.getByRole("button", {
    name: "Remove Moderator from Candidate User",
    exact: true,
  });
  await expect(revokeButton).toHaveCount(1);
  await expect(
    moderatorsSection.getByRole("button", {
      name: "Remove Moderator from Candidate User",
      exact: true,
    })
  ).toHaveCount(1);
  await revokeButton.click();

  const revokeDialog = page.getByRole("dialog", { name: "Remove Moderator?", exact: true });
  await expect(revokeDialog).toBeVisible();
  await revokeDialog.getByRole("button", { name: "Remove Moderator", exact: true }).click();
  await expect.poll(() => revokeRequest).toEqual({ role: "Moderator" });
  await expect(moderatorsSection.getByText("No moderators yet", { exact: true })).toBeVisible();
  await expect(
    moderatorsSection.getByRole("button", {
      name: "Remove Moderator from Candidate User",
      exact: true,
    })
  ).toHaveCount(0);

  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/ru/roles");

  const mobileSearchInput = page.getByLabel("Найти пользователя", { exact: true });
  await expect(mobileSearchInput).toBeVisible();
  await expect(page.getByText("Модераторов пока нет", { exact: true })).toBeVisible();
  const searchRequestCountBeforeMobileSearch = searchRequests.length;
  await mobileSearchInput.fill("к");
  await expect(page.locator("#role-search-status")).toHaveText("Введите минимум 2 символа.");
  expect(searchRequests).toHaveLength(searchRequestCountBeforeMobileSearch);

  await mobileSearchInput.fill("ca");
  const mobileAssignButton = page.getByRole("button", {
    name: "Назначить модератора пользователю Candidate User",
    exact: true,
  });
  await expect(mobileAssignButton).toHaveCount(1);
  await expect(page.getByRole("button", { name: "Очистить поиск", exact: true })).toHaveCount(1);

  const mobileDimensions = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));
  expect(mobileDimensions.scrollWidth).toBeLessThanOrEqual(mobileDimensions.clientWidth);
});

test("moderator RBAC and support claim/unassign ownership", async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  const session = createSession("Moderator");
  let assigned = false;
  let version = 1;
  const assignmentRequests: Array<{
    assignedAdminId: string | null;
    reason: string;
    expectedVersion: number;
  }> = [];
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
    version,
  });

  await page.route(`${apiOrigin}/api/**`, async (route) => {
    const url = new URL(route.request().url());
    if (url.pathname === "/api/auth/login" || url.pathname === "/api/auth/refresh") {
      await fulfillJson(route, session);
    } else if (
      url.pathname === `/api/admin/support/tickets/${conversationId}/assignment` &&
      route.request().method() === "PUT"
    ) {
      const request = route.request().postDataJSON() as {
        assignedAdminId: string | null;
        reason: string;
        expectedVersion: number;
      };
      assignmentRequests.push(request);

      if (request.expectedVersion !== version) {
        await fulfillJson(
          route,
          {
            code: "support.assignment_conflict",
            title: "The ticket assignment changed. Refresh and try again.",
          },
          409
        );
        return;
      }

      if (request.assignedAdminId !== null && request.assignedAdminId !== moderatorUserId) {
        await fulfillJson(
          route,
          {
            code: "support.assignment_forbidden",
            title: "Moderators can only assign tickets to themselves.",
          },
          403
        );
        return;
      }

      assigned = request.assignedAdminId === moderatorUserId;
      version += 1;
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
  await page.goto("/en/support");
  await expect(
    page.getByRole("banner").getByRole("heading", { name: "Support", exact: true })
  ).toBeVisible();
  await captureFigmaState(page, "support-inbox");
  await page.goto(`/en/support/${conversationId}`);

  for (const testId of ["support-queue-pane", "support-chat-pane", "support-info-panel"]) {
    await expect(page.getByTestId(testId)).toBeVisible();
  }

  const readWorkspaceBounds = () =>
    page.evaluate(() => {
      const paneTestIds = ["support-queue-pane", "support-chat-pane", "support-info-panel"];
      const panes = paneTestIds.map((testId) => {
        const pane = document.querySelector<HTMLElement>(`[data-testid="${testId}"]`);
        if (!pane) {
          throw new Error(`Missing support pane: ${testId}`);
        }

        const { bottom, height, left, right, top, width } = pane.getBoundingClientRect();
        return { bottom, height, left, right, top, width };
      });

      return {
        panes,
        scrollWidth: document.documentElement.scrollWidth,
        clientWidth: document.documentElement.clientWidth,
      };
    });

  const assertThreePaneLayout = async () => {
    const { clientWidth, panes, scrollWidth } = await readWorkspaceBounds();
    const [queuePane, chatPane, infoPanel] = panes;

    expect(Math.abs(queuePane.top - chatPane.top)).toBeLessThanOrEqual(1);
    expect(Math.abs(queuePane.top - infoPanel.top)).toBeLessThanOrEqual(1);
    expect(queuePane.right).toBeLessThanOrEqual(chatPane.left + 1);
    expect(chatPane.right).toBeLessThanOrEqual(infoPanel.left + 1);
    expect(scrollWidth).toBeLessThanOrEqual(clientWidth);
  };

  const assertCompactTwoPaneLayout = async () => {
    const dimensions = await page.evaluate(() => {
      const queuePane = document.querySelector<HTMLElement>('[data-testid="support-queue-pane"]');
      const chatPane = document.querySelector<HTMLElement>('[data-testid="support-chat-pane"]');
      if (!queuePane || !chatPane) {
        throw new Error("Missing compact support workspace pane");
      }

      const readBounds = (element: HTMLElement) => {
        const { left, right, top } = element.getBoundingClientRect();
        return { left, right, top };
      };
      return {
        clientWidth: document.documentElement.clientWidth,
        queueBounds: readBounds(queuePane),
        chatBounds: readBounds(chatPane),
        scrollWidth: document.documentElement.scrollWidth,
      };
    });

    expect(dimensions.scrollWidth).toBeLessThanOrEqual(dimensions.clientWidth);
    expect(Math.abs(dimensions.queueBounds.top - dimensions.chatBounds.top)).toBeLessThanOrEqual(1);
    expect(dimensions.queueBounds.right).toBeLessThanOrEqual(dimensions.chatBounds.left + 1);
  };

  const assertSupportControlsFit = async () => {
    const measurements = await page.evaluate(() => {
      const read = (testId: string) => {
        const element = document.querySelector<HTMLElement>(`[data-testid="${testId}"]`);
        if (!element) {
          throw new Error(`Missing support control: ${testId}`);
        }

        const { left, right } = element.getBoundingClientRect();
        return {
          clientWidth: element.clientWidth,
          left,
          right,
          scrollWidth: element.scrollWidth,
        };
      };

      return {
        attachment: read("support-composer-attachment"),
        composer: read("support-composer"),
        tabs: read("support-info-tabs"),
      };
    });

    expect(measurements.composer.scrollWidth).toBeLessThanOrEqual(
      measurements.composer.clientWidth
    );
    expect(measurements.tabs.scrollWidth).toBeLessThanOrEqual(measurements.tabs.clientWidth);
    expect(measurements.attachment.left).toBeGreaterThanOrEqual(measurements.composer.left - 1);
    expect(measurements.attachment.right).toBeLessThanOrEqual(measurements.composer.right + 1);
  };

  const supportInfoPanel = page.getByTestId("support-info-panel");
  const claimTicket = async (expectedVersion: number, editorAlreadyOpen = false) => {
    const requestCount = assignmentRequests.length;
    if (!editorAlreadyOpen) {
      const claimButton = supportInfoPanel.getByRole("button", {
        name: "Claim ticket",
        exact: true,
      });
      await expect(claimButton).toBeEnabled();
      await claimButton.click();
    }

    await expect(
      supportInfoPanel.getByRole("button", {
        name: "Responsible operator",
        exact: true,
      })
    ).toContainText("You");
    const confirmButton = supportInfoPanel
      .getByRole("button", {
        name: "Claim ticket",
        exact: true,
      })
      .last();
    await expect(confirmButton).toBeEnabled();
    await confirmButton.click();

    await expect.poll(() => assignmentRequests.length).toBe(requestCount + 1);
    expect(assignmentRequests.at(-1)).toEqual({
      assignedAdminId: moderatorUserId,
      reason: "Claimed for follow-up",
      expectedVersion,
    });
  };

  const unassignOwnTicket = async (reason: string, expectedVersion: number) => {
    const requestCount = assignmentRequests.length;
    await supportInfoPanel.getByRole("button", { name: "Change assignment", exact: true }).click();

    const assigneeSelect = supportInfoPanel.getByRole("button", {
      name: "Responsible operator",
      exact: true,
    });
    await assigneeSelect.click();
    await page
      .getByRole("listbox", { name: "Responsible operator", exact: true })
      .getByRole("option", { name: "No assignee", exact: true })
      .click();

    const confirmButton = supportInfoPanel.getByRole("button", {
      name: "Confirm",
      exact: true,
    });
    await expect(confirmButton).toBeDisabled();
    await page.locator("#support-assignment-reason").fill(reason);
    await expect(confirmButton).toBeEnabled();
    await confirmButton.click();

    await expect.poll(() => assignmentRequests.length).toBe(requestCount + 1);
    expect(assignmentRequests.at(-1)).toEqual({
      assignedAdminId: null,
      reason,
      expectedVersion,
    });
  };

  await assertThreePaneLayout();
  await captureFigmaState(page, "support-current");
  await expect(
    supportInfoPanel.getByRole("button", { name: "Claim ticket", exact: true })
  ).toBeVisible();
  await expect(page.getByTestId("support-composer-ownership-gate")).toBeHidden();
  const unassignedComposer = page.getByPlaceholder("Write a reply to the user...");
  await expect(unassignedComposer).toBeEnabled();
  await unassignedComposer.fill("A reply that still requires ticket ownership.");
  await page.getByTestId("support-composer").getByRole("button", { name: "Reply" }).click();
  await expect(page.getByTestId("support-composer-ownership-gate")).toBeVisible();
  await page
    .getByTestId("support-composer-ownership-gate")
    .getByRole("button", {
      name: "Claim ticket",
      exact: true,
    })
    .click();
  await expect(page.locator("#support-assignment-reason")).toHaveValue("Claimed for follow-up");

  await claimTicket(1, true);
  await expect(
    supportInfoPanel.getByRole("button", { name: "Change assignment", exact: true })
  ).toBeVisible();
  await expect(page.getByPlaceholder("Write a reply to the user...")).toBeEnabled();
  await assertSupportControlsFit();

  await unassignOwnTicket("Returning the ticket to the shared queue.", 2);
  await expect(
    supportInfoPanel.getByRole("button", { name: "Claim ticket", exact: true })
  ).toBeVisible();

  await page.setViewportSize({ width: 1280, height: 900 });
  await assertCompactTwoPaneLayout();

  const detailsTrigger = page.getByRole("button", { name: "Conversation details" });
  await expect(detailsTrigger).toBeVisible();
  await expect(detailsTrigger).toHaveAttribute("aria-expanded", "false");
  await expect(page.getByTestId("support-info-panel")).toBeHidden();

  await detailsTrigger.click();
  await expect(detailsTrigger).toHaveAttribute("aria-expanded", "true");
  await expect(page.getByRole("dialog", { name: "Conversation details" })).toBeVisible();
  await expect(
    supportInfoPanel.getByRole("button", { name: "Claim ticket", exact: true })
  ).toHaveCount(1);
  await expect(
    supportInfoPanel.getByRole("button", { name: "Claim ticket", exact: true })
  ).toBeVisible();
  await captureFigmaState(page, "support-details-drawer");
  expect(await page.evaluate(() => document.body.style.overflow)).toBe("hidden");

  await page.keyboard.press("Escape");
  await expect(page.getByTestId("support-details-drawer")).toBeHidden();
  await expect(detailsTrigger).toBeFocused();
  expect(await page.evaluate(() => document.body.style.overflow)).toBe("");

  await detailsTrigger.click();
  await claimTicket(3);
  await expect(page.getByPlaceholder("Write a reply to the user...")).toBeEnabled();
  await page.getByTestId("support-details-backdrop").click({ position: { x: 8, y: 8 } });
  await expect(page.getByTestId("support-details-drawer")).toBeHidden();
  await expect(detailsTrigger).toBeFocused();

  await page.setViewportSize({ width: 1024, height: 900 });
  const compactDimensions = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    clientWidth: document.documentElement.clientWidth,
  }));
  expect(compactDimensions.scrollWidth).toBeLessThanOrEqual(compactDimensions.clientWidth);
  await expect(detailsTrigger).toBeVisible();
  await detailsTrigger.click();
  await expect(
    supportInfoPanel.getByRole("button", { name: "Change assignment", exact: true })
  ).toBeVisible();
  await unassignOwnTicket("Releasing ownership after compact-layout review.", 4);
  await expect(page.getByTestId("support-composer-ownership-gate")).toBeHidden();
  await page.keyboard.press("Escape");

  await page.setViewportSize({ width: 390, height: 844 });
  await page.evaluate(() => window.scrollTo(0, 0));
  const mobileLayout = await page.evaluate(() => {
    const paneTestIds = ["support-queue-pane", "support-chat-pane"];
    const panes = paneTestIds.map((testId) => {
      const pane = document.querySelector<HTMLElement>(`[data-testid="${testId}"]`);
      if (!pane) {
        throw new Error(`Missing support pane: ${testId}`);
      }

      const { left, right, top } = pane.getBoundingClientRect();
      return { left, right, top };
    });

    const composer = document.querySelector<HTMLElement>(
      '[data-testid="support-composer"], [data-testid="support-composer-ownership-gate"]'
    );
    if (!composer) {
      throw new Error("Missing support composer state");
    }

    return {
      clientWidth: document.documentElement.clientWidth,
      composerClientWidth: composer.clientWidth,
      composerScrollWidth: composer.scrollWidth,
      panes,
      scrollWidth: document.documentElement.scrollWidth,
    };
  });
  const [mobileQueuePane, mobileChatPane] = mobileLayout.panes;
  expect(mobileLayout.scrollWidth).toBeLessThanOrEqual(mobileLayout.clientWidth);
  expect(mobileLayout.composerScrollWidth).toBeLessThanOrEqual(mobileLayout.composerClientWidth);
  expect(mobileQueuePane.left).toBeGreaterThanOrEqual(-1);
  expect(mobileChatPane.left).toBeGreaterThanOrEqual(-1);
  expect(mobileQueuePane.right).toBeLessThanOrEqual(mobileLayout.clientWidth + 1);
  expect(mobileChatPane.right).toBeLessThanOrEqual(mobileLayout.clientWidth + 1);
  expect(mobileQueuePane.top).toBeLessThanOrEqual(mobileChatPane.top);

  await expect(detailsTrigger).toBeVisible();
  await detailsTrigger.click();
  await expect(
    supportInfoPanel.getByRole("button", { name: "Claim ticket", exact: true })
  ).toBeVisible();
  await claimTicket(5);
  await expect(page.getByPlaceholder("Write a reply to the user...")).toBeEnabled();
  await page.keyboard.press("Escape");

  await page.setViewportSize({ width: 320, height: 844 });
  const narrowDimensions = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    clientWidth: document.documentElement.clientWidth,
  }));
  expect(narrowDimensions.scrollWidth).toBeLessThanOrEqual(narrowDimensions.clientWidth);
  await expect(page.getByPlaceholder("Write a reply to the user...")).toBeEnabled();
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
    } else if (url.pathname === "/api/admin/templates/generation-control") {
      await fulfillJson(route, generationControlSnapshot);
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
  await captureFigmaState(page, "generations-current");
  await page.getByRole("button", { name: /Cancel:/ }).click();
  await expect(page.getByRole("dialog")).toBeVisible();
  await captureFigmaState(page, "generations-cancel-dialog");
  await page.getByRole("button", { name: "Cancel generation", exact: true }).click();
  await expect(
    page.locator('[data-label="Status"]').getByText("Cancelling", { exact: true })
  ).toBeVisible();
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
    } else if (url.pathname === "/api/admin/templates/generation-control") {
      await fulfillJson(route, generationControlSnapshot);
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
  await captureFigmaState(page, "login-current");
});

test("Gamification workspace is responsive and keeps streak reset audited", async ({
  page,
}, testInfo) => {
  const session = createSession("Admin");
  const inspectedUserId = "55555555-5555-5555-5555-555555555555";
  const inspectedUser = {
    userId: inspectedUserId,
    email: "alex.petrov@petmagic.test",
    displayName: "Alex Petrov",
    isPremium: false,
    isActive: true,
    emailConfirmed: true,
    roles: ["User"],
    createdAtUtc: "2026-07-01T00:00:00Z",
    lastActivityAtUtc: "2026-07-24T08:00:00Z",
  };
  const runtimeErrors: string[] = [];
  const userSearchRequests: Array<{
    search: string | null;
    take: string | null;
    sort: string | null;
  }> = [];
  let resetRequest: unknown = null;
  let streakReset = false;

  await page.route(`${apiOrigin}/api/**`, async (route) => {
    const url = new URL(route.request().url());
    if (url.pathname === "/api/auth/login" || url.pathname === "/api/auth/refresh") {
      await fulfillJson(route, session);
      return;
    }

    if (url.pathname === "/api/admin/gamification/dashboard/metrics") {
      await fulfillJson(route, {
        totalUsersWithProgress: 18742,
        totalPetsTracked: 42381,
        totalAchievementDefinitions: 68,
        totalAchievementsUnlocked: 142881,
        usersWithActiveStreak: 6215,
        currentWeekChallenges: 3,
        currentWeekChallengeParticipants: 23518,
        currentWeekChallengeCompletions: 12934,
        generatedAtUtc: "2026-07-25T00:00:00Z",
      });
      return;
    }

    if (url.pathname === "/api/admin/gamification/challenges/current") {
      await fulfillJson(route, [
        {
          id: "11111111-1111-1111-1111-111111111111",
          weekStartDate: "2026-07-20",
          challengeType: "activity",
          targetValue: 15,
          titleKey: "Walk 15 km with your pet",
          descriptionKey: "gamification.challenge.walk.description",
          iconEmoji: "🐾",
          rewardSpark: 150,
          sortOrder: 1,
          participantCount: 12934,
          completedCount: 7114,
        },
        {
          id: "22222222-2222-2222-2222-222222222222",
          weekStartDate: "2026-07-20",
          challengeType: "care",
          targetValue: 20,
          titleKey: "Feed your pet 20 times",
          descriptionKey: "gamification.challenge.feed.description",
          iconEmoji: "🥣",
          rewardSpark: 100,
          sortOrder: 2,
          participantCount: 11248,
          completedCount: 5399,
        },
        {
          id: "33333333-3333-3333-3333-333333333333",
          weekStartDate: "2026-07-20",
          challengeType: "bonding",
          targetValue: 10,
          titleKey: "Play together 10 times",
          descriptionKey: "gamification.challenge.play.description",
          iconEmoji: "🎾",
          rewardSpark: 120,
          sortOrder: 3,
          participantCount: 8317,
          completedCount: 2994,
        },
      ]);
      return;
    }

    if (url.pathname === "/api/admin/gamification/achievements") {
      await fulfillJson(route, [
        {
          key: "first_steps",
          category: "onboarding",
          rarity: "common",
          titleKey: "First steps",
          descriptionKey: "gamification.achievement.first_steps.description",
          iconEmoji: "🏅",
          requirementType: "generation_count",
          requirementValue: 1,
          rewardSpark: 50,
          isSecret: false,
          sortOrder: 1,
          unlockedUsersCount: 24812,
        },
        {
          key: "week_warrior",
          category: "activity",
          rarity: "rare",
          titleKey: "Week warrior",
          descriptionKey: "gamification.achievement.week_warrior.description",
          iconEmoji: "⚡",
          requirementType: "weekly_distance",
          requirementValue: 50,
          rewardSpark: 150,
          isSecret: false,
          sortOrder: 2,
          unlockedUsersCount: 8341,
        },
        {
          key: "streak_king",
          category: "streaks",
          rarity: "legendary",
          titleKey: "Streak king",
          descriptionKey: "gamification.achievement.streak_king.description",
          iconEmoji: "🔥",
          requirementType: "streak_days",
          requirementValue: 30,
          rewardSpark: 500,
          isSecret: false,
          sortOrder: 3,
          unlockedUsersCount: 1102,
        },
      ]);
      return;
    }

    if (url.pathname === "/api/admin/users" && route.request().method() === "GET") {
      userSearchRequests.push({
        search: url.searchParams.get("search"),
        take: url.searchParams.get("take"),
        sort: url.searchParams.get("sort"),
      });
      await fulfillJson(route, {
        items: [inspectedUser],
        totalCount: 1,
        skip: 0,
        take: 8,
        hasMore: false,
      });
      return;
    }

    if (
      url.pathname === `/api/admin/gamification/users/${inspectedUserId}/streak/reset` &&
      route.request().method() === "POST"
    ) {
      resetRequest = route.request().postDataJSON();
      streakReset = true;
      await route.fulfill({ status: 204 });
      return;
    }

    if (url.pathname === `/api/admin/gamification/users/${inspectedUserId}`) {
      await fulfillJson(route, {
        userId: inspectedUserId,
        streak: streakReset
          ? null
          : {
              currentStreak: 12,
              longestStreak: 28,
              freezesAvailable: 1,
              freezesPerWeek: 1,
              lastActiveDate: "2026-07-24",
              activeDaysThisWeek: ["2026-07-21", "2026-07-22", "2026-07-24"],
            },
        pets: [
          {
            petId: "77777777-7777-7777-7777-777777777777",
            xp: 880,
            level: 7,
            evolutionStage: "Adult",
            totalGenerations: 42,
            xpForNextLevel: 1000,
            xpForCurrentLevel: 700,
            daysActive: 28,
            favoriteTemplateId: null,
            lastGenerationAtUtc: "2026-07-24T08:00:00Z",
          },
        ],
        achievements: [
          {
            key: "first_steps",
            category: "onboarding",
            rarity: "common",
            titleKey: "First steps",
            descriptionKey: "gamification.achievement.first_steps.description",
            iconEmoji: "🏅",
            requirementValue: 1,
            currentProgress: 1,
            rewardSpark: 50,
            isSecret: false,
            isUnlocked: true,
            unlockedAtUtc: "2026-07-01T00:00:00Z",
          },
        ],
        currentChallenges: [],
      });
      return;
    }

    await fulfillJson(route, {
      items: [],
      totalCount: 0,
      page: 1,
      pageSize: 25,
      hasMore: false,
      generatedAtUtc: "2026-07-25T00:00:00Z",
    });
  });

  await page.setViewportSize({ width: 1440, height: 1000 });
  await login(page, "Admin");
  page.on("pageerror", (error) => runtimeErrors.push(`pageerror: ${error.message}`));
  page.on("console", (message) => {
    if (message.type() === "error") {
      runtimeErrors.push(`console: ${message.text()}`);
    }
  });
  await page.goto("/en/gamification");

  await expect(
    page.getByRole("banner").getByRole("heading", { name: "Gamification", exact: true })
  ).toBeVisible();
  await expect(page.getByText("Users with progress", { exact: true })).toBeVisible();
  await expect(page.getByText("Current challenges", { exact: true })).toBeVisible();
  await expect(page.getByText("Achievement definitions", { exact: true })).toBeVisible();
  await expect(page.locator('a[href="/en/gamification"]')).toBeVisible();

  const workspaceAccessibilityTree = await page.getByRole("main").ariaSnapshot();
  expect(workspaceAccessibilityTree).not.toContain('heading "Gamification"');
  expect(workspaceAccessibilityTree).toContain('text: "Engagement Last updated:');
  expect(workspaceAccessibilityTree).toContain('heading "Current challenges"');
  expect(workspaceAccessibilityTree).toContain('searchbox "User search"');

  const desktopDimensions = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));
  expect(desktopDimensions.scrollWidth).toBeLessThanOrEqual(desktopDimensions.clientWidth);

  await page.getByLabel("User search", { exact: true }).fill("alex.petrov");
  await page.getByRole("button", { name: "Search", exact: true }).click();
  await expect
    .poll(() => userSearchRequests)
    .toContainEqual({ search: "alex.petrov", take: "8", sort: "last_activity_desc" });
  const userSearchResult = page.getByRole("button", { name: /Alex Petrov/ });
  await expect(userSearchResult).toBeVisible();
  const user360Link = page.getByRole("link", {
    name: "Open User 360: Alex Petrov",
    exact: true,
  });
  await expect(user360Link).toHaveAttribute("href", `/en/users/${inspectedUserId}`);
  await userSearchResult.click();
  await expect(page.getByText("Activity streak", { exact: true })).toBeVisible();
  const diagnosticsAccessibilityTree = await page
    .getByRole("complementary", { name: "User diagnostics", exact: true })
    .ariaSnapshot();
  expect(diagnosticsAccessibilityTree).toContain('textbox "Audit reason"');
  await page.getByLabel("Audit reason", { exact: true }).fill("Verified support incident PM-2042");
  await page.getByRole("button", { name: "Reset streak", exact: true }).click();
  const resetDialog = page.getByRole("dialog", {
    name: "Reset this user's streak?",
    exact: true,
  });
  await expect(resetDialog).toBeVisible();
  const resetDialogAccessibilityTree = await resetDialog.ariaSnapshot();
  expect(resetDialogAccessibilityTree).toContain('dialog "Reset this user\'s streak?"');
  expect(resetDialogAccessibilityTree).toContain('button "Confirm reset"');
  await resetDialog.getByRole("button", { name: "Confirm reset", exact: true }).click();
  await expect.poll(() => resetRequest).toEqual({ reason: "Verified support incident PM-2042" });
  await expect(page.getByText("The user's streak was reset.", { exact: true })).toBeVisible();

  await captureFigmaState(page, "gamification-current");
  await page.screenshot({
    path: testInfo.outputPath("gamification-desktop.png"),
    fullPage: true,
  });

  await user360Link.click();
  await expect(page).toHaveURL(new RegExp(`/en/users/${inspectedUserId}$`));

  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/en/gamification");
  await expect(page.getByText("Current challenges", { exact: true })).toBeVisible();
  const mobileDimensions = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));
  expect(mobileDimensions.scrollWidth).toBeLessThanOrEqual(mobileDimensions.clientWidth);
  await page.screenshot({
    path: testInfo.outputPath("gamification-mobile.png"),
    fullPage: true,
  });

  expect(runtimeErrors).toEqual([]);
});

test("Feedback workspace keeps queue, details, filters, and themes responsive", async ({
  page,
}, testInfo) => {
  const session = createSession("Admin");
  const primaryFeedbackId = "77777777-7777-7777-7777-777777777777";
  const secondaryFeedbackId = "88888888-8888-8888-8888-888888888888";
  const feedbackUserId = "99999999-9999-9999-9999-999999999999";
  const runtimeErrors: string[] = [];
  const apiRequestOrigins = new Set<string>();
  const feedbackListRequests: URL[] = [];
  const feedbackItems = [
    {
      id: primaryFeedbackId,
      userId: feedbackUserId,
      type: "GenerationResult",
      category: "low_value",
      rating: -1,
      sourceScreen: "generation_result",
      platform: "android",
      status: "New",
      priority: "Low",
      message: "The generated portrait does not match the selected pet.",
      createdAtUtc: "2026-07-25T08:30:00Z",
    },
    {
      id: secondaryFeedbackId,
      userId: feedbackUserId,
      type: "FeatureRequest",
      category: "feature_request",
      rating: 1,
      sourceScreen: "profile",
      platform: "ios",
      status: "InReview",
      priority: "Medium",
      message: "Please add a faster way to compare saved generations.",
      createdAtUtc: "2026-07-24T14:10:00Z",
    },
  ];
  const detailsById = new Map([
    [
      primaryFeedbackId,
      {
        ...feedbackItems[0],
        userEmail: "feedback.user@petmagic.test",
        userPlan: "Free",
        userCredits: 18,
        appVersion: "1.0.0",
        deviceModel: "Pixel 9",
        locale: "en",
        canRefund: false,
      },
    ],
    [
      secondaryFeedbackId,
      {
        ...feedbackItems[1],
        userEmail: "feedback.user@petmagic.test",
        userPlan: "Free",
        userCredits: 18,
        appVersion: "1.0.0",
        deviceModel: "iPhone 16",
        locale: "en",
        canRefund: false,
      },
    ],
  ]);

  await page.route(`${apiOrigin}/api/**`, async (route) => {
    const url = new URL(route.request().url());
    if (url.pathname === "/api/auth/login" || url.pathname === "/api/auth/refresh") {
      await fulfillJson(route, session);
      return;
    }

    if (url.pathname === "/api/auth/logout") {
      await fulfillJson(route, {});
      return;
    }

    if (url.pathname === "/api/admin/feedback/" && route.request().method() === "GET") {
      feedbackListRequests.push(url);
      const isResolvedFilter = url.searchParams.get("status") === "Resolved";
      await fulfillJson(route, {
        items: isResolvedFilter ? [] : feedbackItems,
        totalCount: isResolvedFilter ? 0 : feedbackItems.length,
        skip: Number(url.searchParams.get("skip") ?? "0"),
        take: Number(url.searchParams.get("take") ?? "25"),
        hasMore: false,
        generatedAtUtc: "2026-07-25T09:00:00Z",
      });
      return;
    }

    const details = detailsById.get(url.pathname.split("/").at(-1) ?? "");
    if (
      route.request().method() === "GET" &&
      url.pathname.startsWith("/api/admin/feedback/") &&
      details
    ) {
      await fulfillJson(route, details);
      return;
    }

    await fulfillJson(route, {
      items: [],
      totalCount: 0,
      page: 1,
      pageSize: 25,
      hasMore: false,
      generatedAtUtc: "2026-07-25T09:00:00Z",
    });
  });

  await page.setViewportSize({ width: 1440, height: 1000 });
  await login(page, "Admin");
  page.on("request", (request) => {
    const requestUrl = new URL(request.url());
    if (requestUrl.pathname.startsWith("/api/")) {
      apiRequestOrigins.add(requestUrl.origin);
    }
  });
  page.on("pageerror", (error) => runtimeErrors.push(`pageerror: ${error.message}`));
  page.on("console", (message) => {
    if (message.type() === "error") {
      runtimeErrors.push(`console: ${message.text()}`);
    }
  });
  await page.goto("/en/feedback");

  const queue = page.getByRole("list", { name: "Feedback queue", exact: true });
  await expect(queue).toBeVisible();
  await expect(queue.getByRole("button")).toHaveCount(feedbackItems.length);
  await queue.getByRole("button").first().click();
  await expect(page.getByRole("button", { name: "Close details", exact: true })).toBeVisible();
  await expect(
    page.locator(`section[aria-labelledby="feedback-message-${primaryFeedbackId}"]`)
  ).toContainText("The generated portrait does not match the selected pet.");

  const desktopDimensions = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));
  expect(desktopDimensions.scrollWidth).toBeLessThanOrEqual(desktopDimensions.clientWidth);

  const initialTheme = await page.evaluate(() => document.documentElement.dataset.theme);
  if (initialTheme !== "dark") {
    await page.getByRole("button", { name: "Switch to dark theme", exact: true }).click();
  }
  await expect.poll(() => page.evaluate(() => document.documentElement.dataset.theme)).toBe("dark");
  await page.getByRole("button", { name: "Switch to light theme", exact: true }).click();
  await expect
    .poll(() => page.evaluate(() => document.documentElement.dataset.theme))
    .toBe("light");
  await captureFigmaState(page, "feedback-current");
  await page.screenshot({
    path: testInfo.outputPath("feedback-desktop-light.png"),
    fullPage: true,
  });

  await page.getByRole("button", { name: "Switch to dark theme", exact: true }).click();
  await expect.poll(() => page.evaluate(() => document.documentElement.dataset.theme)).toBe("dark");

  const statusTabs = page.getByRole("group", { name: "Status", exact: true });
  await statusTabs.getByRole("button", { name: "Resolved", exact: true }).click();
  await expect(
    page.getByText("No feedback matches the selected filters", { exact: true })
  ).toBeVisible();
  await expect
    .poll(() =>
      feedbackListRequests.some((request) => request.searchParams.get("status") === "Resolved")
    )
    .toBe(true);
  await page.getByRole("button", { name: "Reset filters", exact: true }).first().click();
  await expect(queue.getByRole("button")).toHaveCount(feedbackItems.length);

  await page.setViewportSize({ width: 390, height: 844 });
  await page.evaluate(() => window.scrollTo(0, 0));
  await queue.getByRole("button").nth(1).click();
  await expect(
    page.locator(`section[aria-labelledby="feedback-message-${secondaryFeedbackId}"]`)
  ).toContainText("Please add a faster way to compare saved generations.");
  await expect(page.locator("#feedback-inspector")).toBeFocused();

  const mobileDimensions = await page.evaluate(() => {
    const feedbackQueue = document.querySelector<HTMLElement>('[aria-label="Feedback queue"]');
    const inspector = document.querySelector<HTMLElement>("#feedback-inspector");
    if (!feedbackQueue || !inspector) {
      throw new Error("Feedback queue or inspector is missing.");
    }

    return {
      clientWidth: document.documentElement.clientWidth,
      inspectorClientWidth: inspector.clientWidth,
      inspectorScrollWidth: inspector.scrollWidth,
      queueClientWidth: feedbackQueue.clientWidth,
      queueScrollWidth: feedbackQueue.scrollWidth,
      scrollWidth: document.documentElement.scrollWidth,
    };
  });
  expect(mobileDimensions.scrollWidth).toBeLessThanOrEqual(mobileDimensions.clientWidth);
  expect(mobileDimensions.queueScrollWidth).toBeLessThanOrEqual(mobileDimensions.queueClientWidth);
  expect(mobileDimensions.inspectorScrollWidth).toBeLessThanOrEqual(
    mobileDimensions.inspectorClientWidth
  );
  await page.evaluate(() => window.scrollTo(0, 0));
  await expect.poll(() => page.evaluate(() => window.scrollY)).toBe(0);
  await page.screenshot({
    path: testInfo.outputPath("feedback-mobile-dark.png"),
    fullPage: true,
  });

  expect([...apiRequestOrigins]).toEqual([apiOrigin]);
  expect(runtimeErrors).toEqual([]);
});

test("Russian user dossier keeps profile context and opens the balance controls", async ({
  page,
}, testInfo) => {
  const session = createSession("Admin");
  const inspectedUserId = "aaaaaaa1-1111-1111-1111-111111111111";
  const user = {
    userId: inspectedUserId,
    email: "maria.petrovna@petmagic.test",
    displayName: "Мария Петрова",
    isPremium: true,
    isActive: true,
    emailConfirmed: true,
    termsOfUseAccepted: true,
    privacyPolicyAccepted: true,
    marketingEmailsEnabled: false,
    legalAcceptance: {
      termsOfUseAccepted: true,
      termsOfUseAcceptedVersion: "2026-07",
      termsOfUseAcceptedAtUtc: "2026-07-22T21:24:00Z",
      privacyPolicyAccepted: true,
      privacyPolicyAcceptedVersion: "2026-07",
      privacyPolicyAcceptedAtUtc: "2026-07-22T21:24:00Z",
      currentTermsOfUseVersion: "2026-07",
      currentPrivacyPolicyVersion: "2026-07",
      requiresAcceptance: false,
    },
    roles: ["User"],
    createdAtUtc: "2026-07-22T21:24:00Z",
    avatar: null,
  };
  const analytics = {
    summary: {
      walletBalance: 120,
      totalTokensCredited: 220,
      totalTokensSpent: 100,
      manualTokensGranted: 20,
      manualTokensDebited: 0,
      totalPurchases: 2,
      successfulPurchases: 2,
      totalPurchasedSpark: 200,
      lastPurchaseAtUtc: "2026-07-24T10:00:00Z",
      totalGenerations: 4,
      completedGenerations: 4,
      failedGenerations: 0,
      lastGenerationAtUtc: "2026-07-24T11:00:00Z",
      totalViews: 6,
      totalVideoViews: 0,
      successfulLogins: 3,
      failedLogins: 0,
      lastLoginAtUtc: "2026-07-24T12:00:00Z",
      templateAnalyticsEvents: 8,
      auditEvents: 2,
      lastActivityAtUtc: "2026-07-24T12:00:00Z",
    },
    recentActivity: [],
    recentAuditEvents: [],
    recentPurchases: [],
    recentGenerations: [],
    recentTemplateEvents: [],
    recentWalletLedger: [],
    failureBreakdown: [],
  };
  const subscriptionSummary = {
    isPremium: true,
    provider: "Stripe",
    purchaseChannel: "Stripe",
    status: "Active",
    planName: "Premium",
    billingPeriod: "Monthly",
    currentPeriodEndUtc: "2026-08-24T12:00:00Z",
    cancelAtPeriodEnd: false,
    monthlyTokenLimit: 1_000,
    tokensAvailable: 120,
    canManageSubscription: true,
    manageSubscriptionAction: "",
    hasPendingAdminRevocation: false,
  };

  await page.route(`${apiOrigin}/api/**`, async (route) => {
    const url = new URL(route.request().url());
    if (url.pathname === "/api/auth/login" || url.pathname === "/api/auth/refresh") {
      await fulfillJson(route, session);
      return;
    }

    if (url.pathname === "/api/auth/logout") {
      await fulfillJson(route, {});
      return;
    }

    if (url.pathname === `/api/admin/users/${inspectedUserId}`) {
      await fulfillJson(route, user);
      return;
    }

    if (url.pathname === `/api/admin/users/${inspectedUserId}/analytics`) {
      await fulfillJson(route, analytics);
      return;
    }

    if (url.pathname === `/api/admin/users/${inspectedUserId}/pets`) {
      await fulfillJson(route, []);
      return;
    }

    if (url.pathname === `/api/admin/economy/users/${inspectedUserId}/subscription-summary`) {
      await fulfillJson(route, subscriptionSummary);
      return;
    }

    await fulfillJson(route, {
      items: [],
      totalCount: 0,
      page: 1,
      pageSize: 25,
      hasMore: false,
      generatedAtUtc: "2026-07-24T12:00:00Z",
    });
  });

  await page.setViewportSize({ width: 1440, height: 1000 });
  await login(page, "Admin");
  await page.goto(`/ru/users/${inspectedUserId}`);

  const masthead = page.locator('section[aria-labelledby="user-profile-title"]');
  await expect(masthead).toBeVisible();
  await expect(masthead.getByRole("heading", { name: "Мария Петрова", exact: true })).toBeVisible();
  await expect(masthead.getByText("Активен", { exact: true })).toBeVisible();
  await expect(masthead.getByText("Premium", { exact: true })).toBeVisible();
  await expect(masthead.getByText("Пользователь", { exact: true })).toBeVisible();
  await expect(masthead.getByText("С нами с", { exact: true })).toBeVisible();
  await expect(masthead.getByText("Последняя активность", { exact: true })).toBeVisible();

  const dossierTabs = page.getByRole("navigation", { name: "Раздел досье", exact: true });
  await expect(dossierTabs.getByRole("link")).toHaveCount(5);
  for (const label of [
    "Главное",
    "Баланс и покупки",
    "Обращения",
    "Питомцы и генерации",
    "Доступ",
  ]) {
    await expect(dossierTabs.getByRole("link", { name: label, exact: true })).toBeVisible();
  }
  await expect(dossierTabs.getByRole("link", { name: "Главное", exact: true })).toHaveAttribute(
    "aria-current",
    "page"
  );
  await captureFigmaState(page, "user-detail-overview");
  await page.screenshot({
    path: testInfo.outputPath("user-detail-overview.png"),
    fullPage: true,
  });

  const quickActions = page.getByRole("group", { name: "Быстрые действия", exact: true });
  await quickActions.getByRole("button", { name: "Изменить баланс", exact: true }).click();
  await expect(page).toHaveURL(
    new RegExp(`/ru/users/${inspectedUserId}\\?tab=wallet&action=adjust-balance$`)
  );
  await expect(
    dossierTabs.getByRole("link", { name: "Баланс и покупки", exact: true })
  ).toHaveAttribute("aria-current", "page");

  const adjustmentPanel = page.locator("#wallet-adjustment");
  const adjustmentFields = page.locator("#wallet-adjustment-fields");
  const adjustmentToggle = adjustmentPanel.getByRole("button", {
    name: "Скрыть управление PawSpark",
    exact: true,
  });
  await expect(adjustmentPanel).toBeVisible();
  await expect(adjustmentFields).toBeVisible();
  await expect(adjustmentToggle).toHaveAttribute("aria-controls", "wallet-adjustment-fields");
  await expect(adjustmentToggle).toHaveAttribute("aria-expanded", "true");
  await expect(page.getByLabel("Количество PawSpark", { exact: true })).toBeFocused();
  await captureFigmaState(page, "user-detail-wallet-panel");
  await page.screenshot({
    path: testInfo.outputPath("user-detail-wallet-adjustment.png"),
    fullPage: true,
  });

  await adjustmentToggle.click();
  await expect(page).toHaveURL(new RegExp(`/ru/users/${inspectedUserId}\\?tab=wallet$`));
  await expect(adjustmentFields).toBeHidden();
  await quickActions.getByRole("button", { name: "Изменить баланс", exact: true }).click();
  await expect(page).toHaveURL(
    new RegExp(`/ru/users/${inspectedUserId}\\?tab=wallet&action=adjust-balance$`)
  );
  await expect(page.getByLabel("Количество PawSpark", { exact: true })).toBeFocused();

  await dossierTabs.getByRole("link", { name: "Обращения", exact: true }).click();
  await expect(page).toHaveURL(new RegExp(`/ru/users/${inspectedUserId}\\?tab=support$`));
  await expect(
    page.getByText("Пользователь пока не создавал обращений.", { exact: true })
  ).toBeVisible();
  await captureFigmaState(page, "user-detail-support");
  await page.screenshot({
    path: testInfo.outputPath("user-detail-support.png"),
    fullPage: true,
  });

  await dossierTabs.getByRole("link", { name: "Питомцы и генерации", exact: true }).click();
  await expect(page).toHaveURL(new RegExp(`/ru/users/${inspectedUserId}\\?tab=content$`));
  await expect(page.getByText("Питомцы пока не добавлены.", { exact: true })).toBeVisible();
  await expect(page.getByText("Генераций пока нет.", { exact: true })).toBeVisible();
  await captureFigmaState(page, "user-detail-content");
  await page.screenshot({
    path: testInfo.outputPath("user-detail-content.png"),
    fullPage: true,
  });

  await dossierTabs.getByRole("link", { name: "Доступ", exact: true }).click();
  await expect(page).toHaveURL(new RegExp(`/ru/users/${inspectedUserId}\\?tab=access$`));
  await expect(page.getByRole("heading", { name: "Аккаунт", exact: true })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Права доступа", exact: true })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Подписка", exact: true })).toBeVisible();
  await captureFigmaState(page, "user-detail-access");
  await page.screenshot({
    path: testInfo.outputPath("user-detail-access.png"),
    fullPage: true,
  });

  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto(`/ru/users/${inspectedUserId}`);

  const mobileDossierSelect = page.getByRole("button", { name: "Раздел досье", exact: true });
  await expect(dossierTabs).toBeHidden();
  await expect(mobileDossierSelect).toBeVisible();

  await mobileDossierSelect.click();
  await page
    .getByRole("listbox", { name: "Раздел досье", exact: true })
    .getByRole("option", { name: "Баланс и покупки", exact: true })
    .click();
  await expect(page).toHaveURL(new RegExp(`/ru/users/${inspectedUserId}\\?tab=wallet$`));
  await expect(adjustmentPanel).toBeVisible();

  await mobileDossierSelect.click();
  await page
    .getByRole("listbox", { name: "Раздел досье", exact: true })
    .getByRole("option", { name: "Обращения", exact: true })
    .click();
  await expect(page).toHaveURL(new RegExp(`/ru/users/${inspectedUserId}\\?tab=support$`));
  await expect(
    page.getByText("Пользователь пока не создавал обращений.", { exact: true })
  ).toBeVisible();

  await mobileDossierSelect.click();
  await page
    .getByRole("listbox", { name: "Раздел досье", exact: true })
    .getByRole("option", { name: "Питомцы и генерации", exact: true })
    .click();
  await expect(page).toHaveURL(new RegExp(`/ru/users/${inspectedUserId}\\?tab=content$`));
  await expect(page.getByText("Питомцы пока не добавлены.", { exact: true })).toBeVisible();

  await mobileDossierSelect.click();
  await page
    .getByRole("listbox", { name: "Раздел досье", exact: true })
    .getByRole("option", { name: "Доступ", exact: true })
    .click();
  await expect(page).toHaveURL(new RegExp(`/ru/users/${inspectedUserId}\\?tab=access$`));
  await expect(page.getByRole("heading", { name: "Аккаунт", exact: true })).toBeVisible();

  const mobileDimensions = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));
  expect(mobileDimensions.scrollWidth).toBeLessThanOrEqual(mobileDimensions.clientWidth);

  await page.setViewportSize({ width: 320, height: 844 });
  await page.goto(`/ru/users/${inspectedUserId}`);
  const mobileQuickActions = page.getByRole("group", { name: "Быстрые действия", exact: true });
  const mobileWalletAction = mobileQuickActions.getByRole("button", {
    name: "Изменить баланс",
    exact: true,
  });
  const mobileSupportAction = mobileQuickActions.getByRole("button", {
    name: "Обращения",
    exact: true,
  });
  await expect(mobileWalletAction).toBeVisible();
  await expect(mobileSupportAction).toBeVisible();

  const narrowDimensions = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));
  expect(narrowDimensions.scrollWidth).toBeLessThanOrEqual(narrowDimensions.clientWidth);

  const narrowQuickActionBounds = await Promise.all([
    mobileWalletAction.boundingBox(),
    mobileSupportAction.boundingBox(),
  ]);
  for (const bounds of narrowQuickActionBounds) {
    expect(bounds).not.toBeNull();
    expect(bounds?.x ?? -1).toBeGreaterThanOrEqual(0);
    expect((bounds?.x ?? 0) + (bounds?.width ?? 321)).toBeLessThanOrEqual(320);
  }

  await mobileWalletAction.click();
  await expect(page).toHaveURL(
    new RegExp(`/ru/users/${inspectedUserId}\\?tab=wallet&action=adjust-balance$`)
  );
  await expect(page.getByLabel("Количество PawSpark", { exact: true })).toBeFocused();
  await page.screenshot({
    path: testInfo.outputPath("user-detail-mobile-wallet-adjustment.png"),
    fullPage: true,
  });

  await page.setViewportSize({ width: 768, height: 900 });
  await page.goto(`/ru/users/${inspectedUserId}`);
  await expect(dossierTabs).toBeVisible();
  await expect(mobileDossierSelect).toBeHidden();
  await dossierTabs.getByRole("link", { name: "Доступ", exact: true }).click();
  await expect(page).toHaveURL(new RegExp(`/ru/users/${inspectedUserId}\\?tab=access$`));
  const tabletDimensions = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));
  expect(tabletDimensions.scrollWidth).toBeLessThanOrEqual(tabletDimensions.clientWidth);
});
