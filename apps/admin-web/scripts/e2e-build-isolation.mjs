import { randomUUID } from "node:crypto";
import { mkdir, open, readFile, rm } from "node:fs/promises";
import path from "node:path";

const ownedBuildDirectoryPattern = /^\.next-e2e(?:-[A-Za-z0-9][A-Za-z0-9_-]{0,120})?$/;
const ownedTsconfigPattern = /^\.tsconfig\.e2e-[A-Za-z0-9][A-Za-z0-9_-]{0,160}\.json$/;

export function createE2eRunId(pid = process.pid, uuid = randomUUID()) {
  const runId = `${pid}-${uuid}`;
  if (!/^[A-Za-z0-9][A-Za-z0-9_-]+$/.test(runId)) {
    throw new Error("The generated E2E run identifier contains unsafe characters.");
  }

  return runId;
}

export function resolveOwnedE2eArtifacts({
  appRoot,
  requestedBuildDirectory,
  runId = createE2eRunId(),
}) {
  const resolvedAppRoot = path.resolve(appRoot);
  const buildDirectoryName = requestedBuildDirectory?.trim() || `.next-e2e-${runId}`;
  const tsconfigFileName = `.tsconfig.e2e-${runId}.json`;

  assertSafeOwnedName(buildDirectoryName, ownedBuildDirectoryPattern, "NEXT_E2E_DIST_DIR");
  assertSafeOwnedName(tsconfigFileName, ownedTsconfigPattern, "temporary E2E tsconfig");

  return {
    appRoot: resolvedAppRoot,
    buildDirectoryName,
    buildDirectoryPath: assertOwnedChildPath(
      resolvedAppRoot,
      path.join(resolvedAppRoot, buildDirectoryName),
      ownedBuildDirectoryPattern,
      "E2E build directory"
    ),
    tsconfigFileName,
    tsconfigPath: assertOwnedChildPath(
      resolvedAppRoot,
      path.join(resolvedAppRoot, tsconfigFileName),
      ownedTsconfigPattern,
      "temporary E2E tsconfig"
    ),
    trackedTsconfigPath: path.join(resolvedAppRoot, "tsconfig.json"),
  };
}

export function createE2eTsconfig(buildDirectoryName) {
  assertSafeOwnedName(buildDirectoryName, ownedBuildDirectoryPattern, "E2E build directory");

  return {
    extends: "./tsconfig.json",
    include: [
      "next-env.d.ts",
      "**/*.ts",
      "**/*.tsx",
      `${buildDirectoryName}/types/**/*.ts`,
      `${buildDirectoryName}/dev/types/**/*.ts`,
      "**/*.mts",
    ],
    exclude: ["node_modules"],
  };
}

export function createE2eBuildEnvironment(baseEnvironment, artifacts) {
  return {
    ...baseEnvironment,
    NEXT_E2E_DIST_DIR: artifacts.buildDirectoryName,
    NEXT_DIST_DIR: artifacts.buildDirectoryName,
    NEXT_TYPESCRIPT_TSCONFIG_PATH: artifacts.tsconfigFileName,
    NEXT_E2E_RESTORE_NEXT_ENV: "1",
  };
}

export async function withE2eBuildIsolation(
  {
    appRoot,
    requestedBuildDirectory = /** @type {string | undefined} */ (undefined),
    baseEnvironment = process.env,
    runId = createE2eRunId(),
  },
  action
) {
  if (typeof action !== "function") {
    throw new TypeError("withE2eBuildIsolation requires an action callback.");
  }

  const artifacts = resolveOwnedE2eArtifacts({
    appRoot,
    requestedBuildDirectory,
    runId,
  });
  const trackedTsconfigBefore = await readFile(artifacts.trackedTsconfigPath);

  await prepareOwnedArtifacts(artifacts);

  const environment = createE2eBuildEnvironment(baseEnvironment, artifacts);
  let result;
  let actionError;

  try {
    result = await action({ ...artifacts, environment });
  } catch (error) {
    actionError = error;
  }

  const finalizationErrors = [];
  try {
    await cleanupOwnedE2eArtifacts(artifacts);
  } catch (error) {
    finalizationErrors.push(error);
  }

  try {
    await assertFileByteIdentical(
      artifacts.trackedTsconfigPath,
      trackedTsconfigBefore,
      "Tracked tsconfig.json changed during the isolated E2E build."
    );
  } catch (error) {
    finalizationErrors.push(error);
  }

  if (actionError) {
    if (finalizationErrors.length > 0) {
      throw new AggregateError(
        [actionError, ...finalizationErrors],
        "The E2E run failed and artifact finalization also reported errors."
      );
    }

    throw actionError;
  }

  if (finalizationErrors.length > 0) {
    throw new AggregateError(finalizationErrors, "Unable to finalize isolated E2E artifacts.");
  }

  return result;
}

