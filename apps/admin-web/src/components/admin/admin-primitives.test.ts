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
    expect(source).toContain(".table {\n    min-width: 42rem;");
  });
});
