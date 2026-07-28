import { describe, expect, it } from "vitest";

import { getGenerationCapacityCopy } from "./generation-capacity-page.content";

describe("generation capacity copy", () => {
  it("keeps the redesigned operator workflow complete in both locales", () => {
    for (const locale of ["ru", "en"] as const) {
      const copy = getGenerationCapacityCopy(locale);

      expect(copy.nav).toMatchObject({
        overview: expect.any(String),
        limits: expect.any(String),
        fal: "fal.ai",
        workers: expect.any(String),
        alerts: expect.any(String),
      });
      expect(Object.keys(copy.readiness.states).sort()).toEqual([
        "degraded",
        "draining",
        "provider_blocked",
        "ready",
      ]);
      expect(copy.settings.groups).toHaveProperty("total");
      expect(copy.settings.groups).toHaveProperty("image");
      expect(copy.settings.groups).toHaveProperty("video");
      expect(copy.settings.groups).toHaveProperty("fal");
      expect(copy.settings.groups).toHaveProperty("balance");
      expect(copy.settings.presetValues).toContain("Global 8");
      expect(copy.settings.presetValues).toContain("fal.ai 10−2");
      expect(copy.render.setupVariables).toContain("RENDER_API_KEY");
    }
  });

  it("presents blocked setup, stale history, validation, and known alerts in Russian", () => {
    const copy = getGenerationCapacityCopy("ru");

    expect(copy.readiness.states.provider_blocked.title).toMatch(/приостановлена/iu);
    expect(copy.readiness.providerReasons.concurrency_unknown).toMatch(/лимит/iu);
    expect(copy.readiness.providerReasons.balance_unknown).toMatch(/баланс/iu);
    expect(copy.settings.applyPreset).toBe("Подставить значения");
    expect(copy.settings.presetDoesNotSave).toMatch(/черновик/iu);
    expect(copy.workers.staleHistory(18)).toMatch(/устаревшие.*18/iu);
    expect(copy.workers.staleHistoryHint).toMatch(/скрыта по умолчанию/iu);
    expect(copy.settings.validation.falLimitMissing).toMatch(/укажите.*fal\.ai/iu);
    expect(copy.alerts.catalog.fal_balance_unknown).toMatchObject({
      target: "fal",
      title: expect.stringMatching(/баланс/iu),
    });
    expect(copy.alerts.catalog.worker_capacity_insufficient).toMatchObject({
      target: "workers",
      title: expect.stringMatching(/worker/iu),
    });
  });

  it("keeps every mutable setting labelled and explained in both locales", () => {
    const ru = getGenerationCapacityCopy("ru");
    const en = getGenerationCapacityCopy("en");

    expect(Object.keys(ru.fields).sort()).toEqual(Object.keys(en.fields).sort());
    for (const key of Object.keys(ru.fields)) {
      const fieldKey = key as keyof typeof ru.fields;
      expect(ru.fields[fieldKey].label.trim()).not.toBe("");
      expect(ru.fields[fieldKey].hint.trim()).not.toBe("");
      expect(en.fields[fieldKey].label.trim()).not.toBe("");
      expect(en.fields[fieldKey].hint.trim()).not.toBe("");
    }
  });
});
