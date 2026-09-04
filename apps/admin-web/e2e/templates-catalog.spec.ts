import { expect, test, type Page, type Route } from "@playwright/test";

import {
  expectBoxContains,
  expectBoxesNotToIntersect,
  expectBoxInsideViewportHorizontally,
  expectNoHorizontalDocumentOverflow,
  expectNoHorizontalElementOverflow,
  expectNonZeroBoundingBox,
  expectVisibleColumnCount,
} from "./ui-layout/layout-assertions";
import type { AdminTemplateGenerationControl } from "../src/lib/api-client.types";

const apiOrigin = "https://api.petmagic.test";
const adminAccessToken = "admin-access-token";
const adminUserId = "11111111-1111-1111-1111-111111111111";
const readyTemplateId = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
const missingPreviewTemplateId = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb";
const qaOnlyTemplateId = "cccccccc-cccc-cccc-cccc-cccccccccccc";
const unavailablePreviewUrl = "https://cdn.example.com/templates/qa-neon-preview.png";
const previewDataUrl =
  "data:image/svg+xml;charset=utf-8," +
  encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 640 360"><rect width="640" height="360" fill="#7c3aed"/><circle cx="320" cy="180" r="92" fill="#f5d0fe"/></svg>'
  );

const catalogSummary = {
  totalTemplates: 3,
  imageTemplates: 2,
  videoTemplates: 1,
  activeTemplates: 2,
  draftTemplates: 1,
  archivedTemplates: 0,
  premiumTemplates: 1,
  qaOnlyTemplates: 1,
  missingPreviewTemplates: 1,
};

const shellGenerationControlSnapshot: AdminTemplateGenerationControl = {
  revision: 1,
  admissionEnabled: true,
  confirmedFalConcurrencyLimit: 6,
  confirmedAtUtc: "2026-07-28T10:00:00Z",
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
    checkedAtUtc: "2026-07-28T10:01:00Z",
    lastSuccessfulAtUtc: "2026-07-28T10:01:00Z",
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
    heartbeatAtUtc: "2026-07-28T10:01:00Z",
    lastProgressAtUtc: "2026-07-28T10:01:00Z",
    appliedPolicyRevision: 1,
    schedulerV2Enabled: true,
    dispatchConcurrency: 4,
    reconciliationConcurrency: 1,
    mediaImportConcurrency: 1,
    maintenanceConcurrency: 1,
  },
  alerts: [],
  generatedAtUtc: "2026-07-28T10:01:00Z",
};

type CatalogTemplate = {
  templateId: string;
  templateType: "Image" | "Video";
  title: string;
  shortDescription: string;
  category: string;
  status: "Active" | "Draft" | "Archived";
  promoBadgeMode: "Auto";
  isPremium: boolean;
  isQaOnly: boolean;
  tokenCost: number;
  tags: string[];
  previewAsset?: {
    url: string;
    fileName: string;
    contentType: string;
    fileSizeBytes: number;
  };
  createdAtUtc: string;
  updatedAtUtc: string;
};

const catalogTemplates: CatalogTemplate[] = [
  {
    templateId: readyTemplateId,
    templateType: "Image",
    title: "Golden Studio Portrait",
    shortDescription: "Готовый публичный шаблон портрета питомца.",
    category: "Portrait",
    status: "Active",
    promoBadgeMode: "Auto",
    isPremium: false,
    isQaOnly: false,
    tokenCost: 12,
    tags: ["portrait", "ready"],
    previewAsset: {
      url: previewDataUrl,
      fileName: "golden-studio-preview.svg",
      contentType: "image/svg+xml",
      fileSizeBytes: 512,
    },
    createdAtUtc: "2026-07-20T10:00:00Z",
    updatedAtUtc: "2026-07-25T12:00:00Z",
  },
  {
    templateId: missingPreviewTemplateId,
    templateType: "Video",
    title: "Preview Needed Motion",
    shortDescription: "Черновик видео, который нельзя публиковать без превью.",
    category: "Motion",
    status: "Draft",
    promoBadgeMode: "Auto",
    isPremium: true,
    isQaOnly: false,
    tokenCost: 24,
    tags: ["motion", "draft"],
    createdAtUtc: "2026-07-21T10:00:00Z",
    updatedAtUtc: "2026-07-24T12:00:00Z",
  },
  {
    templateId: qaOnlyTemplateId,
    templateType: "Image",
    title: "QA Neon Portrait",
    shortDescription: "Готовый шаблон для внутренней проверки перед публикацией.",
    category: "QA",
    status: "Active",
    promoBadgeMode: "Auto",
    isPremium: false,
    isQaOnly: true,
    tokenCost: 16,
    tags: ["qa", "neon"],
    previewAsset: {
      url: unavailablePreviewUrl,
      fileName: "qa-neon-preview.svg",
      contentType: "image/svg+xml",
      fileSizeBytes: 512,
    },
    createdAtUtc: "2026-07-22T10:00:00Z",
    updatedAtUtc: "2026-07-26T12:00:00Z",
  },
];

