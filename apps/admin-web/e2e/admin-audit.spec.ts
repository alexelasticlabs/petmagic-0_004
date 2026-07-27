import { expect, test, type Page, type Route } from "@playwright/test";

const apiOrigin = "https://api.petmagic.test";
const adminUserId = "11111111-1111-1111-1111-111111111111";
const actorUserId = "22222222-2222-4222-8222-222222222222";
const subjectUserId = "33333333-3333-4333-8333-333333333333";
const firstEventId = "44444444-4444-4444-8444-444444444444";
const secondEventId = "55555555-5555-4555-8555-555555555555";

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

function corsHeaders(route: Route) {
  return {
    "Access-Control-Allow-Origin": route.request().headers().origin ?? "http://127.0.0.1",
    "Access-Control-Allow-Credentials": "true",
    "Access-Control-Allow-Headers": "Authorization, Content-Type, X-Correlation-ID",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  };
}

async function fulfillJson(route: Route, body: unknown, status = 200) {
  await route.fulfill({
    status,
    contentType: "application/json",
    headers: corsHeaders(route),
    body: JSON.stringify(body),
  });
}

function createAuditList() {
  return {
    items: [
      {
        auditEventId: firstEventId,
        action: "user.blocked",
        category: "identity",
        actorUserId,
        actorDisplayName: null,
        actorEmail: "alex.operator@example.test",
        actorRole: "Admin",
        subjectUserId,
        subjectDisplayName: "Case Owner",
        subjectEmail: "case.owner@example.test",
        targetType: "User",
        targetId: subjectUserId,
        correlationId: "audit-correlation-001",
        occurredAtUtc: "2026-07-26T12:30:00Z",
      },
      {
        auditEventId: secondEventId,
        action: "admin.payment.refund_provider_failed",
        category: "economy",
        actorUserId: null,
        actorDisplayName: null,
        actorEmail: null,
        actorRole: "System",
        subjectUserId: null,
        subjectDisplayName: null,
        subjectEmail: null,
        targetType: "purchase_order",
        targetId: "order-18042",
        correlationId: "audit-correlation-002",
        occurredAtUtc: "2026-07-26T11:10:00Z",
      },
    ],
    skip: 0,
    take: 25,
    totalCount: 2,
    hasMore: false,
    summary: {
      totalEvents: 2,
      uniqueActors: 1,
      accessEvents: 1,
      systemEvents: 1,
    },
  };
}

async function installAuditApiMocks(page: Page) {
  const session = createAdminSession();
  const listUrls: URL[] = [];
  const authorizationHeaders: Array<string | null> = [];

  await page.route(apiOrigin + "/api/**", async (route) => {
    const request = route.request();
    const url = new URL(request.url());

    if (request.method() === "OPTIONS") {
      await route.fulfill({ status: 204, headers: corsHeaders(route) });
      return;
    }

    if (url.pathname === "/api/auth/login" || url.pathname === "/api/auth/refresh") {
      await fulfillJson(route, session);
      return;
    }

    if (url.pathname === "/api/auth/logout") {
      await fulfillJson(route, {});
      return;
    }

    if (url.pathname === "/api/admin/audit-events") {
      listUrls.push(url);
      authorizationHeaders.push(request.headers().authorization ?? null);
      await fulfillJson(route, createAuditList());
      return;
    }

    if (url.pathname === "/api/admin/audit-events/" + firstEventId) {
      authorizationHeaders.push(request.headers().authorization ?? null);
      await fulfillJson(route, {
        ...createAuditList().items[0],
        oldValue: "active",
        newValue: "blocked",
        details: "authorization=secret-token user_id=private-user support investigation",
        ipAddress: "192.0.2.10",
        userAgent: "PetMagic Admin QA",
        createdAtUtc: "2026-07-26T12:30:01Z",
      });
      return;
    }

    if (url.pathname === "/api/admin/audit-events/" + secondEventId) {
      authorizationHeaders.push(request.headers().authorization ?? null);
      await fulfillJson(route, {
        ...createAuditList().items[1],
        oldValue: "pending",
        newValue: "manual_review",
        details: "Provider response requires review",
        ipAddress: null,
        userAgent: "refund-worker",
        createdAtUtc: "2026-07-26T11:10:01Z",
      });
      return;
    }

    await fulfillJson(route, {
      items: [],
      totalCount: 0,
      skip: 0,
      take: 25,
      hasMore: false,
      generatedAtUtc: "2026-07-26T12:30:00Z",
    });
  });

  return {
    getListUrls: () => listUrls,
    getAuthorizationHeaders: () => authorizationHeaders,
  };
}

