import { expect, test, type Page, type Route } from "@playwright/test";
import path from "node:path";
import type {
  AdminTemplate,
  ImageTemplatePayload,
  VideoTemplatePayload,
} from "../src/lib/api-client";
import {
  IMAGE_MODELS,
  KLING_MODELS,
  PREPROCESSING_MODELS,
} from "../src/components/templates/template-form-mappers";

const apiOrigin = "https://api.petmagic.test";
const templateId = "33333333-3333-3333-3333-333333333333";
const png = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAHgAAAC0CAIAAADQLH9KAAAB6UlEQVR4nO3Qha0QAAAD0e7XnXDnI8X14+4O27FFScolb4DLyUeCAv3zgv8Eo2ujjwYFjGb0FvlYUMBoRm+RjwcFjGb0FvlEUMBoRm+RTwYFjGb0FvlUUMBoRm+RTwcFjGb0FvlMUMBoRm+RzwYFjGb0FvlcUMBoRm+RzwcFjGb0FvlCUMBoRm+RLwYFjGb0FvkgKGA0o7fIl4ICRjN6i3w5KGA0o7fIV4ICRjN6i3w1KGA0o7fICQoYzegt8rWggNGM3iJfDwoYzegt8o2ggNGM3iLfDAoYzegt8q2ggNGM3iLfDgoYzegt8p2ggNGM3iLfDQoYzegt8r2ggNGM3iLfDwoYzegt8oOggNGM3iI/DAoYzegt8mFQwGhGb5EfBQWMZvQW+XFQwGhGb5GfBAWMZvQW+WlQwGhGb5GfBQWMZvQW+XlQwGhGb5FfBAWMZvQW+WVQwGhGb5FfBQWMZvQW+XVQwGhGb5HfBAWMZvQW+W1QwGhGb5HfBQWMZvQW+X1QwGhGb5E/BAWMZvQW+WNQwGhGb5E/BQWMZvQW+XNQwGhGb5G/BAWMZvQW+WtQwGhGb5G/BQWMZvQW+XtQwGhGb5F/BAWMZvQW+WdQwGhGb5F/BQWMZvQW+XdQwGhGb5H/BAWMZvSWv2auygZpNkOmAAAAAElFTkSuQmCC",
  "base64"
);
const previewAsset = {
  url: "https://cdn.petmagic.ai/editor-qa.png",
  fileName: "preview.png",
  contentType: "image/png",
  fileSizeBytes: png.length,
};
type Payload = ImageTemplatePayload | VideoTemplatePayload;

type EditorApi = {
  uploads: string[];
  saves: Payload[];
  saveMethods: string[];
  failSave: boolean;
  failUpload: boolean;
  failCategories: boolean;
  uploadGate?: Promise<void>;
  template?: AdminTemplate;
  catalogReads: number;
};

async function json(route: Route, body: unknown, status = 200) {
  await route.fulfill({
    status,
    contentType: "application/json",
    headers: {
      "Access-Control-Allow-Origin": route.request().headers().origin ?? "*",
      "Access-Control-Allow-Credentials": "true",
      "Access-Control-Allow-Headers": "Authorization, Content-Type, X-Correlation-ID",
      "Access-Control-Allow-Methods": "GET, POST, PUT, OPTIONS",
    },
    body: JSON.stringify(body),
  });
}

function savedTemplate(payload: Payload, type: "Image" | "Video"): AdminTemplate {
  return {
    ...payload,
    templateId,
    templateType: type,
    status: payload.status ?? "Draft",
    promoBadgeMode: payload.promoBadgeMode ?? "Auto",
    createdAtUtc: "2026-09-05T10:00:00Z",
    updatedAtUtc: "2026-09-05T10:00:00Z",
  } as AdminTemplate;
}

