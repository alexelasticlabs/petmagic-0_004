import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const userAvatarPath = fileURLToPath(new URL("./user-avatar.tsx", import.meta.url));
const userAvatarStylesPath = fileURLToPath(new URL("./user-avatar.module.css", import.meta.url));

describe("user avatar URL exposure", () => {
  it("does not render backend avatar URLs directly in image src attributes", () => {
    const source = readFileSync(userAvatarPath, "utf8");

    expect(source).not.toContain('from "next/image"');
    expect(source).not.toContain("src={imageUrl}");
    expect(source).toContain("URL.createObjectURL(blob)");
    expect(source).toContain("fetchWithTimeout(imageUrl");
    expect(source).toContain("users.avatar_fetch_failed");
    expect(source).toContain("import { sanitizeSensitiveText }");
    expect(source).toContain("function getAvatarFetchErrorDetails(error: unknown)");
    expect(source).toContain('errorName: error instanceof Error ? error.name : "UnknownError"');
    expect(source).toContain("getAvatarFetchErrorDetails(error)");
    expect(source).not.toContain('clientLogger.warn("users.avatar_fetch_failed", { error })');
  });

  it("keeps avatar fallback styling theme-token based", () => {
    const source = readFileSync(userAvatarStylesPath, "utf8");

    expect(source).toContain("border: 1px solid var(--border-soft)");
    expect(source).toContain("var(--surface-2)");
    expect(source).toContain("var(--surface-raised)");
    expect(source).toContain("color-mix(in srgb, var(--surface-2) 88%, var(--accent) 12%)");
    expect(source).toContain("box-shadow: var(--shadow-card)");
    expect(source).toContain("color: var(--text-strong)");
    expect(source).toContain("letter-spacing: 0");
    expect(source).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(source).not.toContain("rgba(");
    expect(source).not.toContain("radial-gradient");
  });
});