export async function cleanupOwnedE2eArtifacts(artifacts) {
  const tsconfigPath = assertOwnedChildPath(
    artifacts.appRoot,
    artifacts.tsconfigPath,
    ownedTsconfigPattern,
    "temporary E2E tsconfig"
  );
  const buildDirectoryPath = assertOwnedChildPath(
    artifacts.appRoot,
    artifacts.buildDirectoryPath,
    ownedBuildDirectoryPattern,
    "E2E build directory"
  );

  const cleanupResults = await Promise.allSettled([
    rm(tsconfigPath, { force: true }),
    rm(buildDirectoryPath, { force: true, recursive: true }),
  ]);
  const cleanupErrors = cleanupResults
    .filter((result) => result.status === "rejected")
    .map((result) => result.reason);

  if (cleanupErrors.length > 0) {
    throw new AggregateError(cleanupErrors, "Unable to remove owned E2E artifacts.");
  }
}

async function prepareOwnedArtifacts(artifacts) {
  let buildDirectoryCreated = false;
  let tsconfigCreated = false;

  try {
    await mkdir(artifacts.buildDirectoryPath);
    buildDirectoryCreated = true;

    const tsconfigHandle = await open(artifacts.tsconfigPath, "wx");
    tsconfigCreated = true;
    try {
      await tsconfigHandle.writeFile(
        `${JSON.stringify(createE2eTsconfig(artifacts.buildDirectoryName), null, 2)}\n`,
        "utf8"
      );
    } finally {
      await tsconfigHandle.close();
    }
  } catch (error) {
    const cleanupResults = await Promise.allSettled([
      tsconfigCreated ? rm(artifacts.tsconfigPath, { force: true }) : Promise.resolve(),
      buildDirectoryCreated
        ? rm(artifacts.buildDirectoryPath, { force: true, recursive: true })
        : Promise.resolve(),
    ]);
    const cleanupErrors = cleanupResults
      .filter((result) => result.status === "rejected")
      .map((result) => result.reason);

    if (cleanupErrors.length > 0) {
      throw new AggregateError(
        [error, ...cleanupErrors],
        "Unable to prepare or clean up isolated E2E artifacts."
      );
    }

    throw error;
  }
}

async function assertFileByteIdentical(filePath, expected, message) {
  const actual = await readFile(filePath);
  if (!actual.equals(expected)) {
    throw new Error(message);
  }
}

function assertSafeOwnedName(value, pattern, label) {
  if (
    !pattern.test(value) ||
    path.isAbsolute(value) ||
    path.posix.isAbsolute(value) ||
    path.win32.isAbsolute(value) ||
    value.includes("/") ||
    value.includes("\\")
  ) {
    throw new Error(
      `${label} must be a single app-local name reserved for isolated E2E artifacts.`
    );
  }
}

function assertOwnedChildPath(appRoot, candidatePath, pattern, label) {
  const resolvedAppRoot = path.resolve(appRoot);
  const resolvedCandidate = path.resolve(candidatePath);
  if (
    path.dirname(resolvedCandidate) !== resolvedAppRoot ||
    !pattern.test(path.basename(resolvedCandidate))
  ) {
    throw new Error(`${label} is outside the admin-web root or is not launcher-owned.`);
  }

  return resolvedCandidate;
}
