import { expect, test, type Page, type Route } from "@playwright/test";

const apiOrigin = "https://api.petmagic.test";
const adminUserId = "11111111-1111-4111-8111-111111111111";
const generationId = "22222222-2222-4222-8222-222222222222";
const userId = "33333333-3333-4333-8333-333333333333";
const templateId = "44444444-4444-4444-8444-444444444444";
const recoveryReason = "Verified provider recovery after exhausted automatic attempts.";

const generationControlSnapshot = {
  revision: 1,
  admissionEnabled: true,
  confirmedFalConcurrencyLimit: 6,
  confirmedAtUtc: "2026-07-27T09:30:00Z",
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
    checkedAtUtc: "2026-07-27T09:30:00Z",
    lastSuccessfulAtUtc: "2026-07-27T09:30:00Z",
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
    heartbeatAtUtc: "2026-07-27T09:30:00Z",
    lastProgressAtUtc: "2026-07-27T09:30:00Z",
    appliedPolicyRevision: 1,
    schedulerV2Enabled: true,
    dispatchConcurrency: 4,
    reconciliationConcurrency: 1,
    mediaImportConcurrency: 1,
    maintenanceConcurrency: 1,
  },
  alerts: [],
  generatedAtUtc: "2026-07-27T09:30:00Z",
};

