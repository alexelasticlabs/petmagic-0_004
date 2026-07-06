import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const adminShellPath = fileURLToPath(new URL("./admin-shell.tsx", import.meta.url));

describe("admin shell localization", () => {
  it("keeps the document language synchronized with the active locale route", () => {
    const source = readFileSync(adminShellPath, "utf8");

    expect(source).toContain("document.documentElement.lang = locale;");
    expect(source).toContain("}, [locale]);");
  });
});
