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
    generatedAtUtc: new Date().toISOString(),
    ...overrides,
  };
}

function createRecoveryAttempt(overrides: Partial<Record<string, unknown>> = {}) {
  return {
    attemptId: "9c97c35e-4da1-4de1-8d87-8b02f9fce2ad",
    generationId: "a8b75673-c816-4900-98b6-9ea5846b4198",
    stage: "video_generation",
    ordinal: 1,
    state: "submission_unknown",
    attemptVersion: 4,
    providerRequestId: null,
    createdAtUtc: "2026-07-29T09:55:00Z",
    updatedAtUtc: "2026-07-29T10:03:00Z",
    submittedAtUtc: null,
    submissionDeadlineAtUtc: "2026-07-29T09:57:00Z",
    processingDeadlineAtUtc: "2026-07-29T10:10:00Z",
    reconciliationDeadlineAtUtc: "2026-07-29T10:03:00Z",
    errorCode: "templates.provider_submission_unknown",
    evidenceNeeded: "correlated_accepted_or_confirmed_not_found",
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

async function installMocks(
  page: Page,
  initialControl = createControl(),
  options: {
    policyConflictsBeforeSuccess?: number;
    policyConflictRefreshFails?: boolean;
    providerRefreshOutcome?: "refreshed" | "coalesced" | "failed";
    providerRecoveryItems?: Array<Record<string, unknown>>;
    providerResolutionConflictsBeforeSuccess?: number;
    providerConflictRefreshFails?: boolean;
    providerConflictRefreshDelayMs?: number;
    providerRecoveryRefundScheduled?: boolean;
  } = {}
) {
  let control = initialControl;
  let failNextControlRead = false;
  let failNextRecoveryRead = false;
  let delayNextRecoveryRead = false;
  let providerRecoveryItems = [...(options.providerRecoveryItems ?? [])];
  let policyConflictsRemaining = options.policyConflictsBeforeSuccess ?? 0;
  let providerResolutionConflictsRemaining = options.providerResolutionConflictsBeforeSuccess ?? 0;
  const policyRequests: Array<{ body: Record<string, unknown>; idempotencyKey: string | null }> =
    [];
  const recoveryRequests: Array<{
    attemptId: string;
    body: Record<string, unknown>;
    idempotencyKey: string | null;
  }> = [];

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
      if (policyConflictsRemaining > 0) {
        policyConflictsRemaining -= 1;
        failNextControlRead = options.policyConflictRefreshFails ?? false;
        const nextRevision = Number(control.revision) + 1;
        control = createControl({
          ...control,
          revision: nextRevision,
          worker: { ...control.worker, appliedPolicyRevision: nextRevision },
          generatedAtUtc: new Date().toISOString(),
        });
        await fulfillJson(route, { title: "Generation control policy conflict", status: 409 }, 409);
        return;
      }

      const nextLimit = Number(body.confirmedFalConcurrencyLimit);
      const nextReserve = Number(body.reservedHeadroom);
      const nextCeiling = Number(body.applicationHardCeiling);
      const nextGlobal = Math.min(nextCeiling, nextLimit - nextReserve);
      const nextRevision = Number(control.revision) + 1;
      control = createControl({
        revision: nextRevision,
        admissionEnabled: Boolean(body.admissionEnabled),
        confirmedFalConcurrencyLimit: nextLimit,
        confirmedAtUtc: body.confirmFalConcurrencyLimit
          ? new Date().toISOString()
          : control.confirmedAtUtc,
        reservedHeadroom: nextReserve,
        applicationHardCeiling: nextCeiling,
        effectiveGlobalLimit: nextGlobal,
        effectiveProfile: profile(nextGlobal),
        worker: { ...control.worker, appliedPolicyRevision: nextRevision },
      });
      await fulfillJson(route, control);
      return;
    }

    if (url.pathname === "/api/admin/templates/generation-control/provider/refresh") {
      const outcome = options.providerRefreshOutcome ?? "refreshed";
      if (outcome === "refreshed") {
        control = createControl({
          ...control,
          balance: {
            ...control.balance,
            state: "fresh",
            currentBalanceUsd: 20,
            checkedAtUtc: "2026-07-29T10:10:00Z",
            lastSuccessfulAtUtc: "2026-07-29T10:10:00Z",
          },
          alerts: [],
          generatedAtUtc: new Date().toISOString(),
        });
      }
      await fulfillJson(route, {
        outcome,
        checkedAtUtc: control.balance.checkedAtUtc,
        lastSuccessfulAtUtc: control.balance.lastSuccessfulAtUtc,
        errorCode: outcome === "failed" ? "provider.refresh_failed" : null,
        control,
      });
      return;
    }

    if (url.pathname === "/api/admin/templates/generation-control/provider-attempts/recovery") {
      if (failNextRecoveryRead) {
        failNextRecoveryRead = false;
        delayNextRecoveryRead = (options.providerConflictRefreshDelayMs ?? 0) > 0;
        await fulfillJson(route, { title: "Provider recovery unavailable", status: 503 }, 503);
        return;
      }
      if (delayNextRecoveryRead) {
        delayNextRecoveryRead = false;
        await new Promise((resolve) =>
          setTimeout(resolve, options.providerConflictRefreshDelayMs ?? 0)
        );
      }
      const requestedSkip = Number.parseInt(url.searchParams.get("skip") ?? "0", 10);
      const requestedTake = Number.parseInt(url.searchParams.get("take") ?? "25", 10);
      const skip = Number.isFinite(requestedSkip) ? Math.max(0, requestedSkip) : 0;
      const take = Number.isFinite(requestedTake) ? Math.min(100, Math.max(1, requestedTake)) : 25;
      const items = providerRecoveryItems.slice(skip, skip + take);
      await fulfillJson(route, {
        items,
        totalCount: providerRecoveryItems.length,
        skip,
        take,
        hasMore: skip + items.length < providerRecoveryItems.length,
        generatedAtUtc: new Date().toISOString(),
      });
      return;
    }

    if (
      request.method() === "POST" &&
      url.pathname.startsWith("/api/admin/templates/generation-control/provider-attempts/") &&
      url.pathname.endsWith("/resolve")
    ) {
      const attemptId = url.pathname.split("/").at(-2) ?? "";
      const body = request.postDataJSON() as Record<string, unknown>;
      recoveryRequests.push({
        attemptId,
        body,
        idempotencyKey: request.headers()["idempotency-key"] ?? null,
      });
      if (providerResolutionConflictsRemaining > 0) {
        providerResolutionConflictsRemaining -= 1;
        providerRecoveryItems = providerRecoveryItems.map((candidate) =>
          candidate.attemptId === attemptId
            ? {
                ...candidate,
                attemptVersion: Number(candidate.attemptVersion) + 1,
                updatedAtUtc: new Date().toISOString(),
              }
            : candidate
        );
        failNextRecoveryRead = options.providerConflictRefreshFails ?? false;
        delayNextRecoveryRead =
          !failNextRecoveryRead && (options.providerConflictRefreshDelayMs ?? 0) > 0;
        await fulfillJson(route, { title: "Provider attempt conflict", status: 409 }, 409);
        return;
      }
      const resolvedAttempt = providerRecoveryItems.find(
        (candidate) => candidate.attemptId === attemptId
      );
      providerRecoveryItems = providerRecoveryItems.filter(
        (candidate) => candidate.attemptId !== attemptId
      );
      control = createControl({
        ...control,
        lanes: {
          ...control.lanes,
          submissionUnknownCount: providerRecoveryItems.length,
        },
        alerts: providerRecoveryItems.length > 0 ? control.alerts : [],
        generatedAtUtc: new Date().toISOString(),
      });
      await fulfillJson(route, {
        providerAttemptId: attemptId,
        generationId: resolvedAttempt?.generationId,
        resolution: body.resolution,
        attemptState: body.resolution === "correlated_accepted" ? "ProviderQueued" : "Cancelled",
        attemptVersion: Number(body.expectedAttemptVersion) + 1,
        refundScheduled:
          body.resolution === "confirmed_not_found" &&
          (options.providerRecoveryRefundScheduled ?? true),
        resolvedAtUtc: new Date().toISOString(),
      });
      return;
    }

    if (url.pathname === "/api/admin/templates/generation-control") {
      if (failNextControlRead) {
        failNextControlRead = false;
        await fulfillJson(route, { title: "Generation control unavailable", status: 503 }, 503);
        return;
      }
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
    getRecoveryRequests: () => recoveryRequests,
  };
}

async function loginAsAdmin(page: Page, locale: "en" | "ru" = "en") {
  await page.goto(`/${locale}`);
  await page.locator("#login-email").fill("capacity.admin@petmagic.test");
  await page.locator("#login-password").fill("production-ready-password");
  await page.locator('form button[type="submit"]').click();
  await expect(page).toHaveURL(new RegExp(`/${locale}/dashboard$`));
}

async function readPersistedNotificationMessages(page: Page): Promise<string[]> {
  const storageKey = `petmagic.admin.notifications.v2:${encodeURIComponent(createSession().user.userId)}`;
  return page.evaluate((key) => {
    const rawValue = window.localStorage.getItem(key);
    if (!rawValue) return [];
    const notifications = JSON.parse(rawValue) as Array<{ message?: string }>;
    return notifications
      .map((notification) => notification.message)
      .filter((message): message is string => typeof message === "string");
  }, storageKey);
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
  const confirmedLimit = dialog.getByRole("textbox", {
    name: "Confirmed fal.ai concurrency limit",
  });
  const reserve = dialog.getByRole("textbox", { name: "Capacity reserved outside PetMagic" });
  const reason = dialog.getByRole("textbox", { name: "Change reason" });
  const save = dialog.getByRole("button", { name: "Save policy", exact: true });

  await reason.fill("ab");
  await expect(reason).toHaveAttribute("aria-invalid", "true");
  await expect(reason).toHaveAttribute(
    "aria-describedby",
    "generation-capacity-policy-reason-error"
  );
  await expect(save).toBeDisabled();
  await reason.fill("Verified the new concurrency limit in the fal.ai Dashboard.");
  await expect(reason).toHaveAttribute("aria-invalid", "false");

  await confirmedLimit.fill("40");
  await reserve.fill("40");
  await expect(reserve).toHaveAttribute("aria-invalid", "true");
  await expect(reserve).toHaveAttribute(
    "aria-describedby",
    "generation-capacity-policy-limits-error"
  );
  await expect(save).toBeDisabled();
  await reserve.fill("2");
  await expect(reserve).toHaveAttribute("aria-invalid", "false");
  await dialog
    .getByRole("checkbox", { name: /I checked the concurrency limit in the fal.ai Dashboard/ })
    .check();
  const preview = dialog.getByRole("region", { name: "Balanced profile preview" });
  await expect(preview.getByText("38", { exact: true }).first()).toBeVisible();
  await expect(preview.getByText("10", { exact: true }).first()).toBeVisible();
  await save.click();

  await expect(dialog).toBeHidden();
  await expect.poll(() => api.getPolicyRequests().length).toBe(1);
  expect(api.getPolicyRequests()[0]).toMatchObject({
    body: {
      expectedRevision: 4,
      confirmedFalConcurrencyLimit: 40,
      reservedHeadroom: 2,
      applicationHardCeiling: 38,
      admissionEnabled: true,
      confirmFalConcurrencyLimit: true,
    },
  });
  expect(api.getPolicyRequests()[0]?.idempotencyKey).toMatch(/^generation-policy:/);
});

