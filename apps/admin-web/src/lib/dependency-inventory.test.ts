import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { beforeAll, describe, expect, it } from "vitest";

const adminRoot = fileURLToPath(new URL("../../", import.meta.url));
const packageJsonPath = join(adminRoot, "package.json");
// A cold Windows filesystem scan of src and scripts can exceed Vitest's 5s default.
const filesystemInventoryTimeoutMs = 20_000;

type PackageManifest = {
  dependencies?: Record<string, string>;
  devDependencies?: Record<string, string>;
  scripts?: Record<string, string>;
};

const runtimeDependencyEvidence: Record<string, readonly string[]> = {
  "@microsoft/signalr": ['from "@microsoft/signalr"'],
  "@tanstack/react-query": ['from "@tanstack/react-query"'],
  next: ['"dev": "next dev', '"start": "next start', 'from "next'],
  react: ['from "react"'],
  "react-dom": ['"react-dom"', '"next"'],
};

const devDependencyEvidence: Record<string, readonly string[]> = {
  "@playwright/test": ['"test:e2e": "node ./scripts/test-e2e.mjs"'],
  "@types/node": ['from "node:', "node:fs", "node:path"],
  "@types/react": ['from "react"', ".tsx"],
  "@types/react-dom": ['"react-dom"'],
  "@vitest/coverage-v8": ["vitest run --coverage"],
  eslint: ['"lint": "eslint .'],
  "eslint-config-next": ['from "eslint-config-next/'],
  "eslint-plugin-import": ['from "eslint-plugin-import"'],
  prettier: ['"format": "prettier . --write'],
  typescript: ["typescript/bin/tsc"],
  vitest: ['"test": "vitest run', 'from "vitest"'],
};

function readManifest(): PackageManifest {
  return JSON.parse(readFileSync(packageJsonPath, "utf8")) as PackageManifest;
}

let cachedAdminText: string | undefined;

function readAdminText(): string {
  if (cachedAdminText !== undefined) {
    return cachedAdminText;
  }

  const textFiles = [
    packageJsonPath,
    join(adminRoot, "eslint.config.mjs"),
    join(adminRoot, "next.config.ts"),
    join(adminRoot, "tsconfig.json"),
    join(adminRoot, "vitest.config.ts"),
    ...collectFiles(join(adminRoot, "scripts")),
    ...collectFiles(join(adminRoot, "src")),
  ].filter(
    (path) =>
      /\.(cjs|css|js|json|mjs|ts|tsx)$/.test(path) &&
      !/\.(test|spec)\.(cjs|css|js|json|mjs|ts|tsx)$/.test(path)
  );

  cachedAdminText = textFiles.map((path) => readFileSync(path, "utf8")).join("\n");
  return cachedAdminText;
}

function collectFiles(root: string): string[] {
  const output: string[] = [];
  for (const entry of readdirSync(root)) {
    if (entry === ".next" || entry === "node_modules") {
      continue;
    }

    const path = join(root, entry);
    const stat = statSync(path);
    if (stat.isDirectory()) {
      output.push(...collectFiles(path));
      continue;
    }

    output.push(path);
  }

  return output;
}

describe("admin dependency inventory", () => {
  let adminText: string;

  beforeAll(() => {
    adminText = readAdminText();
  }, filesystemInventoryTimeoutMs);

  it("does not treat its own test assertions as dependency evidence", () => {
    expect(adminText).not.toContain("const runtimeDependencyEvidence:");
  });

  it("keeps runtime dependencies intentionally small and source-backed", () => {
    const manifest = readManifest();
    const dependencies = Object.keys(manifest.dependencies ?? {}).sort();

    expect(dependencies).toEqual(Object.keys(runtimeDependencyEvidence).sort());
    for (const dependency of dependencies) {
      const evidence = runtimeDependencyEvidence[dependency] ?? [];
      expect(
        evidence.some((needle) => adminText.includes(needle)),
        `${dependency} must have source/framework evidence before it stays in dependencies`
      ).toBe(true);
    }
  });

  it("keeps dev dependencies tied to scripts or tool configs", () => {
    const manifest = readManifest();
    const devDependencies = Object.keys(manifest.devDependencies ?? {}).sort();

    expect(devDependencies).toEqual(Object.keys(devDependencyEvidence).sort());
    for (const dependency of devDependencies) {
      const evidence = devDependencyEvidence[dependency] ?? [];
      expect(
        evidence.some((needle) => adminText.includes(needle)),
        `${dependency} must be tied to an admin script, test, type, or lint config`
      ).toBe(true);
    }
  });
});
