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
  const productionBlueprint = readFileSync(resolve(repoRoot, 'render.production.yaml'), 'utf8');

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

  const productionFixedWorkerCountPath = writeFixture(
    'render-production-fixed-worker-count.yaml',
    replaceRequired(
      productionBlueprint,
      '    maxShutdownDelaySeconds: 300\n    buildFilter:',
      '    maxShutdownDelaySeconds: 300\n    numInstances: 1\n    buildFilter:'
    )
  );
  requireCheckerFailure(
    productionFixedWorkerCountPath,
    'production',
    'petmagic-production-generation-worker must omit numInstances so API-managed scaling survives Blueprint sync.'
  );

  const productionWorkerLocalLoopCountPath = writeFixture(
    'render-production-worker-local-loop-count.yaml',
    replaceRequired(
      productionBlueprint,
      '      - key: Templates__GenerationWorkerEnabled\n        value: "true"\n',
      '      - key: Templates__GenerationWorkerEnabled\n        value: "true"\n' +
        '      - key: Templates__MaxConcurrentJobsPerWorker\n        value: "2"\n'
    )
  );
  requireCheckerFailure(
    productionWorkerLocalLoopCountPath,
    'production',
    'petmagic-production-generation-worker must not define Templates__MaxConcurrentJobsPerWorker; configure it in the shared env group.'
  );

  const productionMissingSharedLoopCountPath = writeFixture(
    'render-production-missing-shared-loop-count.yaml',
    replaceRequired(
      productionBlueprint,
      '      - key: Templates__MaxConcurrentJobsPerWorker\n        value: "2"\n',
      ''
    )
  );
  requireCheckerFailure(
    productionMissingSharedLoopCountPath,
    'production',
    'Env group petmagic-production-shared is missing Templates__MaxConcurrentJobsPerWorker.'
  );

  const productionMissingRenderApiKeyPath = writeFixture(
    'render-production-missing-render-api-key.yaml',
    replaceRequired(
      productionBlueprint,
      '      - key: RENDER_API_KEY\n        sync: false\n',
      ''
    )
  );
  requireCheckerFailure(
    productionMissingRenderApiKeyPath,
    'production',
    'petmagic-production-api is missing secret RENDER_API_KEY.'
  );

  const productionMissingFalBillingAdminKeyPath = writeFixture(
    'render-production-missing-fal-billing-admin-key.yaml',
    replaceRequired(
      productionBlueprint,
      '      - key: FAL_ACCOUNT_BILLING_ADMIN_KEY\n        sync: false\n',
      ''
    )
  );
  requireCheckerFailure(
    productionMissingFalBillingAdminKeyPath,
    'production',
    'petmagic-production-api is missing secret FAL_ACCOUNT_BILLING_ADMIN_KEY.'
  );

  const productionMissingFalExpectedAccountPath = writeFixture(
    'render-production-missing-fal-expected-account.yaml',
    replaceRequired(
      productionBlueprint,
      '      - key: FAL_EXPECTED_ACCOUNT_USERNAME\n        sync: false\n',
      ''
    )
  );
  requireCheckerFailure(
    productionMissingFalExpectedAccountPath,
    'production',
    'petmagic-production-api is missing deferred env FAL_EXPECTED_ACCOUNT_USERNAME.'
  );

  const productionWorkerWithFalBillingAdminKeyPath = writeFixture(
    'render-production-worker-with-fal-billing-admin-key.yaml',
    replaceRequired(
      productionBlueprint,
      '      - key: Templates__GenerationWorkerEnabled\n        value: "true"\n',
      '      - key: Templates__GenerationWorkerEnabled\n        value: "true"\n' +
        '      - key: FAL_ACCOUNT_BILLING_ADMIN_KEY\n        sync: false\n'
    )
  );
  requireCheckerFailure(
    productionWorkerWithFalBillingAdminKeyPath,
    'production',
    'petmagic-production-generation-worker must not receive API-only env FAL_ACCOUNT_BILLING_ADMIN_KEY.'
  );

  const productionWorkerWithFalExpectedAccountPath = writeFixture(
    'render-production-worker-with-fal-expected-account.yaml',
    replaceRequired(
      productionBlueprint,
      '      - key: Templates__GenerationWorkerEnabled\n        value: "true"\n',
      '      - key: Templates__GenerationWorkerEnabled\n        value: "true"\n' +
        '      - key: FAL_EXPECTED_ACCOUNT_USERNAME\n        sync: false\n'
    )
  );
  requireCheckerFailure(
    productionWorkerWithFalExpectedAccountPath,
    'production',
    'petmagic-production-generation-worker must not receive API-only env FAL_EXPECTED_ACCOUNT_USERNAME.'
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
