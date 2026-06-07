import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const eslintConfigPath = fileURLToPath(new URL("../../eslint.config.mjs", import.meta.url));
const clientLoggerPath = fileURLToPath(new URL("./client-logger.ts", import.meta.url));

describe("admin logging policy", () => {
  it("allows only warning and error console output in source files", () => {
    const source = readFileSync(eslintConfigPath, "utf8");

    expect(source).toContain('allow: ["error", "warn"]');
    expect(source).not.toContain('"info", "debug"');
    expect(source).not.toContain('allow: ["error", "warn", "info", "debug"]');
  });

  it("keeps client logger info and debug as no-op methods", () => {
    const source = readFileSync(clientLoggerPath, "utf8");

    expect(source).toContain("info(): void {},");
    expect(source).toContain("debug(): void {},");
    expect(source).not.toContain("console.info");
    expect(source).not.toContain("console.debug");
  });
});