test("preserves the draft and rotates concurrency metadata after a 409 conflict", async ({
  page,
}) => {
  const api = await installMocks(page, createControl(), { policyConflictsBeforeSuccess: 1 });
  await loginAsAdmin(page);
  await page.goto("/en/generations");
  await page.getByRole("button", { name: "Configure", exact: true }).click();

  const dialog = page.getByRole("dialog", {
    name: "Configure generation capacity",
    exact: true,
  });
  const confirmedLimit = dialog.getByRole("textbox", {
    name: "Confirmed fal.ai concurrency limit",
  });
  const reason = dialog.getByRole("textbox", { name: "Change reason" });
  const save = dialog.getByRole("button", { name: "Save policy", exact: true });
  const preservedReason = "Verified the desired capacity after reviewing the live queue.";

  await confirmedLimit.fill("40");
  await reason.fill(preservedReason);
  const falLimitConfirmation = dialog.getByRole("checkbox", {
    name: /I checked the concurrency limit in the fal.ai Dashboard/,
  });
  await falLimitConfirmation.check();
  await save.click();

  await expect(dialog.getByText(/latest revision was loaded/i)).toBeVisible();
  await expect(confirmedLimit).toHaveValue("40");
  await expect(reason).toHaveValue(preservedReason);
  await expect.poll(() => api.getPolicyRequests().length).toBe(1);
  expect(api.getPolicyRequests()[0]?.body.expectedRevision).toBe(4);
  const firstIdempotencyKey = api.getPolicyRequests()[0]?.idempotencyKey;

  await expect(falLimitConfirmation).not.toBeChecked();
  await expect(save).toBeDisabled();
  await falLimitConfirmation.check();
  await expect(save).toBeEnabled();
  await save.click();
  await expect(dialog).toBeHidden();
  await expect.poll(() => api.getPolicyRequests().length).toBe(2);
  expect(api.getPolicyRequests()[1]?.body.expectedRevision).toBe(5);
  expect(api.getPolicyRequests()[1]?.body.reason).toBe(preservedReason);
  expect(api.getPolicyRequests()[1]?.idempotencyKey).toMatch(/^generation-policy:/);
  expect(api.getPolicyRequests()[1]?.idempotencyKey).not.toBe(firstIdempotencyKey);
});

