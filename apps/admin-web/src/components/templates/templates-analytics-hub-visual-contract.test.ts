import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const hubPagePath = fileURLToPath(new URL("./templates-analytics-hub-page.tsx", import.meta.url));
const hubStylesPath = fileURLToPath(
  new URL("./templates-analytics-hub-page.module.css", import.meta.url)
);

describe("templates analytics hub visual contract", () => {
  it("keeps chart and funnel colors on semantic theme tokens", () => {
    const source = readFileSync(hubPagePath, "utf8");
    const styles = readFileSync(hubStylesPath, "utf8");

    expect(source).toContain('stopColor="var(--success)"');
    expect(source).toContain('stopColor="var(--info)"');
    expect(source).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(styles).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(styles).not.toContain("rgba(");
    expect(styles).toContain("background: var(--accent-soft-bg);");
    expect(styles).toContain("color: var(--danger-soft-fg);");
  });

  it("keeps analytics summary panels on compact admin radii", () => {
    const styles = readFileSync(hubStylesPath, "utf8");

    expect(styles).toContain(".chartSummary {");
    expect(styles).toContain("border-radius: var(--radius-sm);");
    expect(styles).not.toMatch(/border-radius:\s*(?:0\.7rem|0\.8rem|0\.9rem|1rem|1[2-9]px|[2-9][0-9]px)/);
  });

  it("keeps the analytics table usable on narrow screens", () => {
    const styles = readFileSync(hubStylesPath, "utf8");

    expect(styles).toContain(".tableWrap {\n  position: relative;");
    expect(styles).toContain("overflow-x: auto;");
    expect(styles).toContain("overscroll-behavior-inline: contain;");
    expect(styles).toContain("scrollbar-width: thin;");
    expect(styles).toContain(".tableWrap::after");
    expect(styles).toContain(".table th {\n  position: sticky;");
    expect(styles).toContain("background: var(--surface-1);");
  });

  it("keeps analytics hub controls stacked and tappable on phone screens", () => {
    const styles = readFileSync(hubStylesPath, "utf8");

    expect(styles).toContain("@media (max-width: 760px)");
    expect(styles).toContain(".toolbar {\n    flex-direction: column;");
    expect(styles).toContain(".filters,\n  .segmented,\n  .chartTabs");
    expect(styles).toContain("width: 100%;\n    justify-content: flex-start;");
    expect(styles).toContain(".chartTab,\n  .chartTabActive");
    expect(styles).toContain("width: 100%;");
  });

  it("keeps access filter options unique", () => {
    const source = readFileSync(hubPagePath, "utf8");
    const accessFilterBlock = source.slice(
      source.indexOf("label={text.accessFilter}"),
      source.indexOf("label={text.sortFilter}")
    );

    expect(accessFilterBlock.match(/value: "free"/g) ?? []).toHaveLength(1);
    expect(accessFilterBlock.match(/value: "premium"/g) ?? []).toHaveLength(1);
  });

  it("bounds analytics bar widths so backend outliers cannot overflow panels", () => {
    const source = readFileSync(hubPagePath, "utf8");

    expect(source).toContain("function getBoundedBarWidthPercent");
    expect(source).toContain("return Math.min(100, Math.max(minimumVisiblePercent, value));");
    expect(source).toContain("getBoundedBarWidthPercent((row.value / max) * 100, 5)");
    expect(source).toContain("getBoundedBarWidthPercent((row.views / maxViews) * 100, 6)");
    expect(source).toContain("getBoundedBarWidthPercent(row.sharePercent, 5)");
    expect(source).not.toContain("width: `${Math.max(5, (row.value / max) * 100)}%`");
    expect(source).not.toContain("width: `${Math.max(6, (row.views / maxViews) * 100)}%`");
    expect(source).not.toContain("width: `${Math.max(5, row.sharePercent)}%`");
  });
});
