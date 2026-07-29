import { expect, test, type Page, type Route } from "@playwright/test";

const apiOrigin = "https://api.petmagic.test";
const adminUserId = "11111111-1111-4111-8111-111111111111";
const moderationEventId = "22222222-2222-4222-8222-222222222222";
const templateId = "33333333-3333-4333-8333-333333333333";
const userId = "44444444-4444-4444-8444-444444444444";
const generationId = "55555555-5555-4555-8555-555555555555";

type Locale = "en" | "ru";
type DecisionMode = "success" | "conflict";
type ModerationDecisionPayload = {
  action: "approve" | "reject";
  expectedVersion: number;
  reason: string;
};

const pendingItem = {
  eventId: moderationEventId,
  templateId,
  templateTitle: "Golden Hour Portrait",
  templateType: "Image",
  eventType: "complaint",
  status: "pending",
  message: "The preview contains an unsafe background element.",
  source: "template_details",
  deviceClass: "mobile",
  countryCode: "BY",
  userId,
  generationId,
  moderationComment: null,
  createdAtUtc: "2026-07-20T08:30:00Z",
  moderatedAtUtc: null,
  leaseOwnerUserId: null,
  leaseOwnerDisplayName: null,
  leaseExpiresAtUtc: null,
  version: 1,
};

const initialSummary = {
  pendingCount: 3,
  approvedCount: 12,
  rejectedCount: 4,
  pendingComplaintsCount: 2,
  pendingFeedbackCount: 1,
  oldestPendingAtUtc: "2026-07-18T07:00:00Z",
  generatedAtUtc: "2026-07-26T10:00:00Z",
};

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

async function installModerationApiMocks(
  page: Page,
  options: { decisionMode?: DecisionMode } = {}
) {
  const session = createAdminSession();
  const decisionMode = options.decisionMode ?? "success";
  const moderationAuthorizationHeaders: Array<string | null> = [];
  const pageQueueUrls: URL[] = [];
  let decisionRequest: ModerationDecisionPayload | null = null;
  let decisionResolved = false;
  let claimRequest: { expectedVersion: number; leaseMinutes: number } | null = null;
  let currentItem = {
    ...pendingItem,
    leaseOwnerUserId: null as string | null,
    leaseOwnerDisplayName: null as string | null,
    leaseExpiresAtUtc: null as string | null,
    version: 1 as number,
  };

  await page.route(apiOrigin + "/api/**", async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    const method = request.method();

    if (method === "OPTIONS") {
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

    if (url.pathname === "/api/admin/templates/moderation" && method === "GET") {
      moderationAuthorizationHeaders.push(request.headers().authorization ?? null);

      const take = Number(url.searchParams.get("take") ?? "25");
      const skip = Number(url.searchParams.get("skip") ?? "0");
      const requestedStatus = url.searchParams.get("status");
      if (take === 25) {
        pageQueueUrls.push(url);
      }

      const shouldHideResolvedItem = decisionResolved && requestedStatus === "pending";
      const resolvedStatus =
        decisionRequest?.action === "reject" ? ("rejected" as const) : ("approved" as const);
      const items = shouldHideResolvedItem
        ? []
        : [
            {
              ...currentItem,
              status: decisionResolved ? resolvedStatus : pendingItem.status,
              moderationComment: decisionResolved ? decisionRequest?.reason : null,
              moderatedAtUtc: decisionResolved ? "2026-07-26T10:01:00Z" : null,
            },
          ];

      await fulfillJson(route, {
        items: items.slice(0, take),
        skip,
        take,
        totalCount: items.length,
        hasMore: false,
        generatedAtUtc: "2026-07-26T10:00:00Z",
        summary: decisionResolved
          ? {
              ...initialSummary,
              pendingCount: 2,
              approvedCount:
                decisionRequest?.action === "approve"
                  ? initialSummary.approvedCount + 1
                  : initialSummary.approvedCount,
              rejectedCount:
                decisionRequest?.action === "reject"
                  ? initialSummary.rejectedCount + 1
                  : initialSummary.rejectedCount,
              pendingComplaintsCount: 1,
              generatedAtUtc: "2026-07-26T10:01:00Z",
            }
          : initialSummary,
      });
      return;
    }

    if (
      url.pathname === "/api/admin/templates/moderation/" + moderationEventId + "/claim" &&
      method === "POST"
    ) {
      moderationAuthorizationHeaders.push(request.headers().authorization ?? null);
      claimRequest = request.postDataJSON() as { expectedVersion: number; leaseMinutes: number };
      currentItem = {
        ...currentItem,
        leaseOwnerUserId: adminUserId,
        leaseOwnerDisplayName: "Admin Operator",
        leaseExpiresAtUtc: "2099-01-01T00:15:00Z",
        version: 2,
      };
      await fulfillJson(route, currentItem);
      return;
    }

    if (
      url.pathname === "/api/admin/templates/moderation/" + moderationEventId + "/decision" &&
      method === "POST"
    ) {
      moderationAuthorizationHeaders.push(request.headers().authorization ?? null);
      decisionRequest = request.postDataJSON() as ModerationDecisionPayload;
      decisionResolved = true;

      if (decisionMode === "conflict") {
        await fulfillJson(
          route,
          {
            title: "templates.moderation_decision_conflict",
            detail: "Moderation item was already decided differently.",
          },
          409
        );
        return;
      }

      await fulfillJson(route, {
        ...currentItem,
        status: decisionRequest.action === "approve" ? "approved" : "rejected",
        moderationComment: decisionRequest.reason,
        moderatedAtUtc: "2026-07-26T10:01:00Z",
        leaseOwnerUserId: null,
        leaseOwnerDisplayName: null,
        leaseExpiresAtUtc: null,
        version: 3,
      });
      return;
    }

    await fulfillJson(route, {
      items: [],
      totalCount: 0,
      skip: 0,
      take: 25,
      page: 1,
      pageSize: 25,
      hasMore: false,
      generatedAtUtc: "2026-07-26T10:00:00Z",
    });
  });

  return {
    getClaimRequest: () => claimRequest,
    getDecisionRequest: () => decisionRequest,
    getModerationAuthorizationHeaders: () => moderationAuthorizationHeaders,
    getPageQueueReadCount: () => pageQueueUrls.length,
    getPageQueueUrls: () => pageQueueUrls,
  };
}