type CatalogApiState = {
  catalogRequests: URL[];
  contractViolations: string[];
  unexpectedRequests: string[];
};

function createAdminSession() {
  return {
    accessToken: adminAccessToken,
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
  const requestOrigin = route.request().headers().origin;
  return {
    "Access-Control-Allow-Origin": requestOrigin ?? "http://127.0.0.1",
    "Access-Control-Allow-Credentials": "true",
    "Access-Control-Allow-Headers": "Authorization, Content-Type",
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

async function fulfillPreflight(route: Route) {
  await route.fulfill({ status: 204, headers: corsHeaders(route) });
}

async function installStrictAuthMocks(page: Page, violations: string[]) {
  const session = createAdminSession();

  await page.route(`${apiOrigin}/api/auth/**`, async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    const method = request.method();

    if (method === "OPTIONS") {
      await fulfillPreflight(route);
      return;
    }

    if (url.pathname === "/api/auth/login" && method === "POST") {
      const payload = request.postDataJSON() as { email?: string; password?: string };
      if (
        payload.email !== "admin@petmagic.test" ||
        payload.password !== "production-ready-password"
      ) {
        violations.push(`POST ${url.pathname} received an unexpected login payload.`);
      }
      if (request.headers().authorization) {
        violations.push(`POST ${url.pathname} unexpectedly included Authorization.`);
      }
      await fulfillJson(route, session);
      return;
    }

    if (url.pathname === "/api/auth/refresh" && method === "POST") {
      await fulfillJson(route, session);
      return;
    }

    if (url.pathname === "/api/auth/logout" && method === "POST") {
      await fulfillJson(route, {});
      return;
    }

    violations.push(`${method} ${url.pathname}${url.search}`);
    await fulfillJson(route, { code: "e2e.unexpected_auth_request" }, 501);
  });
}

async function loginAsAdmin(page: Page) {
  const dashboardPattern = `${apiOrigin}/api/admin/**`;
  const quarantineDashboardRequests = async (route: Route) => {
    if (route.request().method() === "OPTIONS") {
      await fulfillPreflight(route);
      return;
    }
    await route.abort("blockedbyclient");
  };

  await page.route(dashboardPattern, quarantineDashboardRequests);
  await page.goto("/ru");
  await page.locator("#login-email").fill("admin@petmagic.test");
  await page.locator("#login-password").fill("production-ready-password");
  await page.locator('form button[type="submit"]').click();
  await expect(page).toHaveURL(/\/ru\/dashboard$/);
  await page.waitForTimeout(100);
  await page.unroute(dashboardPattern, quarantineDashboardRequests);
}

function createAnalyticsOverview(templateIds: readonly string[]) {
  const requestedTemplateIds = new Set(templateIds);
  const templates = catalogTemplates
    .filter((template) => requestedTemplateIds.has(template.templateId))
    .map((template) => {
      const index = catalogTemplates.findIndex(
        (candidate) => candidate.templateId === template.templateId
      );
      return {
        templateId: template.templateId,
        templateType: template.templateType,
        title: template.title,
        category: template.category,
        status: template.status,
        isPremium: template.isPremium,
        tokenCost: template.tokenCost,
        previewAsset: template.previewAsset ?? null,
        views: 120 - index * 30,
        generationStarts: 42 - index * 8,
        completedGenerations: 36 - index * 7,
        failedGenerations: index + 1,
        conversionPercent: 80 - index * 5,
        totalTokenCost: 504 - index * 120,
        totalProviderCostUsd: 6.4 - index,
        updatedAtUtc: template.updatedAtUtc,
      };
    });

  return {
    summary: {
      totalTemplates: templates.length,
      videoTemplates: templates.filter((template) => template.templateType === "Video").length,
      imageTemplates: templates.filter((template) => template.templateType === "Image").length,
      activeTemplates: templates.filter((template) => template.status === "Active").length,
      premiumTemplates: templates.filter((template) => template.isPremium).length,
      totalViews: templates.reduce((total, template) => total + template.views, 0),
      totalGenerationStarts: templates.reduce(
        (total, template) => total + template.generationStarts,
        0
      ),
      completedGenerations: templates.reduce(
        (total, template) => total + template.completedGenerations,
        0
      ),
      failedGenerations: templates.reduce(
        (total, template) => total + template.failedGenerations,
        0
      ),
      conversionPercent: 85.3,
      totalTokenCost: 1_152,
      averageTokenCost: 17.3,
      totalProviderCostUsd: 16.2,
      totalComplaints: 0,
    },
    trendPoints: [],
    topTemplates: templates,
    categories: [],
    templateTypes: [],
    sources: [],
    devices: [],
    geography: [],
    feedbackItems: [],
    conversionFunnel: {
      views: 270,
      generationStarts: 102,
      completedGenerations: 87,
      failedGenerations: 6,
      complaints: 0,
    },
    templates,
    skip: 0,
    take: templates.length,
    totalCount: templates.length,
    hasMore: false,
    availableCategories: ["Motion", "Portrait", "QA"],
    generatedAtUtc: "2026-07-26T12:00:00Z",
  };
}

function filterCatalog(url: URL) {
  let templates = [...catalogTemplates];
  const type = url.searchParams.get("type");
  const status = url.searchParams.get("status");
  const category = url.searchParams.get("category");
  const access = url.searchParams.get("access");
  const visibility = url.searchParams.get("visibility");
  const readiness = url.searchParams.get("readiness");
  const search = url.searchParams.get("search")?.toLocaleLowerCase("ru-RU");

  if (type) templates = templates.filter((template) => template.templateType === type);
  if (status === "not_archived") {
    templates = templates.filter((template) => template.status !== "Archived");
  } else if (status) {
    templates = templates.filter((template) => template.status === status);
  }
  if (category) templates = templates.filter((template) => template.category === category);
  if (access === "premium") templates = templates.filter((template) => template.isPremium);
  if (access === "free") templates = templates.filter((template) => !template.isPremium);
  if (visibility === "qa_only") templates = templates.filter((template) => template.isQaOnly);
  if (visibility === "public") templates = templates.filter((template) => !template.isQaOnly);
  if (readiness === "ready") templates = templates.filter((template) => template.previewAsset);
  if (readiness === "missing_preview") {
    templates = templates.filter((template) => !template.previewAsset);
  }
  if (search) {
    templates = templates.filter((template) =>
      [template.title, template.shortDescription, ...template.tags]
        .join(" ")
        .toLocaleLowerCase("ru-RU")
        .includes(search)
    );
  }

  if (url.searchParams.get("sort") === "title") {
    templates.sort((left, right) => left.title.localeCompare(right.title));
  } else if (url.searchParams.get("sort") === "tokens") {
    templates.sort((left, right) => right.tokenCost - left.tokenCost);
  } else {
    templates.sort((left, right) => right.updatedAtUtc.localeCompare(left.updatedAtUtc));
  }

  const skip = Number.parseInt(url.searchParams.get("skip") ?? "0", 10) || 0;
  const take = Number.parseInt(url.searchParams.get("take") ?? "24", 10) || 24;
  return {
    items: templates.slice(skip, skip + take),
    skip,
    take,
    totalCount: templates.length,
    hasMore: skip + take < templates.length,
    summary: catalogSummary,
  };
}

function validateQueryKeys(url: URL, expectedKeys: readonly string[], state: CatalogApiState) {
  const allowedKeys = new Set(expectedKeys);
  for (const key of url.searchParams.keys()) {
    if (!allowedKeys.has(key)) {
      state.contractViolations.push(`${url.pathname} received unsupported query parameter ${key}.`);
    }
  }
}

function validateBearer(route: Route, state: CatalogApiState) {
  const authorization = route.request().headers().authorization;
  if (authorization !== `Bearer ${adminAccessToken}`) {
    state.contractViolations.push(
      `${route.request().method()} ${new URL(route.request().url()).pathname} used ${authorization ?? "no Authorization header"}.`
    );
  }
}

async function installStrictCatalogMocks(page: Page, state: CatalogApiState) {
  await page.route(`${apiOrigin}/api/admin/support/tickets/metrics`, async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    const method = request.method();

    if (method === "OPTIONS") {
      await fulfillPreflight(route);
      return;
    }

    validateBearer(route, state);
    if (method !== "GET") {
      state.unexpectedRequests.push(`${method} ${url.pathname}${url.search}`);
      await fulfillJson(route, { code: "e2e.unexpected_support_metrics_request" }, 501);
      return;
    }

    await fulfillJson(route, {
      totalConversations: 0,
      openConversations: 0,
      closedConversations: 0,
      unassignedConversations: 0,
      unreadForAdminConversations: 0,
    });
  });

  await page.route(`${apiOrigin}/api/admin/templates/**`, async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    const method = request.method();

    if (method === "OPTIONS") {
      await fulfillPreflight(route);
      return;
    }

    validateBearer(route, state);

    if (url.pathname === "/api/admin/templates/generation-control" && method === "GET") {
      validateQueryKeys(url, [], state);
      await fulfillJson(route, shellGenerationControlSnapshot);
      return;
    }

    if (url.pathname === "/api/admin/templates/moderation" && method === "GET") {
      validateQueryKeys(url, ["status", "take"], state);
      if (url.searchParams.get("status") !== "pending" || url.searchParams.get("take") !== "1") {
        state.contractViolations.push(
          `${url.pathname}${url.search} used an unexpected shell moderation query.`
        );
      }
      await fulfillJson(route, {
        items: [],
        skip: 0,
        take: 1,
        totalCount: 0,
        hasMore: false,
        generatedAtUtc: "2026-07-27T00:00:00Z",
        summary: {
          pendingCount: 0,
          approvedCount: 0,
          rejectedCount: 0,
          pendingComplaintsCount: 0,
          pendingFeedbackCount: 0,
          oldestPendingAtUtc: null,
          generatedAtUtc: "2026-07-27T00:00:00Z",
        },
      });
      return;
    }

    if (url.pathname === "/api/admin/templates/generations/metrics" && method === "GET") {
      validateQueryKeys(url, [], state);
      await fulfillJson(route, {
        totalJobs: 0,
        generationsToday: 0,
        generationsThisWeek: 0,
        generationsThisMonth: 0,
        failedGenerationsToday: 0,
        failedGenerationsThisWeek: 0,
        failedGenerationsThisMonth: 0,
        pendingJobs: 0,
        runningJobs: 0,
        completedJobs: 0,
        failedJobs: 0,
        cancelledJobs: 0,
        cancellingJobs: 0,
        retryingJobs: 0,
        pendingRefunds: 0,
        exhaustedRefunds: 0,
        generatedAtUtc: "2026-07-27T00:00:00Z",
      });
      return;
    }

    if (url.pathname === "/api/admin/templates/categories/" && method === "GET") {
      validateQueryKeys(url, ["includeArchived"], state);
      if (url.searchParams.get("includeArchived") !== "true") {
        state.contractViolations.push(`${url.pathname} must request includeArchived=true.`);
      }
      await fulfillJson(route, [
        {
          categoryId: "dddddddd-dddd-dddd-dddd-dddddddddddd",
          name: "Portrait",
          isArchived: false,
          totalTemplates: 1,
          videoTemplates: 0,
          imageTemplates: 1,
          activeTemplates: 1,
          draftTemplates: 0,
          archivedTemplates: 0,
          premiumTemplates: 0,
          tags: ["portrait"],
          createdAtUtc: "2026-07-20T10:00:00Z",
          updatedAtUtc: "2026-07-25T12:00:00Z",
        },
      ]);
      return;
    }

    if (url.pathname === "/api/admin/templates/analytics" && method === "GET") {
      validateQueryKeys(url, ["templateIds", "templateType", "sort", "take"], state);
      const templateIds = url.searchParams.getAll("templateIds");
      const templateType = url.searchParams.get("templateType");
      if (
        templateIds.length === 0 ||
        templateIds.length > 100 ||
        new Set(templateIds).size !== templateIds.length ||
        (templateType !== null && templateType !== "Video" && templateType !== "Image") ||
        url.searchParams.get("sort") !== "updated" ||
        url.searchParams.get("take") !== String(templateIds.length)
      ) {
        state.contractViolations.push(
          `${url.pathname}${url.search} used an unexpected catalog analytics query.`
        );
      }
      await fulfillJson(route, createAnalyticsOverview(templateIds));
      return;
    }

    if (url.pathname === "/api/admin/templates/" && method === "GET") {
      state.catalogRequests.push(url);
      validateQueryKeys(
        url,
        [
          "type",
          "status",
          "search",
          "category",
          "access",
          "visibility",
          "readiness",
          "sort",
          "skip",
          "take",
        ],
        state
      );
      const type = url.searchParams.get("type");
      if (
        (type !== null && type !== "Video" && type !== "Image") ||
        url.searchParams.get("status") !== "not_archived" ||
        url.searchParams.get("sort") !== "newest" ||
        url.searchParams.get("skip") !== "0" ||
        url.searchParams.get("take") !== "24"
      ) {
        state.contractViolations.push(
          `${url.pathname}${url.search} violated the unified catalog query contract.`
        );
      }
      await fulfillJson(route, filterCatalog(url));
      return;
    }

    state.unexpectedRequests.push(`${method} ${url.pathname}${url.search}`);
    await fulfillJson(route, { code: "e2e.unexpected_templates_request" }, 501);
  });
}

