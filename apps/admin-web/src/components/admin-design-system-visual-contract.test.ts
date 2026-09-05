import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const read = (path: string) => readFileSync(fileURLToPath(new URL(path, import.meta.url)), "utf8");

const globalStyles = read("../app/globals.css");
const shellStyles = read("./admin/admin-shell.module.css");
const primitiveStyles = read("./admin/admin-primitives.module.css");
const commandPaletteStyles = read("./admin/admin-command-palette.module.css");
const selectStyles = read("./ui/select.module.css");

describe("admin design system visual contract", () => {
  it("keeps shared semantic aliases and control heights centralized", () => {
    expect(globalStyles).toContain("--text-secondary: var(--text-soft);");
    expect(globalStyles).toContain("--accent-soft: var(--accent-soft-bg);");
    expect(globalStyles).toContain("--control-height-md: 2.5rem;");
    expect(commandPaletteStyles).toContain("min-height: var(--control-height-md);");
    expect(selectStyles).toContain("min-height: var(--control-height-md);");
  });

  it("keeps navigation flat with a visible active rail and keyboard focus", () => {
    expect(shellStyles).toMatch(/\.navItem\s*\{[\s\S]*?background:\s*transparent;/);
    expect(shellStyles).toContain(".navItemActive::before {");
    expect(shellStyles).toMatch(/\.navItemActive::before\s*\{[^}]*width:\s*2px;/);
    expect(shellStyles).toContain(".navItem:focus-visible,");
  });

  it("uses open hierarchy for page chrome and semantic rails for state", () => {
    expect(primitiveStyles).toMatch(/\.pageHero\s*\{[\s\S]*?border-bottom:/);
    expect(primitiveStyles).toMatch(/\.filterBar\s*\{[\s\S]*?background:\s*transparent;/);
    expect(primitiveStyles).toContain("border-left: 3px solid var(--tone-color);");
    expect(selectStyles).toContain("box-shadow: inset 3px 0 0 var(--accent);");
  });

  it("compacts mobile chrome without hiding global operator controls", () => {
    expect(shellStyles).toContain("grid-template-columns: auto minmax(0, 1fr);");
    expect(shellStyles).toContain(".themeTrigger > span:last-child {");
    expect(shellStyles).toContain(".localeRoot > .localeTrigger > span,");
  });
});
