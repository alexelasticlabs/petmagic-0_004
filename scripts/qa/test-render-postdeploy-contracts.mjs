import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { dirname, isAbsolute, relative, resolve } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, '..', '..');
const smokePath = resolve(scriptDir, 'run-render-postdeploy-smoke.mjs');
const adminProxyPath = resolve(repoRoot, 'apps', 'admin-web', 'src', 'proxy.ts');
const tempBase = resolve(tmpdir());
const fixtureRoot = mkdtempSync(resolve(tempBase, 'petmagic-render-postdeploy-contracts-'));

try {
  const httpResult = runSmoke(
    'http://api.example.test',
    'https://admin.example.test',
    resolve(fixtureRoot, 'http'));
  assert.notEqual(httpResult.status, 0, 'HTTP API URL must fail before authenticated checks.');
  assert.match(formatResult(httpResult), /input\.apiBaseUrl\.absolute_https_url/);
  assert.doesNotMatch(
    formatResult(httpResult),
    /api\.health\.http_200/,
    'Invalid HTTPS input must stop before any remote request is attempted.');

  const dirtyAuthorityResult = runSmoke(
    'https://operator@example.test?token=unsafe#fragment',
    'https://admin.example.test',
    resolve(fixtureRoot, 'authority'));
  assert.notEqual(dirtyAuthorityResult.status, 0, 'URL userinfo/query/fragment must be rejected.');
  assert.match(formatResult(dirtyAuthorityResult), /input\.apiBaseUrl\.clean_authority/);
  assert.doesNotMatch(
    formatResult(dirtyAuthorityResult),
    /api\.health\.http_200/,
    'Unsafe URL authority must stop before any remote request is attempted.');

  const invalidRevisionResult = runSmoke(
    'https://api.example.test',
    'https://admin.example.test',
    resolve(fixtureRoot, 'revision'),
    'not-a-revision');
  assert.notEqual(invalidRevisionResult.status, 0, 'Invalid expected source revision must fail before remote requests.');
  assert.match(formatResult(invalidRevisionResult), /input\.expected_source_revision_format/);
  assert.doesNotMatch(formatResult(invalidRevisionResult), /api\.health\.http_200/);

  const smokeSource = readFileSync(smokePath, 'utf8');
  for (const requiredContract of [
    "'api.health.source_revision_matches_deploy'",
    "'api.generation_control.progress_present_when_work_exists'",
    "'api.generation_control.progress_fresh_when_work_exists'",
    "`${adminBaseUrl}/ru/generations`",
    "'admin.generations.route_identity'",
    "response.headers.get('x-petmagic-admin-route')",
    "'admin.generations.csp_expected_api'",
    "sourceRevision: abbreviateSourceRevision(readCaseInsensitive(build, 'sourceRevision'))"
  ]) {
    assert.ok(smokeSource.includes(requiredContract), `Postdeploy smoke contract missing: ${requiredContract}`);
  }

  const adminProxySource = readFileSync(adminProxyPath, 'utf8');
  assert.ok(
    adminProxySource.includes('response.headers.set("X-PetMagic-Admin-Route", "generations")'),
    'Admin proxy must attest the generations route for the read-only postdeploy check.');
  assert.ok(
    adminProxySource.includes('/^\\/(?:ru|en)\\/generations\\/?$/'),
    'Admin route attestation must be scoped to localized generations routes only.');

  console.log('Render post-deploy contract tests passed.');
} finally {
  const fixtureRelativePath = relative(tempBase, fixtureRoot);
  if (!fixtureRelativePath || fixtureRelativePath.startsWith('..') || isAbsolute(fixtureRelativePath)) {
    throw new Error(`Refusing to remove unsafe fixture path: ${fixtureRoot}`);
  }

  rmSync(fixtureRoot, { recursive: true, force: true });
}

function runSmoke(apiBaseUrl, adminBaseUrl, artifactDir, expectedSourceRevision = 'abcdef0') {
  const result = spawnSync(
    process.execPath,
    [
      smokePath,
      '--environment',
      'staging',
      '--api-base-url',
      apiBaseUrl,
      '--admin-base-url',
      adminBaseUrl,
      '--expected-source-revision',
      expectedSourceRevision,
      '--artifact-dir',
      artifactDir,
      '--run-id',
      'contract-test'
    ],
    {
      cwd: repoRoot,
      encoding: 'utf8',
      windowsHide: true,
      env: {
        ...process.env,
        PETMAGIC_ADMIN_AUTH_TOKEN: 'contract-test-token'
      }
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