function createAdminSession() {
  return {
    accessToken: "refund-recovery-access-token",
    refreshToken: "refund-recovery-refresh-token",
    expiresAtUtc: "2099-01-01T00:00:00Z",
    user: {
      userId: adminUserId,
      email: "refund.admin@petmagic.test",
      displayName: "Refund Admin",
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
  return {
    "Access-Control-Allow-Origin": route.request().headers().origin ?? "http://127.0.0.1",
    "Access-Control-Allow-Credentials": "true",
    "Access-Control-Allow-Headers":
      "Authorization, Content-Type, Idempotency-Key, X-Correlation-ID",
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

function createGeneration(refundQueued: boolean) {
  return {
    generationId,
    userId,
    templateId,
    templateTitle: "Refund recovery portrait",
    templateType: "Image",
    status: "Failed",
    provider: "fal-ai",
    model: "flux-pro",
    tokenCost: 12,
    attemptCount: 3,
    providerCostUsd: 0.08,
    failureCode: "generation.provider_failed",
    failureMessage: "Provider generation failed.",
    createdAtUtc: "2026-07-27T08:00:00Z",
    updatedAtUtc: refundQueued ? "2026-07-27T09:30:00Z" : "2026-07-27T09:00:00Z",
    startedAtUtc: "2026-07-27T08:01:00Z",
    completedAtUtc: "2026-07-27T08:03:00Z",
    refundedAtUtc: null,
    chargedAtUtc: "2026-07-27T08:00:30Z",
    refundState: refundQueued ? "pending" : "exhausted",
    refundAttemptCount: refundQueued ? 0 : 5,
    refundAttemptLimit: 5,
    refundLastAttemptedAtUtc: "2026-07-27T09:00:00Z",
    refundLastErrorCode: refundQueued ? "economy.retrying" : "economy.temporarily_unavailable",
    canRetryRefund: !refundQueued,
    isWatermarkRequired: false,
    isWatermarkRemoved: false,
    inputSourceType: "user_upload",
    canCompareBeforeAfter: false,
    childCount: 0,
    generationMode: "normal",
    canCancel: false,
    canRetry: false,
    gamificationLegacyReviewRequired: false,
  };
}

function createGenerationDetail(refundQueued: boolean) {
  return {
    generation: {
      ...createGeneration(refundQueued),
      refundAttemptCount: refundQueued ? 1 : 5,
      refundLastErrorCode: refundQueued
        ? "economy.refund_retry_queued"
        : "economy.temporarily_unavailable",
    },
    generatedAtUtc: "2026-07-27T09:30:00Z",
  };
}

function createGenerationMetrics(refundQueued: boolean) {
  return {
    totalJobs: 1,
    generationsToday: 1,
    generationsThisWeek: 1,
    generationsThisMonth: 1,
    failedGenerationsToday: 1,
    failedGenerationsThisWeek: 1,
    failedGenerationsThisMonth: 1,
    pendingJobs: 0,
    runningJobs: 0,
    completedJobs: 0,
    failedJobs: 1,
    cancelledJobs: 0,
    cancellingJobs: 0,
    retryingJobs: 0,
    pendingRefunds: refundQueued ? 1 : 0,
    exhaustedRefunds: refundQueued ? 0 : 1,
    generatedAtUtc: "2026-07-27T09:30:00Z",
  };
}

type RefundRequest = {
  idempotencyKey: string | null;
  body: unknown;
};

async function installRefundRecoveryMocks(
  page: Page,
  failFirstRefundRequest: boolean,
  media: Record<string, unknown> = {}
) {
  const session = createAdminSession();
  const refundRequests: RefundRequest[] = [];
  let refundQueued = false;
  let listRequests = 0;
  let metricsRequests = 0;
  let detailRequests = 0;
  const requestedRefundStates: Array<string | null> = [];

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

    if (url.pathname === `/api/admin/templates/generations/${generationId}/retry-refund`) {
      refundRequests.push({
        idempotencyKey: request.headers()["idempotency-key"] ?? null,
        body: request.postDataJSON(),
      });

      if (failFirstRefundRequest && refundRequests.length === 1) {
        await fulfillJson(
          route,
          {
            code: "templates.generation_refund_retry_temporarily_unavailable",
            message: "The refund recovery request is temporarily unavailable.",
          },
          503
        );
        return;
      }

      refundQueued = true;
      await fulfillJson(route, {
        generationId,
        status: "RefundRetryQueued",
        canRetryRefund: false,
      });
      return;
    }

    if (
      url.pathname === `/api/admin/templates/generations/${generationId}` &&
      request.method() === "GET"
    ) {
      detailRequests += 1;
      const detail = createGenerationDetail(refundQueued);
      await fulfillJson(route, { ...detail, generation: { ...detail.generation, ...media } });
      return;
    }

    if (url.pathname === "/api/admin/templates/generations/metrics") {
      metricsRequests += 1;
      await fulfillJson(route, createGenerationMetrics(refundQueued));
      return;
    }

    if (url.pathname === "/api/admin/templates/generation-control") {
      await fulfillJson(route, generationControlSnapshot);
      return;
    }

    if (url.pathname === "/api/admin/templates/generations") {
      listRequests += 1;
      const requestedRefundState = url.searchParams.get("refundState");
      requestedRefundStates.push(requestedRefundState);
      const generation = { ...createGeneration(refundQueued), ...media };
      const items =
        !requestedRefundState || requestedRefundState === generation.refundState
          ? [generation]
          : [];
      await fulfillJson(route, {
        items,
        totalCount: items.length,
        skip: 0,
        take: 25,
        hasMore: false,
        generatedAtUtc: "2026-07-27T09:30:00Z",
      });
      return;
    }

    await fulfillJson(route, {
      items: [],
      totalCount: 0,
      skip: 0,
      take: 25,
      hasMore: false,
      generatedAtUtc: "2026-07-27T09:30:00Z",
    });
  });

  return {
    getRefundRequests: () => refundRequests,
    getListRequests: () => listRequests,
    getMetricsRequests: () => metricsRequests,
    getDetailRequests: () => detailRequests,
    getRequestedRefundStates: () => requestedRefundStates,
  };
}

async function loginAsAdmin(page: Page) {
  await page.goto("/en");
  await page.locator("#login-email").fill("refund.admin@petmagic.test");
  await page.locator("#login-password").fill("production-ready-password");
  await page.locator('form button[type="submit"]').click();
  await expect(page).toHaveURL(/\/en\/dashboard$/);
}

function collectUnexpectedRuntimeErrors(page: Page) {
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push("pageerror: " + error.message));
  page.on("console", (message) => {
    if (message.type() !== "error") {
      return;
    }

    const text = message.text();
    if (text.includes("503") && text.includes("Failed to load resource")) {
      return;
    }

    errors.push("console: " + text);
  });
  return errors;
}

test("refund recovery keeps one idempotency key across a controlled retry", async ({
  page,
}, testInfo) => {
  const api = await installRefundRecoveryMocks(page, true);
  await page.setViewportSize({ width: 1440, height: 960 });
  await loginAsAdmin(page);
  const runtimeErrors = collectUnexpectedRuntimeErrors(page);

  await page.goto("/en/generations?refundState=exhausted");
  await expect(page.getByRole("heading", { name: "Generations", exact: true })).toBeVisible();
  await expect(page.getByRole("combobox", { name: "Charge refund", exact: true })).toHaveValue(
    "exhausted"
  );
  await expect(page.getByText("Refund recovery portrait", { exact: true })).toBeVisible();

  const desktopGenerationRow = page
    .locator("tr")
    .filter({ hasText: "Refund recovery portrait" })
    .first();
  const columnBorders = await desktopGenerationRow
    .locator("td")
    .evaluateAll((cells) =>
      cells.slice(1).map((cell) => getComputedStyle(cell).borderInlineStartWidth)
    );
  expect(columnBorders).toHaveLength(8);
  expect(columnBorders.every((width) => width === "1px")).toBe(true);

  const retryButton = page.getByRole("button", { name: /Retry refund:/ });
  await expect(retryButton).toBeVisible();
  await retryButton.click();

  const dialog = page.getByRole("dialog", { name: "Retry the charge refund?", exact: true });
  await expect(dialog).toBeVisible();
  const confirmButton = dialog.getByRole("button", { name: "Queue refund", exact: true });
  await expect(confirmButton).toBeDisabled();
  await expect(
    dialog.getByText("Provide a verified reason for restoring the refund.", { exact: true })
  ).toBeVisible();

  await dialog.getByRole("textbox", { name: /Recovery reason/ }).fill(recoveryReason);
  await expect(confirmButton).toBeEnabled();
  await confirmButton.click();

  await expect.poll(() => api.getRefundRequests().length).toBe(1);
  await expect(dialog).toBeVisible();
  await expect(confirmButton).toBeEnabled();
  await page.screenshot({
    path: testInfo.outputPath("generation-refund-recovery-desktop.png"),
    fullPage: false,
  });

  await confirmButton.click();
  await expect.poll(() => api.getRefundRequests().length).toBe(2);
  const [firstRequest, secondRequest] = api.getRefundRequests();
  expect(firstRequest.body).toEqual({ reason: recoveryReason });
  expect(secondRequest.body).toEqual({ reason: recoveryReason });
  expect(firstRequest.idempotencyKey).not.toBeNull();
  expect(firstRequest.idempotencyKey).toMatch(/^generation-refund:.+/);
  expect(secondRequest.idempotencyKey).toBe(firstRequest.idempotencyKey);

  await expect(dialog).toBeHidden();
  await expect.poll(api.getListRequests).toBeGreaterThan(1);
  await expect.poll(api.getMetricsRequests).toBeGreaterThan(1);
  await expect(retryButton).toHaveCount(0);
  await expect(page.getByText("No generations found", { exact: true })).toBeVisible();

  const refundFilter = page.getByRole("combobox", { name: "Charge refund", exact: true });
  await refundFilter.selectOption("pending");
  await expect(page).toHaveURL(/[?&]refundState=pending(?:&|$)/);
  await expect.poll(() => api.getRequestedRefundStates().includes("pending")).toBe(true);
  await expect(page.getByText("Refund recovery portrait", { exact: true })).toBeVisible();
  const showDetails = page.getByRole("button", { name: /Show:/ });
  await showDetails.click();
  await expect(page).toHaveURL(new RegExp(`[?&]selected=${generationId}(?:&|$)`));
  await expect.poll(api.getDetailRequests).toBeGreaterThan(0);
  const hideDetails = page.getByRole("button", { name: /Hide:/ });
  await expect(hideDetails).toHaveAttribute("aria-expanded", "true");
  const detailsPanelId = await hideDetails.getAttribute("aria-controls");
  expect(detailsPanelId).toBeTruthy();
  const details = page.locator(`#${detailsPanelId}`);
  await expect(details.getByText("Source media is unavailable", { exact: true })).toBeVisible();
  await expect(details.getByText("Result is not available yet", { exact: true })).toBeVisible();
  await details.getByText("Technical details", { exact: true }).click();
  await expect(details.getByText("Pending", { exact: true })).toBeVisible();
  await expect(details.getByText("1 / 5", { exact: true })).toBeVisible();
  await expect(details.getByText("economy.refund_retry_queued", { exact: true })).toBeVisible();
  await page.screenshot({
    path: testInfo.outputPath("generation-refund-recovery-success-desktop.png"),
    fullPage: true,
  });

  expect(runtimeErrors).toEqual([]);
});

test("exhausted refund recovery dialog stays within the 390px viewport", async ({
  page,
}, testInfo) => {
  const api = await installRefundRecoveryMocks(page, false);
  await page.setViewportSize({ width: 390, height: 844 });
  await loginAsAdmin(page);
  const runtimeErrors = collectUnexpectedRuntimeErrors(page);

  await page.goto("/en/generations?refundState=exhausted");
  const retryButton = page.getByRole("button", { name: /Retry refund:/ });
  await expect(retryButton).toBeVisible();
  await expect(page.locator("h1")).toHaveCount(1);
  await expect(page.getByRole("main").locator("h1")).toHaveCount(0);

  const jobCell = page.locator('[data-label="Job"]');
  await expect(jobCell).toBeVisible();
  await expect(jobCell.getByRole("button", { name: /Copy full ID:/ })).toBeVisible();
  const mobileQueueLayout = await jobCell.evaluate((cell) => ({
    cellDisplay: getComputedStyle(cell).display,
    rowDisplay: getComputedStyle(cell.parentElement as HTMLElement).display,
  }));
  expect(mobileQueueLayout.cellDisplay).toBe("grid");
  expect(mobileQueueLayout.rowDisplay).toBe("grid");
  await retryButton.click();

  const dialog = page.getByRole("dialog", { name: "Retry the charge refund?", exact: true });
  await expect(dialog).toBeVisible();
  await expect(dialog.getByRole("button", { name: "Queue refund", exact: true })).toBeDisabled();

  const dimensions = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
    dialogWidth:
      document.querySelector<HTMLElement>('[role="dialog"]')?.getBoundingClientRect().width ?? 0,
    viewportWidth: window.innerWidth,
  }));
  expect(dimensions.scrollWidth).toBeLessThanOrEqual(dimensions.clientWidth);
  expect(dimensions.clientWidth).toBe(dimensions.viewportWidth);
  expect(dimensions.dialogWidth).toBeLessThanOrEqual(dimensions.viewportWidth);

  await page.screenshot({
    path: testInfo.outputPath("generation-refund-recovery-mobile-390.png"),
    fullPage: false,
  });

  await page.keyboard.press("Escape");
  await page.setViewportSize({ width: 320, height: 844 });
  const narrowDimensions = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));
  expect(narrowDimensions.scrollWidth).toBeLessThanOrEqual(narrowDimensions.clientWidth);
  await expect(jobCell).toBeVisible();
  await page.screenshot({
    path: testInfo.outputPath("generation-priority-queue-mobile-320.png"),
    fullPage: true,
  });
  expect(api.getRefundRequests()).toEqual([]);
  expect(runtimeErrors).toEqual([]);
});