test("blocks a blind policy retry when the 409 refresh did not load a newer revision", async ({
  page,
}) => {
  const api = await installMocks(page, createControl(), {
    policyConflictsBeforeSuccess: 1,
    policyConflictRefreshFails: true,
  });
  await loginAsAdmin(page);
  await page.goto("/en/generations");
  await page.getByRole("button", { name: "Configure", exact: true }).click();

  const dialog = page.getByRole("dialog", {
    name: "Configure generation capacity",
    exact: true,
  });
  const confirmedLimit = dialog.getByRole("textbox", {
    name: "Confirmed fal.ai concurrency limit",
  });
  const reason = dialog.getByRole("textbox", { name: "Change reason" });
  const falLimitConfirmation = dialog.getByRole("checkbox", {
    name: /I checked the concurrency limit in the fal.ai Dashboard/,
  });
  const save = dialog.getByRole("button", { name: "Save policy", exact: true });
  await confirmedLimit.fill("40");
  await reason.fill("Verified the desired capacity but need a fresh policy revision.");
  await falLimitConfirmation.check();
  await save.click();

  await expect(dialog.getByText(/newer revision could not be loaded/i)).toBeVisible();
  await expect(save).toBeDisabled();
  await expect(confirmedLimit).toHaveValue("40");
  await expect(reason).toHaveValue(
    "Verified the desired capacity but need a fresh policy revision."
  );
  await expect.poll(() => api.getPolicyRequests().length).toBe(1);

  await dialog.getByRole("button", { name: "Load latest revision" }).click();
  await expect(dialog.getByText(/latest revision was loaded/i)).toBeVisible();
  await expect(falLimitConfirmation).not.toBeChecked();
  await expect(save).toBeDisabled();
});

