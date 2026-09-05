import { expect, test, type Page, type Route } from "@playwright/test";
import { join } from "node:path";

const id = "d31c5839-5889-4d85-88f8-f6ea9c87fe84";
const userId = "11111111-1111-4111-8111-111111111111";
const recipientId = "22222222-2222-4222-8222-222222222222";
const campaign = {
  broadcastId: id,
  audience: "selected",
  subject: "Новости PetMagic",
  status: "partially-failed",
  recipientCount: 12,
  pendingCount: 0,
  sentCount: 10,
  failedCount: 2,
  retryableFailedCount: 2,
  createdAtUtc: "2026-09-05T08:00:00Z",
  updatedAtUtc: "2026-09-05T08:01:00Z",
  completedAtUtc: "2026-09-05T08:01:00Z",
};

async function json(route: Route, body: unknown, status = 200) {
  await route.fulfill({
    status,
    contentType: "application/json",
    headers: {
      "Access-Control-Allow-Origin": route.request().headers().origin ?? "*",
      "Access-Control-Allow-Credentials": "true",
    },
    body: JSON.stringify(body),
  });
}

async function setup(
  page: Page,
  options: {
    empty?: boolean;
    role?: "Admin" | "Moderator";
    failFirstSend?: boolean;
    failHistory?: boolean;
  } = {}
) {
  const role = options.role ?? "Admin";
  const state = {
    sends: [] as { key: string | undefined; body: Record<string, unknown> }[],
    retries: 0,
    historyCalls: 0,
    failHistory: options.failHistory ?? false,
    empty: options.empty ?? false,
    detail: { ...campaign },
  };
  const session = {
    accessToken: "e2e-access",
    refreshToken: "e2e-refresh",
    expiresAtUtc: "2099-01-01T00:00:00Z",
    user: {
      userId,
      email: "admin@petmagic.test",
      displayName: "Admin Operator",
      isPremium: false,
      emailConfirmed: true,
      roles: [role],
      legalAcceptance: {
        termsOfUseAccepted: true,
        privacyPolicyAccepted: true,
        currentTermsOfUseVersion: "1",
        currentPrivacyPolicyVersion: "1",
        requiresAcceptance: false,
      },
    },
  };
  await page.route("https://api.petmagic.test/api/**", async (route) => {
    const url = new URL(route.request().url());
    if (url.pathname.startsWith("/api/auth/")) return json(route, session);
    if (url.pathname.endsWith("/retry-failed")) {
      state.retries++;
      state.detail = {
        ...state.detail,
        retryableFailedCount: 0,
        failedCount: 0,
        pendingCount: 2,
        status: "queued",
      };
      return json(route, { ...state.detail, retriedCount: 2 });
    }
    if (url.pathname === "/api/admin/users/emails") {
      state.sends.push({
        key: route.request().headers()["idempotency-key"],
        body: route.request().postDataJSON(),
      });
      if (options.failFirstSend && state.sends.length === 1)
        return json(route, { title: "Temporary failure", status: 503 }, 503);
      state.empty = false;
      state.detail = {
        ...campaign,
        subject: String(state.sends.at(-1)?.body.subject),
        recipientCount: 1,
        sentCount: 0,
        failedCount: 0,
        pendingCount: 1,
        retryableFailedCount: 0,
        status: "queued",
      };
      return json(route, state.detail, 202);
    }
    if (url.pathname === "/api/admin/users/email-broadcasts") {
      state.historyCalls++;
      if (state.failHistory) return json(route, { title: "History unavailable", status: 403 }, 403);
      const filtered = url.searchParams.get("status") === "failed";
      return json(route, {
        items: state.empty || filtered ? [] : [state.detail],
        totalCount: state.empty || filtered ? 0 : 12,
        skip: Number(url.searchParams.get("skip") ?? 0),
        take: 10,
        hasMore: true,
      });
    }
    if (url.pathname === "/api/admin/users/email-broadcasts/" + id)
      return json(route, state.detail);
    if (url.pathname === "/api/admin/users")
      return json(route, {
        items: [
          {
            userId: recipientId,
            email: "alex@petmagic.test",
            displayName: "Alex Test",
            roles: ["User"],
            isPremium: true,
            isActive: true,
            emailConfirmed: true,
            createdAtUtc: campaign.createdAtUtc,
          },
          {
            userId: "33333333-3333-4333-8333-333333333333",
            email: "pending@petmagic.test",
            displayName: "Pending Test",
            roles: ["User"],
            isPremium: false,
            isActive: true,
            emailConfirmed: false,
            createdAtUtc: campaign.createdAtUtc,
          },
        ],
        totalCount: 2,
        skip: 0,
        take: 24,
        hasMore: false,
      });
    if (url.pathname.includes("dashboard-metrics"))
      return json(route, {
        totalUsers: 2,
        activeUsers: 2,
        premiumUsers: 1,
        blockedUsers: 0,
        newUsersLast30Days: 2,
      });
    return json(route, { items: [], totalCount: 0, hasMore: false, skip: 0, take: 20 });
  });
  await page.goto("/ru");
  await page.locator("#login-email").fill("admin@petmagic.test");
  await page.locator("#login-password").fill("synthetic-password");
  await page.locator('form button[type="submit"]').click();
  await expect(page).toHaveURL(role === "Admin" ? /[/]ru[/]dashboard$/ : /[/]ru[/]support$/);
  return state;
}

