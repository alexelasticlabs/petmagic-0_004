import { expect, test, type Page, type Route } from "@playwright/test";

import { captureFigmaState, installFigmaCaptureRouting } from "./figma-capture";

test.beforeEach(async ({ page }) => installFigmaCaptureRouting(page));

const apiOrigin = "https://api.petmagic.test";
const adminUserId = "11111111-1111-1111-1111-111111111111";
const imageTemplateId = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
const videoTemplateId = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb";
const existingAssignmentId = "cccccccc-cccc-cccc-cccc-cccccccccccc";
const createdAssignmentId = "dddddddd-dddd-dddd-dddd-dddddddddddd";
const autoPickAssignmentId = "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee";

type AssignmentPayload = {
  templateId: string;
  startDate: string;
  endDate?: string | null;
  isActive: boolean;
  isManual: boolean;
  priority: number;
  titleOverride?: string | null;
  subtitleOverride?: string | null;
  badgeTextOverride?: string | null;
};

type Assignment = AssignmentPayload & {
  id: string;
  templateTitle: string;
  templateType: "Image" | "Video";
  category: string;
  status: "Active";
  isPremium: boolean;
  previewAsset: null;
  createdAtUtc: string;
  updatedAtUtc: string;
  createdByAdminId: string;
};

type DailyFeaturedSettings = {
  autoModeEnabled: boolean;
  allowedTypes: "both" | "image" | "video";
  excludeRecentDays: number;
  businessDate?: string;
  updatedAtUtc: string;
  updatedByAdminId: string;
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

async function login(page: Page) {
  await page.goto("/en");
  await page.locator("#login-email").fill("admin@petmagic.test");
  await page.locator("#login-password").fill("production-ready-password");
  await page.locator('form button[type="submit"]').click();
  await expect(page).toHaveURL(/\/en\/dashboard$/);
}

function createAssignment(
  id: string,
  payload: AssignmentPayload,
  template: { title: string; templateType: "Image" | "Video"; category: string; isPremium: boolean }
): Assignment {
  return {
    id,
    templateId: payload.templateId,
    templateTitle: template.title,
    templateType: template.templateType,
    category: template.category,
    status: "Active",
    isPremium: template.isPremium,
    previewAsset: null,
    startDate: payload.startDate,
    endDate: payload.endDate ?? null,
    isActive: payload.isActive,
    isManual: payload.isManual,
    priority: payload.priority,
    titleOverride: payload.titleOverride ?? null,
    subtitleOverride: payload.subtitleOverride ?? null,
    badgeTextOverride: payload.badgeTextOverride ?? null,
    createdAtUtc: "2026-07-26T09:00:00Z",
    updatedAtUtc: "2026-07-26T09:00:00Z",
    createdByAdminId: adminUserId,
  };
}

async function installDailyFeaturedApiMocks(
  page: Page,
  options: { failFirstSettingsGet?: boolean } = {}
) {
  const session = createAdminSession();
  const templates = [
    {
      templateId: imageTemplateId,
      templateType: "Image" as const,
      title: "Golden Hour Portrait",
      shortDescription: "A warm editorial pet portrait.",
      category: "Portrait",
      status: "Active" as const,
      promoBadgeMode: "Auto" as const,
      isPremium: false,
      isQaOnly: false,
      tokenCost: 12,
      tags: ["portrait", "warm"],
      createdAtUtc: "2026-07-20T10:00:00Z",
      updatedAtUtc: "2026-07-20T10:00:00Z",
    },
    {
      templateId: videoTemplateId,
      templateType: "Video" as const,
      title: "Rainy Day Motion",
      shortDescription: "A quiet cinematic motion loop.",
      category: "Motion",
      status: "Active" as const,
      promoBadgeMode: "Auto" as const,
      isPremium: true,
      isQaOnly: false,
      tokenCost: 20,
      tags: ["motion", "rain"],
      createdAtUtc: "2026-07-21T10:00:00Z",
      updatedAtUtc: "2026-07-21T10:00:00Z",
    },
  ];
  const templatesById = new Map(templates.map((template) => [template.templateId, template]));
  let settings: DailyFeaturedSettings = {
    autoModeEnabled: true,
    allowedTypes: "both",
    excludeRecentDays: 7,
    businessDate: "2030-02-15",
    updatedAtUtc: "2026-07-26T09:00:00Z",
    updatedByAdminId: adminUserId,
  };
  let schedule: Assignment[] = [
    createAssignment(
      existingAssignmentId,
      {
        templateId: videoTemplateId,
        startDate: "2030-01-10",
        endDate: "2030-01-10",
        isActive: true,
        isManual: true,
        priority: 2,
        titleOverride: null,
        subtitleOverride: null,
        badgeTextOverride: null,
      },
      templatesById.get(videoTemplateId)!
    ),
  ];
  const templateQueries: URL[] = [];
  let settingsGetRequestCount = 0;
  let settingsRequest: unknown = null;
  let createRequest: unknown = null;
  let autoPickRequest: unknown = null;
  const updateRequests: Array<{ id: string; payload: unknown }> = [];
  const deleteRequests: string[] = [];

  await page.route(`${apiOrigin}/api/**`, async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    const method = request.method();

    if (url.pathname === "/api/auth/login" || url.pathname === "/api/auth/refresh") {
      await fulfillJson(route, session);
      return;
    }

    if (url.pathname === "/api/auth/logout") {
      await fulfillJson(route, {});
      return;
    }

    if (
      (url.pathname === "/api/admin/templates" || url.pathname === "/api/admin/templates/") &&
      method === "GET"
    ) {
      templateQueries.push(url);
      await fulfillJson(route, {
        items: templates,
        skip: Number(url.searchParams.get("skip") ?? "0"),
        take: Number(url.searchParams.get("take") ?? "30"),
        totalCount: templates.length,
        hasMore: false,
      });
      return;
    }

    if (url.pathname === "/api/admin/template-of-the-day/schedule" && method === "GET") {
      const skip = Number(url.searchParams.get("skip") ?? "0");
      const take = Number(url.searchParams.get("take") ?? "30");
      await fulfillJson(route, {
        items: schedule.slice(skip, skip + take),
        skip,
        take,
        totalCount: schedule.length,
        hasMore: skip + take < schedule.length,
        generatedAtUtc: "2026-07-26T09:00:00Z",
      });
      return;
    }

    if (url.pathname === "/api/admin/template-of-the-day/current" && method === "GET") {
      await fulfillJson(route, null);
      return;
    }

    if (url.pathname === "/api/admin/template-of-the-day/settings" && method === "GET") {
      settingsGetRequestCount += 1;
      if (options.failFirstSettingsGet && settingsGetRequestCount === 1) {
        await fulfillJson(route, { code: "settings.unavailable" }, 503);
        return;
      }

      await fulfillJson(route, settings);
      return;
    }

    if (url.pathname === "/api/admin/template-of-the-day/settings" && method === "PUT") {
      settingsRequest = request.postDataJSON();
      const payload = settingsRequest as {
        autoModeEnabled: boolean;
        allowedTypes: "both" | "image" | "video";
        excludeRecentDays: number;
      };
      settings = {
        ...settings,
        ...payload,
        updatedAtUtc: "2026-07-26T09:01:00Z",
      };
      await fulfillJson(route, settings);
      return;
    }

    if (url.pathname === "/api/admin/template-of-the-day/auto-pick" && method === "POST") {
      autoPickRequest = request.postDataJSON();
      const payload = autoPickRequest as {
        date: string;
        allowedTypes: "both" | "image" | "video";
        excludeRecentDays: number;
      };
      const assignment = createAssignment(
        autoPickAssignmentId,
        {
          templateId: videoTemplateId,
          startDate: payload.date,
          endDate: null,
          isActive: true,
          isManual: false,
          priority: 0,
          titleOverride: null,
          subtitleOverride: null,
          badgeTextOverride: null,
        },
        templatesById.get(videoTemplateId)!
      );
      schedule = [...schedule.filter((item) => item.id !== autoPickAssignmentId), assignment];
      await fulfillJson(route, assignment);
      return;
    }

    if (url.pathname === "/api/admin/template-of-the-day" && method === "POST") {
      createRequest = request.postDataJSON();
      const payload = createRequest as AssignmentPayload;
      const template = templatesById.get(payload.templateId);
      if (!template) {
        await fulfillJson(route, { code: "template.not_found" }, 404);
        return;
      }

      const assignment = createAssignment(createdAssignmentId, payload, template);
      schedule = [...schedule, assignment];
      await fulfillJson(route, assignment, 201);
      return;
    }

    const assignmentId = url.pathname.replace("/api/admin/template-of-the-day/", "");
    if (assignmentId !== url.pathname && assignmentId.length > 0 && method === "PUT") {
      const payload = request.postDataJSON() as AssignmentPayload;
      updateRequests.push({ id: assignmentId, payload });
      const template = templatesById.get(payload.templateId);
      const existing = schedule.find((item) => item.id === assignmentId);
      if (!template || !existing) {
        await fulfillJson(route, { code: "template_of_the_day.not_found" }, 404);
        return;
      }

      const updated = createAssignment(assignmentId, payload, template);
      schedule = schedule.map((item) => (item.id === assignmentId ? updated : item));
      await fulfillJson(route, updated);
      return;
    }

    if (assignmentId !== url.pathname && assignmentId.length > 0 && method === "DELETE") {
      deleteRequests.push(assignmentId);
      schedule = schedule.filter((item) => item.id !== assignmentId);
      await route.fulfill({ status: 204 });
      return;
    }

    await fulfillJson(route, {
      items: [],
      totalCount: 0,
      skip: 0,
      take: 25,
      hasMore: false,
      generatedAtUtc: "2026-07-26T09:00:00Z",
    });
  });

  return {
    deleteRequests,
    getCreateRequest: () => createRequest,
    getSettingsGetRequestCount: () => settingsGetRequestCount,
    getSettingsRequest: () => settingsRequest,
    getAutoPickRequest: () => autoPickRequest,
    getTemplateQueries: () => templateQueries,
    getUpdateRequests: () => updateRequests,
  };
}

