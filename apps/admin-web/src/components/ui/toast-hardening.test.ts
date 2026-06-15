import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const toastPath = fileURLToPath(new URL("./toast.tsx", import.meta.url));
const globalsCssPath = fileURLToPath(new URL("../../app/globals.css", import.meta.url));

function sliceBetween(source: string, start: string, end: string): string {
  const startIndex = source.indexOf(start);
  const endIndex = source.indexOf(end, startIndex + start.length);

  expect(startIndex).toBeGreaterThanOrEqual(0);
  expect(endIndex).toBeGreaterThan(startIndex);

  return source.slice(startIndex, endIndex);
}

describe("shared admin toast hardening", () => {
  it("announces errors assertively and keeps long messages inside the viewport", () => {
    const source = readFileSync(toastPath, "utf8");
    const css = readFileSync(globalsCssPath, "utf8");

    expect(source).toContain('const isError = type === "error";');
    expect(source).toContain('role={isError ? "alert" : "status"}');
    expect(source).toContain('aria-live={isError ? "assertive" : "polite"}');
    expect(source).toContain('aria-atomic="true"');
    expect(source).toContain('aria-relevant="additions text"');
    expect(source).not.toContain('role="status" aria-live="polite"');

    expect(css).toContain(".ui-toast {");
    expect(css).toContain("linear-gradient(135deg, var(--bg-glow) 0%, transparent 32rem)");
    expect(css).not.toContain("radial-gradient");
    expect(css).toContain("max-width: min(28rem, calc(100vw - 2rem));");
    expect(css).toContain("max-height: min(18rem, calc(100dvh - 2rem));");
    expect(css).toContain("overflow-y: auto;");
    expect(css).toContain("overflow-wrap: anywhere;");
    expect(css).toContain("white-space: normal;");
    expect(css).toContain("@media (max-width: 480px)");
    expect(css).toContain("left: 0.75rem;");
    expect(css).toContain("scrollbar-color: var(--scrollbar-thumb) var(--scrollbar-track);");
    expect(css).toContain("*::-webkit-scrollbar-thumb {");
    expect(css).toContain("background: var(--scrollbar-thumb);");
    expect(css).toContain("*::-webkit-scrollbar-thumb:hover {");
    expect(css).toContain("background: var(--scrollbar-thumb-hover);");
    expect(css).toContain(
      "border-color: color-mix(in srgb, var(--danger) 40%, var(--border-soft));"
    );
    expect(css).not.toContain("background: rgba(72, 82, 94, 0.92);");
    expect(css).not.toContain("background: rgba(97, 108, 122, 0.96);");
    expect(css).not.toContain("border-color: rgba(248, 81, 73, 0.4);");
  });

  it("keeps global derived theme tokens tied to semantic color tokens", () => {
    const css = readFileSync(globalsCssPath, "utf8");
    const darkRoot = sliceBetween(css, ":root {", ':root[data-theme="light"] {');
    const lightRoot = sliceBetween(css, ':root[data-theme="light"] {', "\n}\n\n* {");
    const derivedTokenPattern =
      /^\s+--(?:surface-overlay|shadow-(?:soft|card|strong)|focus-ring|interactive-glow|scrollbar-(?:track|thumb|thumb-hover)|bg-grid-(?:primary|secondary)|bg-glow|primary-border(?:-hover)?|ghost-bg|secondary-bg|surface-hover|accent-soft-bg|danger-soft-bg|toast-(?:success|error)-(?:bg|border)):\s.*$/gm;
    const derivedTokenLines = [...css.matchAll(derivedTokenPattern)].map((match) => match[0]);

    expect(darkRoot).toContain("--surface-overlay: color-mix(in srgb, var(--surface-0) 92%, transparent);");
    expect(darkRoot).toContain("--focus-ring: 0 0 0 2px color-mix(in srgb, var(--accent) 24%, transparent);");
    expect(darkRoot).toContain("--toast-error-bg: color-mix(in srgb, var(--danger) 18%, var(--surface-2));");
    expect(lightRoot).toContain("--surface-overlay: color-mix(in srgb, var(--surface-1) 94%, transparent);");
    expect(lightRoot).toContain("--focus-ring: 0 0 0 2px color-mix(in srgb, var(--accent) 24%, transparent);");
    expect(lightRoot).toContain("--toast-error-bg: color-mix(in srgb, var(--danger) 12%, var(--surface-1));");
    expect(derivedTokenLines.length).toBeGreaterThan(30);
    expect(derivedTokenLines.join("\n")).toContain("color-mix(in srgb");
    expect(derivedTokenLines.join("\n")).not.toContain("rgba(");
  });
});
