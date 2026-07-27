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