test("blocks policy mutations while a server snapshot is too old", async ({ page }) => {
  await installMocks(page, createControl({ generatedAtUtc: "2000-01-01T00:00:00Z" }));
  await loginAsAdmin(page);
  await page.goto("/en/generations");

  await expect(
    page.getByText("Generation capacity snapshot is stale", { exact: true })
  ).toBeVisible();
  await expect(page.getByRole("button", { name: "Configure", exact: true })).toBeDisabled();
  const refresh = page.getByRole("button", { name: "Refresh balance", exact: true });
  await expect(refresh).toBeEnabled();
  await refresh.click();
  await expect(
    page.getByText("Generation capacity snapshot is stale", { exact: true })
  ).toHaveCount(0);
  await expect(page.getByRole("button", { name: "Configure", exact: true })).toBeEnabled();
});

test("does not report a failed provider refresh as successful", async ({ page }) => {
  await installMocks(page, createControl(), { providerRefreshOutcome: "failed" });
  await loginAsAdmin(page);
  await page.goto("/en/generations");

  await page.getByRole("button", { name: "Refresh balance", exact: true }).click();

  await expect(
    page.getByText("fal.ai did not confirm the refresh; the last safe snapshot is still shown.", {
      exact: true,
    })
  ).toBeVisible();
  await expect(page.getByText("$8.25", { exact: true })).toBeVisible();
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
  await expect(
    page.getByText(
      "No attempts are currently eligible for a manual decision. Ambiguous submits might still be in automatic recovery.",
      { exact: true }
    )
  ).toBeVisible();
});

