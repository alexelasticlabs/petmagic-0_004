import { describe, expect, it } from "vitest";

import { buildAdminUrlStateHref, readAdminUrlState, updateAdminUrlState } from "./admin-url-state";

describe("admin URL state", () => {
  it("reads canonical filters, sorting, pagination, selection and tabs", () => {
    const state = readAdminUrlState(
      new URLSearchParams(
        "status=failed&provider=%20kling%20&sort=-createdAt&page=3&selected=job-42&tab=history"
      ),
      { filterKeys: ["status", "provider", "page", "invalid key"] }
    );

    expect(state).toEqual({
      filters: { status: "failed", provider: "kling" },
      sort: "-createdAt",
      page: 3,
      selected: "job-42",
      tab: "history",
    });
  });

  it("falls back to a safe page and ignores invalid filter keys", () => {
    const state = readAdminUrlState(new URLSearchParams("page=2invalid&bad%20key=value"), {
      filterKeys: ["bad key"],
      defaultPage: 2,
    });

    expect(state.page).toBe(2);
    expect(state.filters).toEqual({});
  });

  it("preserves unrelated query state and resets pagination after a query change", () => {
    const next = updateAdminUrlState(new URLSearchParams("status=pending&page=7&dialog=refund"), {
      filters: { status: "failed", provider: "" },
      sort: "-createdAt",
      selected: "job-42",
      tab: "events",
    });

    expect(next.toString()).toBe(
      "status=failed&dialog=refund&sort=-createdAt&selected=job-42&tab=events"
    );
  });

  it("keeps an explicitly requested page and canonicalizes the first page", () => {
    const explicitPage = updateAdminUrlState(new URLSearchParams("page=8"), {
      filters: { status: "done" },
      page: 4,
    });
    const firstPage = updateAdminUrlState(explicitPage, { page: 1 });

    expect(explicitPage.toString()).toBe("page=4&status=done");
    expect(firstPage.toString()).toBe("status=done");
  });

  it("builds a deep link without adding an empty question mark", () => {
    expect(
      buildAdminUrlStateHref("/ru/generations", new URLSearchParams("page=2"), {
        page: null,
      })
    ).toBe("/ru/generations");
  });
});