function hasCatalogQuery(requests: readonly URL[], expected: Record<string, string | null>) {
  return requests.some((url) =>
    Object.entries(expected).every(([key, value]) => url.searchParams.get(key) === value)
  );
}

async function chooseCatalogSelectOption(page: Page, label: string, option: string) {
  const main = page.locator("#admin-main");
  const trigger = main.getByRole("button", { name: label, exact: true });
  await trigger.click();
  const listbox = main.getByRole("listbox", { name: label, exact: true });
  await expect(listbox).toBeVisible();
  await listbox.getByRole("option", { name: option, exact: true }).click();
  await expect(trigger).toHaveAttribute("aria-expanded", "false");
}

async function expectCatalogCardGeometry(page: Page, expectedCount: number) {
  const cards = page.locator("#admin-main article");
  await expect(cards).toHaveCount(expectedCount);

  const geometry = await cards.evaluateAll((elements) =>
    elements.map((card) => {
      const [media, body, actions] = Array.from(card.children) as HTMLElement[];
      if (!media || !body || !actions) {
        throw new Error("Template card anatomy is incomplete.");
      }

      const cardRect = card.getBoundingClientRect();
      const mediaRect = media.getBoundingClientRect();
      const bodyRect = body.getBoundingClientRect();
      const actionsRect = actions.getBoundingClientRect();
      const actionRects = Array.from(actions.children).map((action) =>
        action.getBoundingClientRect()
      );

      return {
        card: {
          left: cardRect.left,
          right: cardRect.right,
          top: cardRect.top,
          width: cardRect.width,
        },
        media: {
          left: mediaRect.left,
          right: mediaRect.right,
          bottom: mediaRect.bottom,
          width: mediaRect.width,
        },
        body: { left: bodyRect.left, right: bodyRect.right, bottom: bodyRect.bottom },
        actions: {
          left: actionsRect.left,
          right: actionsRect.right,
          top: actionsRect.top,
          width: actionsRect.width,
        },
        actionRects: actionRects.map((rect) => ({ left: rect.left, right: rect.right })),
      };
    })
  );

  for (const item of geometry) {
    expect(item.card.width).toBeGreaterThanOrEqual(300);
    expect(item.media.left).toBeGreaterThanOrEqual(item.card.left - 1);
    expect(item.media.right).toBeLessThanOrEqual(item.body.left + 1);
    expect(item.body.right).toBeLessThanOrEqual(item.card.right + 1);
    expect(item.media.width / item.card.width).toBeGreaterThan(0.39);
    expect(item.media.width / item.card.width).toBeLessThan(0.46);
    expect(item.actions.left).toBeGreaterThanOrEqual(item.card.left - 1);
    expect(item.actions.right).toBeLessThanOrEqual(item.card.right + 1);
    expect(item.actions.top).toBeGreaterThanOrEqual(item.media.bottom - 1);
    expect(item.actions.top).toBeGreaterThanOrEqual(item.body.bottom - 1);
    expect(item.actions.width / item.card.width).toBeGreaterThan(0.99);
    for (const action of item.actionRects) {
      expect(action.left).toBeGreaterThanOrEqual(item.actions.left - 1);
      expect(action.right).toBeLessThanOrEqual(item.actions.right + 1);
    }
  }

  if (geometry.length >= 3) {
    expect(Math.abs(geometry[0].card.top - geometry[1].card.top)).toBeLessThanOrEqual(1);
    expect(Math.abs(geometry[1].card.top - geometry[2].card.top)).toBeLessThanOrEqual(1);
    expect(geometry[0].card.left).toBeLessThan(geometry[1].card.left);
    expect(geometry[1].card.left).toBeLessThan(geometry[2].card.left);
  }
}

