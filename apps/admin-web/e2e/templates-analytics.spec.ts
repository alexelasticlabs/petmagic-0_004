import { expect, test, type Page, type Route } from "@playwright/test";

import { captureFigmaState, installFigmaCaptureRouting } from "./figma-capture";

test.beforeEach(async ({ page }) => installFigmaCaptureRouting(page));

const apiOrigin = "https://api.petmagic.test";
const adminUserId = "11111111-1111-1111-1111-111111111111";
const firstTemplateId = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
const secondTemplateId = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb";
const analyticsTemplateCount = 401;

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

function createAnalyticsOverview(skip: number, take: number) {
  const firstTemplate = {
    templateId: firstTemplateId,
    templateType: "Image",
    title: "QA Pet Portrait",
    category: "QA",
    status: "Active",
    isPremium: false,
    tokenCost: 12,
    views: 70,
    generationStarts: 28,
    completedGenerations: 21,
    failedGenerations: 2,
    conversionPercent: 75,
    totalTokenCost: 336,
    totalProviderCostUsd: 4.2,
    updatedAtUtc: "2026-07-24T12:00:00Z",
  };
  const secondTemplate = {
    templateId: secondTemplateId,
    templateType: "Video",
    title: "QA Pet Adventure",
    category: "QA",
    status: "Active",
    isPremium: true,
    tokenCost: 24,
    views: 44,
    generationStarts: 18,
    completedGenerations: 12,
    failedGenerations: 3,
    conversionPercent: 66.7,
    totalTokenCost: 432,
    totalProviderCostUsd: 6.5,
    updatedAtUtc: "2026-07-25T12:00:00Z",
  };
  const visibleTemplateCount = Math.min(take, Math.max(0, analyticsTemplateCount - skip));
  const templates = Array.from({ length: visibleTemplateCount }, (_, index) => {
    if (index === 0 && skip === 0) {
      return firstTemplate;
    }

    if (index === 0 && skip === 50) {
      return secondTemplate;
    }

    const ordinal = skip + index + 1;
    return {
      ...firstTemplate,
      templateId: `cccccccc-cccc-cccc-cccc-${String(ordinal).padStart(12, "0")}`,
      title: `QA Template ${ordinal}`,
      views: Math.max(1, firstTemplate.views - ordinal),
      generationStarts: Math.max(1, firstTemplate.generationStarts - (ordinal % 12)),
      totalTokenCost: Math.max(12, firstTemplate.totalTokenCost - ordinal * 2),
    };
  });

  return {
    summary: {
      totalTemplates: analyticsTemplateCount,
      videoTemplates: 121,
      imageTemplates: 280,
      activeTemplates: 398,
      premiumTemplates: 119,
      totalViews: 114,
      totalGenerationStarts: 46,
      completedGenerations: 33,
      failedGenerations: 5,
      conversionPercent: 71.7,
      totalTokenCost: 768,
      averageTokenCost: 16.7,
      totalProviderCostUsd: 10.7,
      totalComplaints: 1,
    },
    trendPoints: [
      {
        dateUtc: "2026-07-20T00:00:00Z",
        totalViews: 21,
        totalGenerationStarts: 8,
        completedGenerations: 6,
        failedGenerations: 1,
        totalTokenCost: 96,
        totalProviderCostUsd: 1.3,
      },
      {
        dateUtc: "2026-07-21T00:00:00Z",
        totalViews: 37,
        totalGenerationStarts: 14,
        completedGenerations: 11,
        failedGenerations: 1,
        totalTokenCost: 228,
        totalProviderCostUsd: 3.4,
      },
      {
        dateUtc: "2026-07-22T00:00:00Z",
        totalViews: 56,
        totalGenerationStarts: 24,
        completedGenerations: 16,
        failedGenerations: 3,
        totalTokenCost: 444,
        totalProviderCostUsd: 6,
      },
    ],
    topTemplates: [firstTemplate, secondTemplate],
    categories: [
      {
        key: "qa",
        label: "QA",
        templateCount: analyticsTemplateCount,
        views: 114,
        generationStarts: 46,
        completedGenerations: 33,
        conversionPercent: 71.7,
        totalTokenCost: 768,
        totalProviderCostUsd: 10.7,
      },
    ],
    templateTypes: [
      {
        key: "image",
        label: "Image",
        templateCount: 280,
        views: 70,
        generationStarts: 28,
        completedGenerations: 21,
        conversionPercent: 75,
        totalTokenCost: 336,
        totalProviderCostUsd: 4.2,
      },
      {
        key: "video",
        label: "Video",
        templateCount: 121,
        views: 44,
        generationStarts: 18,
        completedGenerations: 12,
        conversionPercent: 66.7,
        totalTokenCost: 432,
        totalProviderCostUsd: 6.5,
      },
    ],
    sources: [{ key: "direct", label: "Direct", count: 114, sharePercent: 100 }],
    devices: [{ key: "web", label: "Web", count: 114, sharePercent: 100 }],
    geography: [{ key: "by", label: "BY", count: 114, sharePercent: 100 }],
    feedbackItems: [],
    conversionFunnel: {
      views: 114,
      generationStarts: 46,
      completedGenerations: 33,
      failedGenerations: 5,
      complaints: 1,
    },
    templates,
    skip,
    take,
    totalCount: analyticsTemplateCount,
    hasMore: skip + templates.length < analyticsTemplateCount,
    availableCategories: ["QA"],
    generatedAtUtc: "2026-07-26T12:00:00Z",
  };
}