test("daily featured supports settings, manual schedule, auto-pick, edit and delete without runtime errors", async ({
  page,
}, testInfo) => {
  const api = await installDailyFeaturedApiMocks(page);
  const runtimeErrors: string[] = [];
  const apiRequestOrigins = new Set<string>();

  await page.setViewportSize({ width: 1440, height: 1000 });
  await login(page);

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

  await page.goto("/en/templates/daily-featured");
  await expect(
    page.getByRole("banner").getByRole("heading", { name: "Daily Featured", exact: true })
  ).toBeVisible();
  const scheduleTable = page.getByRole("table");
  await expect(scheduleTable).toHaveCount(1);
  await expect.poll(() => api.getTemplateQueries().length).toBeGreaterThan(0);
  expect(
    api
      .getTemplateQueries()
      .some(
        (query) =>
          query.searchParams.get("status") === "Active" && query.searchParams.get("take") === "30"
      )
  ).toBe(true);

  const assignmentForm = page.locator('form[aria-busy="false"]');
  await expect(assignmentForm).toHaveCount(1);
  await expect(page.getByRole("combobox", { name: "Template", exact: true })).toBeEnabled();

  const desktopDimensions = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));
  expect(desktopDimensions.scrollWidth).toBeLessThanOrEqual(desktopDimensions.clientWidth);
  await captureFigmaState(page, "templates-daily-current");
  await page.screenshot({
    path: testInfo.outputPath("daily-featured-desktop.png"),
    fullPage: true,
  });

  await page.getByRole("combobox", { name: "Allowed types", exact: true }).selectOption("video");
  await page.getByRole("spinbutton", { name: "Exclude recent days", exact: true }).fill("12");
  await page.getByRole("button", { name: "Save settings", exact: true }).click();
  await expect.poll(api.getSettingsRequest).toEqual({
    autoModeEnabled: true,
    allowedTypes: "video",
    excludeRecentDays: 12,
  });
  await expect(page.getByRole("button", { name: "Run auto-pick", exact: true })).toBeEnabled();

  await page.getByRole("combobox", { name: "Template", exact: true }).selectOption(imageTemplateId);
  await page.getByRole("textbox", { name: "Start date", exact: true }).fill("2030-02-15");
  await page.getByRole("textbox", { name: "End date", exact: true }).fill("2030-02-16");
  await page.getByRole("spinbutton", { name: "Priority", exact: true }).fill("7");
  await page
    .getByRole("textbox", { name: "Storefront title", exact: true })
    .fill("Golden studio pick");
  await page
    .getByRole("textbox", { name: "Storefront subtitle", exact: true })
    .fill("A bright hand-picked portrait.");
  await page.getByRole("textbox", { name: "Badge text", exact: true }).fill("Editor's choice");
  await expect(
    page.getByRole("heading", { name: "Golden studio pick", exact: true })
  ).toBeVisible();
  await page.getByRole("button", { name: "Create", exact: true }).click();
  await expect.poll(api.getCreateRequest).toEqual({
    templateId: imageTemplateId,
    startDate: "2030-02-15",
    endDate: "2030-02-16",
    isActive: true,
    isManual: true,
    priority: 7,
    titleOverride: "Golden studio pick",
    subtitleOverride: "A bright hand-picked portrait.",
    badgeTextOverride: "Editor's choice",
  });
  await expect(scheduleTable.getByText("Golden Hour Portrait", { exact: true })).toBeVisible();
  await expect(page.getByText("Total: 2", { exact: true })).toBeVisible();

  await page.getByRole("textbox", { name: "Auto-pick date", exact: true }).fill("2030-03-01");
  await page.getByRole("button", { name: "Run auto-pick", exact: true }).click();
  const autoPickDialog = page.getByRole("dialog", { name: "Run auto-pick?", exact: true });
  await expect(autoPickDialog).toBeVisible();
  await expect(autoPickDialog).toContainText("2030-03-01");
  await captureFigmaState(page, "templates-daily-autopick-dialog");
  await autoPickDialog.getByRole("button", { name: "Run auto-pick", exact: true }).click();
  await expect.poll(api.getAutoPickRequest).toEqual({
    date: "2030-03-01",
    allowedTypes: "video",
    excludeRecentDays: 12,
  });
  await expect(scheduleTable.getByText("Rainy Day Motion", { exact: true })).toHaveCount(2);
  await expect(page.getByText("Total: 3", { exact: true })).toBeVisible();

  await page
    .getByRole("button", { name: "Edit Golden Hour Portrait assignment", exact: true })
    .click();
  await expect(page.getByRole("button", { name: "Save", exact: true })).toBeVisible();
  await page.getByRole("spinbutton", { name: "Priority", exact: true }).fill("9");
  await page
    .getByRole("textbox", { name: "Storefront title", exact: true })
    .fill("Updated studio pick");
  await page.getByRole("button", { name: "Save", exact: true }).click();
  await expect
    .poll(() => api.getUpdateRequests())
    .toEqual([
      {
        id: createdAssignmentId,
        payload: {
          templateId: imageTemplateId,
          startDate: "2030-02-15",
          endDate: "2030-02-16",
          isActive: true,
          isManual: true,
          priority: 9,
          titleOverride: "Updated studio pick",
          subtitleOverride: "A bright hand-picked portrait.",
          badgeTextOverride: "Editor's choice",
        },
      },
    ]);
  await expect(
    page.getByText('Assignment for "Golden Hour Portrait" was updated.', { exact: true })
  ).toBeVisible();

  await page
    .getByRole("button", { name: "Delete Golden Hour Portrait assignment", exact: true })
    .click();
  const deleteDialog = page.getByRole("dialog", { name: "Delete assignment?", exact: true });
  await expect(deleteDialog).toBeVisible();
  await deleteDialog.getByRole("button", { name: "Delete", exact: true }).click();
  await expect.poll(() => api.deleteRequests).toEqual([createdAssignmentId]);
  await expect(
    page.getByRole("button", { name: "Delete Golden Hour Portrait assignment", exact: true })
  ).toHaveCount(0);
  await expect(page.getByText("Total: 2", { exact: true })).toBeVisible();

  await page.setViewportSize({ width: 390, height: 844 });
  // The admin shell turns the desktop sidebar into a drawer with a 220ms exit transition.
  // Wait for the settled mobile layout so the visual artifact represents the usable screen.
  await page.waitForTimeout(260);
  await page.evaluate(() => window.scrollTo(0, 0));
  await expect(
    page.getByRole("banner").getByRole("heading", { name: "Daily Featured", exact: true })
  ).toBeVisible();
  const mobileDimensions = await page.evaluate(() => {
    const form = document.querySelector<HTMLFormElement>("form[aria-busy]");
    if (!form) {
      throw new Error("Daily featured assignment form is missing.");
    }

    const sidebar = document.querySelector<HTMLElement>("#admin-sidebar");
    if (!sidebar) {
      throw new Error("Admin sidebar is missing.");
    }

    return {
      clientWidth: document.documentElement.clientWidth,
      formClientWidth: form.clientWidth,
      formScrollWidth: form.scrollWidth,
      scrollWidth: document.documentElement.scrollWidth,
      sidebarRight: sidebar.getBoundingClientRect().right,
      visibleScheduleActionCount: Array.from(
        document.querySelectorAll<HTMLButtonElement>("table tbody button")
      ).filter((button) => {
        const bounds = button.getBoundingClientRect();
        return (
          bounds.width > 0 &&
          bounds.height > 0 &&
          bounds.left >= 0 &&
          bounds.right <= window.innerWidth
        );
      }).length,
    };
  });
  expect(mobileDimensions.scrollWidth).toBeLessThanOrEqual(mobileDimensions.clientWidth);
  expect(mobileDimensions.formScrollWidth).toBeLessThanOrEqual(mobileDimensions.formClientWidth);
  expect(mobileDimensions.sidebarRight).toBeLessThanOrEqual(0);
  expect(mobileDimensions.visibleScheduleActionCount).toBeGreaterThanOrEqual(2);
  await page.screenshot({
    path: testInfo.outputPath("daily-featured-mobile.png"),
    fullPage: true,
  });

  expect([...apiRequestOrigins]).toEqual([apiOrigin]);
  expect(runtimeErrors).toEqual([]);
});

