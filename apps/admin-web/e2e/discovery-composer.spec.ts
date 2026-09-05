import { expect, test, type Page, type Route } from "@playwright/test";
import type {
  DiscoveryAdmin,
  DiscoveryDocument,
  DiscoveryRevision,
} from "../src/lib/api-client.discovery";

const api = "https://api.petmagic.test";
const categoryA = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
const categoryB = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb";
const now = "2026-09-05T12:00:00Z";
const media =
  "data:image/svg+xml," +
  encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" width="320" height="480"><defs><linearGradient id="g" x2="1" y2="1"><stop stop-color="#225f49"/><stop offset="1" stop-color="#202d48"/></linearGradient></defs><rect width="320" height="480" fill="url(#g)"/><circle cx="160" cy="195" r="75" fill="#d8bb89"/><path d="M90 170L70 70L145 125M175 125L250 70L230 170" fill="#a88658"/><ellipse cx="160" cy="230" rx="40" ry="27" fill="#f8e7ca"/><circle cx="133" cy="185" r="9" fill="#182321"/><circle cx="187" cy="185" r="9" fill="#182321"/><ellipse cx="160" cy="215" rx="13" ry="10" fill="#182321"/><text x="160" y="385" text-anchor="middle" fill="#8ce7bb" font-family="sans-serif" font-size="22">PetMagic</text></svg>'
  );