async function openEditor(
  page: Page,
  type: "image" | "video" = "image",
  options: Partial<EditorApi> = {},
  locale = "ru"
) {
  const state: EditorApi = {
    uploads: [],
    saves: [],
    saveMethods: [],
    failSave: false,
    failUpload: false,
    failCategories: false,
    catalogReads: 0,
    ...options,
  };
  await page.route("https://cdn.petmagic.ai/**", (route) =>
    route.fulfill({
      contentType: "image/png",
      headers: { "Access-Control-Allow-Origin": "*" },
      body: png,
    })
  );
  await page.route(`${apiOrigin}/**`, async (route) => {
    const request = route.request();
    const pathname = new URL(request.url()).pathname;
    if (request.method() === "OPTIONS") return json(route, {}, 204);
    if (pathname.startsWith("/api/auth/"))
      return json(route, {
        accessToken: "editor-qa-token",
        refreshToken: "editor-qa-refresh",
        expiresAtUtc: "2099-01-01T00:00:00Z",
        user: {
          userId: "11111111-1111-1111-1111-111111111111",
          email: "admin@petmagic.test",
          displayName: "Editor QA",
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
      });
    if (pathname.startsWith("/api/admin/templates/categories/"))
      return json(
        route,
        state.failCategories
          ? { title: "Categories unavailable" }
          : [
              {
                categoryId: "22222222-2222-2222-2222-222222222222",
                name: "Портреты",
                isArchived: false,
              },
            ],
        state.failCategories ? 503 : 200
      );
    if (pathname.endsWith("/media/upload")) {
      expect(request.method()).toBe("POST");
      expect(request.headers().authorization).toBe("Bearer editor-qa-token");
      const kind = request.postDataBuffer()?.toString().includes("ReferenceMotion")
        ? "ReferenceMotion"
        : "Preview";
      state.uploads.push(kind);
      await state.uploadGate;
      if (state.failUpload) return json(route, { title: "Upload temporarily unavailable" }, 503);
      return json(
        route,
        kind === "Preview"
          ? {
              ...previewAsset,
              thumbnailAsset: previewAsset,
              feedLoopLowAsset: previewAsset,
              detailPreviewAsset: previewAsset,
            }
          : {
              url: "https://cdn.petmagic.ai/reference.mp4",
              fileName: "reference.mp4",
              contentType: "video/mp4",
              fileSizeBytes: 1024,
              durationSeconds: 15,
            }
      );
    }
    if (
      /\/templates\/(image|video)(\/[^/]+)?$/.test(pathname) &&
      ["POST", "PUT"].includes(request.method())
    ) {
      expect(request.headers().authorization).toBe("Bearer editor-qa-token");
      const payload = request.postDataJSON() as Payload;
      state.saves.push(payload);
      state.saveMethods.push(request.method());
      if (state.failSave) return json(route, { title: "Save temporarily unavailable" }, 503);
      return json(route, savedTemplate(payload, type === "video" ? "Video" : "Image"));
    }
    if (pathname === `/api/admin/templates/${templateId}` && state.template)
      return json(route, state.template);
    if (pathname === "/api/admin/templates" || pathname === "/api/admin/templates/")
      state.catalogReads++;
    return json(route, { items: [], totalCount: 0, hasMore: false, unreadCount: 0 });
  });
  await page.goto(`/${locale}`);
  await page.locator("#login-email").fill("admin@petmagic.test");
  await page.locator("#login-password").fill("editor-test-password");
  await page.locator('form button[type="submit"]').click();
  await expect(page).toHaveURL(new RegExp(`/${locale}/dashboard$`));
  await page.goto(
    `/${locale}/templates/${type}/editor${state.template ? `?templateId=${templateId}` : ""}`
  );
  await expect(page.locator("#template-basics")).toBeVisible();
  return state;
}

async function fillDetails(page: Page) {
  await page.locator("#template-title").fill("Портрет питомца");
  await page
    .locator("#template-description")
    .fill("Мягкий свет и выразительный портрет вашего питомца.");
  await page.getByRole("button", { name: "Категория", exact: true }).click();
  await page.getByRole("option", { name: /Портреты/ }).click();
}

async function selectPreview(page: Page) {
  await page
    .locator('#template-preview input[type="file"]')
    .setInputFiles({ name: "preview.png", mimeType: "image/png", buffer: png });
}

test("draft with only a title saves without waiting for a catalog or requiring media", async ({
  page,
}) => {
  const state = await openEditor(page);
  expect(state.catalogReads).toBe(0);
  await expect(
    page.getByRole("button", { name: "Сохранить как черновик", exact: true })
  ).toBeDisabled();
  await page.locator("#template-title").fill("Новый черновик");
  await page.getByRole("button", { name: "Сохранить как черновик", exact: true }).click();
  await expect(page).toHaveURL(/\/ru\/templates\/image$/, { timeout: 20000 });
  expect(state.uploads).toEqual([]);
  expect(state.saves).toHaveLength(1);
  expect(state.saves[0]).toMatchObject({
    title: "Новый черновик",
    status: "Draft",
    requiredInputMediaType: "Image",
  });
});

test("publication uploads a selected preview once and locks the entire operation", async ({
  page,
}) => {
  let releaseUpload!: () => void;
  const state = await openEditor(page, "image", {
    uploadGate: new Promise<void>((resolve) => {
      releaseUpload = resolve;
    }),
  });
  await fillDetails(page);
  await selectPreview(page);
  await expect(page.locator("#template-preview")).toContainText(
    "Выбран · загрузится при сохранении"
  );
  await expect(page.locator("aside img")).toHaveAttribute("src", /^blob:/);
  await page.getByRole("button", { name: "Активен", exact: true }).click();
  await page.getByRole("button", { name: "Сохранить и активировать", exact: true }).click();
  await expect(
    page.getByRole("status").filter({ hasText: "Загружаем и обрабатываем" })
  ).toBeVisible();
  await expect(page.locator("#template-title")).toBeDisabled();
  await expect(page.locator('#template-preview input[type="file"]')).toBeDisabled();
  await expect(page.getByRole("button", { name: "Активен", exact: true })).toBeDisabled();
  await page.locator("form").evaluate((form) => {
    form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
  });
  expect(state.uploads).toEqual(["Preview"]);
  releaseUpload();
  await expect(page).toHaveURL(/\/ru\/templates\/image$/, { timeout: 20000 });
  expect(state.saves).toHaveLength(1);
  expect(state.saves[0]).toMatchObject({
    status: "Active",
    previewAsset,
    thumbnailAsset: previewAsset,
    feedLoopLowAsset: previewAsset,
    supportsGenerationResultInput: false,
  });
});

test("a failed save retains fields and uploaded media for a retry", async ({ page }) => {
  const state = await openEditor(page, "image", { failSave: true });
  await fillDetails(page);
  await selectPreview(page);
  await page.getByRole("button", { name: "Сохранить как черновик", exact: true }).click();
  await expect(
    page.getByRole("alert").filter({ hasText: "Save temporarily unavailable" }).first()
  ).toBeVisible();
  await expect(page.locator("#template-title")).toHaveValue("Портрет питомца");
  await expect(page.locator("#template-title")).toBeEnabled();
  state.failSave = false;
  await page.getByRole("button", { name: "Сохранить как черновик", exact: true }).click();
  await expect(page).toHaveURL(/\/ru\/templates\/image$/, { timeout: 20000 });
  expect(state.uploads).toEqual(["Preview"]);
  expect(state.saves).toHaveLength(2);
  expect(state.saves[1]).toMatchObject({ previewAsset, title: "Портрет питомца" });
});

test("a failed upload retains the selected file and never submits the template", async ({
  page,
}) => {
  const state = await openEditor(page, "image", { failUpload: true });
  await fillDetails(page);
  await selectPreview(page);
  await page.getByRole("button", { name: "Сохранить как черновик", exact: true }).click();
  await expect(
    page.getByRole("alert").filter({ hasText: "Upload temporarily unavailable" }).first()
  ).toBeVisible();
  expect(state.saves).toHaveLength(0);
  await expect(page.locator("#template-preview")).toContainText(
    "Выбран · загрузится при сохранении"
  );
  state.failUpload = false;
  await page.getByRole("button", { name: "Сохранить как черновик", exact: true }).click();
  await expect(page).toHaveURL(/\/ru\/templates\/image$/, { timeout: 20000 });
  expect(state.saves).toHaveLength(1);
});

test("checklist focuses missing fields and reset/navigation protect unsaved edits", async ({
  page,
}) => {
  await openEditor(page);
  await page
    .locator("aside")
    .getByRole("button", { name: "Название Не заполнено", exact: true })
    .click();
  await expect(page.locator("#template-title")).toBeFocused();
  await page.locator("#template-title").fill("Не потерять");
  page.once("dialog", (dialog) => dialog.dismiss());
  await page.getByRole("button", { name: "Отмена", exact: true }).click();
  await expect(page.locator("#template-title")).toHaveValue("Не потерять");
  page.once("dialog", (dialog) => dialog.dismiss());
  await page.locator('a[href="/ru/templates/video"]').first().click();
  await expect(page).toHaveURL(/\/image\/editor$/);
  page.once("dialog", (dialog) => dialog.accept());
  await page.getByRole("button", { name: "Сбросить", exact: true }).click();
  await expect(page.locator("#template-title")).toHaveValue("");
});

test("categories can be retried without discarding typed data", async ({ page }) => {
  const state = await openEditor(page, "image", { failCategories: true });
  await page.locator("#template-title").fill("Категории загрузятся позже");
  await expect(
    page.getByText("Не удалось загрузить категории. Остальные поля доступны.")
  ).toBeVisible({ timeout: 15000 });
  state.failCategories = false;
  await page
    .locator("#template-basics")
    .getByRole("button", { name: /Повторить/ })
    .click();
  await page.getByRole("button", { name: "Категория", exact: true }).click();
  await expect(page.getByRole("option", { name: /Портреты/ })).toBeVisible();
  await expect(page.locator("#template-title")).toHaveValue("Категории загрузятся позже");
});

test("unsupported media is rejected before upload and a valid replacement remains selectable", async ({
  page,
}) => {
  const state = await openEditor(page);
  await page.locator('#template-preview input[type="file"]').setInputFiles({
    name: "notes.txt",
    mimeType: "text/plain",
    buffer: Buffer.from("not an image"),
  });
  await expect(page.locator("#template-preview").getByRole("alert")).toBeVisible();
  expect(state.uploads).toEqual([]);
  await selectPreview(page);
  await expect(page.locator("#template-preview").getByRole("alert")).toHaveCount(0);
  await expect(page.locator("#template-preview")).toContainText(
    "Выбран · загрузится при сохранении"
  );
});

test("video creation uploads both media roles and preserves the generation contract", async ({
  page,
}) => {
  const state = await openEditor(page, "video");
  await fillDetails(page);
  await selectPreview(page);
  // The media endpoint is stubbed: this test verifies multipart roles and save sequencing,
  // while codec probing and derivative generation remain backend integration concerns.
  await page.locator('#template-reference input[type="file"]').setInputFiles({
    name: "reference.mp4",
    mimeType: "video/mp4",
    buffer: Buffer.from("reference-upload-contract-fixture"),
  });
  await page.getByRole("button", { name: "Активен", exact: true }).click();
  await page.getByRole("button", { name: "Сохранить и активировать", exact: true }).click();
  await expect(page).toHaveURL(/\/ru\/templates\/video$/, { timeout: 20000 });
  expect(state.uploads).toEqual(["Preview", "ReferenceMotion"]);
  expect(state.saves).toHaveLength(1);
  expect(state.saves[0]).toMatchObject({
    status: "Active",
    previewAsset,
    preprocessingModel: PREPROCESSING_MODELS[0],
    klingModel: KLING_MODELS[0],
    keepOriginalSound: true,
    requiredInputMediaType: "Image",
    referenceMotionAsset: { durationSeconds: 15, contentType: "video/mp4" },
  });
});

test("editing preserves persisted assets and sends PUT with an empty optional prompt", async ({
  page,
}) => {
  const template = savedTemplate(
    {
      title: "Портрет",
      shortDescription: "Описание",
      category: "Портреты",
      tags: [],
      petPhotoRequirements: ["One pet"],
      status: "Active",
      promoBadgeMode: "Auto",
      isPremium: false,
      isQaOnly: false,
      tokenCost: 20,
      previewAsset,
      thumbnailAsset: previewAsset,
      feedLoopLowAsset: previewAsset,
      imageModel: IMAGE_MODELS[0],
      imagePrompt: "original",
    },
    "Image"
  );
  const state = await openEditor(page, "image", { template });
  await page.locator("#template-ai textarea").fill("");
  await page.getByRole("button", { name: "Сохранить и активировать", exact: true }).click();
  await expect(page).toHaveURL(/\/ru\/templates\/image$/, { timeout: 20000 });
  expect(state.uploads).toEqual([]);
  expect(state.saveMethods).toEqual(["PUT"]);
  expect(state.saves[0]).toMatchObject({
    keepPreviewAsset: true,
    imagePrompt: "",
    status: "Active",
  });
  expect(state.saves[0].previewAsset).toBeUndefined();
});

test("portrait media can be inspected without losing editor focus or data", async ({ page }) => {
  await openEditor(page);
  await page.locator("#template-title").fill("Портрет 2:3");
  await selectPreview(page);
  const trigger = page.locator("#template-preview").getByRole("button", { name: "Открыть крупно" });
  await trigger.click();
  const dialog = page.getByRole("dialog", { name: "Превью", exact: true });
  await expect(dialog).toBeVisible();
  await expect(dialog.locator("img")).toHaveJSProperty("naturalWidth", 120);
  await expect(dialog.locator("img")).toHaveCSS("object-fit", "contain");
  await page.keyboard.press("Escape");
  await expect(dialog).not.toBeVisible();
  await expect(trigger).toBeFocused();
  await expect(page.locator("#template-title")).toHaveValue("Портрет 2:3");
  await trigger.click();
  await dialog.getByRole("button", { name: "Закрыть", exact: true }).click();
  await expect(dialog).not.toBeVisible();
});

for (const type of ["image", "video"] as const) {
  for (const width of [1536, 1280, 390, 320]) {
    test(`${type} editor renders and navigates at ${width}px`, async ({ page }) => {
      await page.setViewportSize({ width, height: 960 });
      await openEditor(page, type);
      const errors: string[] = [];
      const consoleErrors: string[] = [];
      page.on("pageerror", (error) => errors.push(error.message));
      page.on("console", (message) => {
        if (message.type() === "error") consoleErrors.push(message.text());
      });
      expect(await page.title()).toBe("PetMagic Admin");
      await expect(page.getByRole("navigation", { name: "Разделы редактора" })).toBeVisible();
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(
        true
      );
      await expect(
        page.getByText("Application error: a client-side exception has occurred")
      ).toHaveCount(0);
      const mediaFrames = page.locator('#template-media [role="button"]');
      for (const frame of await mediaFrames.all()) {
        const bounds = await frame.boundingBox();
        expect(bounds).not.toBeNull();
        expect(bounds!.width / bounds!.height).toBeCloseTo(2 / 3, 2);
      }
      if (width === 1536) {
        const basics = await page.locator("#template-basics").boundingBox();
        expect(basics!.height).toBeLessThan(510);
      }
      if (width <= 720) {
        const position = await page
          .locator('button[type="submit"]')
          .evaluate((button) => getComputedStyle(button.parentElement!.parentElement!).position);
        expect(position).toBe("static");
      }
      if (process.env.EDITOR_QA_SCREENSHOT_DIR)
        await page.screenshot({
          animations: "disabled",
          path: path.join(process.env.EDITOR_QA_SCREENSHOT_DIR, `editor-${type}-${width}.png`),
        });
      await page
        .getByRole("navigation", { name: "Разделы редактора" })
        .getByRole("button", { name: /Медиа/ })
        .click();
      await expect(page.locator('#template-preview [role="button"]')).toBeFocused();
      await page.getByRole("button", { name: "Активен", exact: true }).click();
      await expect(
        page.getByRole("button", { name: "Сохранить и активировать", exact: true })
      ).toBeDisabled();
      await selectPreview(page);
      await expect(page.locator("#template-preview img")).toHaveJSProperty("naturalWidth", 120);
      await expect(page.locator("#template-preview img")).toHaveJSProperty("naturalHeight", 180);
      await expect(page.locator("#template-preview img")).toHaveCSS("object-fit", "contain");
      await page.getByRole("button", { name: "Включить тёмную тему", exact: true }).click();
      await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
      await page
        .locator("#template-media")
        .evaluate((section) => section.scrollIntoView({ block: "start" }));
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(
        true
      );
      if (process.env.EDITOR_QA_SCREENSHOT_DIR)
        await page.screenshot({
          animations: "disabled",
          path: path.join(
            process.env.EDITOR_QA_SCREENSHOT_DIR,
            `editor-${type}-${width}-dark-media.png`
          ),
        });
      expect(errors).toEqual([]);
      if (process.env.NODE_ENV === "production") expect(consoleErrors).toEqual([]);
    });
  }
}

test("English editor preserves image API defaults", async ({ page }) => {
  await openEditor(page, "image", {}, "en");
  await expect(page.getByRole("navigation", { name: "Editor sections" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Save as draft", exact: true })).toBeDisabled();
});
