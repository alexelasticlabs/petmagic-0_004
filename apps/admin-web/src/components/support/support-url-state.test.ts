import { describe, expect, it } from "vitest";

import {
  buildSupportQueueSearchParams,
  DEFAULT_SUPPORT_QUEUE_URL_STATE,
  readSupportQueueUrlState,
  SUPPORT_QUEUE_PAGE_MAX,
  SUPPORT_SEARCH_MAX_LENGTH,
} from "@/components/support/support-conversation-controller.helpers";

describe("support queue URL state", () => {
  it("restores the supported server-side filters with project casing", () => {
    const state = readSupportQueueUrlState(
      new URLSearchParams({
        queue: "UnAssigned",
        status: "waitingforuser",
        priority: "high",
        sort: "WAITING",
        search: "  delayed refund  ",
        page: "12",
      })
    );

    expect(state).toEqual({
      subFilter: "unassigned",
      status: "WaitingForUser",
      priority: "High",
      sort: "waiting",
      search: "delayed refund",
      page: 12,
    });
  });

  it("accepts legacy subFilter and assignment links while keeping a canonical queue value", () => {
    expect(readSupportQueueUrlState(new URLSearchParams("subFilter=unassigned")).subFilter).toBe(
      "unassigned"
    );
    expect(readSupportQueueUrlState(new URLSearchParams("assignment=unassigned")).subFilter).toBe(
      "unassigned"
    );
  });

  it("round-trips the dashboard unread queue as a supported backend filter", () => {
    const state = readSupportQueueUrlState(new URLSearchParams("queue=unread"));

    expect(state.subFilter).toBe("unread");
    expect(buildSupportQueueSearchParams(state)).toBe("queue=unread");
  });

  it("rejects unsupported values and applies search and page limits", () => {
    const state = readSupportQueueUrlState(
      new URLSearchParams({
        queue: "mine",
        status: "Deleted",
        priority: "Critical",
        sort: "random",
        search: "x".repeat(SUPPORT_SEARCH_MAX_LENGTH + 40),
        page: "999999",
      })
    );

    expect(state).toEqual({
      ...DEFAULT_SUPPORT_QUEUE_URL_STATE,
      search: "x".repeat(SUPPORT_SEARCH_MAX_LENGTH),
      page: SUPPORT_QUEUE_PAGE_MAX,
    });
    expect(readSupportQueueUrlState(new URLSearchParams("page=0")).page).toBe(1);
    expect(readSupportQueueUrlState(new URLSearchParams("page=2oops")).page).toBe(1);
  });

  it("writes a canonical query without dropping unrelated route state", () => {
    const query = buildSupportQueueSearchParams(
      {
        subFilter: "unassigned",
        status: "New",
        priority: "High",
        sort: "priority",
        search: "  urgent ticket  ",
        page: 3,
      },
      "tab=activity&subFilter=unassigned&assignment=mine&queue=all&status=all&page=1"
    );
    const params = new URLSearchParams(query);

    expect(Object.fromEntries(params)).toEqual({
      tab: "activity",
      queue: "unassigned",
      status: "New",
      priority: "High",
      sort: "priority",
      search: "urgent ticket",
      page: "3",
    });
    expect(params.has("subFilter")).toBe(false);
    expect(params.has("assignment")).toBe(false);
  });

  it("omits default values so the inbox URL stays compact", () => {
    expect(
      buildSupportQueueSearchParams(
        DEFAULT_SUPPORT_QUEUE_URL_STATE,
        "tab=user&queue=all&status=all&priority=all&sort=default&search=&page=1"
      )
    ).toBe("tab=user");
  });
});