async function expectTemplatesDesktopLayout(page: Page) {
  const viewport = page.viewportSize();
  expect(viewport).toEqual({ width: 1536, height: 1024 });
  if (!viewport) {
    throw new Error("Desktop viewport is unavailable.");
  }

  await expectNoHorizontalDocumentOverflow(page);

  const main = page.locator("#admin-main");
  const sidebar = page.locator("#admin-sidebar");
  const catalogCards = main.locator("article");
  const catalogGrid = catalogCards.first().locator("..");
  const rightRail = main.getByRole("complementary", {
    name: "Контроль публикации",
    exact: true,
  });
  const catalogWorkspace = rightRail.locator("..");
  const [sidebarBox, mainBox, workspaceBox, gridBox, railBox] = await Promise.all([
    expectNonZeroBoundingBox(sidebar, "admin sidebar"),
    expectNonZeroBoundingBox(main, "admin workspace"),
    expectNonZeroBoundingBox(catalogWorkspace, "templates workspace"),
    expectNonZeroBoundingBox(catalogGrid, "template grid"),
    expectNonZeroBoundingBox(rightRail, "templates right rail"),
  ]);

  expectBoxInsideViewportHorizontally(sidebarBox, viewport, "admin sidebar");
  expectBoxInsideViewportHorizontally(mainBox, viewport, "admin workspace");
  expectBoxInsideViewportHorizontally(railBox, viewport, "templates right rail");
  expect(sidebarBox.width, "expanded desktop sidebar width").toBeGreaterThanOrEqual(230);
  expect(sidebarBox.width, "expanded desktop sidebar width").toBeLessThanOrEqual(250);
  expect(mainBox.x, "admin workspace starts after sidebar").toBeGreaterThanOrEqual(
    sidebarBox.x + sidebarBox.width - 1
  );
  expectBoxContains(workspaceBox, gridBox, "template grid within workspace");
  expectBoxContains(workspaceBox, railBox, "right rail within workspace");
  expectBoxesNotToIntersect(gridBox, railBox, "template grid and right rail");
  await expectNoHorizontalElementOverflow(catalogGrid, "template grid");
  await expectNoHorizontalElementOverflow(rightRail, "templates right rail");
  await expectVisibleColumnCount(catalogCards, 3);
  await expectCatalogCardGeometry(page, 3);
}

