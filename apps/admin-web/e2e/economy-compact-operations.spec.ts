import { expect, test, type Page, type Route } from "@playwright/test";

import {
  captureFigmaState,
  hasFigmaCaptureState,
  installFigmaCaptureRouting,
} from "./figma-capture";

test.beforeEach(async ({ page }) => installFigmaCaptureRouting(page));

const adminUserId = "11111111-1111-4111-8111-111111111111";
const operatorUserId = "22222222-2222-4222-8222-222222222222";

function createAdminSession() {
  return {
    accessToken: "economy-compact-operations-token",
    refreshToken: "economy-compact-operations-refresh-token",
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

async function fulfillJson(route: Route, body: unknown, status = 200) {
  await route.fulfill({
    status,
    contentType: "application/json",
    headers: {
      "Access-Control-Allow-Origin": route.request().headers().origin ?? "http://127.0.0.1",
      "Access-Control-Allow-Credentials": "true",
      "Access-Control-Allow-Headers": "Authorization, Content-Type",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    },
    body: JSON.stringify(body),
  });
}

async function installEconomyMocks(page: Page) {
  await page.route("**/api/**", async (route) => {
    const request = route.request();
    const url = new URL(request.url());

    if (request.method() === "OPTIONS") {
      await route.fulfill({ status: 204 });
      return;
    }
    if (url.pathname === "/api/auth/login" || url.pathname === "/api/auth/refresh") {
      await fulfillJson(route, createAdminSession());
      return;
    }
    if (url.pathname === "/api/auth/logout") {
      await fulfillJson(route, {});
      return;
    }
    if (url.pathname === "/api/admin/notifications") {
      await fulfillJson(route, {
        items: [],
        nextCursor: null,
        unreadCount: 0,
        criticalUnacknowledgedCount: 0,
        asOfUtc: "2026-07-29T16:00:00Z",
      });
      return;
    }
    if (url.pathname === "/api/admin/templates/monetization/watermark") {
      await fulfillJson(route, {
        enabled: true,
        text: "PetMagic",
        logoUrl: null,
        opacity: 0.55,
        position: "bottom-right",
        size: "medium",
        costCredits: 10,
        applyToImages: true,
        applyToVideos: true,
        previewImageUrl: "",
        previewVideoFrameUrl: "",
      });
      return;
    }
    if (url.pathname === "/api/admin/economy/redeem-codes/metrics") {
      await fulfillJson(route, {
        totalCodes: 24,
        activeCodes: 18,
        totalUses: 486,
        totalGranted: 48600,
        createdLast7d: 3,
        activeTouchedLast7d: 11,
        usesLast7d: 82,
        grantedLast7d: 8200,
      });
      return;
    }
    if (url.pathname === "/api/admin/economy/redeem-codes") {
      await fulfillJson(route, {
        items: [
          {
            redeemCodeId: "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
            code: "PETMAGIC-SUMMER-2026",
            codePrefix: "PETMAGIC",
            description: "Retention campaign for verified operators",
            campaignName: "Summer retention",
            campaignChannel: "operator-console",
            minimumSuccessfulPurchases: 1,
            createdBy: "Operations Admin",
            rewardKind: "spark",
            rewardValue: 100,
            maxRedemptions: 1000,
            maxRedemptionsPerUser: 1,
            redeemedCount: 486,
            isActive: true,
            startsAtUtc: "2026-07-01T00:00:00Z",
            expiresAtUtc: "2026-08-31T23:59:59Z",
            createdAtUtc: "2026-06-28T10:00:00Z",
            updatedAtUtc: "2026-07-29T15:45:00Z",
            lastRedeemedAtUtc: "2026-07-29T15:41:00Z",
            usesLast7d: 82,
            grantedLast7d: 8200,
            maxRedeemedBySingleUser: 1,
            redemptions: [],
          },
        ],
        totalCount: 1,
        skip: 0,
        take: 25,
        hasMore: false,
      });
      return;
    }
    if (url.pathname === "/api/admin/economy/dashboard/metrics") {
      await fulfillJson(route, {
        purchasesThisWeek: 184,
        purchasesPreviousWeek: 165,
        successfulPaymentsThisWeek: 178,
        successfulPaymentsPreviousWeek: 160,
        failedPaymentsThisWeek: 6,
        failedPaymentsPreviousWeek: 5,
        revenueThisWeek: 28450,
        revenuePreviousWeek: 24700,
        totalWalletCredits: 54320,
        totalWalletDebits: 48110,
        activeSubscriptions: 1240,
        renewalStops: 18,
        currencyCode: "USD",
        revenueSeries: [],
        periodDays: 7,
        asOfUtc: "2026-07-29T16:00:00Z",
      });
      return;
    }
    if (url.pathname === "/api/admin/economy/packs") {
      await fulfillJson(route, [
        {
          packId: "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
          code: "pro",
          displayName: "Pro token pack",
          currencyCode: "USD",
          priceAmount: 24.99,
          grantedSpark: 500,
          bonusSpark: 50,
          totalSpark: 550,
          isActive: true,
          sortOrder: 10,
        },
      ]);
      return;
    }
    if (url.pathname === "/api/admin/economy/ledger") {
      await fulfillJson(route, {
        items: [
          {
            entryId: "33333333-3333-4333-8333-333333333333",
            userId: operatorUserId,
            delta: -25,
            balanceAfter: 475,
            source: "template_generation",
            reason: "Premium portrait generation",
            createdAtUtc: "2026-07-29T15:42:00Z",
            tokenKind: "spark",
            operationKind: "debit",
          },
          {
            entryId: "44444444-4444-4444-8444-444444444444",
            userId: operatorUserId,
            delta: 500,
            balanceAfter: 500,
            source: "purchase",
            reason: "Pro token pack",
            createdAtUtc: "2026-07-29T15:31:00Z",
            tokenKind: "spark",
            operationKind: "credit",
          },
        ],
        totalCount: 2,
        skip: 0,
        take: 20,
        hasMore: false,
      });
      return;
    }
    if (url.pathname === "/api/admin/economy/purchases") {
      await fulfillJson(route, {
        items: [
          {
            orderId: "55555555-5555-4555-8555-555555555555",
            userId: operatorUserId,
            packId: "66666666-6666-4666-8666-666666666666",
            packCode: "pro",
            packDisplayName: "Pro token pack",
            paymentProvider: "stripe",
            status: "succeeded",
            priceAmount: 24.99,
            currencyCode: "USD",
            sparkToGrant: 500,
            canRefund: true,
            productType: "TokenPack",
            tokenAmount: 500,
            refundStatus: "none",
            createdAtUtc: "2026-07-29T15:30:00Z",
            confirmedAtUtc: "2026-07-29T15:31:00Z",
          },
        ],
        totalCount: 1,
        skip: 0,
        take: 20,
        hasMore: false,
      });
      return;
    }
    if (url.pathname === "/api/admin/economy/subscription-plans") {
      await fulfillJson(route, [
        {
          planId: "77777777-7777-4777-8777-777777777777",
          name: "Premium Monthly",
          billingPeriod: "monthly",
          priceAmount: 9.99,
          currencyCode: "USD",
          monthlyTokenLimit: 800,
          isRecommended: true,
          isActive: true,
          appleProductId: "petmagic.premium.monthly",
          googleProductId: "petmagic_premium_monthly",
          stripePriceId: "price_premium_monthly",
          displayOrder: 1,
          updatedAtUtc: "2026-07-29T14:00:00Z",
        },
      ]);
      return;
    }
    if (url.pathname === "/api/admin/economy/subscriptions") {
      await fulfillJson(route, {
        items: [
          {
            subscriptionId: "88888888-8888-4888-8888-888888888888",
            userId: operatorUserId,
            provider: "stripe",
            purchaseChannel: "web",
            region: "US",
            planId: "77777777-7777-4777-8777-777777777777",
            planName: "Premium Monthly",
            status: "active",
            currentPeriodStartUtc: "2026-07-01T12:00:00Z",
            currentPeriodEndUtc: "2026-08-01T12:00:00Z",
            cancelAtPeriodEnd: false,
            monthlyTokenLimit: 800,
            monthlyTokensGranted: 800,
            lastTokenGrantAtUtc: "2026-07-01T12:00:00Z",
            createdAtUtc: "2026-05-01T12:00:00Z",
            updatedAtUtc: "2026-07-29T15:00:00Z",
          },
        ],
        totalCount: 1,
        skip: 0,
        take: 20,
        hasMore: false,
      });
      return;
    }
    if (url.pathname === "/api/admin/economy/subscription-events") {
      await fulfillJson(route, {
        items: [
          {
            eventId: "99999999-9999-4999-8999-999999999999",
            userId: operatorUserId,
            userSubscriptionId: "88888888-8888-4888-8888-888888888888",
            provider: "stripe",
            eventType: "invoice.payment_succeeded",
            status: "processed",
            externalEventId: "evt_01J7QW8R9T0Y1234567890",
            createdAtUtc: "2026-07-29T15:02:00Z",
            processedAtUtc: "2026-07-29T15:02:03Z",
          },
        ],
        totalCount: 1,
        skip: 0,
        take: 20,
        hasMore: false,
      });
      return;
    }
    if (url.pathname === "/api/admin/economy/payment-provider-configs") {
      await fulfillJson(route, [
        {
          configurationId: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
          provider: "stripe",
          platform: "web",
          region: "*",
          isEnabled: true,
          isRecommended: true,
          isSelectedByDefault: true,
          requiresExternalWarning: false,
          requiresStoreDisclosure: false,
          allowedFromAppVersion: "1.0.0",
          externalCheckoutAllowed: true,
          bonusTokensPercent: 0,
          displayLabel: "Stripe web checkout",
          displaySubtitle: "Default web payment route",
          warningTitle: null,
          warningMessage: null,
          mode: "live",
          notes: null,
          updatedAtUtc: "2026-07-29T14:00:00Z",
        },
      ]);
      return;
    }
    if (url.pathname === "/api/admin/economy/incidents") {
      await fulfillJson(route, {
        items: [
          {
            incidentId: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
            type: "PremiumEntitlementMismatch",
            category: "reconciliation_required",
            severity: "high",
            status: "open",
            userId: operatorUserId,
            purchaseOrderId: "55555555-5555-4555-8555-555555555555",
            userSubscriptionId: "88888888-8888-4888-8888-888888888888",
            provider: "stripe",
            externalReferenceId: "in_01J7QW8R9T0Y",
            summary: "Payment succeeded, but Premium access was not restored.",
            detectionCount: 2,
            retryCount: 1,
            autoFixApplied: false,
            firstDetectedAtUtc: "2026-07-29T14:48:00Z",
            lastDetectedAtUtc: "2026-07-29T15:12:00Z",
            nextRetryAtUtc: "2026-07-29T15:42:00Z",
            resolvedAtUtc: null,
            resolutionNote: null,
            lastError: "entitlement_projection_not_found",
          },
        ],
        totalCount: 1,
        skip: 0,
        take: 20,
        hasMore: false,
      });
      return;
    }
    if (url.pathname === "/api/admin/economy/incidents/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb") {
      const incident = {
        incidentId: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
        type: "PremiumEntitlementMismatch",
        category: "reconciliation_required",
        severity: "high",
        status: "open",
        userId: operatorUserId,
        purchaseOrderId: "55555555-5555-4555-8555-555555555555",
        userSubscriptionId: "88888888-8888-4888-8888-888888888888",
        provider: "stripe",
        externalReferenceId: "in_01J7QW8R9T0Y",
        summary: "Payment succeeded, but Premium access was not restored.",
        detectionCount: 2,
        retryCount: 1,
        autoFixApplied: false,
        firstDetectedAtUtc: "2026-07-29T14:48:00Z",
        lastDetectedAtUtc: "2026-07-29T15:12:00Z",
        nextRetryAtUtc: "2026-07-29T15:42:00Z",
        resolvedAtUtc: null,
        resolutionNote: null,
        lastError: "entitlement_projection_not_found",
      };
      await fulfillJson(route, {
        incident,
        purchaseOrder: null,
        subscription: null,
        wallet: null,
        generation: null,
        ledgerEntries: [],
        webhookEvents: [],
        auditTrail: [],
      });
      return;
    }

    await fulfillJson(route, {
      items: [],
      totalCount: 0,
      skip: 0,
      take: 20,
      hasMore: false,
    });
  });
}

async function login(page: Page) {
  await page.goto("/en");
  await page.locator("#login-email").fill("operator@petmagic.test");
  await page.locator("#login-password").fill("production-ready-password");
  await page.locator('form button[type="submit"]').click();
  await expect(page).toHaveURL(/\/en\/dashboard$/);
}

async function expectNoDocumentOverflow(page: Page) {
  const viewport = await page.evaluate(() => {
    const clientWidth = document.documentElement.clientWidth;
    const offenders = Array.from(document.querySelectorAll<HTMLElement>("body *"))
      .map((element) => {
        const rect = element.getBoundingClientRect();
        return {
          tag: element.tagName.toLowerCase(),
          className: element.className,
          left: Math.round(rect.left),
          right: Math.round(rect.right),
          width: Math.round(rect.width),
        };
      })
      .filter((element) => element.right > clientWidth + 1 && element.left < clientWidth)
      .slice(0, 8);

    return {
      clientWidth,
      scrollWidth: document.documentElement.scrollWidth,
      offenders,
    };
  });
  expect(
    viewport.scrollWidth,
    `Document overflow offenders: ${JSON.stringify(viewport.offenders)}`
  ).toBeLessThanOrEqual(viewport.clientWidth);
}

async function expectMobileDrawerClosed(page: Page) {
  const sidebar = page.locator("#admin-sidebar");
  await expect(sidebar).toHaveAttribute("aria-hidden", "true");
  await expect
    .poll(() => sidebar.evaluate((element) => element.getBoundingClientRect().right))
    .toBeLessThanOrEqual(0);
}

async function expectWorkspaceTabFullyVisible(page: Page, name: RegExp) {
  const tab = page.getByRole("tab", { name });
  await expect(tab).toBeVisible();
  await expect
    .poll(() =>
      tab.evaluate((element) => {
        const rect = element.getBoundingClientRect();
        return rect.left >= 0 && rect.right <= document.documentElement.clientWidth;
      })
    )
    .toBe(true);
}

test("economy overview follows the compact operations hierarchy on desktop and mobile", async ({
  page,
}, testInfo) => {
  const runtimeErrors: string[] = [];
  page.on("pageerror", (error) => runtimeErrors.push(`pageerror: ${error.message}`));
  page.on("console", (message) => {
    if (message.type() === "error") runtimeErrors.push(`console: ${message.text()}`);
  });

  await page.setViewportSize({ width: 1440, height: 960 });
  await installEconomyMocks(page);
  await login(page);
  await page.goto("/en/economy");

  await expect(
    page.getByRole("banner").getByRole("heading", { name: "Economy", exact: true })
  ).toBeVisible();
  await expect(page.getByRole("main").getByRole("heading", { name: "Economy" })).toHaveCount(0);
  await expect(page.getByRole("heading", { name: "Last 7 days", exact: true })).toBeVisible();
  await expect(page.getByText("Revenue", { exact: true })).toBeVisible();
  await expect(page.getByText("$28,450.00", { exact: true })).toBeVisible();
  await expect(page.locator('[data-tone="success"]')).toContainText("Successful payments");
  await expect(page.locator('[data-tone="danger"]')).toContainText("Payment failures");
  await expect(page.getByText("Quick actions", { exact: true })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Recent activity", exact: true })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Recent purchases", exact: true })).toBeVisible();
  await expectNoDocumentOverflow(page);
  await captureFigmaState(page, "economy-overview");
  await page.screenshot({
    path: testInfo.outputPath("economy-desktop-light-1440.png"),
    fullPage: true,
    animations: "disabled",
  });

  await page.getByRole("tab", { name: /Premium:/ }).click();
  await expectWorkspaceTabFullyVisible(page, /Premium:/);
  await expect(page.getByRole("heading", { name: "Premium plans", exact: true })).toBeVisible();
  await expect(
    page.getByRole("heading", { name: "Active and recent subscriptions", exact: true })
  ).toBeVisible();
  await expect(page.getByRole("table")).toHaveCount(2);
  await expectNoDocumentOverflow(page);
  await captureFigmaState(page, "economy-premium");
  await page.screenshot({
    path: testInfo.outputPath("economy-premium-desktop-light-1440.png"),
    fullPage: true,
    animations: "disabled",
  });

  await page.getByRole("tab", { name: /Payments and incidents:/ }).click();
  await expectWorkspaceTabFullyVisible(page, /Payments and incidents:/);
  await expect(page.getByRole("heading", { name: "Payment incidents", exact: true })).toBeVisible();
  await expect(page.getByText("PremiumEntitlementMismatch", { exact: true }).first()).toBeVisible();
  await expectNoDocumentOverflow(page);
  await captureFigmaState(page, "economy-incidents");
  await page.screenshot({
    path: testInfo.outputPath("economy-incidents-desktop-light-1440.png"),
    fullPage: true,
    animations: "disabled",
  });

  await page.getByRole("tab", { name: /Overview:/ }).click();
  await page.getByRole("button", { name: "Switch to dark theme", exact: true }).click();
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
  await page.screenshot({
    path: testInfo.outputPath("economy-desktop-dark-1440.png"),
    fullPage: true,
    animations: "disabled",
  });

  await page.setViewportSize({ width: 390, height: 844 });
  await expectMobileDrawerClosed(page);
  await expectNoDocumentOverflow(page);
  await expect(page.getByRole("tab", { name: /Overview:/ })).toBeVisible();
  await expect(page.getByText("Pro token pack", { exact: true }).last()).toBeVisible();

  const navigationTrigger = page.getByRole("button", {
    name: "Open navigation",
    exact: true,
  });
  await navigationTrigger.click();
  await expect(page.getByRole("dialog", { name: "Admin navigation", exact: true })).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(navigationTrigger).toBeFocused();
  await expectMobileDrawerClosed(page);

  await page.screenshot({
    path: testInfo.outputPath("economy-mobile-dark-390.png"),
    fullPage: true,
    animations: "disabled",
  });

  await page.getByRole("tab", { name: /Premium:/ }).click();
  await expect(
    page.getByRole("list", { name: "Active and recent subscriptions", exact: true })
  ).toBeVisible();
  await expect(
    page.getByRole("list", { name: "Subscription event log", exact: true })
  ).toBeVisible();
  await expect(page.getByText("Premium Monthly", { exact: true }).last()).toBeVisible();
  await expect(page.getByRole("button", { name: /Cancel:/ }).last()).toBeVisible();
  await expectNoDocumentOverflow(page);
  await page.screenshot({
    path: testInfo.outputPath("economy-premium-mobile-dark-390.png"),
    fullPage: true,
    animations: "disabled",
  });

  await page.getByRole("tab", { name: /Payments and incidents:/ }).click();
  await expect(page.getByRole("list", { name: "Payment incidents", exact: true })).toBeVisible();
  await expect(page.getByText("PremiumEntitlementMismatch", { exact: true }).last()).toBeVisible();
  await expect(page.getByRole("button", { name: /Resolve:/ }).last()).toBeVisible();
  await expect(page.getByRole("button", { name: /Details:/ }).last()).toBeVisible();
  await expectNoDocumentOverflow(page);
  await page.screenshot({
    path: testInfo.outputPath("economy-incidents-mobile-dark-390.png"),
    fullPage: true,
    animations: "disabled",
  });

  await page.getByRole("button", { name: "Switch to light theme", exact: true }).click();
  await page.setViewportSize({ width: 320, height: 844 });
  await expectMobileDrawerClosed(page);
  await expectNoDocumentOverflow(page);
  await expectWorkspaceTabFullyVisible(page, /Payments and incidents:/);
  await expectWorkspaceTabFullyVisible(page, /Premium:/);
  await expect
    .poll(() =>
      page
        .getByRole("banner")
        .getByRole("heading", { name: "Economy", exact: true })
        .evaluate((element) => element.scrollWidth <= element.clientWidth)
    )
    .toBe(true);
  await expect(page.getByRole("list", { name: "Payment incidents", exact: true })).toBeVisible();
  await expect(
    page.getByRole("button", { name: /Resolve: PremiumEntitlementMismatch/ })
  ).toBeVisible();
  await page.screenshot({
    path: testInfo.outputPath("economy-incidents-mobile-light-320.png"),
    fullPage: true,
    animations: "disabled",
  });

  expect(runtimeErrors).toEqual([]);
});