async function loginAsAdmin(page: Page, locale: Locale) {
  await page.goto("/" + locale);
  await page.locator("#login-email").fill("admin@petmagic.test");
  await page.locator("#login-password").fill("production-ready-password");
  await page.locator('form button[type="submit"]').click();
  await expect(page).toHaveURL(new RegExp("/" + locale + "/dashboard$"));
}

function collectRuntimeErrors(page: Page) {
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push("pageerror: " + error.message));
  page.on("console", (message) => {
    if (message.type() === "error") {
      errors.push("console: " + message.text());
    }
  });
  return errors;
}

async function expectMobileCardLayout(page: Page) {
  const dimensions = await page.evaluate(() => {
    const card = document.querySelector<HTMLElement>('ul[aria-label="Moderation queue"] article');
    const reviewButton = card?.querySelector<HTMLButtonElement>("button");
    if (!card || !reviewButton) {
      throw new Error("Semantic moderation mobile card is missing.");
    }

    const cardBounds = card.getBoundingClientRect();
    const actionBounds = reviewButton.getBoundingClientRect();
    return {
      clientWidth: document.documentElement.clientWidth,
      scrollWidth: document.documentElement.scrollWidth,
      cardClientWidth: card.clientWidth,
      cardScrollWidth: card.scrollWidth,
      cardLeft: cardBounds.left,
      cardRight: cardBounds.right,
      actionLeft: actionBounds.left,
      actionRight: actionBounds.right,
      viewportWidth: window.innerWidth,
    };
  });

  expect(dimensions.scrollWidth).toBeLessThanOrEqual(dimensions.clientWidth);
  expect(dimensions.cardScrollWidth).toBeLessThanOrEqual(dimensions.cardClientWidth);
  expect(dimensions.cardLeft).toBeGreaterThanOrEqual(-1);
  expect(dimensions.cardRight).toBeLessThanOrEqual(dimensions.viewportWidth + 1);
  expect(dimensions.actionLeft).toBeGreaterThanOrEqual(-1);
  expect(dimensions.actionRight).toBeLessThanOrEqual(dimensions.viewportWidth + 1);
}

