import { randomUUID } from "node:crypto";
import { access, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { setTimeout as delay } from "node:timers/promises";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import { nextTypeScriptConfiguration } from "../../next.config";
import { captureFileSnapshot, restoreFileSnapshot, withBuildLock } from "../../scripts/build.mjs";
import {
  resolveOwnedE2eArtifacts,
  withE2eBuildIsolation,
} from "../../scripts/e2e-build-isolation.mjs";

interface E2eArtifacts {
  appRoot: string;
  buildDirectoryName: string;
  buildDirectoryPath: string;
  tsconfigFileName: string;
  tsconfigPath: string;
  trackedTsconfigPath: string;
  environment: NodeJS.ProcessEnv;
}

const adminRoot = fileURLToPath(new URL("../../", import.meta.url));
const trackedTsconfigPath = path.join(adminRoot, "tsconfig.json");
const e2eLauncherPath = path.join(adminRoot, "scripts", "test-e2e.mjs");
const buildScriptPath = path.join(adminRoot, "scripts", "build.mjs");
const nextConfigPath = path.join(adminRoot, "next.config.ts");
const gitignorePath = path.join(adminRoot, ".gitignore");

describe("admin E2E build isolation", () => {
  it("wires a temporary tsconfig, owned output, build lock, and next-env restoration", async () => {
    const [launcher, buildScript, nextConfig, gitignore] = await Promise.all([
      readFile(e2eLauncherPath, "utf8"),
      readFile(buildScriptPath, "utf8"),
      readFile(nextConfigPath, "utf8"),
      readFile(gitignorePath, "utf8"),
    ]);

    expect(launcher).toContain("withE2eBuildIsolation(");
    expect(launcher).toContain("await runE2eLifecycle(e2eEnvironment);");
    expect(launcher).toContain('PLAYWRIGHT_EXTERNAL_SERVER: "1"');
    expect(launcher).toContain("await stopOwnedServer(server);");
    expect(launcher).not.toContain("taskkill");
    expect(buildScript).toContain("withBuildLock(buildLockPath");
    expect(buildScript).toContain('environment.NEXT_E2E_RESTORE_NEXT_ENV === "1"');
    expect(buildScript).toContain("await restoreFileSnapshot(nextEnvPath, nextEnvSnapshot);");
    expect(nextConfig).toContain("NEXT_TYPESCRIPT_TSCONFIG_PATH");
    expect(nextConfig).toContain("typescript: configuredTypeScript");
    expect(gitignore).toContain("/.next-e2e*/");
    expect(gitignore).toContain("/.next-build.lock");
    expect(gitignore).toContain("/.tsconfig.e2e-*.json");
  });

  it("leaves the tracked tsconfig byte-identical and removes default owned artifacts", async () => {
    const before = await readFile(trackedTsconfigPath);
    const runId = createTestRunId("byte-identical");
    let temporaryTsconfigPath = "";
    let buildDirectoryPath = "";

    await withE2eBuildIsolation(
      {
        appRoot: adminRoot,
        baseEnvironment: process.env,
        runId,
      },
      async (artifacts: E2eArtifacts) => {
        temporaryTsconfigPath = artifacts.tsconfigPath;
        buildDirectoryPath = artifacts.buildDirectoryPath;
        expect(artifacts.buildDirectoryName).toBe(`.next-e2e-${runId}`);
        expect(JSON.parse(await readFile(artifacts.tsconfigPath, "utf8"))).toMatchObject({
          extends: "./tsconfig.json",
        });
      }
    );

    expect((await readFile(trackedTsconfigPath)).equals(before)).toBe(true);
    await expect(access(temporaryTsconfigPath)).rejects.toMatchObject({ code: "ENOENT" });
    await expect(access(buildDirectoryPath)).rejects.toMatchObject({ code: "ENOENT" });
  });

  it("cleans the temporary config and output when the build lifecycle fails", async () => {
    const runId = createTestRunId("failure-cleanup");
    let temporaryTsconfigPath = "";
    let buildDirectoryPath = "";

    await expect(
      withE2eBuildIsolation(
        {
          appRoot: adminRoot,
          baseEnvironment: process.env,
          runId,
        },
        async (artifacts: E2eArtifacts) => {
          temporaryTsconfigPath = artifacts.tsconfigPath;
          buildDirectoryPath = artifacts.buildDirectoryPath;
          await writeFile(path.join(artifacts.buildDirectoryPath, "partial-build.txt"), "partial");
          throw new Error("simulated build failure");
        }
      )
    ).rejects.toThrow("simulated build failure");

    await expect(access(temporaryTsconfigPath)).rejects.toMatchObject({ code: "ENOENT" });
    await expect(access(buildDirectoryPath)).rejects.toMatchObject({ code: "ENOENT" });
  });

  it("puts a validated custom dist directory into generated types and the build environment", async () => {
    const runId = createTestRunId("custom-dist");
    const customBuildDirectory = `.next-e2e-custom-${process.pid}-${randomUUID()}`;

    await withE2eBuildIsolation(
      {
        appRoot: adminRoot,
        requestedBuildDirectory: customBuildDirectory,
        baseEnvironment: { ...process.env, KEEP_ME: "yes" },
        runId,
      },
      async (artifacts: E2eArtifacts) => {
        const config = JSON.parse(await readFile(artifacts.tsconfigPath, "utf8"));
        expect(config.include).toContain(`${customBuildDirectory}/types/**/*.ts`);
        expect(config.include).toContain(`${customBuildDirectory}/dev/types/**/*.ts`);
        expect(artifacts.environment).toMatchObject({
          KEEP_ME: "yes",
          NEXT_E2E_DIST_DIR: customBuildDirectory,
          NEXT_DIST_DIR: customBuildDirectory,
          NEXT_TYPESCRIPT_TSCONFIG_PATH: artifacts.tsconfigFileName,
          NEXT_E2E_RESTORE_NEXT_ENV: "1",
        });
        expect(
          nextTypeScriptConfiguration(artifacts.environment.NEXT_TYPESCRIPT_TSCONFIG_PATH)
        ).toEqual({ tsconfigPath: artifacts.tsconfigFileName });
      }
    );
  });

  it.each([
    "../.next-e2e-escape",
    ".next-e2e/nested",
    ".next-e2e\\nested",
    "/tmp/.next-e2e-escape",
    "C:\\temp\\.next-e2e-escape",
  ])("rejects non-owned or traversing build path %s", (requestedBuildDirectory) => {
    expect(() =>
      resolveOwnedE2eArtifacts({
        appRoot: adminRoot,
        requestedBuildDirectory,
        runId: createTestRunId("invalid-path"),
      })
    ).toThrow(/single app-local name/);
  });

  it("restores next-env.d.ts byte-for-byte, including the originally absent state", async () => {
    const temporaryRoot = await mkdtemp(path.join(tmpdir(), "petmagic-next-env-"));
    const existingPath = path.join(temporaryRoot, "next-env.d.ts");
    const absentPath = path.join(temporaryRoot, "absent-next-env.d.ts");
    const original = Buffer.from("/// original next env\r\n", "utf8");

    try {
      await writeFile(existingPath, original);
      const existingSnapshot = await captureFileSnapshot(existingPath);
      await writeFile(existingPath, "generated E2E contents\n");
      await restoreFileSnapshot(existingPath, existingSnapshot);
      expect((await readFile(existingPath)).equals(original)).toBe(true);

      const absentSnapshot = await captureFileSnapshot(absentPath);
      await writeFile(absentPath, "generated E2E contents\n");
      await restoreFileSnapshot(absentPath, absentSnapshot);
      await expect(access(absentPath)).rejects.toMatchObject({ code: "ENOENT" });
    } finally {
      await rm(temporaryRoot, { force: true, recursive: true });
    }
  });

  it("serializes concurrent Next build sections with one shared lock", async () => {
    const temporaryRoot = await mkdtemp(path.join(tmpdir(), "petmagic-next-lock-"));
    const lockPath = path.join(temporaryRoot, ".next-build.lock");
    let activeBuilds = 0;
    let maximumActiveBuilds = 0;

    try {
      await Promise.all(
        Array.from({ length: 3 }, () =>
          withBuildLock(
            lockPath,
            async () => {
              activeBuilds += 1;
              maximumActiveBuilds = Math.max(maximumActiveBuilds, activeBuilds);
              await delay(20);
              activeBuilds -= 1;
            },
            { timeoutMs: 2_000, staleLockMs: 2_000, retryDelayMs: 5 }
          )
        )
      );

      expect(maximumActiveBuilds).toBe(1);
      await expect(access(lockPath)).rejects.toMatchObject({ code: "ENOENT" });
    } finally {
      await rm(temporaryRoot, { force: true, recursive: true });
    }
  });

  it("reclaims a fresh lock whose owner process no longer exists", async () => {
    const temporaryRoot = await mkdtemp(path.join(tmpdir(), "petmagic-dead-next-lock-"));
    const lockPath = path.join(temporaryRoot, ".next-build.lock");

    try {
      await writeFile(lockPath, `${JSON.stringify({ pid: 2_147_483_647, token: "dead-owner" })}\n`);
      await withBuildLock(lockPath, async () => undefined, {
        timeoutMs: 500,
        staleLockMs: 60_000,
        retryDelayMs: 5,
      });
      await expect(access(lockPath)).rejects.toMatchObject({ code: "ENOENT" });
    } finally {
      await rm(temporaryRoot, { force: true, recursive: true });
    }
  });
});

function createTestRunId(label: string): string {
  return `${label}-${process.pid}-${randomUUID()}`;
}