test("daily featured blocks auto-pick controls until settings are successfully retried", async ({
  page,
}) => {
  const api = await installDailyFeaturedApiMocks(page, { failFirstSettingsGet: true });

  await page.setViewportSize({ width: 1440, height: 900 });
  await login(page);
  await page.goto("/en/templates/daily-featured");

  const autoPickCard = page
    .getByRole("heading", { name: "Auto-pick", exact: true })
    .locator("xpath=ancestor::section[1]");
  await expect(
    autoPickCard.getByText(
      "Auto-mode settings could not be safely loaded. Retry before changing or running auto-pick.",
      { exact: true }
    )
  ).toBeVisible();
  await expect(autoPickCard.getByRole("button", { name: "Retry", exact: true })).toBeEnabled();
  await expect(
    autoPickCard.getByRole("button", { name: "Save settings", exact: true })
  ).toHaveCount(0);
  await expect(
    autoPickCard.getByRole("button", { name: "Run auto-pick", exact: true })
  ).toHaveCount(0);

  await autoPickCard.getByRole("button", { name: "Retry", exact: true }).click();
  await expect.poll(api.getSettingsGetRequestCount).toBeGreaterThanOrEqual(2);
  await expect(
    autoPickCard.getByRole("checkbox", { name: "Auto mode", exact: true })
  ).toBeEnabled();
  await expect(
    autoPickCard.getByRole("button", { name: "Run auto-pick", exact: true })
  ).toBeEnabled();
});
