import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const globalsPath = fileURLToPath(new URL("../../app/globals.css", import.meta.url));

describe("shared admin button hardening", () => {
  it("bounds button SVGs so icon actions do not stretch or collapse their labels", () => {
    const source = readFileSync(globalsPath, "utf8");

    expect(source).toContain(
      ".ui-button > svg {\n  flex: 0 0 auto;\n  width: 1rem;\n  height: 1rem;"
    );
  });
});
