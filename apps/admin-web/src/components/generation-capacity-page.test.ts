import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

import {
  createGenerationCapacitySettingsCommand,
  updateGenerationCapacitySettingsDraft,
} from "../lib/generation-capacity-settings-draft";

import type { AdminGenerationControlSettings } from "../lib/api-client.types.generation-control";

const component = readFileSync(resolve(__dirname, "generation-capacity-page.tsx"), "utf8");
const styles = readFileSync(resolve(__dirname, "generation-capacity-page.module.css"), "utf8");
const topbar = readFileSync(resolve(__dirname, "admin/admin-topbar.tsx"), "utf8");
const apiClient = readFileSync(
  resolve(__dirname, "../lib/api-client.generation-control.ts"),
  "utf8"
);

function createSettings(version: number): AdminGenerationControlSettings {
  return {
    version,
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
    updatedByAdminId: "admin-1",
  };
}

describe("generation capacity admin workflow", () => {
  it("keeps settings and scaling behind explicit review contracts", () => {
    expect(component).toContain("createGenerationCapacitySettingsCommand(settingsDraft");
    expect(component).toContain("settingsReason.trim().length < 3");
    expect(component).toContain("scaleCostConfirmed");
    expect(component).toContain("scaleReviewBaseline.instances");
    expect(component).toContain("setScaleReviewBaseline({");
    expect(component).toContain("instances: currentInstances");
    expect(component).toContain("plan: currentPlan");
    expect(component).toContain('title={`${scaleReviewBaseline?.plan ?? "Render"} ×');
    expect(component).toContain("scaleConflict ||");
    expect(component).toContain("!snapshot.status.isDraining");
    expect(component).toContain("Array.from({ length: 8 }");
    expect(apiClient).toContain('"Idempotency-Key": idempotencyKey');
  });

  it("pins the draft base version so a polled stale draft receives 409", async () => {
    const initialSettings = createSettings(3);
    const draft = updateGenerationCapacitySettingsDraft(
      null,
      initialSettings,
      "globalMaxConcurrent",
      7
    );

    const polledSettings = {
      ...initialSettings,
      version: 4,
      imageMaxConcurrent: 6,
      updatedAtUtc: "2026-07-28T10:01:00Z",
    };
    const draftAfterPolling = updateGenerationCapacitySettingsDraft(
      draft,
      polledSettings,
      "videoMaxConcurrent",
      3
    );
    const command = createGenerationCapacitySettingsCommand(
      draftAfterPolling,
      "Controlled capacity update"
    );

    expect(draftAfterPolling.baseVersion).toBe(3);
    expect(draftAfterPolling.baseValues.imageMaxConcurrent).toBe(7);
    expect(command).toMatchObject({
      expectedVersion: 3,
      globalMaxConcurrent: 7,
      videoMaxConcurrent: 3,
    });

    const fakeBackendUpdate = async () => {
      if (command.expectedVersion !== polledSettings.version) {
        throw Object.assign(new Error("Version conflict"), { status: 409 });
      }
    };

    await expect(fakeBackendUpdate()).rejects.toMatchObject({ status: 409 });
  });

  it("polls live status and a durable Render operation without background polling", () => {
    expect(component).toContain("refetchInterval: 15_000");
    expect(component).toContain("refetchIntervalInBackground: false");
    expect(component).toContain("isTerminalOperation(queryState.state.data)");
    expect(component).toContain("snapshotHasActiveRenderOperation");
    expect(component).toContain(
      "snapshotHasActiveRenderOperation || queriedHasActiveRenderOperation"
    );
    expect(component).toContain(
      "authoritativeRenderInstances * snapshot.settings.workerLoopsPerInstance"
    );
    expect(component).toContain("Math.min(freshWorkers.length, authoritativeRenderInstances)");
  });

  it("keeps persistent generation alerts in the topbar alongside local notifications", () => {
    expect(topbar).toContain("persistentGenerationAlerts");
    expect(topbar).toContain("useAdminNotifications");
    expect(topbar).toContain("onAcknowledgePersistentAlert");
    expect(topbar).toContain("/generations/capacity");
    expect(topbar).toContain("persistentGenerationAlertError");
    expect(topbar).toContain("totalAttentionCount > 0");
  });

  it("renders the compact operator workflow instead of a duplicate page hero", () => {
    expect(component).not.toContain("AdminPageHero");
    expect(component).toContain("createGenerationCapacityViewModel(snapshot, observedLoops)");
    expect(component).toContain('id="generation-overview"');
    expect(component).toContain('id="generation-limits"');
    expect(component).toContain('id="generation-fal"');
    expect(component).toContain('id="generation-workers"');
    expect(component).toContain('id="generation-alerts"');
    expect(component).toContain("aria-label={text.nav.label}");
    expect(component).toContain("applyGenerationCapacityPreset(values)");
    expect(component).toContain('aria-live="polite"');
    expect(component).toContain('role="tablist"');
    expect(component).toContain('role="tab"');
    expect(component).toContain('role="tabpanel"');
    expect(component).toContain('activeSection === "overview"');
    expect(component).toContain('activeSection === "limits"');
    expect(component).toContain('activeSection === "fal"');
    expect(component).toContain('activeSection === "workers"');
    expect(component).toContain('activeSection === "alerts"');
    expect(component).toContain("handleSectionKeyDown");
    expect(component).toContain("aria-controls={activeSection === section ?");
    expect(component).toContain('scrollIntoView({ block: "nearest", inline: "nearest" })');
  });

  it("keeps settings progressive and renders safe server-side fal diagnostics", () => {
    expect(component).toContain("settingsEditing");
    expect(component).toContain("text.settings.summaryTitle");
    expect(component).toContain("text.settings.edit");
    expect(component).toContain("text.fal.verificationChecks.map");
    expect(component).toContain("snapshot.fal.lastErrorCode");
    expect(component).toContain("snapshot.fal.billingAdminKeyConfigured");
    expect(component).toContain("text.fal.lastConfirmedBalance");
    expect(component).toContain('falAttemptState === "stale"');
    expect(component).toContain("queryClient.cancelQueries");
    expect(component).toContain("queryClient.invalidateQueries");
    expect(component).toContain("function MetricStrip");
    expect(component).not.toContain("AdminMetricStrip");
    expect(component).not.toContain("FAL_ACCOUNT_BILLING_ADMIN_KEY");
    expect(component).not.toContain("FAL_EXPECTED_ACCOUNT_USERNAME");
  });

  it("keeps stale workers collapsed and numeric settings accessible", () => {
    expect(component).toContain("const staleWorkers = snapshot.workers.filter");
    expect(component).toContain("<details className={styles.staleWorkers}>");
    expect(component).toContain("text.workers.staleHistory(staleWorkers.length)");
    expect(component).not.toContain("snapshot.workers.map((worker)");
    expect(component).toContain("htmlFor={inputId}");
    expect(component).toContain("aria-describedby=");
    expect(component).toContain("aria-invalid={fieldIssues.length > 0}");
  });

  it("uses shell-aligned breakpoints and mobile-safe layouts", () => {
    expect(styles).toContain("@media (max-width: 1080px)");
    expect(styles).toContain("@media (max-width: 860px)");
    expect(styles).toContain("@media (max-width: 640px)");
    expect(styles).toContain("@media (max-width: 420px)");
    expect(styles).toContain("grid-template-columns: minmax(0, 1fr)");
    expect(styles).toContain("overflow-wrap: anywhere");
    expect(styles).toContain("overflow-x: auto");
  });
});
