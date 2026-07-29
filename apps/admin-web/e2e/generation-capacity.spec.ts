import { expect, test, type Page, type Route } from "@playwright/test";

const apiOrigin = "https://api.petmagic.test";

function createSession() {
  return {
    accessToken: "capacity-admin-token",
    refreshToken: "capacity-admin-refresh",
    expiresAtUtc: "2099-01-01T00:00:00Z",
    user: {
      userId: "11111111-1111-4111-8111-111111111111",
      email: "capacity.admin@petmagic.test",
      displayName: "Capacity Admin",
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

function profile(globalLimit: number) {
  if (globalLimit === 38) {
    return {
      globalMaxConcurrentGenerations: 38,
      imageReservedConcurrentGenerations: 14,
      imageProtectedConcurrentGenerations: 14,
      imageMaxConcurrentGenerations: 33,
      videoReservedConcurrentGenerations: 10,
      videoMaxConcurrentGenerations: 19,
      videoBorrowMaxConcurrentGenerations: 10,
      videoPreprocessingMaxConcurrentGenerations: 5,
    };
  }

  return {
    globalMaxConcurrentGenerations: 8,
    imageReservedConcurrentGenerations: 3,
    imageProtectedConcurrentGenerations: 3,
    imageMaxConcurrentGenerations: 7,
    videoReservedConcurrentGenerations: 2,
    videoMaxConcurrentGenerations: 4,
    videoBorrowMaxConcurrentGenerations: 2,
    videoPreprocessingMaxConcurrentGenerations: 1,
  };
}

function createControl(overrides: Partial<Record<string, unknown>> = {}) {
  const effectiveProfile = profile(8);
  return {
    revision: 4,
    admissionEnabled: true,
    confirmedFalConcurrencyLimit: 10,
    confirmedAtUtc: "2026-07-29T10:00:00Z",
    reservedHeadroom: 2,
    applicationHardCeiling: 38,
    effectiveGlobalLimit: 8,
    policy: effectiveProfile,
    effectiveProfile,
    balance: {
      state: "low",
      currentBalanceUsd: 8.25,
      lastSuccessfulAtUtc: "2026-07-29T10:05:00Z",
      checkedAtUtc: "2026-07-29T10:05:00Z",
    },
    queue: {
      totalDepth: 7,
      imageDepth: 5,
      videoDepth: 2,
      oldestQueuedAtUtc: "2026-07-29T10:01:00Z",
      stages: [
        { stage: "image_generation", count: 5, oldestAtUtc: "2026-07-29T10:01:00Z" },
        { stage: "video_generation", count: 2, oldestAtUtc: "2026-07-29T10:02:00Z" },
      ],
    },
    lanes: {
      inFlightTotal: 6,
      imageInFlight: 4,
      videoInFlight: 2,
      videoPreprocessingInFlight: 1,
      nativeSlotsInUse: 5,
      borrowedSlotsInUse: 1,
      reservedSlotsAvailable: 2,
      submissionUnknownCount: 0,
    },
    worker: {
      instanceCount: 1,
      heartbeatAtUtc: "2026-07-29T10:05:00Z",
      lastProgressAtUtc: "2026-07-29T10:04:58Z",
      appliedPolicyRevision: 4,
      schedulerV2Enabled: true,
      dispatchConcurrency: 4,
      reconciliationConcurrency: 4,
      mediaImportConcurrency: 1,
      maintenanceConcurrency: 1,
    },
    alerts: [
      {
        alertId: "fal-balance-low",
        statusChangedAtUtc: "2026-07-29T10:05:00Z",
        severity: "warning",
        title: "fal.ai balance is low",
        message: "Top up the provider balance before the advertising launch.",
      },
    ],
    generatedAtUtc: "2026-07-29T10:05:00Z",
    ...overrides,
  };
}

function corsHeaders(route: Route) {
  return {
    "Access-Control-Allow-Origin": route.request().headers().origin ?? "http://127.0.0.1",
    "Access-Control-Allow-Credentials": "true",
    "Access-Control-Allow-Headers":
      "Authorization, Content-Type, Idempotency-Key, X-Correlation-ID",
    "Access-Control-Allow-Methods": "GET, POST, PUT, OPTIONS",
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

async function installMocks(page: Page, initialControl = createControl()) {
  let control = initialControl;
  const policyRequests: Array<{ body: Record<string, unknown>; idempotencyKey: string | null }> =
    [];

  await page.route(apiOrigin + "/api/**", async (route) => {
    const request = route.request();
    const url = new URL(request.url());

    if (request.method() === "OPTIONS") {
      await route.fulfill({ status: 204, headers: corsHeaders(route) });
      return;
    }

    if (url.pathname === "/api/auth/login" || url.pathname === "/api/auth/refresh") {
      await fulfillJson(route, createSession());
      return;
    }

    if (url.pathname === "/api/admin/templates/generation-control/policy") {
      const body = request.postDataJSON() as Record<string, unknown>;
      policyRequests.push({
        body,
        idempotencyKey: request.headers()["idempotency-key"] ?? null,
      });
      const nextLimit = Number(body.confirmedFalConcurrencyLimit);
      const nextReserve = Number(body.reservedHeadroom);
      const nextCeiling = Number(body.applicationHardCeiling);
      const nextGlobal = Math.min(nextCeiling, nextLimit - nextReserve);
      control = createControl({
        revision: 5,
        admissionEnabled: Boolean(body.admissionEnabled),
        confirmedFalConcurrencyLimit: nextLimit,
        reservedHeadroom: nextReserve,
        applicationHardCeiling: nextCeiling,
        effectiveGlobalLimit: nextGlobal,
        effectiveProfile: profile(nextGlobal),
        worker: { ...control.worker, appliedPolicyRevision: 5 },
      });
      await fulfillJson(route, control);
      return;
    }

    if (url.pathname === "/api/admin/templates/generation-control/provider/refresh") {
      control = createControl({
        ...control,
        balance: {
          ...control.balance,
          state: "fresh",
          currentBalanceUsd: 20,
          checkedAtUtc: "2026-07-29T10:10:00Z",
        },
        alerts: [],
      });
      await fulfillJson(route, control);
      return;
    }

    if (url.pathname === "/api/admin/templates/generation-control") {
      await fulfillJson(route, control);
      return;
    }

    if (url.pathname === "/api/admin/templates/generations/metrics") {
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
        generatedAtUtc: "2026-07-29T10:05:00Z",
      });
      return;
    }

    if (url.pathname === "/api/admin/templates/generations") {
      await fulfillJson(route, {
        items: [],
        totalCount: 0,
        skip: 0,
        take: 25,
        hasMore: false,
        generatedAtUtc: "2026-07-29T10:05:00Z",
      });
      return;
    }

    await fulfillJson(route, { items: [], totalCount: 0 });
  });

  return {
    getPolicyRequests: () => policyRequests,
  };
}

async function loginAsAdmin(page: Page, locale: "en" | "ru" = "en") {
  await page.goto(`/${locale}`);
  await page.locator("#login-email").fill("capacity.admin@petmagic.test");
  await page.locator("#login-password").fill("production-ready-password");
  await page.locator('form button[type="submit"]').click();
  await expect(page).toHaveURL(new RegExp(`/${locale}/dashboard$`));
}

test("generation capacity previews and saves a scale-up with optimistic concurrency", async ({
  page,
}) => {
  const api = await installMocks(page);
  await page.setViewportSize({ width: 1440, height: 960 });
  await loginAsAdmin(page);
  await page.goto("/en/generations");

  await expect(
    page.getByRole("heading", { name: "Capacity and fal.ai", exact: true })
  ).toBeVisible();
  await expect(page.getByText("fal.ai balance is low", { exact: true })).toBeVisible();
  await page.getByRole("button", { name: "Configure", exact: true }).click();

  const dialog = page.getByRole("dialog", { name: "Configure generation capacity", exact: true });
  await dialog.getByRole("textbox", { name: "Confirmed fal.ai concurrency limit" }).fill("40");
  await dialog
    .getByRole("textbox", { name: "Change reason" })
    .fill("Verified the new concurrency limit in the fal.ai Dashboard.");
  const preview = dialog.getByRole("region", { name: "Balanced profile preview" });
  await expect(preview.getByText("38", { exact: true }).first()).toBeVisible();
  await expect(preview.getByText("10", { exact: true }).first()).toBeVisible();
  await dialog.getByRole("button", { name: "Save policy", exact: true }).click();

  await expect(dialog).toBeHidden();
  await expect.poll(() => api.getPolicyRequests().length).toBe(1);
  expect(api.getPolicyRequests()[0]).toMatchObject({
    body: {
      expectedRevision: 4,
      confirmedFalConcurrencyLimit: 40,
      reservedHeadroom: 2,
      applicationHardCeiling: 38,
      admissionEnabled: true,
    },
  });
  expect(api.getPolicyRequests()[0]?.idempotencyKey).toMatch(/^generation-policy:/);
});

test("pausing admission requires explicit acknowledgement and fits a 390px viewport", async ({
  page,
}) => {
  const api = await installMocks(page);
  await page.setViewportSize({ width: 390, height: 844 });
  await loginAsAdmin(page);
  await page.goto("/en/generations");
  await page.getByRole("button", { name: "Configure", exact: true }).click();

  const dialog = page.getByRole("dialog", { name: "Configure generation capacity", exact: true });
  await dialog.getByRole("checkbox", { name: "Accept new generations" }).uncheck();
  await dialog
    .getByRole("textbox", { name: "Change reason" })
    .fill("Pausing admission for a controlled production rollout.");
  const save = dialog.getByRole("button", { name: "Save policy", exact: true });
  await expect(save).toBeDisabled();
  await dialog
    .getByRole("checkbox", { name: /I reviewed fal.ai, the queue, and active generations/ })
    .check();
  await expect(save).toBeEnabled();

  const dimensions = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
    dialogWidth:
      document.querySelector<HTMLElement>('[role="dialog"]')?.getBoundingClientRect().width ?? 0,
  }));
  expect(dimensions.scrollWidth).toBeLessThanOrEqual(dimensions.clientWidth);
  expect(dimensions.dialogWidth).toBeLessThanOrEqual(390);

  await save.click();
  await expect.poll(() => api.getPolicyRequests().length).toBe(1);
  expect(api.getPolicyRequests()[0]?.body.admissionEnabled).toBe(false);
});

