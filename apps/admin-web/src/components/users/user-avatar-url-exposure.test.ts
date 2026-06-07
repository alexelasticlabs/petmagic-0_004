import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const userAvatarPath = fileURLToPath(new URL("./user-avatar.tsx", import.meta.url));

describe("user avatar URL exposure", () => {
  it("does not render backend avatar URLs directly in image src attributes", () => {
    const source = readFileSync(userAvatarPath, "utf8");

    expect(source).not.toContain('from "next/image"');
    expect(source).not.toContain("src={imageUrl}");
    expect(source).toContain("URL.createObjectURL(blob)");
    expect(source).toContain("fetchWithTimeout(imageUrl");
    expect(source).toContain("users.avatar_fetch_failed");
  });
});
