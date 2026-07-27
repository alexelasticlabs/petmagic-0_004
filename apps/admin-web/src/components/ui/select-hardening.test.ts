import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const selectPath = fileURLToPath(new URL("./select.tsx", import.meta.url));
const selectCssPath = fileURLToPath(new URL("./select.module.css", import.meta.url));

describe("shared admin select hardening", () => {
  it("keeps empty option sets locked instead of opening an empty listbox", () => {
    const source = readFileSync(selectPath, "utf8");
    const css = readFileSync(selectCssPath, "utf8");

    expect(source).toContain("const hasOptions = options.length > 0;");
    expect(source).toContain("const isSelectDisabled = disabled || !hasOptions;");
    expect(source).toContain("const isMenuOpen = isOpen && !isSelectDisabled;");
    expect(source).toContain(
      "useEffect(() => {\n    if (!isSelectDisabled) {\n      return;\n    }"
    );
    expect(source).toContain("queueMicrotask(() => {");
    expect(source).toContain("setIsOpen(false);");
    expect(source).toContain("isCurrent = false;");
    expect(source).toContain("if (isSelectDisabled) {\n      return;\n    }");
    expect(source).toContain("disabled={isSelectDisabled}");
    expect(source).not.toContain("const isMenuOpen = isOpen && !disabled;");
    expect(source).not.toContain("disabled={disabled}");

    expect(css).toContain(".trigger:disabled {");
    expect(css).toContain("cursor: not-allowed;");
    expect(css).toContain("opacity: 0.62;");
    expect(css).toContain(".trigger:disabled:hover {");
    expect(css).toContain("transform: none;");
  });

  it("keeps trigger and listbox names stable even when callers omit ariaLabel", () => {
    const source = readFileSync(selectPath, "utf8");

    expect(source).toContain(
      'const effectiveAriaLabel = ariaLabel ?? selectedOption?.label ?? "Select";'
    );
    expect(source).toContain("aria-controls={isMenuOpen ? listboxId : undefined}");
    expect(source).toContain("aria-label={effectiveAriaLabel}");
    expect(source).toContain("title={effectiveAriaLabel}");
    expect(source).toContain("id={listboxId}");
    expect(source).toContain(
      'className={`${styles.menu} ${menuMode === "inline" ? styles.menuInline : ""}`.trim()}'
    );
    expect(source).toContain('role="listbox"');
    expect(source).not.toContain("aria-controls={listboxId}");
    expect(source).not.toContain("aria-label={ariaLabel}");
    expect(source).not.toContain("title={ariaLabel}");
    expect(source).not.toContain('role="listbox" aria-label={ariaLabel}');
  });

  it("returns focus to the trigger when Escape closes an open listbox", () => {
    const source = readFileSync(selectPath, "utf8");

    expect(source).toContain(
      'function handleEscape(event: KeyboardEvent) {\n      if (event.key === "Escape") {\n        closeMenu(true);\n      }\n    }'
    );
    expect(source).toContain(
      'case "Escape":\n                      event.preventDefault();\n                      closeMenu(true);'
    );
  });

  it("keeps select visual states on tokens without decorative tracking", () => {
    const css = readFileSync(selectCssPath, "utf8");
    const nonZeroLetterSpacingRules = [...css.matchAll(/letter-spacing:\s*([^;]+);/g)]
      .map((match) => match[1]?.trim())
      .filter((value) => value !== "0");

    expect(css).toContain("letter-spacing: 0;");
    expect(css).toContain("border-radius: var(--radius-sm);");
    expect(css).toContain("box-shadow: var(--shadow-strong);");
    expect(css).not.toContain("rgba(");
    expect(css).not.toContain("radial-gradient");
    expect(css).not.toContain("linear-gradient(180deg");
    expect(css).not.toContain("0 14px 28px");
    expect(css).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(css).not.toMatch(
      /border-radius:\s*(?:0\.5[8-9]rem|0\.6[0-9]rem|0\.7rem|0\.8rem|0\.9rem|1rem|1[2-9]px|[2-9][0-9]px)/
    );
    expect(nonZeroLetterSpacingRules).toEqual([]);
  });

  it("keeps selected values readable in mobile stacked triggers", () => {
    const css = readFileSync(selectCssPath, "utf8");

    expect(css).toContain("@media (max-width: 720px)");
    expect(css).toContain(".optionTopRow,\n  .triggerTopRow");
    expect(css).toContain("flex-direction: column;");
    expect(css).toContain(".triggerMeta {\n    align-self: flex-start;\n    flex-wrap: wrap;");
    expect(css).toContain(".value,\n  .triggerDescription {\n    overflow: visible;");
    expect(css).toContain("text-overflow: clip;");
    expect(css).toContain("white-space: normal;");
    expect(css).toContain("overflow-wrap: anywhere;");
  });

  it("bounds long option menus so they remain usable on small screens", () => {
    const css = readFileSync(selectCssPath, "utf8");

    const menuBlock = css.match(/\.menu \{[\s\S]*?\n\}/)?.[0] ?? "";
    const mobileBlock =
      css.match(/@media \(max-width: 720px\) \{[\s\S]*?\.menu \{[\s\S]*?\n  \}/)?.[0] ?? "";

    expect(menuBlock).toContain("max-height: min(22rem, calc(100dvh - 8rem));");
    expect(menuBlock).toContain("overflow-y: auto;");
    expect(menuBlock).toContain("overscroll-behavior: contain;");
    expect(menuBlock).toContain("scrollbar-width: thin;");
    expect(css).toContain(".menu::-webkit-scrollbar");
    expect(css).toContain(".menu::-webkit-scrollbar-thumb");
    expect(mobileBlock).toContain("max-height: min(20rem, calc(100dvh - 10rem));");
    expect(css).not.toContain("100vh");
  });

  it("supports an inline menu where a scrollable parent would clip an overlay", () => {
    const source = readFileSync(selectPath, "utf8");
    const css = readFileSync(selectCssPath, "utf8");

    expect(source).toContain('menuMode?: "overlay" | "inline";');
    expect(source).toContain('menuMode = "overlay",');
    expect(source).toContain('menuMode === "inline" ? styles.menuInline : ""');
    expect(css).toContain(".menuInline {");
    expect(css).toContain("position: static;");
    expect(css).toContain("max-height: min(18rem, calc(100dvh - 12rem));");
  });
});