async function screenshot(page: Page, name: string) {
  if (process.env.ADMIN_EMAIL_SCREENSHOT_DIR) {
    await page.evaluate(() => {
      window.scrollTo(0, 0);
      document.getElementById("qa-evidence-label")?.remove();
      const label = document.createElement("div");
      label.id = "qa-evidence-label";
      label.textContent = "Локальный QA · синтетические данные · письма не отправляются";
      label.style.cssText =
        "position:fixed;bottom:0;left:0;right:0;padding:6px 12px;background:#10213d;color:white;font:11px sans-serif;z-index:9999;text-align:center";
      document.body.append(label);
    });
    await page.screenshot({
      path: join(process.env.ADMIN_EMAIL_SCREENSHOT_DIR, name + ".png"),
      fullPage: false,
    });
    await page.evaluate(() => document.getElementById("qa-evidence-label")?.remove());
  }
}

test("email campaigns have their own page, filter, pagination, retry and legacy links", async ({
  page,
}) => {
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("console", (message) => {
    if (message.type() === "error") errors.push(message.text());
  });
  const state = await setup(page);
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.getByRole("link", { name: "Email-рассылки", exact: true }).click();
  await expect(page).toHaveURL(/[/]ru[/]email-broadcasts$/);
  await expect(page.getByRole("heading", { name: "Email-рассылки", exact: true })).toBeVisible();
  await expect(page).toHaveTitle(/PetMagic/);
  await page.getByRole("button", { name: "Открыть рассылку: Новости PetMagic" }).click();
  await expect(page).toHaveURL(new RegExp("selected=" + id));
  await expect(page.getByRole("button", { name: "Повторить ошибки (2)" })).toBeVisible();
  await screenshot(page, "email-history-desktop");
  await page.setViewportSize({ width: 390, height: 844 });
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(
    true
  );
  await expect(page.locator('aside[aria-hidden="true"]')).toBeHidden();
  await screenshot(page, "email-history-mobile");
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.getByRole("button", { name: "Повторить ошибки (2)" }).click();
  expect(state.retries).toBe(0);
  await page.getByRole("button", { name: "Повторить неуспешные", exact: true }).click();
  await expect.poll(() => state.retries).toBe(1);
  await expect(page.getByRole("button", { name: "Повторить ошибки (2)" })).toHaveCount(0);
  await page.goto("/ru/users?tab=broadcasts&selected=" + id);
  await expect(page).toHaveURL(new RegExp("/ru/email-broadcasts[?]selected=" + id));
  await expect(page.getByRole("heading", { name: "Новости PetMagic", exact: true })).toBeVisible();
  await page
    .getByRole("dialog")
    .getByRole("button", { name: "Закрыть инспектор рассылки" })
    .click();
  await page.getByRole("button", { name: "Статус рассылки" }).click();
  await page.getByRole("option", { name: "Не выполнена", exact: true }).click();
  await expect(page).toHaveURL(/broadcastStatus=failed/);
  await expect(page.getByText("Рассылок с выбранным статусом нет.", { exact: true })).toBeVisible();
  await page.getByRole("button", { name: "Сбросить фильтр" }).click();
  await page.getByRole("button", { name: "Вперёд", exact: true }).click();
  await expect(page).toHaveURL(/broadcastPage=2/);
  await page.reload();
  await expect(
    page.getByRole("button", { name: "Открыть рассылку: Новости PetMagic" })
  ).toBeVisible();
  await page.goto("/ru/users");
  await expect(page.getByRole("heading", { name: "Пользователи", exact: true })).toBeVisible();
  await expect(page.getByRole("heading", { name: "История email-рассылок" })).toHaveCount(0);
  expect(errors).toEqual([]);
});