test("resuming admission also requires explicit acknowledgement", async ({ page }) => {
  const api = await installMocks(page, createControl({ admissionEnabled: false }));
  await page.setViewportSize({ width: 1440, height: 960 });
  await loginAsAdmin(page);
  await page.goto("/en/generations");
  await page.getByRole("button", { name: "Configure", exact: true }).click();

  const dialog = page.getByRole("dialog", {
    name: "Configure generation capacity",
    exact: true,
  });
  await dialog.getByRole("checkbox", { name: "Accept new generations" }).check();
  await dialog
    .getByRole("textbox", { name: "Change reason" })
    .fill("Resuming admission after provider and worker verification.");
  const save = dialog.getByRole("button", { name: "Save policy", exact: true });
  await expect(save).toBeDisabled();
  await dialog
    .getByRole("checkbox", { name: /I reviewed fal.ai, the queue, and active generations/ })
    .check();
  await expect(save).toBeEnabled();

  await save.click();
  await expect.poll(() => api.getPolicyRequests().length).toBe(1);
  expect(api.getPolicyRequests()[0]?.body.admissionEnabled).toBe(true);
});

test("localizes known capacity alerts and does not duplicate their transition after reload", async ({
  page,
}) => {
  await installMocks(page);
  await page.setViewportSize({ width: 1440, height: 960 });
  await loginAsAdmin(page, "ru");
  await page.goto("/ru/generations");

  await expect(page.getByText("Низкий баланс fal.ai", { exact: true })).toBeVisible();
  await expect(page.getByText("fal.ai balance is low", { exact: true })).toHaveCount(0);

  const userId = createSession().user.userId;
  const transitionStorageKey = `petmagic.admin.generation-capacity-alert-transitions.v1:${encodeURIComponent(userId)}`;
  const notificationStorageKey = `petmagic.admin.notifications.v2:${encodeURIComponent(userId)}`;
  const countLocalizedNotifications = () =>
    page.evaluate(
      ({ storageKey, title }) => {
        const rawValue = window.localStorage.getItem(storageKey);
        if (!rawValue) return 0;
        const value = JSON.parse(rawValue) as Array<{ title?: string }>;
        return value.filter((notification) => notification.title === title).length;
      },
      {
        storageKey: notificationStorageKey,
        title: "Низкий баланс fal.ai",
      }
    );

  await expect
    .poll(() =>
      page.evaluate(
        ({ storageKey, transitionKey }) =>
          JSON.parse(window.localStorage.getItem(storageKey) ?? "[]").includes(transitionKey),
        {
          storageKey: transitionStorageKey,
          transitionKey: "fal-balance-low:2026-07-29T10:05:00Z",
        }
      )
    )
    .toBe(true);
  await expect.poll(countLocalizedNotifications).toBe(1);

  await page.reload();
  await expect(page.getByText("Низкий баланс fal.ai", { exact: true })).toBeVisible();
  await expect.poll(countLocalizedNotifications).toBe(1);
});

