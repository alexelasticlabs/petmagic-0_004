import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const sourceRoot = fileURLToPath(new URL("../", import.meta.url));
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

  it("routes console output through the centralized client logger only", () => {
    const violations = sourceFiles(sourceRoot)
      .filter((path) => !/\.test\.(ts|tsx)$/.test(path))
      .filter((path) => path !== clientLoggerPath)
      .flatMap((path) => {
        const source = readFileSync(path, "utf8");
        const matches = source.match(/\bconsole\.(log|debug|info|warn|error)\s*\(/g) ?? [];
        return matches.map((match) => `${relative(sourceRoot, path)} uses ${match}`);
      });

    expect(violations).toEqual([]);

    const clientLoggerSource = readFileSync(clientLoggerPath, "utf8");
    expect(clientLoggerSource).toContain("console.error");
    expect(clientLoggerSource).toContain("console.warn");
  });
});

function sourceFiles(directory: string): string[] {
  return readdirSync(directory).flatMap((entry) => {
    const path = join(directory, entry);
    const stat = statSync(path);
    if (stat.isDirectory()) {
      return sourceFiles(path);
    }

    return /\.(ts|tsx)$/.test(path) ? [path] : [];
  });
}
