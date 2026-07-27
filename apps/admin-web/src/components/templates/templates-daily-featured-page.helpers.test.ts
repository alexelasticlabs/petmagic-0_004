import { describe, expect, it } from "vitest";

import {
  emptyForm,
  formFromAssignment,
  getBusinessDateOrClientToday,
  isExcludeRecentDaysValid,
  isPriorityValid,
  toPayload,
} from "./templates-daily-featured-page.helpers";

describe("templates daily featured helpers", () => {
  it("preserves the automatic mode while editing an existing auto-pick", () => {
    const form = formFromAssignment({
      id: "11111111-1111-1111-1111-111111111111",
      templateId: "22222222-2222-2222-2222-222222222222",
      templateTitle: "Auto portrait",
      templateType: "Image",
      category: "Portrait",
      status: "Active",
      isPremium: false,
      startDate: "2026-07-26",
      endDate: "2026-07-26",
      isActive: true,
      isManual: false,
      priority: 0,
      createdAtUtc: "2026-07-26T08:00:00Z",
      updatedAtUtc: "2026-07-26T08:00:00Z",
    });

    expect(form.isManual).toBe(false);
    expect(toPayload(form).isManual).toBe(false);
    expect(emptyForm("2026-07-26").isManual).toBe(true);
  });

  it("uses the backend business date when it is available", () => {
    expect(getBusinessDateOrClientToday("2026-07-26")).toBe("2026-07-26");
  });

  it("rejects values that would otherwise be silently coerced", () => {
    expect(isExcludeRecentDaysValid("0")).toBe(true);
    expect(isExcludeRecentDaysValid("365")).toBe(true);
    expect(isExcludeRecentDaysValid("365.5")).toBe(false);
    expect(isExcludeRecentDaysValid("366")).toBe(false);
    expect(isPriorityValid("-1")).toBe(true);
    expect(isPriorityValid("3.5")).toBe(false);
    expect(isPriorityValid("2147483648")).toBe(false);
  });
});