test("loads provider recovery attempts beyond the first bounded page", async ({ page }) => {
  const attempts = Array.from({ length: 26 }, (_, index) =>
    createRecoveryAttempt({
      attemptId: `9c97c35e-4da1-4de1-8d87-${String(index + 1).padStart(12, "0")}`,
      generationId: `a8b75673-c816-4900-98b6-${String(index + 1).padStart(12, "0")}`,
      ordinal: index + 1,
    })
  );
  const base = createControl();
  await installMocks(
    page,
    createControl({
      lanes: { ...base.lanes, submissionUnknownCount: attempts.length },
      alerts: [],
    }),
    { providerRecoveryItems: attempts }
  );
  await loginAsAdmin(page);
  await page.goto("/en/generations");

  const recovery = page.getByRole("region", {
    name: "Manual provider submit reconciliation",
  });
  await expect(recovery.getByText(attempts[0].generationId as string)).toBeVisible();
  await expect(recovery.getByText(attempts[25].generationId as string)).toHaveCount(0);
  await expect(recovery.getByText("Showing 25 of 26", { exact: true })).toBeVisible();
  await expect(
    recovery.getByRole("button", {
      name: `Resolve attempt: Generation ${attempts[0].generationId}, Stage video_generation #1`,
    })
  ).toBeVisible();

  await recovery.getByRole("button", { name: "Load more attempts", exact: true }).click();

  await expect(recovery.getByText(attempts[25].generationId as string)).toBeVisible();
  await expect(recovery.getByText("Showing 26 of 26", { exact: true })).toBeVisible();
  await expect(
    recovery.getByRole("button", { name: "Load more attempts", exact: true })
  ).toHaveCount(0);
});