test("Admin reviews a moderation item with summary, keyboard focus and an audited approve payload", async ({
  page,
}, testInfo) => {
  const api = await installModerationApiMocks(page);
  await page.setViewportSize({ width: 1440, height: 1000 });
  await loginAsAdmin(page, "en");
  const runtimeErrors = collectRuntimeErrors(page);

  await page.goto("/en/moderation");
  await expect(page).toHaveURL(/\/en\/moderation$/);
  await expect(
    page.getByRole("banner").getByRole("heading", { name: "Moderation", exact: true })
  ).toBeVisible();
  await expect.poll(api.getPageQueueReadCount).toBeGreaterThanOrEqual(1);

  const pendingKpi = page
    .getByText("Awaiting decision", { exact: true })
    .locator("xpath=ancestor::article[1]");
  await expect(pendingKpi.locator("strong")).toHaveText("3");
  await expect(pendingKpi).toContainText("2 complaints · 1 feedback");
  await expect(page.getByText("Approved", { exact: true }).first()).toBeVisible();
  await expect(page.getByText("Rejected", { exact: true }).first()).toBeVisible();
  await expect(
    page.getByText("Pending queue composition: 2 complaints · 1 feedback", { exact: true })
  ).toBeVisible();

  const tableRegion = page.getByRole("region", {
    name: "Moderation queue table. Use arrow keys to scroll.",
    exact: true,
  });
  await expect(tableRegion).toBeVisible();
  const queueTable = tableRegion.getByRole("table");
  await expect(queueTable.getByText("Golden Hour Portrait", { exact: true })).toBeVisible();
  await expect(page.locator('ul[aria-label="Moderation queue"]')).toBeHidden();
  expect(
    api
      .getPageQueueUrls()
      .some(
        (url) =>
          url.searchParams.get("status") === "pending" &&
          url.searchParams.get("skip") === "0" &&
          url.searchParams.get("take") === "25"
      )
  ).toBe(true);
  expect(api.getModerationAuthorizationHeaders()).toContain("Bearer admin-access-token");

  const reviewButton = queueTable.getByRole("button", {
    name: "Review item: Golden Hour Portrait",
    exact: true,
  });
  await reviewButton.focus();
  await reviewButton.press("Enter");

  let inspector = page.getByRole("dialog", { name: "Golden Hour Portrait", exact: true });
  await expect(inspector).toBeVisible();
  await expect(page).toHaveURL(new RegExp("/en/moderation\\?.*selected=" + moderationEventId));
  await expect(inspector.getByRole("button", { name: "Claim", exact: true })).toBeVisible();

  await page.keyboard.press("Escape");
  await expect(inspector).toBeHidden();
  await expect(reviewButton).toBeFocused();

  await reviewButton.press("Enter");
  inspector = page.getByRole("dialog", { name: "Golden Hour Portrait", exact: true });
  const claimButton = inspector.getByRole("button", { name: "Claim", exact: true });
  await claimButton.click();
  await expect.poll(api.getClaimRequest).toEqual({ expectedVersion: 1, leaseMinutes: 15 });
  await expect(inspector.getByText("You", { exact: true })).toBeVisible();
  await inspector.getByRole("button", { name: "Leave unchanged", exact: true }).click();

  const reviewDialog = page.getByRole("dialog", { name: "Review report", exact: true });
  const approveOption = reviewDialog
    .locator("fieldset")
    .getByRole("button", { name: /^Leave unchanged/ });
  await expect(approveOption).toBeFocused();
  await expect(approveOption).toHaveAttribute("aria-pressed", "true");

  const confirmButton = reviewDialog.getByRole("button", {
    name: "Leave this item unchanged?",
    exact: true,
  });
  await expect(confirmButton).toBeDisabled();
  await reviewDialog
    .getByLabel("Reason/comment", { exact: true })
    .fill("  Reviewed complaint evidence; no restriction is required.  ");
  await expect(confirmButton).toBeEnabled();

  await page.screenshot({
    path: testInfo.outputPath("moderation-desktop-review.png"),
    fullPage: false,
  });
  await confirmButton.focus();
  await confirmButton.press("Enter");

  await expect.poll(api.getDecisionRequest).toEqual({
    action: "approve",
    expectedVersion: 2,
    reason: "Reviewed complaint evidence; no restriction is required.",
  });
  await expect(page.getByRole("status").filter({ hasText: "Decision saved" })).toBeVisible();
  await expect(reviewDialog).toBeHidden();
  expect(api.getModerationAuthorizationHeaders()).toContain("Bearer admin-access-token");
  expect(runtimeErrors).toEqual([]);
});