const templates = [
  { templateId: "11111111-1111-1111-1111-111111111111", title: "Big Boss", category: "Funny" },
  { templateId: "22222222-2222-2222-2222-222222222222", title: "Secret Agent", category: "Funny" },
  {
    templateId: "33333333-3333-3333-3333-333333333333",
    title: "Cinema Star",
    category: "Cinematic",
  },
].map((item) => ({
  ...item,
  templateType: "Image",
  status: "Active",
  isQaOnly: false,
  tokenCost: 3,
  previewAsset: { url: media, contentType: "image/svg+xml" },
  thumbnailAsset: { url: media, contentType: "image/svg+xml" },
}));
const document: DiscoveryDocument = {
  schemaVersion: 1,
  copy: {
    en: { title: "Create magic", subtitle: "Your pet's next adventure" },
    ru: { title: "Создай магию", subtitle: "Новое приключение для питомца" },
  },
  searchEnabled: true,
  carouselEnabled: true,
  autoplayEnabled: true,
  autoplayIntervalMs: 7000,
  sections: [
    {
      id: "44444444-4444-4444-4444-444444444444",
      categoryId: categoryA,
      isEnabled: true,
      showInCarousel: true,
      showAsRail: true,
      heroTemplateId: null,
      selectionMode: "Latest",
      itemLimit: 6,
      templateIds: [],
      copy: { en: { title: "Funny", subtitle: "" } },
    },
    {
      id: "55555555-5555-5555-5555-555555555555",
      categoryId: categoryB,
      isEnabled: true,
      showInCarousel: true,
      showAsRail: true,
      heroTemplateId: null,
      selectionMode: "Latest",
      itemLimit: 6,
      templateIds: [],
      copy: { en: { title: "Cinematic", subtitle: "" } },
    },
  ],
};
function revision(number: number): DiscoveryRevision {
  return {
    id: `66666666-6666-6666-6666-${String(number).padStart(12, "0")}`,
    number,
    editVersion: 1,
    state: "Draft",
    document: structuredClone(document),
    basedOnRevisionId: null,
    createdAtUtc: now,
    updatedAtUtc: now,
    publishedAtUtc: null,
    createdBy: categoryA,
    updatedBy: categoryA,
    publishedBy: null,
    reason: null,
  };
}
async function json(route: Route, value: unknown, status = 200) {
  await route.fulfill({
    status,
    contentType: "application/json",
    headers: {
      "Access-Control-Allow-Origin": route.request().headers().origin ?? "*",
      "Access-Control-Allow-Credentials": "true",
      "Access-Control-Allow-Headers": "Authorization,Content-Type,Idempotency-Key,X-Correlation-ID",
      "Access-Control-Allow-Methods": "GET,POST,PUT,OPTIONS",
    },
    body: status === 204 ? "" : JSON.stringify(value),
  });
}
async function setup(page: Page, role = "Admin") {
  const state: DiscoveryAdmin = { pageVersion: 1, published: null, draft: revision(1) };
  const history: DiscoveryRevision[] = [];
  const calls: { method: string; path: string; body: unknown }[] = [];
  const errors: string[] = [];
  let conflict = false;
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("console", (message) => {
    if (
      message.type() === "error" &&
      !(conflict && /409|discovery.conflict/.test(message.text()))
    ) {
      errors.push(message.text());
    }
  });
  const session = {
    expiresAtUtc: "2099-01-01T00:00:00Z",
    user: {
      userId: categoryA,
      email: "admin@petmagic.test",
      displayName: "Alex",
      isPremium: false,
      emailConfirmed: true,
      roles: [role],
      legalAcceptance: { requiresAcceptance: false },
    },
  };
  await page.addInitScript(
    (value) => sessionStorage.setItem("petmagic_admin_auth", JSON.stringify(value)),
    session
  );
  await page.route(`${api}/api/**`, async (route) => {
    const request = route.request();
    if (request.method() === "OPTIONS") {
      await json(route, null, 204);
      return;
    }
    const path = new URL(request.url()).pathname;
    const body = request.postData() ? request.postDataJSON() : null;
    if (path === "/api/auth/refresh") {
      await json(route, { ...session, accessToken: "discovery-test-token" });
      return;
    }
    if (path === "/api/admin/templates/discovery/") {
      await json(route, state);
      return;
    }
    if (path === "/api/admin/templates/discovery/revisions") {
      await json(route, {
        items: [...history, ...(state.draft ? [state.draft] : [])].reverse(),
        hasMore: false,
      });
      return;
    }
    if (path === "/api/admin/templates/discovery/drafts" && request.method() === "POST") {
      calls.push({ method: request.method(), path, body });
      const source = history.find((item) => item.id === body.sourceRevisionId) ?? state.published;
      state.draft = {
        ...revision((state.published?.number ?? 1) + 1),
        document: structuredClone(source?.document ?? document),
        basedOnRevisionId: source?.id ?? null,
      };
      state.pageVersion++;
      await json(route, state.draft);
      return;
    }
    if (path.startsWith("/api/admin/templates/discovery/drafts/")) {
      const selected = state.draft ?? state.published!;
      if (path.endsWith("/validate")) {
        await json(route, { isValid: true, issues: [] });
        return;
      }
      if (path.endsWith("/preview")) {
        const locale = new URL(request.url()).searchParams.get("locale") as "ru" | "en";
        const doc = selected.document;
        await json(route, {
          revision: selected.number,
          page: { ...doc, ...(doc.copy[locale] ?? doc.copy.en) },
          sections: doc.sections
            .filter((section) => section.isEnabled)
            .map((section) => {
              const category = section.categoryId === categoryA ? "Funny" : "Cinematic";
              const items = templates.filter((item) => item.category === category);
              const ids = [
                ...new Set(
                  [
                    section.heroTemplateId,
                    ...section.templateIds,
                    ...(section.selectionMode === "Manual"
                      ? []
                      : items.map((item) => item.templateId)),
                  ].filter(Boolean)
                ),
              ];
              return {
                ...section,
                sectionId: section.id,
                category,
                title: section.copy[locale]?.title || section.copy.en?.title || category,
                subtitle: "",
                items: ids
                  .map((id) => templates.find((item) => item.templateId === id)!)
                  .filter(Boolean)
                  .map((item) => ({
                    id: item.templateId,
                    title: item.title,
                    tokenCost: 3,
                    thumbnailUrl: media,
                    type: "Image",
                    media: { thumbnailUrl: media, mediaKind: "image" },
                  })),
              };
            }),
        });
        return;
      }
      calls.push({ method: request.method(), path, body });
      if (request.method() === "PUT") {
        if (conflict) {
          await json(route, { code: "discovery.conflict", detail: "Changed" }, 409);
          return;
        }
        expect(body.expectedVersion).toBe(selected.editVersion);
        selected.document = body.document;
        selected.editVersion++;
        await json(route, selected);
        return;
      }
      if (path.endsWith("/publish")) {
        expect(request.headers()["idempotency-key"]).toBeTruthy();
        expect(body.expectedVersion).toBe(selected.editVersion);
        expect(body.expectedPageVersion).toBe(state.pageVersion);
        selected.state = "Published";
        selected.reason = body.reason;
        selected.publishedAtUtc = now;
        selected.editVersion++;
        state.published = structuredClone(selected);
        history.push(structuredClone(selected));
        state.draft = null;
        state.pageVersion++;
        await json(route, state.published);
        return;
      }
      if (path.endsWith("/discard")) {
        state.draft = null;
        state.pageVersion++;
        await json(route, true);
        return;
      }
    }
    if (path === "/api/admin/templates/categories/") {
      await json(route, [
        { categoryId: categoryA, name: "Funny", isArchived: false },
        { categoryId: categoryB, name: "Cinematic", isArchived: false },
      ]);
      return;
    }
    if (path === "/api/admin/templates/") {
      const category = new URL(request.url()).searchParams.get("category");
      await json(route, {
        items: templates.filter((item) => item.category === category),
        hasMore: false,
      });
      return;
    }
    if (path === "/api/admin/templates/generation-control") {
      const profile = {
        globalMaxConcurrentGenerations: 4,
        imageReservedConcurrentGenerations: 3,
        imageProtectedConcurrentGenerations: 2,
        imageMaxConcurrentGenerations: 3,
        videoReservedConcurrentGenerations: 1,
        videoMaxConcurrentGenerations: 2,
        videoBorrowMaxConcurrentGenerations: 1,
        videoPreprocessingMaxConcurrentGenerations: 1,
      };
      await json(route, {
        revision: 1,
        admissionEnabled: true,
        confirmedFalConcurrencyLimit: 6,
        reservedHeadroom: 1,
        applicationHardCeiling: 5,
        effectiveGlobalLimit: 4,
        policy: profile,
        effectiveProfile: profile,
        balance: { state: "fresh", currentBalanceUsd: 25, checkedAtUtc: now },
        queue: { totalDepth: 0, stages: [] },
        lanes: { inFlightTotal: 0 },
        worker: { instanceCount: 1, heartbeatAtUtc: now, schedulerV2Enabled: true },
        alerts: [],
        generatedAtUtc: now,
      });
      return;
    }
    if (path.endsWith("/support/tickets/metrics")) {
      await json(route, {
        totalConversations: 0,
        openConversations: 0,
        closedConversations: 0,
        unassignedConversations: 0,
        unreadForAdminConversations: 0,
      });
      return;
    }
    if (path.endsWith("/moderation")) {
      await json(route, {
        items: [],
        totalCount: 0,
        hasMore: false,
        summary: { pendingCount: 0, pendingComplaintsCount: 0, pendingFeedbackCount: 0 },
      });
      return;
    }
    if (path.endsWith("/notifications")) {
      await json(route, { items: [], totalCount: 0, unreadCount: 0, hasMore: false });
      return;
    }
    if (path.endsWith("/generations/metrics")) {
      await json(route, {
        pendingJobs: 0,
        runningJobs: 0,
        failedJobs: 0,
        pendingRefunds: 0,
        exhaustedRefunds: 0,
      });
      return;
    }
    errors.push(`Unexpected API request ${request.method()} ${path}`);
    await json(route, {}, 501);
  });
  await page.goto("/ru/templates/discovery");
  await expect(page.getByTestId("discovery-phone-preview")).toBeVisible();
  return {
    state,
    calls,
    errors,
    forceConflict: () => {
      conflict = true;
    },
  };
}

