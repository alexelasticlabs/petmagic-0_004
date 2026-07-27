import { describe, expect, it } from "vitest";

import {
  getAvailableStatusActions,
  statusLabel,
} from "@/components/support/support-status-helpers";
import { getDictionary } from "@/lib/i18n";

function createConversationActionState(
  status: "New" | "InProgress" | "WaitingForUser" | "Closed",
  availableActions: string[],
  canReopen = false
) {
  return { status, availableActions, canReopen };
}

describe("getAvailableStatusActions", () => {
  it("uses the close action advertised by the backend for open tickets", () => {
    const actions = getAvailableStatusActions(
      createConversationActionState("New", ["close"]),
      getDictionary("ru")
    );

    expect(actions.some((action) => action.status === "InProgress")).toBe(false);
    expect(actions).toEqual([
      {
        status: "Closed",
        label: getDictionary("ru").supportCloseConversationAction,
        variant: "secondary",
      },
    ]);
  });

  it("does not invent a status action when the backend does not advertise it", () => {
    const actions = getAvailableStatusActions(
      createConversationActionState("WaitingForUser", []),
      getDictionary("en")
    );

    expect(actions).toEqual([]);
  });

  it("exposes reopen only when both backend signals permit it", () => {
    const text = getDictionary("ru");
    const actions = getAvailableStatusActions(
      createConversationActionState("Closed", ["reopen"], true),
      text
    );

    expect(actions).toEqual([
      {
        status: "InProgress",
        label: text.supportReopenConversationAction,
        variant: "primary",
      },
    ]);

    expect(
      getAvailableStatusActions(createConversationActionState("Closed", ["reopen"]), text)
    ).toEqual([]);
  });

  it("ignores backend actions that are not status transitions rendered in this UI", () => {
    const actions = getAvailableStatusActions(
      createConversationActionState("InProgress", ["unassign", "unknown-action"]),
      getDictionary("en")
    );

    expect(actions).toEqual([]);
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