test("surfaces ambiguous provider submissions as occupied capacity requiring reconciliation", async ({
  page,
}) => {
  const base = createControl();
  await installMocks(
    page,
    createControl({
      lanes: { ...base.lanes, submissionUnknownCount: 2 },
      alerts: [
        {
          alertId: "generation-provider-submission-unknown",
          statusChangedAtUtc: "2026-07-29T10:03:00Z",
          severity: "critical",
          title: "Provider submissions require reconciliation",
          message: "2 ambiguous submissions occupy capacity.",
        },
      ],
    })
  );
  await loginAsAdmin(page);
  await page.goto("/en/generations");

  await expect(
    page.getByText("fal.ai submissions require reconciliation", { exact: true })
  ).toBeVisible();
  await page.getByText("Worker and lanes", { exact: true }).click();
  const unknownRow = page.getByText("Provider submits to reconcile", { exact: true }).locator("..");
  await expect(unknownRow).toContainText("2");
});

test("shows unknown worker runtime instead of claiming compatibility mode before heartbeat", async ({
  page,
}) => {
  const base = createControl();
  await installMocks(
    page,
    createControl({
      worker: {
        ...base.worker,
        instanceCount: 0,
        heartbeatAtUtc: null,
        lastProgressAtUtc: null,
        appliedPolicyRevision: null,
        schedulerV2Enabled: null,
        dispatchConcurrency: null,
        reconciliationConcurrency: null,
        mediaImportConcurrency: null,
        maintenanceConcurrency: null,
      },
      alerts: [
        {
          alertId: "generation-worker-heartbeat-missing",
          statusChangedAtUtc: "2026-07-29T10:05:00Z",
          severity: "critical",
          title: "Generation worker heartbeat is missing",
          message: "No healthy generation worker reported during the last two minutes.",
        },
      ],
    })
  );
  await loginAsAdmin(page);
  await page.goto("/en/generations");

  await expect(
    page.getByText("Generation worker heartbeat is missing", { exact: true })
  ).toBeVisible();
  await page.getByText("Worker and lanes", { exact: true }).click();
  await expect(page.getByText("Compatibility loop", { exact: true })).toHaveCount(0);
  await expect(page.getByText("No data", { exact: true })).toHaveCount(5);
});