test("editor saves layout, cover and copy, publishes and restores a revision", async ({
  page,
}, testInfo) => {
  await page.setViewportSize({ width: 1536, height: 1024 });
  const { state, calls, errors } = await setup(page);
  await page.getByRole("button", { name: "Ниже: Funny", exact: true }).click();
  await expect(page.getByRole("button", { name: "Опубликовать", exact: true })).toBeDisabled();
  await page.getByRole("combobox", { name: "Наполнение", exact: true }).selectOption("Hybrid");
  await page
    .getByRole("article")
    .filter({ hasText: "Secret Agent" })
    .getByRole("button", { name: "Сделать обложкой" })
    .click();
  await page.getByLabel("Название секции", { exact: true }).fill("Смешные истории");
  await page.getByRole("button", { name: "Сохранить черновик", exact: true }).click();
  await expect(page.getByText("Черновик сохранён", { exact: true })).toBeVisible();
  await expect(
    page.getByTestId("discovery-phone-preview").getByText("Смешные истории", { exact: true })
  ).toBeVisible();
  expect(state.draft?.document.sections[0].categoryId).toBe(categoryB);
  expect(state.draft?.document.sections[1].heroTemplateId).toBe(templates[1].templateId);
  await page.screenshot({ path: testInfo.outputPath("discovery-desktop.png"), fullPage: false });
  await page.getByRole("button", { name: "Опубликовать", exact: true }).click();
  await page
    .getByLabel("Что изменилось", { exact: true })
    .fill("Обновлены категории и обложка Funny");
  await page.getByRole("dialog").getByRole("button", { name: "Опубликовать", exact: true }).click();
  await expect(page.getByRole("button", { name: "Создать черновик", exact: true })).toBeVisible();
  await page.getByRole("tab", { name: "История", exact: true }).click();
  await page.getByRole("button", { name: "Восстановить в черновик", exact: true }).click();
  await page
    .getByRole("dialog")
    .getByRole("button", { name: "Восстановить в черновик", exact: true })
    .click();
  await expect(page.getByRole("button", { name: "Сохранить черновик", exact: true })).toBeVisible();
  expect(state.draft?.number).toBe(2);
  expect(state.published?.number).toBe(1);
  expect(calls.filter((call) => call.path.endsWith("/publish"))).toHaveLength(1);
  expect(errors).toEqual([]);
});

