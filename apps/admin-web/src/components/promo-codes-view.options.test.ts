import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import { buildPromoCodesViewOptions } from "@/components/promo-codes-view.options";
import { getDictionary } from "@/lib/i18n";

import { readPromoCodesViewLibrarySource } from "./promo-codes-view.test-source";

const promoCodesViewOptionsPath = fileURLToPath(
  new URL("./promo-codes-view.options.ts", import.meta.url)
);
const promoCodesContentPath = fileURLToPath(
  new URL("./promo-codes-view.content.ts", import.meta.url)
);
const promoCodesListCardPath = fileURLToPath(
  new URL("./promo-codes-list-card.tsx", import.meta.url)
);
const promoCodesEditorDrawerPath = fileURLToPath(
  new URL("./promo-codes-editor-drawer.tsx", import.meta.url)
);

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

    expect(result.rewardOptions.map((item) => item.value)).toEqual(["all", "spark"]);

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
    const optionsSource = readFileSync(promoCodesViewOptionsPath, "utf8");
    const contentSource = readFileSync(promoCodesContentPath, "utf8");

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
    expect(optionsSource).toContain(
      'import {\n  buildPromoCodesPageSizeLabel,\n  getPromoCodesViewText,\n} from "@/components/promo-codes-view.content";'
    );
    expect(optionsSource).toContain("const promoText = getPromoCodesViewText(locale);");
    expect(optionsSource).not.toContain('locale === "ru" ? "Все" : "All"');
    expect(optionsSource).not.toContain('locale === "ru" ? "Все награды" : "All rewards"');
    expect(optionsSource).not.toContain(
      'locale === "ru" ? `${option} на странице` : `${option} per page`'
    );
    expect(contentSource).toContain('statusTabAll: "All"');
    expect(contentSource).toContain('rewardAllLabel: "All rewards"');
  });

  it("does not expose backend-unsupported premium rewards as production UI options", () => {
    const text = getDictionary("en");
    const result = buildPromoCodesViewOptions("en", text);
    const drawerSource = readFileSync(promoCodesEditorDrawerPath, "utf8");

    expect(text.promoCodesRewardTypePremiumOption).not.toMatch(/soon/i);
    expect(getDictionary("ru").promoCodesRewardTypePremiumOption).not.toContain("скоро");
    expect(result.rewardOptions.map((item) => item.value)).not.toContain("premium_days");
    expect(drawerSource).not.toContain('<option value="premium_days" disabled>');
    expect(drawerSource).toContain(
      '<option value="spark">{text.promoCodesRewardTypeSparkOption}</option>'
    );
  });

  it("bounds promo code search input before filtering the client-side registry", () => {
    const viewSource = readPromoCodesViewLibrarySource();
    const listSource = readFileSync(promoCodesListCardPath, "utf8");

    expect(viewSource).toContain("const PROMO_CODES_SEARCH_MAX_LENGTH = 120;");
    expect(viewSource).toContain("setSearch(value.slice(0, PROMO_CODES_SEARCH_MAX_LENGTH));");
    expect(listSource).toContain("const PROMO_CODES_SEARCH_MAX_LENGTH = 120;");
    expect(listSource).toContain(
      "onSearchChange(event.target.value.slice(0, PROMO_CODES_SEARCH_MAX_LENGTH))"
    );
    expect(listSource).toContain("maxLength={PROMO_CODES_SEARCH_MAX_LENGTH}");
    expect(viewSource).not.toContain("setSearch(value);\n            setPage(1);");
    expect(listSource).not.toContain("onChange={(event) => onSearchChange(event.target.value)}");
  });
});
