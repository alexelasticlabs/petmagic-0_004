#!/usr/bin/env node

import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { dirname, isAbsolute, join, relative, resolve } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, '..', '..');
const checkerPath = resolve(scriptDir, 'check-render-blueprint.mjs');
const tempBase = resolve(tmpdir());
const fixtureRoot = mkdtempSync(join(tempBase, 'petmagic-render-blueprint-contracts-'));

try {
  requireCheckerPass(resolve(repoRoot, 'render.yaml'), 'staging');
  requireCheckerPass(resolve(repoRoot, 'render.production.yaml'), 'production');

  const stagingBlueprint = readFileSync(resolve(repoRoot, 'render.yaml'), 'utf8');

  const missingSharedPath = writeFixture(
    'render-missing-shared.yaml',
    replaceOccurrenceRequired(stagingBlueprint, '        - shared/**', '', 1)
  );
  requireCheckerFailure(
    missingSharedPath,
    'staging',
    'petmagic-staging-api buildFilter must include shared/**.'
  );

  const missingWorkerSharedPath = writeFixture(
    'render-missing-worker-shared.yaml',
    replaceOccurrenceRequired(stagingBlueprint, '        - shared/**', '', 2)
  );
  requireCheckerFailure(
    missingWorkerSharedPath,
    'staging',
    'petmagic-staging-generation-worker buildFilter must include shared/**.'
  );

  const missingDatabaseAllowListPath = writeFixture(
    'render-missing-database-allow-list.yaml',
    replaceRequired(stagingBlueprint, '    ipAllowList: []', '')
  );
  requireCheckerFailure(
    missingDatabaseAllowListPath,
    'staging',
    'petmagic-staging-db must define an empty ipAllowList to block public database access.'
  );

  const publicDatabaseAllowListPath = writeFixture(
    'render-public-database-allow-list.yaml',
    replaceRequired(
      stagingBlueprint,
      '    ipAllowList: []',
      '    ipAllowList:\n      - source: 0.0.0.0/0\n        description: regression fixture'
    )
  );
  requireCheckerFailure(
    publicDatabaseAllowListPath,
    'staging',
    'petmagic-staging-db must define an empty ipAllowList to block public database access.'
  );

  const scaledWorkerPath = writeFixture(
    'render-scaled-worker.yaml',
    replaceOccurrenceRequired(stagingBlueprint, '    numInstances: 1', '    numInstances: 2', 2)
  );
  requireCheckerFailure(
    scaledWorkerPath,
    'staging',
    'petmagic-staging-generation-worker numInstances must be 1, found 2.'
  );

  const wrongWorkerPlanPath = writeFixture(
    'render-wrong-worker-plan.yaml',
    replaceOccurrenceRequired(stagingBlueprint, '    plan: standard', '    plan: starter', 2)
  );
  requireCheckerFailure(
    wrongWorkerPlanPath,
    'staging',
    'petmagic-staging-generation-worker plan must be standard, found starter.'
  );

  const shortWorkerShutdownPath = writeFixture(
    'render-short-worker-shutdown.yaml',
    replaceRequired(stagingBlueprint, '    maxShutdownDelaySeconds: 300', '    maxShutdownDelaySeconds: 60')
  );
  requireCheckerFailure(
    shortWorkerShutdownPath,
    'staging',
    'petmagic-staging-generation-worker maxShutdownDelaySeconds must be 300, found 60.'
  );

  const publicWorkerPath = writeFixture(
    'render-public-worker.yaml',
    replaceRequired(
      stagingBlueprint,
      '    maxShutdownDelaySeconds: 300\n',
      '    maxShutdownDelaySeconds: 300\n    domains:\n      - worker.staging.petmagic.app\n'
    )
  );
  requireCheckerFailure(
    publicWorkerPath,
    'staging',
    'petmagic-staging-generation-worker must not define domains.'
  );

  const healthCheckedWorkerPath = writeFixture(
    'render-health-checked-worker.yaml',
    replaceOccurrenceRequired(
      stagingBlueprint,
      '    dockerContext: .\n',
      '    dockerContext: .\n    healthCheckPath: /health\n',
      2
    )
  );
  requireCheckerFailure(
    healthCheckedWorkerPath,
    'staging',
    'petmagic-staging-generation-worker must not define healthCheckPath.'
  );

  const diskBackedWorkerPath = writeFixture(
    'render-disk-backed-worker.yaml',
    replaceRequired(
      stagingBlueprint,
      '    maxShutdownDelaySeconds: 300\n',
      '    maxShutdownDelaySeconds: 300\n    disk:\n      name: unexpected-worker-disk\n      mountPath: /var/petmagic\n      sizeGB: 10\n'
    )
  );
  requireCheckerFailure(
    diskBackedWorkerPath,
    'staging',
    'petmagic-staging-generation-worker must not define disk.'
  );

  const autoscaledApiPath = writeFixture(
    'render-autoscaled-api.yaml',
    replaceRequired(
      stagingBlueprint,
      '    numInstances: 1\n    branch: master',
      '    numInstances: 1\n    scaling:\n      minInstances: 1\n      maxInstances: 2\n    branch: master'
    )
  );
  requireCheckerFailure(
    autoscaledApiPath,
    'staging',
    'petmagic-staging-api must not define Render autoscaling; use fixed numInstances: 1.'
  );

  const workerSchedulerOverridePath = writeFixture(
    'render-worker-scheduler-override.yaml',
    replaceOccurrenceRequired(
      stagingBlueprint,
      '      - fromGroup: petmagic-staging-shared\n',
      '      - fromGroup: petmagic-staging-shared\n      - key: Templates__QueueMaxSize\n        value: "999"\n',
      2
    )
  );
  requireCheckerFailure(
    workerSchedulerOverridePath,
    'staging',
    'Scheduler fingerprint mismatch for admission.queueMaxSize'
  );

  const localWorkerLoopOverridePath = writeFixture(
    'render-local-worker-loop-override.yaml',
    replaceOccurrenceRequired(
      stagingBlueprint,
      '      - fromGroup: petmagic-staging-shared\n',
      '      - fromGroup: petmagic-staging-shared\n      - key: Templates__MaxConcurrentJobsPerWorker\n        value: "2"\n',
      2
    )
  );
  requireCheckerFailure(
    localWorkerLoopOverridePath,
    'staging',
    'must inherit Templates__MaxConcurrentJobsPerWorker from petmagic-staging-shared'
  );

  const inertLegacySchedulerKeyPath = writeFixture(
    'render-inert-legacy-scheduler-key.yaml',
    replaceRequired(
      stagingBlueprint,
      '      - key: Templates__GlobalMaxConcurrentGenerations',
      '      - key: GENERATION_GLOBAL_MAX_CONCURRENT'
    )
  );
  requireCheckerFailure(
    inertLegacySchedulerKeyPath,
    'staging',
    'uses inert legacy scheduler key GENERATION_GLOBAL_MAX_CONCURRENT'
  );

  console.log('Render Blueprint contract tests passed.');
} finally {
  const fixtureRelativePath = relative(tempBase, fixtureRoot);
  if (!fixtureRelativePath || fixtureRelativePath.startsWith('..') || isAbsolute(fixtureRelativePath)) {
    throw new Error(`Refusing to remove unsafe fixture path: ${fixtureRoot}`);
  }

  rmSync(fixtureRoot, { recursive: true, force: true });
}