test("create selected email campaign with review and idempotent retry without leaving campaigns", async ({
  page,
}) => {
  const state = await setup(page, { empty: true, failFirstSend: true });
  await page.goto("/ru/email-broadcasts");
  await expect(page.getByText("Первое письмо начинается здесь", { exact: true })).toBeVisible();
  await screenshot(page, "email-empty-desktop");
  await page.getByRole("button", { name: "Создать рассылку", exact: true }).first().click();
  const editor = page.getByRole("region", { name: "Новая рассылка" });
  const dialog = page.getByRole("dialog");
  await editor.getByRole("radio", { name: /Выбранные пользователи/ }).check();
  await editor.getByRole("textbox", { name: "Поиск", exact: true }).fill("Alex");
  await editor.getByRole("checkbox", { name: "Выбрать получателя: Alex Test" }).check();
  await expect(
    editor.getByRole("checkbox", { name: "Выбрать получателя: Pending Test" })
  ).toBeDisabled();
  await editor.getByRole("textbox", { name: "Тема письма", exact: true }).fill("Проверка рассылки");
  await editor
    .getByRole("textbox", { name: "Текст письма", exact: true })
    .fill("Тестовое письмо для проверки интерфейса.");
  await editor.getByRole("checkbox", { name: /подтверждаю/i }).check();
  await expect(
    editor.getByRole("complementary").getByText("Проверка рассылки", { exact: true })
  ).toBeVisible();
  await editor.getByRole("button", { name: "Телефон", exact: true }).click();
  await expect(editor.getByRole("button", { name: "Телефон", exact: true })).toHaveAttribute(
    "aria-pressed",
    "true"
  );
  await editor.getByRole("button", { name: "Компьютер", exact: true }).click();
  await page.setViewportSize({ width: 1440, height: 1100 });
  await screenshot(page, "email-compose-desktop");
  await editor.getByRole("button", { name: "Проверить письмо", exact: true }).first().click();
  expect(state.sends).toHaveLength(0);
  await expect(
    dialog.getByText("Тестовое письмо для проверки интерфейса.", { exact: true })
  ).toBeVisible();
  await dialog.getByRole("button", { name: "Поставить в очередь" }).click();
  await expect(dialog.getByRole("alert")).toBeVisible();
  await dialog.getByRole("button", { name: "Поставить в очередь" }).click();
  await expect(page).toHaveURL(new RegExp("/ru/email-broadcasts[?]selected=" + id));
  await expect(page.getByRole("dialog", { name: "Проверить рассылку" })).toHaveCount(0);
  await expect(page.getByText(/Рассылка создана. Получателей: 1/)).toBeVisible();
  expect(state.sends).toHaveLength(2);
  expect(state.sends[0].key).toBeTruthy();
  expect(state.sends[0]).toEqual(state.sends[1]);
  expect(state.sends[1].body).toMatchObject({ audience: "selected", userIds: [recipientId] });
});

test("mobile campaign editor keeps user selection and warns before discarding changes", async ({
  page,
}) => {
  await setup(page, { empty: true });
  await page.goto("/ru/users");
  await page.getByRole("checkbox", { name: "Выбрать получателя: Alex Test" }).check();
  await page.getByRole("button", { name: "Email-рассылка", exact: true }).first().click();
  await expect(page).toHaveURL(/[/]ru[/]email-broadcasts[?]compose=1/);
  await expect(page.getByRole("radio", { name: /Выбранные пользователи/ })).toBeChecked();
  await page.getByRole("button", { name: "Отмена", exact: true }).click();
  await expect(page).toHaveURL(/[/]ru[/]email-broadcasts$/);
  await page.setViewportSize({ width: 390, height: 844 });
  const create = page.getByRole("button", { name: "Создать рассылку", exact: true }).first();
  await create.click();
  await expect(page.getByRole("region", { name: "Новая рассылка" })).toBeVisible();
  await screenshot(page, "email-compose-mobile");
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(
    true
  );
  await page.getByRole("textbox", { name: "Тема письма", exact: true }).fill("Черновик");
  await page.getByRole("button", { name: "Отмена", exact: true }).click();
  await expect(page.getByRole("dialog", { name: "Закрыть новую рассылку?" })).toBeVisible();
  await page.getByRole("button", { name: "Продолжить редактирование" }).click();
  await expect(page.getByRole("textbox", { name: "Тема письма", exact: true })).toHaveValue(
    "Черновик"
  );
  await page.getByRole("button", { name: "Отмена", exact: true }).click();
  await page.getByRole("button", { name: "Закрыть без сохранения" }).click();
  await expect(page.getByRole("region", { name: "Новая рассылка" })).toHaveCount(0);
  await expect(create).toBeVisible();
  await screenshot(page, "email-empty-mobile");
});

test("history errors are recoverable", async ({ page }) => {
  const state = await setup(page, { failHistory: true });
  await page.goto("/ru/email-broadcasts");
  await expect(
    page.getByText("Не удалось загрузить историю рассылок.", { exact: true })
  ).toBeVisible();
  state.failHistory = false;
  await page.getByRole("button", { name: "Повторить загрузку", exact: true }).click();
  await expect(
    page.getByRole("button", { name: "Открыть рассылку: Новости PetMagic" })
  ).toBeVisible();
});

test("moderator cannot navigate to campaigns or load campaign data", async ({ page }) => {
  const state = await setup(page, { role: "Moderator" });
  await expect(page.getByRole("link", { name: "Email-рассылки", exact: true })).toHaveCount(0);
  await page.goto("/ru/email-broadcasts");
  await expect(page).toHaveURL(/[/]ru[/]support$/);
  expect(state.historyCalls).toBe(0);
});

test("anonymous visitors are redirected before loading campaigns", async ({ page }) => {
  let historyCalls = 0;
  await page.route("https://api.petmagic.test/api/**", async (route) => {
    if (route.request().url().includes("email-broadcasts")) historyCalls++;
    await json(route, { title: "Unauthorized", status: 401 }, 401);
  });
  await page.goto("/ru/email-broadcasts");
  await expect(page).toHaveURL(/[/]ru$/);
  await expect(page.locator("#login-email")).toBeVisible();
  expect(historyCalls).toBe(0);
});
