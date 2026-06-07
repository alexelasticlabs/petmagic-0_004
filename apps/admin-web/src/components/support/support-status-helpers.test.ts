import { describe, expect, it } from "vitest";

import {
  getAvailableStatusActions,
  statusLabel,
} from "@/components/support/support-status-helpers";
import { getDictionary } from "@/lib/i18n";

describe("getAvailableStatusActions", () => {
  it("does not expose manual InProgress action for New status", () => {
    const actions = getAvailableStatusActions("New", getDictionary("ru"));

    expect(actions.some((action) => action.status === "InProgress")).toBe(false);
    expect(actions).toEqual([
      {
        status: "Closed",
        label: getDictionary("ru").supportCloseConversationAction,
        variant: "secondary",
      },
    ]);
  });

  it("does not expose manual InProgress action for WaitingForUser status", () => {
    const actions = getAvailableStatusActions("WaitingForUser", getDictionary("en"));

    expect(actions.some((action) => action.status === "InProgress")).toBe(false);
    expect(actions).toEqual([
      {
        status: "Closed",
        label: getDictionary("en").supportCloseConversationAction,
        variant: "secondary",
      },
    ]);
  });

  it("does not expose manual WaitingForUser action for InProgress status", () => {
    const actions = getAvailableStatusActions("InProgress", getDictionary("ru"));

    expect(actions.some((action) => action.status === "WaitingForUser")).toBe(false);
    expect(actions).toEqual([
      {
        status: "Closed",
        label: getDictionary("ru").supportCloseConversationAction,
        variant: "secondary",
      },
    ]);
  });
});

describe("support status labels", () => {
  it("sanitizes unexpected backend status values before display", () => {
    const label = statusLabel(
      "Escalated token=raw-secret receipt=ios-secret https://cdn.example.com/a?sig=1",
      getDictionary("en")
    );

    expect(label).toContain("token=[redacted]");
    expect(label).toContain("receipt=[redacted]");
    expect(label).not.toContain("raw-secret");
    expect(label).not.toContain("ios-secret");
    expect(label).not.toContain("sig=1");
    expect(label.length).toBeLessThanOrEqual(48);
  });
});