test("economy pack management becomes an action card on mobile", async ({ page }, testInfo) => {
  const runtimeErrors: string[] = [];
  page.on("pageerror", (error) => runtimeErrors.push(`pageerror: ${error.message}`));
  page.on("console", (message) => {
    if (message.type() === "error") runtimeErrors.push(`console: ${message.text()}`);
  });

  await page.setViewportSize({ width: 1440, height: 960 });
  await installEconomyMocks(page);
  await login(page);
  await page.goto("/en/economy?workspace=catalog");

  await expect(page.getByRole("heading", { name: "Top-up packs", exact: true })).toBeVisible();
  await expect(page.getByRole("table")).toContainText("PRO");
  await expectNoDocumentOverflow(page);
  await captureFigmaState(page, "economy-catalog");
  await page.screenshot({
    path: testInfo.outputPath("economy-monetization-desktop-light-1440.png"),
    fullPage: true,
    animations: "disabled",
  });

  await page.getByRole("button", { name: "Switch to dark theme", exact: true }).click();
  await page.setViewportSize({ width: 390, height: 844 });
  await expectMobileDrawerClosed(page);
  await expect(page.locator('td[data-label="Pack"]').first()).toBeVisible();
  await expect(page.getByRole("button", { name: "Edit", exact: true })).toBeVisible();
  await expectNoDocumentOverflow(page);
  await page.screenshot({
    path: testInfo.outputPath("economy-monetization-mobile-dark-390.png"),
    fullPage: true,
    animations: "disabled",
  });

  expect(runtimeErrors).toEqual([]);
});