async function installAnalyticsApiMocks(page: Page, analyticsRequests: URL[]) {
  const session = createAdminSession();

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

    if (url.pathname === "/api/admin/templates/analytics") {
      analyticsRequests.push(url);
      const skip = Number.parseInt(url.searchParams.get("skip") ?? "0", 10) || 0;
      const take = Number.parseInt(url.searchParams.get("take") ?? "50", 10) || 50;
      await fulfillJson(route, createAnalyticsOverview(skip, take));
      return;
    }

    await fulfillJson(route, {
      items: [],
      totalCount: 0,
      skip: 0,
      take: 25,
      hasMore: false,
      generatedAtUtc: "2026-07-26T12:00:00Z",
    });
  });
}

async function loginAsAdmin(page: Page) {
  await page.goto("/ru");
  await page.locator("#login-email").fill("admin@petmagic.test");
  await page.locator("#login-password").fill("production-ready-password");
  await page.locator('form button[type="submit"]').click();
  await expect(page).toHaveURL(/\/ru\/dashboard$/);
}

function hasAnalyticsQuery(
  requests: readonly URL[],
  expected: { periodDays?: string; sort?: string; skip?: string; take?: string }
) {
  return requests.some((url) => {
    const params = url.searchParams;
    return (
      (!expected.periodDays || params.get("periodDays") === expected.periodDays) &&
      (!expected.sort || params.get("sort") === expected.sort) &&
      (!expected.skip || params.get("skip") === expected.skip) &&
      params.get("take") === (expected.take ?? "50")
    );
  });
}

test("admin operates template analytics hub filters, pagination, links and export", async ({
  page,
}) => {
  await page.setViewportSize({ width: 1440, height: 1000 });
  const analyticsRequests: URL[] = [];
  const pageErrors: string[] = [];
  const consoleErrors: string[] = [];
  page.on("pageerror", (error) => pageErrors.push(error.message));
  page.on("console", (message) => {
    if (message.type() === "error") {
      consoleErrors.push(message.text());
    }
  });

  await installAnalyticsApiMocks(page, analyticsRequests);
  await loginAsAdmin(page);
  await page.goto("/ru/templates/analytics");

  await expect(page).toHaveURL(/\/ru\/templates\/analytics$/);
  await expect(
    page.getByRole("banner").getByRole("heading", { name: "Аналитика шаблонов", exact: true })
  ).toBeVisible();
  await expect(page.getByRole("img", { name: "Динамика по времени", exact: true })).toBeVisible();
  await expect(page.locator("nextjs-portal")).toHaveCount(0);
  await expect(page.getByText("Unhandled Runtime Error", { exact: false })).toHaveCount(0);
  await expect(page.getByText("Application error", { exact: false })).toHaveCount(0);
  await expect
    .poll(() => hasAnalyticsQuery(analyticsRequests, { periodDays: "30", sort: "views" }))
    .toBe(true);

  await captureFigmaState(page, "templates-analytics-current");

  const topTemplates = page
    .locator("section")
    .filter({ has: page.getByRole("heading", { name: "Топ шаблонов", exact: true }) });
  const templatesTable = page
    .locator("section")
    .filter({ has: page.getByRole("heading", { name: "Все шаблоны", exact: true }) });
  const analyticsTable = templatesTable.getByRole("table");
  const expectedAnalyticsHref = `/ru/templates/image/analytics/${firstTemplateId}`;
  await expect(topTemplates.getByRole("link", { name: /QA Pet Portrait/ })).toHaveAttribute(
    "href",
    expectedAnalyticsHref
  );
  await expect(analyticsTable.locator(`a[href="${expectedAnalyticsHref}"]`)).toBeVisible();

  await page.getByRole("button", { name: "7 дней", exact: true }).click();
  await expect
    .poll(() => hasAnalyticsQuery(analyticsRequests, { periodDays: "7", sort: "views" }))
    .toBe(true);

  const sortSelect = page.getByRole("combobox", { name: "Сортировка", exact: true });
  await expect(sortSelect).toBeEnabled();
  await sortSelect.selectOption("tokens");
  await expect
    .poll(() => hasAnalyticsQuery(analyticsRequests, { periodDays: "7", sort: "tokens" }))
    .toBe(true);

  const nextPage = page.getByRole("button", { name: "Далее", exact: true });
  await expect(nextPage).toBeEnabled();
  await nextPage.click();
  await expect
    .poll(() =>
      hasAnalyticsQuery(analyticsRequests, { periodDays: "7", sort: "tokens", skip: "50" })
    )
    .toBe(true);
  await expect(analyticsTable.getByText("QA Pet Adventure", { exact: true })).toBeVisible();

  const analyticsRequestCountBeforeExport = analyticsRequests.length;
  const downloadPromise = page.waitForEvent("download");
  await page.getByRole("button", { name: "Экспорт", exact: true }).click();
  const download = await downloadPromise;
  expect(download.suggestedFilename()).toMatch(/^templates-analytics-\d{4}-\d{2}-\d{2}\.json$/);
  expect(await download.failure()).toBeNull();
  await expect
    .poll(() =>
      analyticsRequests.slice(analyticsRequestCountBeforeExport).map((url) => ({
        periodDays: url.searchParams.get("periodDays"),
        sort: url.searchParams.get("sort"),
        skip: url.searchParams.get("skip"),
        take: url.searchParams.get("take"),
      }))
    )
    .toEqual([
      { periodDays: "7", sort: "tokens", skip: "0", take: "200" },
      { periodDays: "7", sort: "tokens", skip: "200", take: "200" },
      { periodDays: "7", sort: "tokens", skip: "400", take: "200" },
    ]);

  expect(pageErrors).toEqual([]);
  expect(consoleErrors).toEqual([]);
});
