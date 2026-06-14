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

  it("keeps access filter options unique", () => {
    const source = readFileSync(hubPagePath, "utf8");
    const accessFilterBlock = source.slice(
      source.indexOf("label={text.accessFilter}"),
      source.indexOf("label={text.sortFilter}")
    );

    expect(accessFilterBlock.match(/value: "free"/g) ?? []).toHaveLength(1);
    expect(accessFilterBlock.match(/value: "premium"/g) ?? []).toHaveLength(1);
  });
});
