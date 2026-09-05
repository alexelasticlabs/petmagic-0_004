import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const editorStylesPath = fileURLToPath(new URL("./template-editor.module.css", import.meta.url));
const editorAssetStylesPath = fileURLToPath(
  new URL("./template-editor-assets.module.css", import.meta.url)
);
const editorLayoutPath = fileURLToPath(new URL("./template-editor-layout.tsx", import.meta.url));

describe("template editor visual contract", () => {
  it("keeps editor typography and upload surfaces theme-token based", () => {
    const styles = readFileSync(editorStylesPath, "utf8");
    const assetStyles = readFileSync(editorAssetStylesPath, "utf8");
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

    expect(assetStyles).toContain(".uploadPanel {");
    expect(assetStyles).not.toMatch(/#[0-9a-fA-F]{3,8}|rgba\(/);
    expect(assetStyles).not.toContain("!important");
  });

  it("keeps the medium-screen editor rail below the form after wider breakpoints", () => {
    const styles = readFileSync(editorStylesPath, "utf8");
    const wideBreakpointIndex = styles.indexOf("@media (max-width: 1440px)");
    const mediumBreakpointIndex = styles.indexOf("@media (max-width: 1120px)");

    expect(wideBreakpointIndex).toBeGreaterThanOrEqual(0);
    expect(mediumBreakpointIndex).toBeGreaterThan(wideBreakpointIndex);
    expect(styles).toContain(".editorGrid,\n  .loadingGrid {\n    grid-template-columns: 1fr;");
    expect(styles).toContain(".editorRail {\n    position: static;");
  });

  it("locks the visibility switch while the template save is in flight", () => {
    const layoutSource = readFileSync(editorLayoutPath, "utf8");
    const styles = readFileSync(editorStylesPath, "utf8");

    expect(layoutSource.match(/disabled=\{isSaving\}/g)).toHaveLength(4);
    expect(layoutSource).toContain("disabled={isSaving || !isSaveReady}");
    expect(styles).toContain(".footerStatusButton:disabled");
    expect(styles).toContain("cursor: not-allowed;");
  });
});