test("Templates structural layout at 1536x1024", async ({ page }, testInfo) => {
  test.setTimeout(60_000);
  const authViolations: string[] = [];
  const apiState: CatalogApiState = {
    catalogRequests: [],
    contractViolations: [],
    unexpectedRequests: [],
  };
  const runtimeErrors: string[] = [];

  await page.setViewportSize({ width: 1536, height: 1024 });
  await installStrictAuthMocks(page, authViolations);
  await loginAsAdmin(page);
  await installStrictCatalogMocks(page, apiState);

  page.on("pageerror", (error) => runtimeErrors.push(`pageerror: ${error.message}`));
  page.on("requestfailed", (request) => {
    const errorText = request.failure()?.errorText;
    if (errorText && errorText !== "net::ERR_ABORTED") {
      runtimeErrors.push(`requestfailed: ${request.url()} (${errorText})`);
    }
  });
  page.on("console", (message) => {
    if (message.type() === "error") {
      const sourceUrl = message.location().url;
      runtimeErrors.push(`console: ${message.text()}${sourceUrl ? ` (${sourceUrl})` : ""}`);
    }
  });

  await page.goto("/ru/templates");
  const main = page.locator("#admin-main");
  await expect(page).toHaveURL(/\/ru\/templates$/);
  await expect(
    page.getByRole("banner").getByRole("heading", { name: "Шаблоны", exact: true })
  ).toBeVisible();
  await expect(
    main.getByRole("heading", { name: "Golden Studio Portrait", exact: true })
  ).toBeVisible();

  await expectTemplatesDesktopLayout(page);
  await page.screenshot({
    path: testInfo.outputPath("templates-current-1536x1024.png"),
  });

  await expect(page.locator("nextjs-portal")).toHaveCount(0);
  await expect(page.getByText("Unhandled Runtime Error", { exact: false })).toHaveCount(0);
  await expect(page.getByText("Application error", { exact: false })).toHaveCount(0);
  expect(authViolations).toEqual([]);
  expect(apiState.contractViolations).toEqual([]);
  expect(apiState.unexpectedRequests).toEqual([]);
  expect(runtimeErrors).toEqual([]);
});

