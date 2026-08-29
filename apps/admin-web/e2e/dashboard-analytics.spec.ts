import { expect, test, type Page, type Route } from "@playwright/test";

const adminUserId = "11111111-1111-1111-1111-111111111111";

function createAdminSession() {
  return {
    accessToken: "admin-access-token",
    refreshToken: "admin-refresh-token",
    expiresAtUtc: "2099-01-01T00:00:00Z",
    user: {
      userId: adminUserId,
      email: "admin@petmagic.test",
      displayName: "Admin Operator",
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

async function fulfillJson(route: Route, body: unknown, status = 200) {
  await route.fulfill({
    status,
    contentType: "application/json",
    headers: {
      "Access-Control-Allow-Origin": route.request().headers().origin ?? "http://127.0.0.1",
      "Access-Control-Allow-Credentials": "true",
    },
    body: JSON.stringify(body),
  });
}

function createRevenueSeries(periodDays: number) {
  const start = Date.UTC(2026, 3, 1);

  return Array.from({ length: periodDays }, (_, index) => ({
    date: new Date(start + index * 86_400_000).toISOString().slice(0, 10),
    amount: 120 + (index % 9) * 25,
  }));
}

async function installDashboardMocks(page: Page) {
  const requestedPeriods: number[] = [];
  const session = createAdminSession();

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

    if (url.pathname === "/api/admin/users/dashboard/metrics") {
      await fulfillJson(route, {
        totalUsers: 240,
        premiumUsers: 64,
        activeUsers: 197,
        blockedUsers: 2,
        adminUsers: 1,
        moderatorUsers: 3,
        regularUsers: 236,
        usersThisWeek: 12,
        usersPreviousWeek: 0,
        newUsersLast7Days: 12,
        newUsersLast30Days: 42,
        newUsersLast90Days: 120,
      });
      return;
    }

    if (url.pathname === "/api/admin/users") {
      await fulfillJson(route, {
        items: [
          {
            userId: "22222222-2222-2222-2222-222222222222",
            email: "alice@petmagic.test",
            displayName: "Alice",
            isPremium: true,
            isActive: true,
            emailConfirmed: true,
            roles: ["User"],
            createdAtUtc: "2026-04-22T12:00:00Z",
          },
        ],
        totalCount: 1,
        skip: 0,
        take: 100,
        hasMore: false,
      });
      return;
    }

    if (url.pathname === "/api/admin/economy/dashboard/metrics") {
      const periodDays = Number(url.searchParams.get("periodDays") ?? "7");
      requestedPeriods.push(periodDays);
      await fulfillJson(route, {
        purchasesThisWeek: periodDays + 2,
        purchasesPreviousWeek: periodDays - 1,
        successfulPaymentsThisWeek: periodDays + 1,
        successfulPaymentsPreviousWeek: periodDays - 2,
        failedPaymentsThisWeek: 1,
        failedPaymentsPreviousWeek: 2,
        revenueThisWeek: periodDays * 170,
        revenuePreviousWeek: periodDays * 140,
        totalWalletCredits: 1024,
        totalWalletDebits: 875,
        activeSubscriptions: 64,
        renewalStops: 3,
        currencyCode: "USD",
        revenueSeries: createRevenueSeries(periodDays),
        periodDays,
        asOfUtc: "2026-06-29T12:00:00Z",
      });
      return;
    }

    if (url.pathname === "/api/admin/economy/purchases") {
      await fulfillJson(route, {
        items: [
          {
            orderId: "order-1",
            userId: "22222222-2222-2222-2222-222222222222",
            packId: "pack-1",
            packCode: "starter",
            packDisplayName: "Starter pack",
            paymentProvider: "stripe",
            status: "Succeeded",
            priceAmount: 12,
            currencyCode: "USD",
            sparkToGrant: 120,
            createdAtUtc: "2026-06-29T10:00:00Z",
            confirmedAtUtc: "2026-06-29T10:01:00Z",
          },
        ],
        totalCount: 1,
        skip: 0,
        take: 50,
        hasMore: false,
      });
      return;
    }

    if (url.pathname === "/api/admin/templates/moderation") {
      await fulfillJson(route, {
        items: [],
        totalCount: 0,
        skip: 0,
        take: 1,
        hasMore: false,
        availableCategories: [],
        generatedAtUtc: "2026-06-29T12:00:00Z",
      });
      return;
    }

    if (url.pathname === "/api/admin/templates/generations/metrics") {
      await fulfillJson(route, {
        totalJobs: 82,
        generationsToday: 8,
        generationsThisWeek: 34,
        generationsThisMonth: 82,
        failedGenerationsToday: 0,
        failedGenerationsThisWeek: 1,
        failedGenerationsThisMonth: 2,
        pendingJobs: 2,
        runningJobs: 3,
        completedJobs: 74,
        failedJobs: 2,
        cancelledJobs: 0,
        cancellingJobs: 0,
        retryingJobs: 1,
        pendingRefunds: 2,
        exhaustedRefunds: 1,
        generatedAtUtc: "2026-06-29T12:00:00Z",
      });
      return;
    }

    if (url.pathname === "/api/admin/system/status") {
      await fulfillJson(route, {
        overallStatus: "degraded",
        generatedAtUtc: "2099-01-01T00:00:00Z",
        staleAfterSeconds: 300,
        checks: [
          {
            key: "api",
            status: "healthy",
            summary: "API is operational.",
            checkedAtUtc: "2099-01-01T00:00:00Z",
          },
          {
            key: "subscriptionCatalog",
            status: "healthy",
            summary: "Subscription catalog is operational.",
            checkedAtUtc: "2099-01-01T00:00:00Z",
          },
          {
            key: "storeAccountBinding",
            status: "degraded",
            summary: "Store account binding requires review.",
            checkedAtUtc: "2099-01-01T00:00:00Z",
          },
          {
            key: "generationScheduler",
            status: "healthy",
            summary: "Generation scheduler is operational.",
            checkedAtUtc: "2099-01-01T00:00:00Z",
          },
        ],
      });
      return;
    }

    if (url.pathname === "/api/admin/system/operations") {
      await fulfillJson(route, {
        overallStatus: "unhealthy",
        generatedAtUtc: "2099-01-01T00:00:00Z",
        cacheDurationSeconds: 15,
        staleAfterSeconds: 45,
        email: { status: "healthy", backlogCount: 0, deadLetterCount: 0 },
        auditOutbox: { status: "healthy", backlogCount: 0, deadLetterCount: 0 },
        pushOutbox: { status: "unhealthy", backlogCount: 0, deadLetterCount: 1 },
        generations: { status: "healthy", queueDepth: 0 },
        economy: { status: "healthy", openIncidentCount: 0, criticalIncidentCount: 0 },
        workers: { status: "healthy", generationWorkerHeartbeatAgeSeconds: 10 },
        unavailableSources: [],
      });
      return;
    }

    if (url.pathname === "/api/admin/support/tickets/metrics") {
      await fulfillJson(route, {
        totalConversations: 5,
        openConversations: 2,
        closedConversations: 3,
        unassignedConversations: 1,
        unreadForAdminConversations: 1,
      });
      return;
    }

    if (url.pathname === "/api/admin/support/tickets") {
      await fulfillJson(route, {
        items: [],
        page: 1,
        pageSize: 50,
        totalCount: 0,
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
    });
  });

  return requestedPeriods;
}

test("dashboard switches commerce ranges and stays within the mobile viewport", async ({
  page,
}, testInfo) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  const requestedPeriods = await installDashboardMocks(page);

  await page.goto("/en");
  await page.locator("#login-email").fill("admin@petmagic.test");
  await page.locator("#login-password").fill("production-ready-password");
  await page.locator('form button[type="submit"]').click();
  await expect(page).toHaveURL(/\/en\/dashboard$/);
  await expect(
    page.getByRole("banner").getByRole("heading", { name: "Dashboard", exact: true })
  ).toBeVisible();
  await expect(
    page.locator("#admin-main").getByRole("heading", { name: "Admin Overview", exact: true })
  ).toHaveCount(0);

  const attentionRegion = page.getByRole("region", { name: "Needs attention", exact: true });
  await expect(attentionRegion).toBeVisible();
  await expect(attentionRegion.getByText("Failed payments", { exact: true })).toBeVisible();
  await expect(attentionRegion.getByText("Failed generations", { exact: true })).toBeVisible();
  await expect(
    attentionRegion.getByText("Refund attempts exhausted", { exact: true })
  ).toBeVisible();
  await expect(attentionRegion.getByText("System status", { exact: true })).toBeVisible();
  await expect(
    attentionRegion.getByText("Unread support conversations", { exact: true })
  ).toBeHidden();
  await expect(attentionRegion.getByText("Unassigned conversations", { exact: true })).toBeHidden();
  await attentionRegion.getByText("Show 2 more", { exact: true }).click();
  await expect(
    attentionRegion.getByText("Unread support conversations", { exact: true })
  ).toBeVisible();
  await expect(
    attentionRegion.getByText("Unassigned conversations", { exact: true })
  ).toBeVisible();
  await expect(
    attentionRegion.getByRole("link", { name: "Open: Unread support conversations", exact: true })
  ).toHaveAttribute("href", "/en/support?queue=unread");
  await expect(
    attentionRegion.getByRole("link", { name: "Open: Failed payments", exact: true })
  ).toHaveAttribute("href", "/en/economy?workspace=overview&purchaseStatus=failed");
  await expect(
    attentionRegion.getByRole("link", { name: "Open: Failed generations", exact: true })
  ).toHaveAttribute("href", "/en/generations?status=Failed");
  await expect(
    attentionRegion.getByRole("link", { name: "Open: Refund attempts exhausted", exact: true })
  ).toHaveAttribute("href", "/en/generations?refundState=exhausted");
  await expect(
    attentionRegion.getByRole("link", { name: "Open: System status", exact: true })
  ).toHaveAttribute("href", "/en/dashboard#system-status");
  await expect(page.getByRole("heading", { name: "System status", exact: true })).toBeVisible();
  await expect(page.getByText("Store purchase verification", { exact: true })).toBeVisible();
  await expect(page.getByText("Needs attention", { exact: true }).last()).toBeVisible();
  await expect(
    page.getByText(
      "New purchases are not blocked, but legacy purchases without a store account binding are still accepted.",
      { exact: true }
    )
  ).toBeVisible();
  await expect(
    page.getByText(
      /Confirm a purchase and restore flow in Apple and Google sandbox, then enable strict binding verification\./
    )
  ).toBeVisible();
  await expect(page.getByText("Push notification delivery", { exact: true })).toBeVisible();
  await expect(
    page.getByText(
      "1 delivery item(s) will not be retried automatically because all attempts were exhausted."
    )
  ).toBeVisible();
  await expect(
    page.getByText(/Review the worker journal entry, fix the cause, and trigger the event again\./)
  ).toBeVisible();

  const commercePeriod = page.getByRole("group", { name: "Commerce period", exact: true });
  await expect(commercePeriod).toHaveCount(1);
  const thirtyDays = commercePeriod.getByRole("button", { name: "30 days", exact: true });
  await expect(thirtyDays).toHaveCount(1);
  await expect(thirtyDays).toHaveAttribute("aria-pressed", "false");
  await thirtyDays.click();
  await expect.poll(() => requestedPeriods.includes(30)).toBe(true);
  await expect(thirtyDays).toHaveAttribute("aria-pressed", "true");
  await expect(page.getByText("Successful payments over 30 days", { exact: true })).toBeVisible();
  await page.screenshot({ path: testInfo.outputPath("dashboard-desktop-viewport.png") });
  await page.screenshot({ path: testInfo.outputPath("dashboard-desktop.png"), fullPage: true });

  const darkThemeToggle = page.getByRole("button", {
    name: "Switch to dark theme",
    exact: true,
  });
  await expect(darkThemeToggle).toHaveCount(1);
  await darkThemeToggle.click();
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
  await page.screenshot({
    path: testInfo.outputPath("dashboard-desktop-dark-viewport.png"),
    animations: "disabled",
  });

  const lightThemeToggle = page.getByRole("button", {
    name: "Switch to light theme",
    exact: true,
  });
  await expect(lightThemeToggle).toHaveCount(1);
  await lightThemeToggle.click();
  await expect(page.locator("html")).toHaveAttribute("data-theme", "light");

  await page.setViewportSize({ width: 390, height: 844 });
  await expect(commercePeriod).toBeVisible();
  await expect(thirtyDays).toHaveAttribute("aria-pressed", "true");

  const mobileSidebar = page.locator("#admin-sidebar");
  await expect(mobileSidebar).toHaveAttribute("aria-hidden", "true");
  await expect(mobileSidebar).toHaveCSS("visibility", "hidden");
  await expect
    .poll(() =>
      mobileSidebar.evaluate((element) => Math.ceil(element.getBoundingClientRect().right))
    )
    .toBeLessThanOrEqual(0);

  await expect
    .poll(() =>
      page.evaluate(() => ({
        clientWidth: document.documentElement.clientWidth,
        scrollWidth: document.documentElement.scrollWidth,
      }))
    )
    .toEqual({ clientWidth: 390, scrollWidth: 390 });

  await expect(page.getByRole("list", { name: "Recent orders", exact: true })).toBeVisible();
  await expect(page.getByRole("link", { name: "#ORDER1", exact: true }).last()).toBeVisible();
  await expect(page.locator("table").filter({ hasText: "#ORDER1" })).toBeHidden();

  await page.screenshot({ path: testInfo.outputPath("dashboard-mobile-viewport.png") });

  const mobileNavigationToggle = page.getByRole("button", {
    name: "Open navigation",
    exact: true,
  });
  await expect(mobileNavigationToggle).toHaveCount(1);
  await mobileNavigationToggle.click();
  await expect(mobileSidebar).toBeVisible();
  await expect(mobileSidebar).not.toHaveAttribute("aria-hidden", "true");
  await expect(mobileSidebar).toHaveCSS("visibility", "visible");
  await expect
    .poll(() =>
      mobileSidebar.evaluate((element) => {
        const bounds = element.getBoundingClientRect();
        return bounds.left >= 0 && bounds.right <= window.innerWidth;
      })
    )
    .toBe(true);
  await page.screenshot({ path: testInfo.outputPath("dashboard-mobile-navigation.png") });

  const mobileNavigationClose = mobileSidebar.locator("[data-admin-sidebar-close]");
  await expect(mobileNavigationClose).toHaveCount(1);
  await mobileNavigationClose.click();
  await expect(mobileSidebar).toHaveAttribute("aria-hidden", "true");
  await expect(mobileSidebar).toHaveCSS("visibility", "hidden");

  await page.screenshot({ path: testInfo.outputPath("dashboard-mobile.png"), fullPage: true });
});