test("moderation queue renders semantic cards without horizontal overflow at 390 and 320 pixels", async ({
  page,
}, testInfo) => {
  await installModerationApiMocks(page);
  await page.setViewportSize({ width: 390, height: 844 });
  await loginAsAdmin(page, "en");
  const runtimeErrors = collectRuntimeErrors(page);

  await page.goto("/en/moderation");
  const mobileQueue = page.getByRole("list", { name: "Moderation queue", exact: true });
  await expect(mobileQueue).toBeVisible();
  const mobileCard = mobileQueue.getByRole("article").first();
  await expect(
    mobileCard.getByRole("heading", { name: "Golden Hour Portrait", exact: true, level: 3 })
  ).toBeVisible();
  await expect(mobileCard.locator("dl")).toBeVisible();
  await expect(
    mobileCard.getByRole("button", {
      name: "Review item: Golden Hour Portrait",
      exact: true,
    })
  ).toBeVisible();
  await expect(
    page.getByRole("region", {
      name: "Moderation queue table. Use arrow keys to scroll.",
      exact: true,
    })
  ).toBeHidden();
  await expectMobileCardLayout(page);
  await page.screenshot({
    path: testInfo.outputPath("moderation-mobile-390.png"),
    fullPage: true,
  });

  await page.setViewportSize({ width: 320, height: 844 });
  await page.waitForTimeout(260);
  await expect(mobileQueue).toBeVisible();
  await expectMobileCardLayout(page);
  await page.screenshot({
    path: testInfo.outputPath("moderation-mobile-320.png"),
    fullPage: true,
  });
  expect(runtimeErrors).toEqual([]);
});

test("409 moderation conflict shows a localized toast and refetches the queue", async ({
  page,
}, testInfo) => {
  const api = await installModerationApiMocks(page, { decisionMode: "conflict" });
  await page.setViewportSize({ width: 1440, height: 1000 });
  await loginAsAdmin(page, "ru");
  const runtimeErrors = collectRuntimeErrors(page);

  await page.goto("/ru/moderation");
  await expect(
    page.getByRole("banner").getByRole("heading", { name: "Модерация", exact: true })
  ).toBeVisible();
  await expect.poll(api.getPageQueueReadCount).toBeGreaterThanOrEqual(1);
  const readsBeforeConflict = api.getPageQueueReadCount();

  const reviewButton = page.getByRole("table").getByRole("button", {
    name: "Рассмотреть элемент: Golden Hour Portrait",
    exact: true,
  });
  await reviewButton.click();
  const inspector = page.getByRole("dialog", {
    name: "Golden Hour Portrait",
    exact: true,
  });
  await inspector.getByRole("button", { name: "Взять в работу", exact: true }).click();
  await expect.poll(api.getClaimRequest).toEqual({ expectedVersion: 1, leaseMinutes: 15 });
  await inspector.getByRole("button", { name: "Подтвердить нарушение", exact: true }).click();
  const reviewDialog = page.getByRole("dialog", {
    name: "Проверка обращения",
    exact: true,
  });
  await reviewDialog
    .getByLabel("Причина/комментарий", { exact: true })
    .fill("Другой модератор уже обработал жалобу");

  const confirmButton = reviewDialog.getByRole("button", {
    name: "Подтвердить нарушение?",
    exact: true,
  });
  await confirmButton.press("Enter");

  await expect.poll(api.getDecisionRequest).toEqual({
    action: "reject",
    expectedVersion: 2,
    reason: "Другой модератор уже обработал жалобу",
  });
  await expect(
    page.getByRole("alert").filter({
      hasText:
        "Элемент уже обработан другим модератором. Очередь обновлена — проверьте актуальный статус.",
    })
  ).toBeVisible();
  await expect(reviewDialog).toBeHidden();
  await expect.poll(api.getPageQueueReadCount).toBeGreaterThan(readsBeforeConflict);
  await expect(page.getByText("В очереди ничего нет", { exact: true })).toBeVisible();
  await page.screenshot({
    path: testInfo.outputPath("moderation-conflict-toast.png"),
    fullPage: false,
  });
  expect(api.getModerationAuthorizationHeaders()).toContain("Bearer admin-access-token");
  expect(
    runtimeErrors.filter(
      (error) =>
        !error.includes(
          "Failed to load resource: the server responded with a status of 409 (Conflict)"
        )
    )
  ).toEqual([]);
  expect(runtimeErrors.some((error) => error.includes("409 (Conflict)"))).toBe(true);
});
