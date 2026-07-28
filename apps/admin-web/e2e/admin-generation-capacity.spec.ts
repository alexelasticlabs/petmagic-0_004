import { expect, test, type Page, type Route } from "@playwright/test";

const apiOrigin = "https://api.petmagic.test";

function session(roles: string[] = ["Admin"]) {
  return {
    accessToken: "capacity-access-token",
    refreshToken: "capacity-refresh-token",
    expiresAtUtc: "2099-01-01T00:00:00Z",
    user: {
      userId: "11111111-1111-4111-8111-111111111111",
      email: "capacity.admin@petmagic.test",
      displayName: "Capacity Admin",
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

function snapshot() {
  return {
    settings: {
      version: 3,
      globalMaxConcurrent: 8,
      imageMaxConcurrent: 7,
      imageProtectedConcurrent: 3,
      videoGuaranteedConcurrent: 2,
      videoMaxConcurrent: 4,
      videoBorrowMaxConcurrent: 2,
      workerLoopsPerInstance: 2,
      falConfiguredConcurrency: 10,
      falReservedConcurrency: 2,
      falBalanceLowThresholdUsd: 10,
      falBalanceCriticalThresholdUsd: 5,
      updatedAtUtc: "2026-07-28T10:00:00Z",
      updatedByAdminId: null,
    },
    status: {
      generatedAtUtc: "2026-07-28T10:01:00Z",
      activeGlobal: 6,
      activeImage: 5,
      activeVideo: 1,
      queuedImage: 3,
      queuedVideo: 2,
      effectiveImageMaxConcurrent: 6,
      borrowedVideo: 0,
      isDraining: false,
      health: "healthy",
    },
    fal: {
      configuredConcurrency: 10,
      reservedConcurrency: 2,
      usableConcurrency: 8,
      inflightRequests: 6,
      balanceUsd: 20,
      balanceStatus: "healthy",
      checkedAtUtc: "2026-07-28T10:01:00Z",
      lastSuccessAtUtc: "2026-07-28T10:01:00Z",
      isStale: false,
    },
    workers: [
      {
        instanceId: "worker-frankfurt-a",
        lastSeenAtUtc: "2026-07-28T10:01:00Z",
        heartbeatAgeSeconds: 2,
        appliedSettingsVersion: 3,
        configuredLoops: 2,
        isStale: false,
        isConfigCurrent: true,
        isDraining: false,
      },
    ],
    render: {
      isConfigured: true,
      serviceId: "srv-production-worker",
      serviceName: "petmagic-production-generation-worker",
      serviceType: "background_worker",
      plan: "Standard",
      region: "Frankfurt",
      desiredInstances: 1,
      activeInstances: 1,
      autoscalingEnabled: false,
      configurationError: null,
      operation: null,
    },
    alerts: [
      {
        id: "alert-low-balance",
        code: "fal_balance_low",
        severity: "warning",
        title: "fal.ai balance is low",
        message: "Top up credits before launch.",
        activatedAtUtc: "2026-07-28T10:00:00Z",
        resolvedAtUtc: null as string | null,
        acknowledgedAtUtc: null as string | null,
        isActive: true,
        isAcknowledged: false,
      },
    ],
  };
}

function cors(route: Route) {
  return {
    "Access-Control-Allow-Origin": route.request().headers().origin ?? "http://127.0.0.1",
    "Access-Control-Allow-Credentials": "true",
    "Access-Control-Allow-Headers":
      "Authorization, Content-Type, Idempotency-Key, X-Correlation-ID",
    "Access-Control-Allow-Methods": "GET, POST, PUT, OPTIONS",
  };
}

async function json(route: Route, body: unknown, status = 200) {
  await route.fulfill({
    status,
    contentType: "application/json",
    headers: cors(route),
    body: JSON.stringify(body),
  });
}

async function installMocks(
  page: Page,
  options: { roles?: string[]; scaleConflictOnce?: boolean; settingsConflictOnce?: boolean } = {}
) {
  let state = snapshot();
  const settingsRequests: unknown[] = [];
  const scaleRequests: Array<{ body: unknown; idempotencyKey: string | null }> = [];
  let operationReads = 0;
  let generationControlReads = 0;
  let scaleConflictReturned = false;
  let settingsConflictReturned = false;

  await page.route(apiOrigin + "/api/**", async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    if (request.method() === "OPTIONS") {
      await route.fulfill({ status: 204, headers: cors(route) });
      return;
    }
    if (url.pathname === "/api/auth/login" || url.pathname === "/api/auth/refresh") {
      await json(route, session(options.roles));
      return;
    }
    if (url.pathname === "/api/auth/logout") {
      await json(route, {});
      return;
    }
    if (url.pathname === "/api/admin/support/inbox/metrics") {
      await json(route, { unreadCount: 0, unassignedCount: 0 });
      return;
    }
    if (url.pathname.endsWith("/provider/refresh")) {
      state = { ...state, fal: { ...state.fal, balanceUsd: 19.5 } };
      await json(route, state);
      return;
    }
    if (url.pathname.endsWith("/alerts/alert-low-balance/acknowledge")) {
      state.alerts[0] = {
        ...state.alerts[0],
        acknowledgedAtUtc: "2026-07-28T10:02:00Z",
        isAcknowledged: true,
      };
      await json(route, state.alerts[0]);
      return;
    }
    if (url.pathname.endsWith("/render/scale")) {
      scaleRequests.push({
        body: request.postDataJSON(),
        idempotencyKey: request.headers()["idempotency-key"] ?? null,
      });
      if (options.scaleConflictOnce && !scaleConflictReturned) {
        scaleConflictReturned = true;
        state = {
          ...state,
          render: { ...state.render, desiredInstances: 2, activeInstances: 2 },
        };
        await json(
          route,
          {
            title: "templates.render.scale_current_instances_changed",
            status: 409,
            detail: "Render worker instance count changed. Reload the page before scaling.",
          },
          409
        );
        return;
      }
      await json(route, {
        operationId: "scale-operation-1",
        status: "requested",
        initialInstances: 1,
        targetInstances: 4,
        loopsPerInstance: 2,
        reason: "Controlled launch capacity",
        createdAtUtc: "2026-07-28T10:03:00Z",
        updatedAtUtc: "2026-07-28T10:03:00Z",
        drainStartedAtUtc: null,
        scaleRequestedAtUtc: null,
        completedAtUtc: null,
        cancelledAtUtc: null,
        errorCode: null,
        canCancel: true,
      });
      return;
    }
    if (url.pathname.endsWith("/render/operations/scale-operation-1")) {
      operationReads += 1;
      await json(route, {
        operationId: "scale-operation-1",
        status: operationReads > 1 ? "completed" : "scaling",
        initialInstances: 1,
        targetInstances: 4,
        loopsPerInstance: 2,
        reason: "Controlled launch capacity",
        createdAtUtc: "2026-07-28T10:03:00Z",
        updatedAtUtc: "2026-07-28T10:04:00Z",
        drainStartedAtUtc: null,
        scaleRequestedAtUtc: "2026-07-28T10:03:30Z",
        completedAtUtc: operationReads > 1 ? "2026-07-28T10:04:00Z" : null,
        cancelledAtUtc: null,
        errorCode: null,
        canCancel: operationReads <= 1,
      });
      return;
    }
    if (url.pathname === "/api/admin/templates/generation-control" && request.method() === "PUT") {
      const body = request.postDataJSON() as Record<string, unknown>;
      settingsRequests.push(body);
      if (options.settingsConflictOnce && !settingsConflictReturned) {
        settingsConflictReturned = true;
        state = {
          ...state,
          settings: {
            ...state.settings,
            version: 4,
            globalMaxConcurrent: 6,
            imageMaxConcurrent: 6,
            updatedAtUtc: "2026-07-28T10:02:00Z",
          },
        };
        await json(
          route,
          {
            title: "templates.generation_control_version_conflict",
            status: 409,
            detail: "Generation runtime settings changed. Reload and review the latest version.",
          },
          409
        );
        return;
      }
      state = {
        ...state,
        settings: { ...state.settings, ...body, version: 4, updatedAtUtc: "2026-07-28T10:02:00Z" },
      };
      await json(route, state);
      return;
    }
    if (url.pathname === "/api/admin/templates/generation-control") {
      generationControlReads += 1;
      await json(route, state);
      return;
    }
    await json(route, { items: [], totalCount: 0 });
  });

  return {
    getSettingsRequests: () => settingsRequests,
    getScaleRequests: () => scaleRequests,
    getGenerationControlReads: () => generationControlReads,
  };
}

async function login(page: Page) {
  await page.goto("/en");
  await page.locator("#login-email").fill("capacity.admin@petmagic.test");
  await page.locator("#login-password").fill("production-ready-password");
  await page.locator('form button[type="submit"]').click();
  await expect(page).toHaveURL(/\/en\/dashboard$/);
}

test("admin reviews versioned runtime settings and acknowledges a persistent alert", async ({
  page,
}) => {
  const api = await installMocks(page);
  await page.setViewportSize({ width: 1440, height: 960 });
  await login(page);
  await page.goto("/en/generations/capacity");
  await expect(
    page.getByRole("heading", { name: "Generation capacity", exact: true })
  ).toBeVisible();
  await expect(page.getByText("$20.00", { exact: true })).toBeVisible();
  await page.getByRole("spinbutton", { name: "Global max" }).fill("7");
  await page.getByRole("button", { name: "Review changes" }).click();
  const dialog = page.getByRole("dialog", { name: "Confirm runtime settings" });
  await expect(dialog.getByRole("button", { name: "Apply settings" })).toBeDisabled();
  await dialog
    .getByRole("textbox", { name: "Change reason" })
    .fill("Controlled prelaunch capacity verification");
  await dialog.getByRole("button", { name: "Apply settings" }).click();
  await expect.poll(() => api.getSettingsRequests().length).toBe(1);
  expect(api.getSettingsRequests()[0]).toMatchObject({
    expectedVersion: 3,
    globalMaxConcurrent: 7,
  });
  await page.getByRole("button", { name: "Acknowledge", exact: true }).last().click();
  await expect(page.getByText("Acknowledged", { exact: true })).toBeVisible();
});

test("settings conflict keeps stale values blocked until the admin reloads", async ({ page }) => {
  const api = await installMocks(page, { settingsConflictOnce: true });
  await page.setViewportSize({ width: 1440, height: 960 });
  await login(page);
  await page.goto("/en/generations/capacity");
  const globalMax = page.getByRole("spinbutton", { name: "Global max" });
  await globalMax.fill("7");
  await page.getByRole("button", { name: "Review changes" }).click();
  const dialog = page.getByRole("dialog", { name: "Confirm runtime settings" });
  await dialog.getByRole("textbox", { name: "Change reason" }).fill("Conflict protection test");
  await dialog.getByRole("button", { name: "Apply settings" }).click();

  await expect(page.getByText("Settings changed on the server", { exact: true })).toBeVisible();
  await expect(globalMax).toHaveValue("7");
  await expect(page.getByRole("button", { name: "Review changes" })).toBeDisabled();
  await page.getByRole("button", { name: "Load current values" }).click();
  await expect(globalMax).toHaveValue("6");
  expect(api.getSettingsRequests()).toHaveLength(1);
});

test("Moderator cannot open or query the Admin-only capacity route", async ({ page }) => {
  const api = await installMocks(page, { roles: ["Moderator"] });
  await page.goto("/en");
  await page.locator("#login-email").fill("capacity.moderator@petmagic.test");
  await page.locator("#login-password").fill("production-ready-password");
  await page.locator('form button[type="submit"]').click();
  await expect(page).toHaveURL(/\/en\/support$/);

  await page.goto("/en/generations/capacity");
  await expect(page).toHaveURL(/\/en\/support$/);
  expect(api.getGenerationControlReads()).toBe(0);
});

test("Render conflict blocks retry until live topology is reloaded and reviewed", async ({
  page,
}) => {
  const api = await installMocks(page, { scaleConflictOnce: true });
  await page.setViewportSize({ width: 1440, height: 960 });
  await login(page);
  await page.goto("/en/generations/capacity");
  await page.getByRole("button", { name: "Change instances" }).click();
  const dialog = page.getByRole("dialog", { name: "Confirm Render scaling" });
  await dialog.getByRole("combobox", { name: "Target instances" }).selectOption("4");
  await dialog
    .getByRole("textbox", { name: "Scaling reason" })
    .fill("Pinned topology conflict test");
  await dialog.getByRole("checkbox").check();
  await dialog.getByRole("button", { name: "Start scaling" }).click();

  await expect(dialog.getByText("Render topology changed", { exact: true })).toBeVisible();
  await expect(dialog.getByText("Standard × 1 → Standard × 4", { exact: true })).toBeVisible();
  await expect(dialog.getByRole("button", { name: "Start scaling" })).toBeDisabled();
  expect(api.getScaleRequests()[0].body).toMatchObject({ expectedCurrentInstances: 1 });

  await dialog.getByRole("button", { name: "Close and reload" }).click();
  await expect(dialog).toBeHidden();
  await expect(page.getByText("2 / 2", { exact: true })).toBeVisible();
});

for (const width of [390, 320]) {
  test(`Render scaling review stays safe at ${width}px`, async ({ page }) => {
    const api = await installMocks(page);
    await page.setViewportSize({ width, height: 844 });
    await login(page);
    await page.goto("/en/generations/capacity");
    await page.getByRole("button", { name: "Change instances" }).click();
    const dialog = page.getByRole("dialog", { name: "Confirm Render scaling" });
    await dialog.getByRole("combobox", { name: "Target instances" }).selectOption("4");
    await expect(dialog.getByText("Standard × 1 → Standard × 4", { exact: true })).toBeVisible();
    await dialog
      .getByRole("textbox", { name: "Scaling reason" })
      .fill("Controlled launch capacity");
    await expect(dialog.getByRole("button", { name: "Start scaling" })).toBeDisabled();
    await dialog.getByRole("checkbox").check();
    await dialog.getByRole("button", { name: "Start scaling" }).click();
    await expect.poll(() => api.getScaleRequests().length).toBe(1);
    expect(api.getScaleRequests()[0].body).toMatchObject({
      targetInstances: 4,
      expectedCurrentInstances: 1,
      confirmed: true,
    });
    expect(api.getScaleRequests()[0].idempotencyKey).toMatch(/^generation-scale:/);
    await expect(page.getByText("Completed", { exact: true })).toBeVisible({ timeout: 8_000 });
    const dimensions = await page.evaluate(() => ({
      clientWidth: document.documentElement.clientWidth,
      scrollWidth: document.documentElement.scrollWidth,
    }));
    expect(dimensions.scrollWidth).toBeLessThanOrEqual(dimensions.clientWidth);
  });
}
