import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const overviewPath = fileURLToPath(
  new URL("./template-analytics-overview-sections.tsx", import.meta.url)
);
const pagePath = fileURLToPath(new URL("./template-analytics-page.tsx", import.meta.url));
const stylesPath = fileURLToPath(new URL("./template-analytics-page.module.css", import.meta.url));

describe("template analytics overview visual contract", () => {
  it("keeps chart and status ring colors on semantic theme tokens", () => {
    const source = readFileSync(overviewPath, "utf8");

    expect(source).toContain('stopColor="var(--success)" stopOpacity="0.36"');
    expect(source).toContain('stopColor="var(--success)" stopOpacity="0.02"');
    expect(source).toContain('color: "var(--success)"');
    expect(source).toContain('color: "var(--danger)"');
    expect(source).toContain('color: "var(--info)"');
    expect(source).toContain('color: "var(--warning)"');
    expect(source).toContain("conic-gradient(var(--surface-3) 0 100%)");
    expect(source).not.toContain("rgba(74, 222, 128");
    expect(source).not.toContain("#22c55e");
    expect(source).not.toContain("#f87171");
    expect(source).not.toContain("#7dd3fc");
    expect(source).not.toContain("#fcd34d");
    expect(source).not.toContain("conic-gradient(#1f3651 0 100%)");
  });

  it("keeps detail tabs and chart summaries usable on phone screens", () => {
    const styles = readFileSync(stylesPath, "utf8");

    expect(styles).toContain("@media (max-width: 720px)");
    expect(styles).toContain(".toolbarActions,\n  .segmentedControl,\n  .chartTabs");
    expect(styles).toContain(".chartTabs {\n    width: 100%;");
    expect(styles).toContain("justify-content: flex-start;");
    expect(styles).toContain(".chartTab,\n  .chartTabActive");
    expect(styles).toContain("flex: 1 1 min(10rem, 100%);");
    expect(styles).toContain("min-width: 0;");
    expect(styles).toContain(".chartSummaryRow {\n    grid-template-columns: repeat(2, minmax(0, 1fr));");
  });

  it("shows disabled detail analytics controls consistently during refreshes", () => {
    const overviewSource = readFileSync(overviewPath, "utf8");
    const pageSource = readFileSync(pagePath, "utf8");
    const styles = readFileSync(stylesPath, "utf8");

    expect(pageSource).toContain("const isActivePeriod = option.key === period;");
    expect(pageSource).toContain("disabled={isActivePeriod || isAnalyticsToolbarLocked}");
    expect(pageSource).toContain("isChartMetricLocked={isAnalyticsToolbarLocked}");
    expect(overviewSource).toContain("isChartMetricLocked = false");
    expect(overviewSource).toContain("const isActiveChartMetric = tab.key === chartMetric;");
    expect(overviewSource).toContain("disabled={isActiveChartMetric || isChartMetricLocked}");
    expect(styles).toContain(".segmentedButton:disabled,");
    expect(styles).toContain(".toolbarButtonActive:disabled,");
    expect(styles).toContain(".exportButton:disabled,");
    expect(styles).toContain(".chartTabActive:disabled");
    expect(styles).toContain("cursor: not-allowed;");
    expect(styles).toContain("opacity: 0.58;");
    expect(styles).toContain("transform: none;");
    expect(styles).toContain("box-shadow: none;");
  });

  it("keeps template analytics typography readable without decorative tracking", () => {
    const styles = readFileSync(stylesPath, "utf8");
    const nonZeroLetterSpacingRules = [...styles.matchAll(/letter-spacing:\s*([^;]+);/g)]
      .map((match) => match[1].trim())
      .filter((value) => value !== "0");

    expect(nonZeroLetterSpacingRules).toEqual([]);
    expect(styles).toContain("letter-spacing: 0;");
  });

  it("keeps template analytics feedback cards on compact admin radii", () => {
    const styles = readFileSync(stylesPath, "utf8");

    expect(styles).toContain(".feedbackSearchInput:focus-visible");
    expect(styles).toContain("box-shadow: var(--focus-ring);");
    expect(styles).not.toMatch(/\.feedbackSearchInput:focus(?!-visible)/);
    expect(styles).toContain(".feedbackItem {");
    expect(styles).toContain("border-radius: var(--radius-sm);");
    expect(styles).not.toMatch(/border-radius:\s*(?:0\.7rem|0\.8rem|0\.9rem|1rem|1[2-9]px|[2-9][0-9]px)/);
  });
});