test("unified templates catalog supports publishing filters and responsive cards/list workflow", async ({
  page,
}, testInfo) => {
  test.setTimeout(60_000);
  const authViolations: string[] = [];
  const apiState: CatalogApiState = {
    catalogRequests: [],
    contractViolations: [],
    unexpectedRequests: [],
  };
  const runtimeErrors: string[] = [];

  await page.setViewportSize({ width: 1536, height: 1024 });
  await installStrictAuthMocks(page, authViolations);
  await loginAsAdmin(page);
  await installStrictCatalogMocks(page, apiState);

  page.on("pageerror", (error) => runtimeErrors.push(`pageerror: ${error.message}`));
  page.on("requestfailed", (request) => {
    const errorText = request.failure()?.errorText;
    if (!errorText || errorText === "net::ERR_ABORTED") {
      return;
    }
    runtimeErrors.push(`requestfailed: ${request.url()} (${errorText})`);
  });
  page.on("console", (message) => {
    if (message.type() === "error") {
      const sourceUrl = message.location().url;
      runtimeErrors.push(`console: ${message.text()}${sourceUrl ? ` (${sourceUrl})` : ""}`);
    }
  });

  await page.goto("/ru/templates");

  const main = page.locator("#admin-main");
  await expect(page).toHaveURL(/\/ru\/templates$/);
  await expect(
    page.getByRole("banner").getByRole("heading", { name: "Шаблоны", exact: true })
  ).toBeVisible();
  await expect(
    main.getByRole("heading", { name: "Управление шаблонами", exact: true })
  ).toHaveCount(0);
  await expect(main.getByRole("link", { name: "Все", exact: true })).toHaveAttribute(
    "aria-current",
    "page"
  );
  await expect(main.getByRole("button", { name: /Черновики\s*1/ })).toBeVisible();
  await expect(main.getByRole("button", { name: /Без превью\s*1/ })).toBeVisible();
  await expect(main.getByRole("button", { name: /Только QA\s*1/ })).toBeVisible();
  await expect(
    main.getByRole("heading", { name: "Golden Studio Portrait", exact: true })
  ).toBeVisible();
  await expect(
    main.getByRole("heading", { name: "Preview Needed Motion", exact: true })
  ).toBeVisible();
  await expect(main.getByRole("heading", { name: "QA Neon Portrait", exact: true })).toBeVisible();
  const unavailablePreviewCard = main.locator("article").filter({ hasText: "QA Neon Portrait" });
  await expect(
    unavailablePreviewCard.getByText("Не удалось показать превью", { exact: true })
  ).toBeVisible();
  await expect
    .poll(() =>
      hasCatalogQuery(apiState.catalogRequests, {
        status: "not_archived",
        sort: "newest",
        skip: "0",
        take: "24",
        readiness: null,
        visibility: null,
        type: null,
      })
    )
    .toBe(true);

  const desktopDimensions = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));
  expect(desktopDimensions.scrollWidth).toBeLessThanOrEqual(desktopDimensions.clientWidth);
  await expectTemplatesDesktopLayout(page);

  const featuredCard = main.locator("article").filter({ hasText: "Golden Studio Portrait" });
  await expect(featuredCard).toBeVisible();
  await expect(featuredCard.getByRole("link", { name: /Тест:/ })).toBeVisible();
  await expect(featuredCard.getByRole("link", { name: /Аналитика:/ })).toBeVisible();
  const featuredCardWidth = await featuredCard.evaluate(
    (element) => element.getBoundingClientRect().width
  );
  expect(featuredCardWidth).toBeGreaterThanOrEqual(300);

  const actionsButton = featuredCard.getByRole("button", { name: "Действия", exact: true });
  await actionsButton.click();
  const actionsMenu = featuredCard.getByRole("menu", { name: "Действия", exact: true });
  await expect(actionsMenu).toBeVisible();
  const desktopActionsGeometry = await page.evaluate(() => {
    const card = Array.from(document.querySelectorAll("article")).find((element) =>
      element.textContent?.includes("Golden Studio Portrait")
    );
    const menu = document.querySelector<HTMLElement>('[role="menu"][aria-label="Действия"]');
    if (!card || !menu) {
      throw new Error("Template card actions are missing.");
    }

    const cardRect = card.getBoundingClientRect();
    const menuRect = menu.getBoundingClientRect();
    return {
      cardBottom: cardRect.bottom,
      cardWidth: cardRect.width,
      menuBottom: menuRect.bottom,
      menuLeft: menuRect.left,
      menuRight: menuRect.right,
      viewportWidth: document.documentElement.clientWidth,
    };
  });
  expect(desktopActionsGeometry.menuBottom).toBeGreaterThan(desktopActionsGeometry.cardBottom);
  expect(desktopActionsGeometry.menuLeft).toBeGreaterThanOrEqual(0);
  expect(desktopActionsGeometry.menuRight).toBeLessThanOrEqual(
    desktopActionsGeometry.viewportWidth
  );
  await actionsButton.press("Escape");
  await expect(actionsMenu).toHaveCount(0);

  await page.screenshot({
    path: testInfo.outputPath("templates-catalog-desktop.png"),
  });

  await page.goto("/ru/templates/video");
  await expect(page).toHaveURL(/\/ru\/templates\/video$/);
  await expect(
    main.getByRole("heading", { name: "Preview Needed Motion", exact: true })
  ).toBeVisible();
  await expectCatalogCardGeometry(page, 1);
  await page.screenshot({
    path: testInfo.outputPath("templates-video-desktop.png"),
  });

  await page.goto("/ru/templates/image");
  await expect(page).toHaveURL(/\/ru\/templates\/image$/);
  await expect(
    main.getByRole("heading", { name: "Golden Studio Portrait", exact: true })
  ).toBeVisible();
  await expectCatalogCardGeometry(page, 2);
  await page.screenshot({
    path: testInfo.outputPath("templates-image-desktop.png"),
  });

  await page.goto("/ru/templates");
  await expect(page).toHaveURL(/\/ru\/templates$/);
  await expect(
    main.getByRole("heading", { name: "Golden Studio Portrait", exact: true })
  ).toBeVisible();

  const readinessSelect = main.getByRole("button", { name: "Готовность", exact: true });
  await chooseCatalogSelectOption(page, "Готовность", "Без превью");
  await expect
    .poll(() =>
      hasCatalogQuery(apiState.catalogRequests, {
        readiness: "missing_preview",
        visibility: null,
      })
    )
    .toBe(true);
  await expect(
    main.getByRole("heading", { name: "Preview Needed Motion", exact: true })
  ).toBeVisible();
  await expect(
    main.getByRole("heading", { name: "Golden Studio Portrait", exact: true })
  ).toHaveCount(0);
  await expect(readinessSelect).toBeEnabled();
  await chooseCatalogSelectOption(page, "Готовность", "Любая");

  const visibilitySelect = main.getByRole("button", { name: "Видимость", exact: true });
  await expect(visibilitySelect).toBeEnabled();
  await chooseCatalogSelectOption(page, "Видимость", "Только QA");
  await expect
    .poll(() =>
      hasCatalogQuery(apiState.catalogRequests, {
        readiness: null,
        visibility: "qa_only",
      })
    )
    .toBe(true);
  await expect(main.getByRole("heading", { name: "QA Neon Portrait", exact: true })).toBeVisible();
  await expect(
    main.getByRole("heading", { name: "Preview Needed Motion", exact: true })
  ).toHaveCount(0);

  const listButton = main.getByRole("button", { name: "Список", exact: true });
  await listButton.click();
  await expect(listButton).toHaveAttribute("aria-pressed", "true");
  const catalogTable = main.getByRole("table");
  await expect(catalogTable).toBeVisible();
  await expect(catalogTable.getByRole("row", { name: /QA Neon Portrait/ })).toBeVisible();

  await main.getByRole("button", { name: "Сбросить", exact: true }).click();
  const cardsButton = main.getByRole("button", { name: "Карточки", exact: true });
  await expect(cardsButton).toBeEnabled();
  await cardsButton.click();
  await expect(cardsButton).toHaveAttribute("aria-pressed", "true");
  await expect(
    main.getByRole("heading", { name: "Golden Studio Portrait", exact: true })
  ).toBeVisible();

  await page.setViewportSize({ width: 390, height: 844 });
  await page.waitForTimeout(260);
  await page.evaluate(() => window.scrollTo(0, 0));

  const filtersToggle = main.getByRole("button", { name: "Показать фильтры", exact: true });
  await expect(filtersToggle).toBeVisible();
  await expect(filtersToggle).toHaveAttribute("aria-expanded", "false");
  await expect(readinessSelect).not.toBeVisible();
  await filtersToggle.click();
  await expect(main.getByRole("button", { name: "Скрыть фильтры", exact: true })).toHaveAttribute(
    "aria-expanded",
    "true"
  );
  await expect(readinessSelect).toBeVisible();
  await expect(visibilitySelect).toBeVisible();

  const mobileDimensions = await page.evaluate(() => {
    const filters = document.querySelector<HTMLElement>('[aria-label="Фильтры каталога"]');
    const advancedFilters = document.querySelector<HTMLElement>(
      "#template-catalog-advanced-filters"
    );
    const sidebar = document.querySelector<HTMLElement>("#admin-sidebar");
    if (!filters || !advancedFilters || !sidebar) {
      throw new Error("Responsive catalog controls are missing.");
    }

    return {
      advancedClientWidth: advancedFilters.clientWidth,
      advancedScrollWidth: advancedFilters.scrollWidth,
      clientWidth: document.documentElement.clientWidth,
      filtersLeft: filters.getBoundingClientRect().left,
      filtersRight: filters.getBoundingClientRect().right,
      scrollWidth: document.documentElement.scrollWidth,
      sidebarRight: sidebar.getBoundingClientRect().right,
    };
  });
  expect(mobileDimensions.scrollWidth).toBeLessThanOrEqual(mobileDimensions.clientWidth);
  expect(mobileDimensions.advancedScrollWidth).toBeLessThanOrEqual(
    mobileDimensions.advancedClientWidth
  );
  expect(mobileDimensions.filtersLeft).toBeGreaterThanOrEqual(0);
  expect(mobileDimensions.filtersRight).toBeLessThanOrEqual(390);
  expect(mobileDimensions.sidebarRight).toBeLessThanOrEqual(0);

  const mobileFeaturedCard = main.locator("article").filter({ hasText: "Golden Studio Portrait" });
  const mobileActionsButton = mobileFeaturedCard.getByRole("button", {
    name: "Действия",
    exact: true,
  });
  await mobileActionsButton.click();
  const mobileActionsMenu = mobileFeaturedCard.getByRole("menu", {
    name: "Действия",
    exact: true,
  });
  await expect(mobileActionsMenu).toBeVisible();
  const mobileActionsGeometry = await mobileActionsMenu.evaluate((element) => {
    const rect = element.getBoundingClientRect();
    return {
      left: rect.left,
      right: rect.right,
      viewportWidth: document.documentElement.clientWidth,
    };
  });
  expect(mobileActionsGeometry.left).toBeGreaterThanOrEqual(0);
  expect(mobileActionsGeometry.right).toBeLessThanOrEqual(mobileActionsGeometry.viewportWidth);
  await mobileActionsButton.press("Escape");
  await expect(mobileActionsMenu).toHaveCount(0);

  await page.screenshot({
    path: testInfo.outputPath("templates-catalog-mobile.png"),
    fullPage: true,
  });

  await expect(page.locator("nextjs-portal")).toHaveCount(0);
  await expect(page.getByText("Unhandled Runtime Error", { exact: false })).toHaveCount(0);
  await expect(page.getByText("Application error", { exact: false })).toHaveCount(0);
  expect(authViolations).toEqual([]);
  expect(apiState.contractViolations).toEqual([]);
  expect(apiState.unexpectedRequests).toEqual([]);
  expect(runtimeErrors).toEqual([]);
});