test("correlates an ambiguous provider submit only with explicit fal.ai evidence", async ({
  page,
}) => {
  const base = createControl();
  const api = await installMocks(
    page,
    createControl({
      lanes: { ...base.lanes, submissionUnknownCount: 1 },
      alerts: [
        {
          alertId: "generation-provider-submission-unknown",
          statusChangedAtUtc: "2026-07-29T10:03:00Z",
          severity: "critical",
          title: "Provider submissions require reconciliation",
          message: "One ambiguous submission occupies capacity.",
        },
      ],
    }),
    { providerRecoveryItems: [createRecoveryAttempt()] }
  );
  await page.setViewportSize({ width: 390, height: 844 });
  await loginAsAdmin(page);
  await page.goto("/en/generations");

  const recovery = page.getByRole("region", {
    name: "Manual provider submit reconciliation",
  });
  await expect(recovery).toBeVisible();
  await expect(recovery.getByText(createRecoveryAttempt().generationId as string)).toBeVisible();
  await recovery.getByRole("button", { name: /^Resolve attempt:/ }).click();

  const dialog = page.getByRole("dialog", { name: "Evidence-backed provider recovery" });
  const confirm = dialog.getByRole("button", { name: "Apply decision" });
  await expect(confirm).toBeDisabled();
  const providerRequestId = dialog.getByRole("textbox", { name: "fal.ai request ID" });
  const providerRequestDescriptionId = await providerRequestId.getAttribute("aria-describedby");
  expect(providerRequestDescriptionId).toBeTruthy();
  await expect(dialog.locator(`#${providerRequestDescriptionId}`)).toContainText(
    "An accepted request requires its fal.ai request ID."
  );
  await providerRequestId.fill("request_accepted_1");
  await dialog
    .getByRole("textbox", { name: "Evidence reference" })
    .fill("fal-dashboard:request_accepted_1");
  await dialog
    .getByRole("textbox", { name: "Decision reason" })
    .fill("Matched the request ID, model stage, and generation in the fal.ai Dashboard.");
  await dialog
    .getByRole("checkbox", { name: /I verified the generation, stage, and fal.ai evidence/ })
    .check();
  await expect(confirm).toBeEnabled();

  const dimensions = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));
  expect(dimensions.scrollWidth).toBeLessThanOrEqual(dimensions.clientWidth);

  await confirm.click();
  await expect(dialog).toBeHidden();
  await expect.poll(() => api.getRecoveryRequests().length).toBe(1);
  expect(api.getRecoveryRequests()[0]).toMatchObject({
    attemptId: createRecoveryAttempt().attemptId,
    body: {
      expectedAttemptVersion: 4,
      resolution: "correlated_accepted",
      evidenceReference: "fal-dashboard:request_accepted_1",
      providerRequestId: "request_accepted_1",
      providerStatusUrl: null,
      providerResponseUrl: null,
      providerCancelUrl: null,
    },
  });
  expect(api.getRecoveryRequests()[0]?.idempotencyKey).toMatch(/^provider-attempt-resolution:/);
});

test("keeps the recovery dialog locked while a conflicted attempt version is reloaded", async ({
  page,
}) => {
  const firstAttempt = createRecoveryAttempt();
  const secondAttempt = createRecoveryAttempt({
    attemptId: "9c97c35e-4da1-4de1-8d87-8b02f9fce2ae",
    generationId: "a8b75673-c816-4900-98b6-9ea5846b4199",
  });
  const base = createControl();
  await installMocks(
    page,
    createControl({
      lanes: { ...base.lanes, submissionUnknownCount: 2 },
      alerts: [],
    }),
    {
      providerRecoveryItems: [firstAttempt, secondAttempt],
      providerResolutionConflictsBeforeSuccess: 1,
      providerConflictRefreshFails: true,
      providerConflictRefreshDelayMs: 750,
    }
  );
  await loginAsAdmin(page);
  await page.goto("/en/generations");
  await page
    .getByRole("button", {
      name: new RegExp(`^Resolve attempt: Generation ${firstAttempt.generationId}`),
    })
    .click();

  const dialog = page.getByRole("dialog", { name: "Evidence-backed provider recovery" });
  await dialog.getByRole("textbox", { name: "fal.ai request ID" }).fill("request_conflict_1");
  await dialog
    .getByRole("textbox", { name: "Evidence reference" })
    .fill("fal-dashboard:request_conflict_1");
  await dialog
    .getByRole("textbox", { name: "Decision reason" })
    .fill("Matched this request in fal.ai before the attempt version changed.");
  await dialog
    .getByRole("checkbox", { name: /I verified the generation, stage, and fal.ai evidence/ })
    .check();
  await dialog.getByRole("button", { name: "Apply decision" }).click();

  await expect(dialog.getByText(/Retry is blocked/i)).toBeVisible();
  const loadLatest = dialog.getByRole("button", { name: "Load latest version" });
  await loadLatest.click();
  await expect(dialog.getByRole("button", { name: "Cancel", exact: true })).toBeDisabled();
  await expect(dialog.getByRole("textbox", { name: "Evidence reference" })).toBeDisabled();
  await expect(dialog.getByText(/latest version was loaded/i)).toBeVisible();
  await expect(dialog.getByRole("button", { name: "Cancel", exact: true })).toBeEnabled();
  await expect(dialog.getByText(firstAttempt.generationId as string)).toBeVisible();
  await dialog.getByRole("button", { name: "Cancel", exact: true }).click();

  await page
    .getByRole("button", {
      name: new RegExp(`^Resolve attempt: Generation ${secondAttempt.generationId}`),
    })
    .click();
  await expect(dialog.getByText(secondAttempt.generationId as string)).toBeVisible();
  await expect(dialog.getByText(firstAttempt.generationId as string)).toHaveCount(0);
});

