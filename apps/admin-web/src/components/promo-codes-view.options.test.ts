import { describe, expect, it } from "vitest";

import { buildPromoCodesViewOptions } from "@/components/promo-codes-view.options";
import { getDictionary } from "@/lib/i18n";

describe("buildPromoCodesViewOptions", () => {
  it("returns stable options shape for ru locale", () => {
    const text = getDictionary("ru");

    const result = buildPromoCodesViewOptions("ru", text);

    expect(result.statusTabs).toHaveLength(6);
    expect(result.statusTabs[0]).toEqual({ value: "all", label: "Все" });
    expect(result.statusTabs.at(-1)).toEqual({ value: "archived", label: "Архивные" });

    expect(result.statusOptions.map((item) => item.value)).toEqual([
      "all",
      "draft",
      "active",
      "scheduled",
      "paused",
      "exhausted",
      "expired",
      "archived",
    ]);

    expect(result.rewardOptions.map((item) => item.value)).toEqual([
      "all",
      "spark",
      "premium_days",
    ]);

    expect(result.formStatusOptions.map((item) => item.value)).toEqual(["active", "paused"]);

    expect(result.sortOptions.map((item) => item.value)).toEqual([
      "updated",
      "usage",
      "reward",
      "code",
      "expiry",
    ]);

    expect(result.pageSizeOptions.map((item) => item.value)).toEqual(["6", "10", "20"]);
    expect(result.pageSizeOptions[0]?.label).toContain("6");
  });

  it("renders english labels for status tabs", () => {
    const text = getDictionary("en");

    const result = buildPromoCodesViewOptions("en", text);

    expect(result.statusTabs).toEqual([
      { value: "all", label: "All" },
      { value: "active", label: "Active" },
      { value: "draft", label: "Drafts" },
      { value: "paused", label: "Paused" },
      { value: "expired", label: "Expired" },
      { value: "archived", label: "Archived" },
    ]);
    expect(result.pageSizeOptions[1]?.label).toBe("10 per page");
  });
});
