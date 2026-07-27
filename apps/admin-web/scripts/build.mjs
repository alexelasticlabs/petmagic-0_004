import { randomUUID } from "node:crypto";
import { spawn } from "node:child_process";
import { open, readFile, rm, stat, writeFile } from "node:fs/promises";
import path from "node:path";
import { setTimeout as delay } from "node:timers/promises";
import { fileURLToPath } from "node:url";

const defaultLockTimeoutMs = 10 * 60 * 1_000;
const defaultStaleLockMs = 30 * 60 * 1_000;
const currentModulePath = fileURLToPath(import.meta.url);

export async function runAdminBuild({ appRoot = process.cwd(), environment = process.env } = {}) {
  const resolvedAppRoot = path.resolve(appRoot);
  const nextPublicApiBaseUrl =
    environment.NEXT_PUBLIC_API_BASE_URL?.trim() || "https://api.petmagic.app";
  const nextDistDir = environment.NEXT_DIST_DIR?.trim();
  const restoreNextEnv = environment.NEXT_E2E_RESTORE_NEXT_ENV === "1";
  const nextEnvPath = path.join(resolvedAppRoot, "next-env.d.ts");
  const buildLockPath = path.join(resolvedAppRoot, ".next-build.lock");

  const env = {
    ...environment,
    NEXT_PUBLIC_API_BASE_URL: nextPublicApiBaseUrl,
  };
  if (nextDistDir) {
    env.NEXT_DIST_DIR = nextDistDir;
  } else {
    delete env.NEXT_DIST_DIR;
  }

  await withBuildLock(buildLockPath, async () => {
    const nextEnvSnapshot = restoreNextEnv ? await captureFileSnapshot(nextEnvPath) : undefined;
    let buildError;

    try {
      await run(
        process.execPath,
        [resolveTool(resolvedAppRoot, "next/dist/bin/next"), "build", "--webpack"],
        env
      );
    } catch (error) {
      buildError = error;
    }

    let restoreError;
    if (nextEnvSnapshot) {
      try {
        await restoreFileSnapshot(nextEnvPath, nextEnvSnapshot);
      } catch (error) {
        restoreError = error;
      }
    }

    if (buildError) {
      if (restoreError) {
        throw new AggregateError(
          [buildError, restoreError],
          "Next build failed and next-env.d.ts could not be restored."
        );
      }

      throw buildError;
    }

    if (restoreError) {
      throw restoreError;
    }
  });
}

export async function withBuildLock(
  lockPath,
  action,
  { timeoutMs = defaultLockTimeoutMs, staleLockMs = defaultStaleLockMs, retryDelayMs = 200 } = {}
) {
  const release = await acquireBuildLock(lockPath, {
    timeoutMs,
    staleLockMs,
    retryDelayMs,
  });
  let result;
  let actionError;

  try {
    result = await action();
  } catch (error) {
    actionError = error;
  }

  let releaseError;
  try {
    await release();
  } catch (error) {
    releaseError = error;
  }

  if (actionError) {
    if (releaseError) {
      throw new AggregateError(
        [actionError, releaseError],
        "The Next build failed and its build lock could not be released."
      );
    }

    throw actionError;
  }

  if (releaseError) {
    throw releaseError;
  }

  return result;
}

export async function captureFileSnapshot(filePath) {
  try {
    return { exists: true, contents: await readFile(filePath) };
  } catch (error) {
    if (error?.code === "ENOENT") {
      return { exists: false, contents: undefined };
    }

    throw error;
  }
}

export async function restoreFileSnapshot(filePath, snapshot) {
  if (snapshot.exists) {
    await writeFile(filePath, snapshot.contents);
    return;
  }

  await rm(filePath, { force: true });
}

async function acquireBuildLock(lockPath, { timeoutMs, staleLockMs, retryDelayMs }) {
  const deadline = Date.now() + timeoutMs;
  const token = randomUUID();

  while (true) {
    try {
      const handle = await open(lockPath, "wx");
      try {
        await handle.writeFile(
          `${JSON.stringify({ pid: process.pid, token, createdAt: new Date().toISOString() })}\n`
        );
      } catch (error) {
        await handle.close().catch(() => undefined);
        await rm(lockPath, { force: true }).catch(() => undefined);
        throw error;
      }

      let released = false;
      return async () => {
        if (released) {
          return;
        }

        released = true;
        await handle.close();
        const currentOwner = await readLockOwner(lockPath);
        if (!currentOwner) {
          return;
        }

        if (currentOwner.token !== token) {
          throw new Error("The Next build lock owner changed before release.");
        }

        await rm(lockPath);
      };
    } catch (error) {
      if (error?.code !== "EEXIST") {
        throw error;
      }

      if (await removeStaleBuildLock(lockPath, staleLockMs)) {
        continue;
      }

      if (Date.now() >= deadline) {
        throw new Error(`Timed out waiting for the Next build lock at ${lockPath}.`);
      }

      await delay(retryDelayMs);
    }
  }
}

async function removeStaleBuildLock(lockPath, staleLockMs) {
  let lockStats;
  try {
    lockStats = await stat(lockPath);
  } catch (error) {
    if (error?.code === "ENOENT") {
      return true;
    }

    throw error;
  }

  const owner = await readLockOwner(lockPath);
  if (owner?.pid) {
    if (isProcessRunning(owner.pid)) {
      return false;
    }

    await rm(lockPath, { force: true });
    return true;
  }

  if (Date.now() - lockStats.mtimeMs < staleLockMs) {
    return false;
  }

  await rm(lockPath, { force: true });
  return true;
}

async function readLockOwner(lockPath) {
  try {
    return JSON.parse(await readFile(lockPath, "utf8"));
  } catch (error) {
    if (error?.code === "ENOENT") {
      return undefined;
    }

    if (error instanceof SyntaxError) {
      return { malformed: true };
    }

    throw error;
  }
}

function isProcessRunning(pid) {
  if (!Number.isInteger(pid) || pid <= 0) {
    return false;
  }

  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    return error?.code !== "ESRCH";
  }
}

function run(command, args, envVars) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      shell: false,
      env: envVars,
      stdio: "inherit",
    });

    child.once("error", reject);
    child.once("exit", (code) => {
      if (code === 0) {
        resolve();
        return;
      }

      reject(new Error(`${command} ${args.join(" ")} exited with code ${code}`));
    });
  });
}

function resolveTool(appRoot, relativePath) {
  return path.join(appRoot, "node_modules", relativePath);
}

function isMainModule() {
  return Boolean(process.argv[1]) && path.resolve(process.argv[1]) === currentModulePath;
}

if (isMainModule()) {
  await runAdminBuild();
}