test("conflicting save preserves local edits", async ({ page }) => {
  const { forceConflict, state, errors } = await setup(page);
  forceConflict();
  await page.getByLabel("Название секции", { exact: true }).fill("Мои несохранённые изменения");
  await page.getByRole("button", { name: "Сохранить черновик", exact: true }).click();
  await expect(
    page.getByText(/Версия на сервере изменилась\. Ваши правки сохранены в форме/)
  ).toBeVisible();
  await expect(page.getByLabel("Название секции", { exact: true })).toHaveValue(
    "Мои несохранённые изменения"
  );
  expect(state.draft?.editVersion).toBe(1);
  expect(errors).toEqual([]);
});

test("moderator can preview but cannot edit or publish", async ({ page }) => {
  const { calls, errors } = await setup(page, "Moderator");
  await expect(page.getByLabel("Название секции", { exact: true })).toBeDisabled();
  await expect(page.getByRole("button", { name: "Создать черновик", exact: true })).toBeDisabled();
  await expect(page.getByRole("button", { name: "Опубликовать", exact: true })).toHaveCount(0);
  expect(calls).toEqual([]);
  expect(errors).toEqual([]);
});

for (const width of [390, 320])
  test(`editor fits ${width}px without horizontal overflow`, async ({ page }, testInfo) => {
    await page.setViewportSize({ width, height: 844 });
    const { errors } = await setup(page);
    await expect(
      page.getByRole("button", { name: "Сохранить черновик", exact: true })
    ).toBeVisible();
    expect(
      await page.evaluate(() => window.document.documentElement.scrollWidth <= innerWidth + 1)
    ).toBe(true);
    await page.screenshot({ path: testInfo.outputPath(`discovery-${width}.png`), fullPage: false });
    expect(errors).toEqual([]);
  });
