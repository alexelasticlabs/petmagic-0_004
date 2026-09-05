import { expect, test, type Page, type Route } from "@playwright/test";

import { captureFigmaState, installFigmaCaptureRouting } from "./figma-capture";

test.beforeEach(async ({ page }) => installFigmaCaptureRouting(page));

const apiOrigin = "https://api.petmagic.test";
const adminUserId = "11111111-1111-4111-8111-111111111111";
const missingTemplateId = "22222222-2222-4222-8222-222222222222";
const archivedTemplateId = "33333333-3333-4333-8333-333333333333";

function createSession(roles: string[]) {
  return {
    accessToken: "category-diagnostics-access-token",
    refreshToken: "category-diagnostics-refresh-token",
    expiresAtUtc: "2099-01-01T00:00:00Z",
    user: {
      userId: adminUserId,
      email: "catalog.admin@petmagic.test",
      displayName: "Catalog Admin",
      isPremium: false,
      emailConfirmed: true,
      roles,
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
    "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
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

function categoryList() {
  return [
    {
      categoryId: "44444444-4444-4444-8444-444444444444",
      name: "Portraits",
      isArchived: false,
      totalTemplates: 12,
      videoTemplates: 2,
      imageTemplates: 10,
      activeTemplates: 9,
      draftTemplates: 3,
      archivedTemplates: 0,
      premiumTemplates: 4,
      tags: ["portrait", "pet"],
      createdAtUtc: "2026-07-20T08:00:00Z",
      updatedAtUtc: "2026-07-26T08:00:00Z",
    },
  ];
}

function diagnosticsResponse() {
  return {
    totalActiveTemplates: 18,
    noncanonicalTemplates: 2,
    noncanonicalPercent: 11.11,
    generatedAtUtc: "2026-07-27T08:30:00Z",
    items: [
      {
        templateId: archivedTemplateId,
        issueKind: "archived_category",
        title: "Seasonal dance",
        category: "Seasonal",
        normalizedCategory: "SEASONAL",
        templateType: "Video",
        status: "Active",
        updatedAtUtc: "2026-07-26T10:00:00Z",
      },
      {
        templateId: missingTemplateId,
        issueKind: "missing_category",
        title: "Portrait authorization=secret-token",
        category: "Legacy portraits",
        normalizedCategory: "LEGACY PORTRAITS",
        templateType: "Image",
        status: "Active",
        updatedAtUtc: "2026-07-27T07:00:00Z",
      },
    ],
  };
}

async function installCategoryApiMocks(page: Page, roles: string[] = ["Admin"]) {
  const session = createSession(roles);
  let diagnosticsRequests = 0;

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

    if (url.pathname === "/api/admin/templates/categories/diagnostics") {
      diagnosticsRequests += 1;
      await fulfillJson(route, diagnosticsResponse());
      return;
    }

    if (url.pathname === "/api/admin/templates/categories/") {
      if (request.method() === "POST") {
        const body = request.postDataJSON() as { name: string };
        await fulfillJson(route, {
          ...categoryList()[0],
          categoryId: "55555555-5555-4555-8555-555555555555",
          name: body.name,
          totalTemplates: 0,
          videoTemplates: 0,
          imageTemplates: 0,
          activeTemplates: 0,
          draftTemplates: 0,
          premiumTemplates: 0,
          tags: [],
        });
        return;
      }

      await fulfillJson(route, categoryList());
      return;
    }

    await fulfillJson(route, {
      items: [],
      totalCount: 0,
      skip: 0,
      take: 25,
      hasMore: false,
      generatedAtUtc: "2026-07-27T08:30:00Z",
    });
  });

  return { getDiagnosticsRequests: () => diagnosticsRequests };
}

async function login(page: Page, email: string) {
  await page.goto("/ru");
  await page.locator("#login-email").fill(email);
  await page.locator("#login-password").fill("production-ready-password");
  await page.locator('form button[type="submit"]').click();
  await expect(page).toHaveURL(/\/ru\/(dashboard|support)$/);
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

test("Admin runs diagnostics manually and category CRUD only marks the result stale", async ({
  page,
}, testInfo) => {
  const api = await installCategoryApiMocks(page);
  await page.setViewportSize({ width: 1440, height: 960 });
  await login(page, "catalog.admin@petmagic.test");
  const runtimeErrors = collectRuntimeErrors(page);

  await page.goto("/ru/templates/categories");
  await expect(page.getByRole("heading", { name: "Категории шаблонов" })).toBeVisible();
  await expect(page.getByText("Проверка ещё не запускалась", { exact: true })).toBeVisible();
  expect(api.getDiagnosticsRequests()).toBe(0);

  await page.getByRole("button", { name: "Запустить проверку", exact: true }).click();
  await expect(page.getByText("Найдены несоответствия", { exact: true })).toBeVisible();
  const diagnosticsTable = page.locator("table").filter({ hasText: "Seasonal dance" });
  await expect(diagnosticsTable.getByText("Категория в архиве", { exact: true })).toBeVisible();
  await expect(diagnosticsTable.getByText("Категория отсутствует", { exact: true })).toBeVisible();
  await expect(page.getByText("secret-token", { exact: false })).toHaveCount(0);
  expect(api.getDiagnosticsRequests()).toBe(1);

  const diagnosticsSection = page
    .locator("section")
    .filter({ has: page.getByRole("heading", { name: "Целостность каталога", exact: true }) })
    .first();
  await diagnosticsSection.locator("select").selectOption("missing_category");
  await diagnosticsSection.locator('input[type="search"]').fill("portrait");
  await expect(page.getByText("Показано 1 из 2", { exact: true })).toBeVisible();
  await expect(page.getByText("Seasonal dance", { exact: true })).toHaveCount(0);
  await expect(page.getByRole("link", { name: "Открыть редактор", exact: true })).toHaveAttribute(
    "href",
    `/ru/templates/image/editor?templateId=${missingTemplateId}`
  );

  await page.getByPlaceholder("Например, портреты питомцев").fill("Fresh category");
  await page.getByRole("button", { name: "Добавить категорию", exact: true }).click();
  await expect(page.getByText("Результат мог устареть", { exact: true })).toBeVisible();
  expect(api.getDiagnosticsRequests()).toBe(1);

  await captureFigmaState(page, "templates-categories-current");
  await page.screenshot({
    path: testInfo.outputPath("category-diagnostics-desktop.png"),
    fullPage: true,
  });
  expect(runtimeErrors).toEqual([]);
});

test("category diagnostics use mobile cards without horizontal overflow", async ({
  page,
}, testInfo) => {
  await installCategoryApiMocks(page);
  await page.setViewportSize({ width: 390, height: 844 });
  await login(page, "catalog.mobile@petmagic.test");
  const runtimeErrors = collectRuntimeErrors(page);

  await page.goto("/ru/templates/categories");
  await page.getByRole("button", { name: "Запустить проверку", exact: true }).click();
  await expect(page.getByText("Найдены несоответствия", { exact: true })).toBeVisible();
  await expect(page.locator("ul").filter({ hasText: "Seasonal dance" })).toBeVisible();

  const dimensions = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
    viewportWidth: window.innerWidth,
  }));
  expect(dimensions.scrollWidth).toBeLessThanOrEqual(dimensions.clientWidth);
  expect(dimensions.clientWidth).toBe(dimensions.viewportWidth);

  await page.screenshot({
    path: testInfo.outputPath("category-diagnostics-mobile-390.png"),
    fullPage: true,
  });
  expect(runtimeErrors).toEqual([]);
});

test("Moderator never requests Admin-only category diagnostics", async ({ page }) => {
  const api = await installCategoryApiMocks(page, ["Moderator"]);
  await login(page, "catalog.moderator@petmagic.test");

  await page.goto("/ru/templates/categories");
  await expect(page.getByRole("heading", { name: "Категории шаблонов" })).toBeVisible();
  await expect(page.getByText("Целостность каталога", { exact: true })).toHaveCount(0);
  expect(api.getDiagnosticsRequests()).toBe(0);
});