test("promo codes use compact semantic cards on narrow screens", async ({ page }, testInfo) => {
  const runtimeErrors: string[] = [];
  page.on("pageerror", (error) => runtimeErrors.push(`pageerror: ${error.message}`));
  page.on("console", (message) => {
    if (message.type() === "error") runtimeErrors.push(`console: ${message.text()}`);
  });

  await page.setViewportSize({ width: 1440, height: 960 });
  await installEconomyMocks(page);
  await login(page);
  await page.goto("/en/promo-codes");

  await expect(
    page.getByRole("banner").getByRole("heading", { name: "Promo codes", exact: true })
  ).toBeVisible();
  await expect(
    page.getByRole("main").getByRole("heading", { name: "Promo codes", exact: true })
  ).toHaveCount(0);
  await expect(page.getByRole("table")).toContainText("PETMAGIC-SUMMER-2026");
  await expectNoDocumentOverflow(page);

  await page.setViewportSize({ width: 1024, height: 900 });
  await page.getByRole("tab", { name: "Active", exact: true }).hover();
  const promoToolbarLayout = await page.evaluate(() => {
    const tabList = document.querySelector<HTMLElement>('[role="tablist"]');
    const hoverTab = document.querySelector<HTMLElement>('[role="tab"][aria-selected="false"]');
    const toolbarActions = document.querySelector<HTMLElement>(
      '[data-testid="promo-codes-toolbar-actions"]'
    );
    if (!tabList || !hoverTab || !toolbarActions) {
      throw new Error("Missing promo code toolbar controls");
    }

    const tabBounds = tabList.getBoundingClientRect();
    const hoverBounds = hoverTab.getBoundingClientRect();
    const actionCenterPositions = Array.from(toolbarActions.children).map((child) => {
      const childBounds = (child as HTMLElement).getBoundingClientRect();
      return Math.round((childBounds.top + childBounds.height / 2) * 10) / 10;
    });

    return {
      actionCenterPositions,
      clientWidth: document.documentElement.clientWidth,
      scrollWidth: document.documentElement.scrollWidth,
      hoverBottom: hoverBounds.bottom,
      hoverTop: hoverBounds.top,
      tabBottom: tabBounds.bottom,
      tabTop: tabBounds.top,
    };
  });
  expect(promoToolbarLayout.scrollWidth).toBeLessThanOrEqual(promoToolbarLayout.clientWidth);
  expect(promoToolbarLayout.hoverTop).toBeGreaterThanOrEqual(promoToolbarLayout.tabTop - 1);
  expect(promoToolbarLayout.hoverBottom).toBeLessThanOrEqual(promoToolbarLayout.tabBottom + 1);
  expect(new Set(promoToolbarLayout.actionCenterPositions).size).toBe(1);

  await page.setViewportSize({ width: 1440, height: 960 });
  await captureFigmaState(page, "promo-codes-current");

  if (hasFigmaCaptureState("promo-action-menu") || hasFigmaCaptureState("promo-editor-drawer")) {
    const actionsButton = page.getByRole("button", {
      name: /Actions menu: PETMAGIC-SUMMER-2026/,
    });
    await actionsButton.click();
    await captureFigmaState(page, "promo-action-menu");

    if (hasFigmaCaptureState("promo-editor-drawer")) {
      const actionsMenu = page.getByRole("menu");
      if (!(await actionsMenu.isVisible())) {
        await actionsButton.click();
      }
      await actionsMenu.getByRole("button", { name: /^Edit:/ }).click();
      await expect(page.getByRole("dialog")).toBeVisible();
      await captureFigmaState(page, "promo-editor-drawer");
      await page.keyboard.press("Escape");
    } else {
      await page.keyboard.press("Escape");
    }
  }

  await page.screenshot({
    path: testInfo.outputPath("promo-codes-desktop-light-1440.png"),
    fullPage: true,
    animations: "disabled",
  });

  await page.getByRole("button", { name: "Switch to dark theme", exact: true }).click();
  await page.setViewportSize({ width: 390, height: 844 });
  await expectMobileDrawerClosed(page);
  await expect(page.getByRole("table")).toBeVisible();
  await expect(page.locator('td[data-label="Code"]').first()).toBeVisible();
  await expect(
    page.getByRole("button", { name: /Actions menu: PETMAGIC-SUMMER-2026/ })
  ).toBeVisible();
  await expectNoDocumentOverflow(page);
  await page.screenshot({
    path: testInfo.outputPath("promo-codes-mobile-dark-390.png"),
    fullPage: true,
    animations: "disabled",
  });

  await page.getByRole("button", { name: "Switch to light theme", exact: true }).click();
  await page.setViewportSize({ width: 320, height: 844 });
  await expectNoDocumentOverflow(page);
  await page.screenshot({
    path: testInfo.outputPath("promo-codes-mobile-light-320.png"),
    fullPage: true,
    animations: "disabled",
  });

  expect(runtimeErrors).toEqual([]);
});
