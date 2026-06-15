import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const editorStylesPath = fileURLToPath(new URL("./template-editor.module.css", import.meta.url));

describe("template editor visual contract", () => {
  it("keeps editor typography and upload surfaces theme-token based", () => {
    const styles = readFileSync(editorStylesPath, "utf8");
    const letterSpacingRules = styles.match(/letter-spacing:\s*[^;]+;/g) ?? [];

    expect(styles).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(styles).not.toContain("rgba(");
    expect(styles).not.toContain("radial-gradient");
    expect(letterSpacingRules.length).toBeGreaterThan(0);
    expect(letterSpacingRules.every((rule) => rule === "letter-spacing: 0;")).toBe(true);
    expect(styles).toContain(".pageHeader h1 {");
    expect(styles).toContain("font-size: 1.8rem;");
    expect(styles).toContain("@media (max-width: 560px)");
    expect(styles).toContain("font-size: 1.58rem;");
    expect(styles).not.toMatch(/font-size:\s*[^;]*vw/);

    expect(styles).toContain(".uploadPanel {");
    expect(styles).toContain("background: linear-gradient(");
    expect(styles).toContain("color-mix(in srgb, var(--surface-1) 96%, var(--surface-2))");
    expect(styles).toContain("box-shadow:\n    inset 0 1px 0 color-mix");
  });
});