function writeFixture(fileName, contents) {
  const fixturePath = resolve(fixtureRoot, fileName);
  writeFileSync(fixturePath, contents, 'utf8');
  return fixturePath;
}

function replaceRequired(source, expected, replacement) {
  assert(source.includes(expected), `Fixture source must include ${expected}.`);
  return source.replace(expected, replacement);
}

function replaceOccurrenceRequired(source, expected, replacement, occurrence) {
  let matchIndex = -1;
  let searchFrom = 0;

  for (let currentOccurrence = 1; currentOccurrence <= occurrence; currentOccurrence += 1) {
    matchIndex = source.indexOf(expected, searchFrom);
    assert.notEqual(matchIndex, -1, `Fixture source must include occurrence ${occurrence} of ${expected}.`);
    searchFrom = matchIndex + expected.length;
  }

  return source.slice(0, matchIndex) + replacement + source.slice(matchIndex + expected.length);
}

function requireCheckerPass(blueprintPath, environment) {
  const result = runChecker(blueprintPath, environment);
  assert.equal(
    result.status,
    0,
    `Expected ${blueprintPath} to pass Blueprint validation.\n${formatResult(result)}`
  );
}

function requireCheckerFailure(blueprintPath, environment, expectedMessage) {
  const result = runChecker(blueprintPath, environment);
  assert.notEqual(result.status, 0, `Expected ${blueprintPath} to fail Blueprint validation.`);
  assert(
    formatResult(result).includes(expectedMessage),
    `Expected Blueprint validation failure to include "${expectedMessage}".\n${formatResult(result)}`
  );
}

function runChecker(blueprintPath, environment) {
  const result = spawnSync(
    process.execPath,
    [checkerPath, '--root', repoRoot, '--file', blueprintPath, '--environment', environment],
    {
      cwd: repoRoot,
      encoding: 'utf8',
      windowsHide: true
    }
  );

  if (result.error) {
    throw result.error;
  }

  return result;
}

function formatResult(result) {
  return [result.stdout, result.stderr].filter(Boolean).join('\n').trim();
}
