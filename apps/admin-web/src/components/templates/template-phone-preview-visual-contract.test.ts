import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const phonePreviewPath = fileURLToPath(
  new URL("./template-phone-preview-card.tsx", import.meta.url)
);
const phonePreviewCssPath = fileURLToPath(
  new URL("./template-phone-preview-card.module.css", import.meta.url)
);
const globalsCssPath = fileURLToPath(new URL("../../app/globals.css", import.meta.url));

describe("template phone preview visual contract", () => {
  it("uses shared admin icons instead of local inline SVG art", () => {
    const source = readFileSync(phonePreviewPath, "utf8");
    const cssSource = readFileSync(phonePreviewCssPath, "utf8");

    expect(source).toContain('from "@/components/admin/admin-icons"');
    expect(source).toContain("AccessTierIcon");
    expect(source).toContain("ImageIcon");
    expect(source).toContain("MusicIcon");
    expect(source).toContain("PawIcon");
    expect(source).toContain("PlayCircleIcon");
    expect(source).toContain("className={styles.phoneInlineIcon}");
    expect(source).not.toContain("<svg");
    expect(source).not.toContain('focusable="false"');
    expect(cssSource).toContain(".phoneInlineIcon {");
  });

  it("keeps the phone mock readable without raw palette values or negative tracking", () => {
    const cssSource = readFileSync(phonePreviewCssPath, "utf8");
    const globalsSource = readFileSync(globalsCssPath, "utf8");
    const nonZeroLetterSpacingRules = [...cssSource.matchAll(/letter-spacing:\s*([^;]+);/g)]
      .map((match) => match[1]?.trim())
      .filter((value) => value !== "0");

    expect(cssSource).toContain("--text-inverse: var(--accent-contrast);");
    expect(cssSource).toContain("--surface-0: var(--phone-screen-surface);");
    expect(cssSource).toContain(
      "--surface-2: color-mix(in srgb, var(--phone-screen-surface) 88%, var(--accent) 12%);"
    );
    expect(globalsSource).toContain("--phone-screen-surface: #000000;");
    expect(cssSource).toContain("letter-spacing: 0;");
    expect(cssSource).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(cssSource).not.toContain("rgba(");
    expect(cssSource).not.toMatch(/\bblack\b/);
    expect(cssSource).not.toContain("radial-gradient");
    expect(cssSource).not.toMatch(/letter-spacing:\s*-/);
    expect(nonZeroLetterSpacingRules).toEqual([]);
  });

  it("keeps phone preview controls constrained on narrow editor columns", () => {
    const cssSource = readFileSync(phonePreviewCssPath, "utf8");

    expect(cssSource).toContain("@media (max-width: 420px)");
    expect(cssSource).toContain(".phoneTopRow");
    expect(cssSource).toContain(".phoneBottomContent");
    expect(cssSource).toContain(
      ".phoneTitle,\n  .phoneDescription,\n  .phoneMusicDescription,\n  .phoneTagRow"
    );
    expect(cssSource).toContain("max-width: 100%;");
    expect(cssSource).toContain(".phoneAccessTag");
    expect(cssSource).toContain("padding-inline: 0.36rem;");
  });

  it("keeps the Free access badge legible on the dark phone preview in every admin theme", () => {
    const cssSource = readFileSync(phonePreviewCssPath, "utf8");
    const freeBadgeRule = cssSource.match(/\.phoneAccessTagFree \{([\s\S]*?)\n\}/)?.[1] ?? "";
    const freeIconRule = cssSource.match(/\.phoneAccessIconFree \{([\s\S]*?)\n\}/)?.[1] ?? "";

    expect(freeBadgeRule).toContain("color: var(--text-inverse);");
    expect(freeBadgeRule).not.toContain("--toast-success-fg");
    expect(freeIconRule).toContain("color: var(--text-inverse);");
  });
});