async function loginAsAdmin(page: Page) {
  await page.goto("/en");
  await page.locator("#login-email").fill("admin@petmagic.test");
  await page.locator("#login-password").fill("production-ready-password");
  await page.locator('form button[type="submit"]').click();
  await expect(page).toHaveURL(/\/en\/dashboard$/);
}

function collectRuntimeErrors(page: Page) {
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push("pageerror: " + error.message));
  page.on("requestfailed", (request) => {
    const errorText = request.failure()?.errorText;
    if (!errorText || errorText === "net::ERR_ABORTED") {
      return;
    }
    errors.push(`requestfailed: ${request.url()} (${errorText})`);
  });
  page.on("console", (message) => {
    if (message.type() === "error") {
      const sourceUrl = message.location().url;
      errors.push("console: " + message.text() + (sourceUrl ? ` (${sourceUrl})` : ""));
    }
  });
  return errors;
}

test("Admin investigates audit events with server filters and safe detail context", async ({
  page,
}, testInfo) => {
  const api = await installAuditApiMocks(page);
  await page.setViewportSize({ width: 1440, height: 960 });
  await loginAsAdmin(page);
  const runtimeErrors = collectRuntimeErrors(page);

  await page.goto("/en/audit");
  await expect(page).toHaveURL(/\/en\/audit$/);
  await expect(
    page.getByRole("main").getByRole("heading", { name: "Audit trail", exact: true })
  ).toBeVisible();
  const timeline = page.locator('section[aria-labelledby="audit-timeline-title"]');
  await expect(timeline.getByText("User access blocked", { exact: true })).toBeVisible();
  await expect(timeline.getByText("Provider refund failed", { exact: true })).toBeVisible();
  await expect(page.getByText("al***@e***.test", { exact: true }).first()).toBeVisible();
  await expect(page.getByText("alex.operator@example.test", { exact: true })).toHaveCount(0);
  await expect(
    page.getByText("authorization=[redacted] user_id=[redacted] support investigation")
  ).toBeVisible();
  await expect(page.getByText("2", { exact: true }).first()).toBeVisible();

  await page.getByLabel("Search", { exact: true }).fill("refund failed");
  await page.getByRole("combobox", { name: "Category", exact: true }).selectOption("economy");
  await page.getByRole("button", { name: "Search", exact: true }).click();
  await expect.poll(() => api.getListUrls().length).toBeGreaterThanOrEqual(2);
  expect(
    api
      .getListUrls()
      .some(
        (url) =>
          url.searchParams.get("search") === "refund failed" &&
          url.searchParams.get("category") === "economy" &&
          url.searchParams.get("take") === "25" &&
          Boolean(url.searchParams.get("fromUtc")) &&
          Boolean(url.searchParams.get("toUtc"))
      )
  ).toBe(true);
  expect(api.getAuthorizationHeaders()).toContain("Bearer admin-access-token");

  await page.screenshot({
    path: testInfo.outputPath("audit-desktop.png"),
    fullPage: true,
  });
  expect(runtimeErrors).toEqual([]);
});

test("audit detail opens as a keyboard-closeable drawer without mobile overflow", async ({
  page,
}, testInfo) => {
  await installAuditApiMocks(page);
  await page.setViewportSize({ width: 390, height: 844 });
  await loginAsAdmin(page);
  const runtimeErrors = collectRuntimeErrors(page);

  await page.goto("/en/audit");
  const firstEvent = page.getByRole("button", { name: /User access blocked/ });
  await expect(firstEvent).toBeVisible();
  await firstEvent.click();
  await expect(page).toHaveURL(new RegExp(`[?&]event=${firstEventId}(?:&|$)`));
  const inspector = page.locator("#audit-event-inspector");
  await expect(inspector).toBeVisible();
  await expect(
    inspector.getByRole("button", { name: "Close event details", exact: true })
  ).toBeFocused();
  await expect(inspector.getByText("User access blocked", { exact: true })).toBeVisible();

  const dimensions = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
    inspectorWidth: document.querySelector<HTMLElement>("#audit-event-inspector")?.scrollWidth ?? 0,
    viewportWidth: window.innerWidth,
  }));
  expect(dimensions.scrollWidth).toBeLessThanOrEqual(dimensions.clientWidth);
  expect(dimensions.inspectorWidth).toBeLessThanOrEqual(dimensions.viewportWidth);

  await page.screenshot({
    path: testInfo.outputPath("audit-mobile-390.png"),
    fullPage: false,
  });
  await page.keyboard.press("Escape");
  await expect(inspector).toBeHidden();
  await expect(firstEvent).toBeFocused();
  await expect(page).not.toHaveURL(/[?&]event=/);
  expect(runtimeErrors).toEqual([]);
});