const signedMediaOrigin = "https://" + "a".repeat(32) + ".r2.cloudflarestorage.com";
const sourcePreview = signedMediaOrigin + "/private/source.jpg?signature=synthetic";
const resultVideo = signedMediaOrigin + "/private/result.webm?signature=synthetic";
const imageFixture =
  '<svg xmlns="http://www.w3.org/2000/svg" width="640" height="480"><rect width="640" height="480" fill="#dbeafe"/><circle cx="320" cy="215" r="100" fill="#60a5fa"/><text x="320" y="380" text-anchor="middle" font-size="32" fill="#1e3a8a">TEST SOURCE</text></svg>';

async function openMediaHistory(page: Page) {
  await page.goto("/en/generations");
  await expect(page).toHaveTitle(/PetMagic/);
  await page.getByRole("button", { name: /Show:/ }).click();
  return page.locator("#generation-details-" + generationId);
}

test("generation media renders signed image and playable video without fetching full blobs", async ({
  page,
}, testInfo) => {
  const api = await installRefundRecoveryMocks(page, false, {
    templateTitle: "Video portrait",
    templateType: "Video",
    status: "Completed",
    inputPreviewUrl: sourcePreview,
    resultPreviewUrl: signedMediaOrigin + "/private/poster.jpg",
    resultMediaUrl: resultVideo,
    resultMediaType: "video",
    canCompareBeforeAfter: true,
  });
  await loginAsAdmin(page);
  const runtimeErrors = collectUnexpectedRuntimeErrors(page);
  // Generate a tiny real video in-browser; no provider or remote media dependency.
  const bytes = await page.evaluate(async () => {
    const canvas = document.createElement("canvas");
    canvas.width = 320;
    canvas.height = 240;
    const ctx = canvas.getContext("2d")!;
    const stream = canvas.captureStream(10);
    const recorder = new MediaRecorder(stream, { mimeType: "video/webm" });
    const chunks: Blob[] = [];
    const result = new Promise<number[]>((resolve) => {
      recorder.ondataavailable = (event) => chunks.push(event.data);
      recorder.onstop = async () =>
        resolve(Array.from(new Uint8Array(await new Blob(chunks).arrayBuffer())));
    });
    recorder.start();
    ctx.fillStyle = "#c4b5fd";
    ctx.fillRect(0, 0, 320, 240);
    ctx.fillStyle = "#312e81";
    ctx.font = "24px sans-serif";
    ctx.fillText("TEST RESULT", 75, 130);
    for (let frame = 0; frame < 12; frame += 1) {
      ctx.fillStyle = frame % 2 ? "#818cf8" : "#c4b5fd";
      ctx.fillRect(0, 0, 24, 24);
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    recorder.stop();
    stream.getTracks().forEach((track) => track.stop());
    return result;
  });
  const mediaRequests: string[] = [];
  await page.route(signedMediaOrigin + "/**", async (route) => {
    mediaRequests.push(route.request().resourceType());
    await route.fulfill({
      contentType: route.request().url().includes(".webm") ? "video/webm" : "image/svg+xml",
      body: route.request().url().includes(".webm") ? Buffer.from(bytes) : imageFixture,
    });
  });
  await page.setViewportSize({ width: 1440, height: 1000 });
  const details = await openMediaHistory(page);
  const before = details.getByRole("img", { name: "Before", exact: true });
  await expect(before).toBeVisible();
  await expect.poll(() => before.evaluate((node: HTMLImageElement) => node.naturalWidth)).toBe(640);
  const video = details.locator("video");
  await expect(video).toHaveAttribute("controls", "");
  await expect
    .poll(() => video.evaluate((node: HTMLVideoElement) => node.readyState))
    .toBeGreaterThanOrEqual(2);
  await video.scrollIntoViewIfNeeded();
  await video.evaluate((node: HTMLVideoElement) => node.play());
  await expect
    .poll(() => video.evaluate((node: HTMLVideoElement) => node.currentTime))
    .toBeGreaterThan(0);
  await video.evaluate((node: HTMLVideoElement) => node.pause());
  await expect(details.getByText("Loading media…", { exact: true })).toHaveCount(0);
  await expect(details.getByRole("link", { name: "Open file ↗" })).toHaveCount(2);
  await details.scrollIntoViewIfNeeded();
  await page.screenshot({ path: testInfo.outputPath("generation-media-desktop.png") });
  const requests = api.getDetailRequests();
  await details.getByRole("button", { name: "Refresh media", exact: true }).click();
  await expect.poll(api.getDetailRequests).toBeGreaterThan(requests);
  expect(mediaRequests).not.toContain("fetch");
  await page.setViewportSize({ width: 390, height: 844 });
  await details.scrollIntoViewIfNeeded();
  await expect(before).toBeVisible();
  const bounds = await video.boundingBox();
  expect(bounds!.x).toBeGreaterThanOrEqual(0);
  expect(bounds!.x + bounds!.width).toBeLessThanOrEqual(390);
  await expect
    .poll(() => page.evaluate(() => document.documentElement.scrollWidth <= innerWidth))
    .toBe(true);
  await page.screenshot({ path: testInfo.outputPath("generation-media-mobile.png") });
  expect(runtimeErrors).toEqual([]);
});

test("generation media failure is visible and refresh recovers an expired signed URL", async ({
  page,
}) => {
  const media = {
    inputPreviewUrl: sourcePreview,
    resultPreviewUrl: sourcePreview,
    status: "Completed",
  };
  const api = await installRefundRecoveryMocks(page, false, media);
  await loginAsAdmin(page);
  await page.route(signedMediaOrigin + "/**", (route) =>
    route.request().url().includes("renewed")
      ? route.fulfill({ contentType: "image/svg+xml", body: imageFixture })
      : route.fulfill({ status: 403, body: "Expired" })
  );
  const details = await openMediaHistory(page);
  await expect(details.getByText("Unable to load media", { exact: false })).toHaveCount(2);
  media.inputPreviewUrl = sourcePreview + "&renewed=1";
  media.resultPreviewUrl = sourcePreview + "&renewed=1";
  await details.getByRole("button", { name: "Refresh media", exact: true }).click();
  await expect.poll(api.getDetailRequests).toBeGreaterThan(1);
  await expect(details.getByRole("img", { name: "After", exact: true })).toBeVisible();
  await expect(details.getByText("Unable to load media", { exact: false })).toHaveCount(0);
  await expect
    .poll(() =>
      details
        .getByRole("img", { name: "After", exact: true })
        .evaluate((node: HTMLImageElement) => node.naturalWidth)
    )
    .toBe(640);
});

test("generation history resets filters and refreshes the server-backed list", async ({ page }) => {
  const api = await installRefundRecoveryMocks(page, false);
  await loginAsAdmin(page);
  await page.goto("/en/generations?refundState=exhausted");
  await page.getByRole("button", { name: "Reset filters", exact: true }).click();
  await expect(page.getByRole("combobox", { name: "Charge refund", exact: true })).toHaveValue(
    "all"
  );
  await expect(page).not.toHaveURL(/refundState=/);
  await expect(page.getByRole("button", { name: "Refresh history", exact: true })).toBeEnabled();
  const requests = api.getListRequests();
  await page.getByRole("button", { name: "Refresh history", exact: true }).click();
  await expect.poll(api.getListRequests).toBeGreaterThan(requests);
});
