import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const primitivesCssPath = fileURLToPath(
  new URL("./admin-primitives.module.css", import.meta.url)
);
const primitivesSourcePath = fileURLToPath(new URL("./admin-primitives.tsx", import.meta.url));

describe("admin primitives responsive layout", () => {
  it("lets composed screens size status badges without CSS module hash selectors", () => {
    const source = readFileSync(primitivesSourcePath, "utf8");

    expect(source).toContain("className?: string;");
    expect(source).toContain(
      "const badgeClassName = className ? `${styles.statusBadge} ${className}` : styles.statusBadge;"
    );
    expect(source).toContain('<span className={badgeClassName} style={style}>');
  });

  it("keeps stat and status accents on semantic theme fallbacks", () => {
    const source = readFileSync(primitivesCssPath, "utf8");

    expect(source).toContain("var(--stat-accent, var(--success))");
    expect(source).toContain("var(--status-color, var(--success))");
    expect(source).not.toContain("var(--stat-accent, #");
    expect(source).not.toContain("var(--status-color, #");
  });

  it("lets composed dialogs bind shared card headings to aria-labelledby", () => {
    const source = readFileSync(primitivesSourcePath, "utf8");

    expect(source).toContain("titleId?: string;");
    expect(source).toContain("titleId,");
    expect(source).toContain("<h2 id={titleId} className={styles.cardTitle}>");
    expect(source).not.toContain("{title ? <h2 className={styles.cardTitle}>{title}</h2> : null}");
  });

  it("keeps shared primitive typography and surfaces on theme tokens", () => {
    const source = readFileSync(primitivesCssPath, "utf8");
    const nonZeroLetterSpacingRules = [...source.matchAll(/letter-spacing:\s*([^;]+);/g)]
      .map((match) => match[1]?.trim())
      .filter((value) => value !== "0");

    expect(source).toContain("letter-spacing: 0;");
    expect(source).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(source).not.toContain("rgba(");
    expect(source).not.toContain("radial-gradient");
    expect(source).not.toMatch(/font-size:\s*[^;]*vw/);
    expect(nonZeroLetterSpacingRules).toEqual([]);
  });

  it("keeps shared data tables usable on narrow screens and long pages", () => {
    const source = readFileSync(primitivesCssPath, "utf8");

    expect(source).toContain(".tableWrap {\n  position: relative;");
    expect(source).toContain("overflow-x: auto;");
    expect(source).toContain("overscroll-behavior-inline: contain;");
    expect(source).toContain("scrollbar-width: thin;");
    expect(source).toContain(".tableWrap::-webkit-scrollbar");
    expect(source).toContain(".tableWrap::after");
    expect(source).toContain(".table th {\n  position: sticky;");
    expect(source).toContain("background: var(--surface-1);");
    expect(source).toContain("@media (max-width: 640px)");
    expect(source).toContain(".table {\n    min-width: min(34rem, calc(100vw - 2rem));");
  });

  it("keeps native admin select fields locked when option data is empty", () => {
    const source = readFileSync(primitivesSourcePath, "utf8");
    const css = readFileSync(primitivesCssPath, "utf8");

    expect(source).toContain("const hasOptions = options.length > 0;");
    expect(source).toContain("const isSelectDisabled = disabled || !hasOptions;");
    expect(source).toContain("disabled={isSelectDisabled}");
    expect(source).toContain("if (isSelectDisabled) {\n            return;\n          }");
    expect(source).not.toContain("disabled={disabled}");

    expect(css).toContain(".selectControl:disabled {");
    expect(css).toContain("cursor: not-allowed;");
    expect(css).toContain("background: var(--surface-2);");
  });

  it("announces shared state cards with severity-aware live regions", () => {
    const source = readFileSync(primitivesSourcePath, "utf8");

    expect(source).toContain(
      'const stateRole = tone === "danger" || tone === "warning" ? "alert" : "status";'
    );
    expect(source).toContain('const stateLiveMode = stateRole === "alert" ? "assertive" : "polite";');
    expect(source).toContain("role={stateRole}");
    expect(source).toContain("aria-live={stateLiveMode}");
  });
});
