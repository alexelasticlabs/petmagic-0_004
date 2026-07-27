import { describe, expect, it } from "vitest";

import { getAdminPaginationItems } from "./admin-pagination";

describe("admin pagination", () => {
  it("keeps edge pages and a compact current-page window", () => {
    expect(getAdminPaginationItems(6, 12)).toEqual([
      { type: "page", page: 1 },
      { type: "ellipsis", key: "start" },
      { type: "page", page: 5 },
      { type: "page", page: 6 },
      { type: "page", page: 7 },
      { type: "ellipsis", key: "end" },
      { type: "page", page: 12 },
    ]);
  });

  it("does not duplicate pages near either edge", () => {
    expect(getAdminPaginationItems(1, 3)).toEqual([
      { type: "page", page: 1 },
      { type: "page", page: 2 },
      { type: "page", page: 3 },
    ]);
    expect(getAdminPaginationItems(99, 3)).toEqual([
      { type: "page", page: 1 },
      { type: "page", page: 2 },
      { type: "page", page: 3 },
    ]);
    expect(getAdminPaginationItems(4, 4)).toEqual([
      { type: "page", page: 1 },
      { type: "page", page: 2 },
      { type: "page", page: 3 },
      { type: "page", page: 4 },
    ]);
  });

  it("normalizes invalid totals to one page", () => {
    expect(getAdminPaginationItems(Number.NaN, 0)).toEqual([{ type: "page", page: 1 }]);
  });
});
