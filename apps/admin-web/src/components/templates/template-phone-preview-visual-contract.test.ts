import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const phonePreviewPath = fileURLToPath(
  new URL("./template-phone-preview-card.tsx", import.meta.url)
);
const phonePreviewCssPath = fileURLToPath(
  new URL("./template-phone-preview-card.module.css", import.meta.url)
);

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
    expect(source).not.toContain("focusable=\"false\"");
    expect(cssSource).toContain(".phoneInlineIcon {");
  });
});