test("requires explicit acknowledgement before confirming that fal.ai did not accept a submit", async ({
  page,
}) => {
  const base = createControl();
  const api = await installMocks(
    page,
    createControl({
      lanes: { ...base.lanes, submissionUnknownCount: 1 },
      alerts: [],
    }),
    { providerRecoveryItems: [createRecoveryAttempt()] }
  );
  await loginAsAdmin(page);
  await page.goto("/en/generations");
  await page.getByRole("button", { name: /^Resolve attempt:/ }).click();

  const dialog = page.getByRole("dialog", { name: "Evidence-backed provider recovery" });
  await dialog
    .getByRole("combobox", { name: "Confirmed outcome" })
    .selectOption("confirmed_not_found");
  await expect(dialog.getByRole("textbox", { name: "fal.ai request ID" })).toHaveCount(0);
  await expect(dialog.getByText(/idempotent refund/i)).toBeVisible();
  await dialog.getByRole("textbox", { name: "Evidence reference" }).fill("support:case_456");
  await dialog
    .getByRole("textbox", { name: "Decision reason" })
    .fill("fal.ai support confirmed that no provider request was accepted.");
  const confirm = dialog.getByRole("button", { name: "Apply decision" });
  await expect(confirm).toBeDisabled();
  await dialog
    .getByRole("checkbox", { name: /I verified the generation, stage, and fal.ai evidence/ })
    .check();
  await confirm.click();

  await expect.poll(() => api.getRecoveryRequests().length).toBe(1);
  expect(api.getRecoveryRequests()[0]?.body).toMatchObject({
    resolution: "confirmed_not_found",
    evidenceReference: "support:case_456",
    providerRequestId: null,
  });
  await expect
    .poll(async () =>
      (await readPersistedNotificationMessages(page)).includes(
        "Provider request absence was confirmed; cancellation and refund recovery were scheduled."
      )
    )
    .toBe(true);
});

test("does not claim that a refund was scheduled when backend reports no refund work", async ({
  page,
}) => {
  const base = createControl();
  await installMocks(
    page,
    createControl({
      lanes: { ...base.lanes, submissionUnknownCount: 1 },
      alerts: [],
    }),
    {
      providerRecoveryItems: [createRecoveryAttempt()],
      providerRecoveryRefundScheduled: false,
    }
  );
  await loginAsAdmin(page);
  await page.goto("/en/generations");
  await page.getByRole("button", { name: /^Resolve attempt:/ }).click();

  const dialog = page.getByRole("dialog", { name: "Evidence-backed provider recovery" });
  await dialog
    .getByRole("combobox", { name: "Confirmed outcome" })
    .selectOption("confirmed_not_found");
  await dialog.getByRole("textbox", { name: "Evidence reference" }).fill("support:case_789");
  await dialog
    .getByRole("textbox", { name: "Decision reason" })
    .fill("The request was never accepted and the generation had no charge to refund.");
  await dialog
    .getByRole("checkbox", { name: /I verified the generation, stage, and fal.ai evidence/ })
    .check();
  await dialog.getByRole("button", { name: "Apply decision" }).click();

  await expect
    .poll(async () =>
      (await readPersistedNotificationMessages(page)).includes(
        "Provider request absence was confirmed; the generation was cancelled and no new refund was required."
      )
    )
    .toBe(true);
  expect(await readPersistedNotificationMessages(page)).not.toContain(
    "Provider request absence was confirmed; cancellation and refund recovery were scheduled."
  );
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
