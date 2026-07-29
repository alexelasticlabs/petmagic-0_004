#!/usr/bin/env node
import assert from 'node:assert/strict';
import {
  existsSync,
  chmodSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const acceptanceWrapper = read('scripts/load/run-generation-scheduler-v2-acceptance.sh');
const acceptanceVerifier = join(repoRoot, 'scripts/load/verify-generation-scheduler-v2-acceptance.mjs');
const authSubjectValidator = join(repoRoot, 'scripts/load/validate-generation-load-auth-subjects.mjs');
const k6Source = read('scripts/k6/template-generation-load-test.js');
const backupScript = join(repoRoot, 'scripts/backup-render-postgres.ps1');
const backupSource = read('scripts/backup-render-postgres.ps1');

assert(acceptanceWrapper.includes('[[ "$WORKER_COUNT" == "1" ]]'));
assert(acceptanceWrapper.includes('[[ "$ARTIFACT_ROOT" == "$CANONICAL_ARTIFACT_ROOT" ]]'));
assert(acceptanceWrapper.includes('[[ "$VUS" == "50" ]]'));
assert(acceptanceWrapper.includes('[[ "$ITERATIONS" == "200" ]]'));
assert(acceptanceWrapper.includes('IMAGE_TEMPLATE_ID'));
assert(acceptanceWrapper.includes('VIDEO_TEMPLATE_ID'));
assert(acceptanceWrapper.includes('"TemplateType" = 1'));
assert(acceptanceWrapper.includes('"TemplateType" = 2'));
assert(acceptanceWrapper.includes('[[ "$template_role_counts" == "1,1" ]]'));
assert(acceptanceWrapper.includes('validate-generation-load-auth-subjects.mjs'));
assert(acceptanceWrapper.includes('[[ "$AUTH_SUBJECT_COUNT" == "50" ]]'));
assert(acceptanceWrapper.includes('SCOPE=core_load_only'));
assert(acceptanceWrapper.includes('FULL_ACCEPTANCE=false'));
assert(acceptanceWrapper.includes('runtime-series.csv'));
assert(acceptanceWrapper.includes('templates_generation_provider_attempts'));
assert(acceptanceWrapper.includes('pg_stat_activity'));
assert(acceptanceWrapper.includes('"GenerationSchedulerV2Enabled"'));
assert(acceptanceWrapper.includes('"GenerationDispatchConcurrency"'));
assert(acceptanceWrapper.includes('"ProviderReconciliationConcurrency"'));
assert(acceptanceWrapper.includes('"MediaImportConcurrency"'));
assert(acceptanceWrapper.includes('"GenerationMaintenanceConcurrency"'));
assert(acceptanceWrapper.includes('"LastProgressAtUtc"'));
assert(!acceptanceWrapper.includes('-e AUTH_TOKENS="$AUTH_TOKENS"'));
assert(!acceptanceWrapper.includes('export AUTH_TOKENS'));
assert(acceptanceWrapper.includes('AUTH_TOKENS="$AUTH_TOKENS" docker run'));

assert(k6Source.includes("selectedProfile === 'mixed-acceptance'"));
assert(k6Source.includes("executor: 'per-vu-iterations'"));
assert(k6Source.includes('vus !== 50 || iterations !== 200'));
assert(k6Source.includes("generation_mixed_submissions = ['count==200']"));
assert(k6Source.includes("generation_mixed_image_submissions = ['count==100']"));
assert(k6Source.includes("generation_mixed_video_submissions = ['count==100']"));

assert(backupSource.includes('$env:RENDER_POSTGRES_DATABASE_URL'));
assert(backupSource.includes('$env:PGDATABASE = $databaseUrl'));
assert(backupSource.includes('--format=custom'));
assert(backupSource.includes('--list'));
assert(backupSource.includes('.partial'));
assert(backupSource.includes('Get-FileHash -LiteralPath $partialBackupPath -Algorithm SHA256'));
assert(backupSource.includes('Move-Item -LiteralPath $partialBackupPath -Destination $finalBackupPath'));
assert(!backupSource.includes('[string]$DatabaseUrl'));
assert(!backupSource.includes('--dbname'));

const tempRoot = mkdtempSync(join(tmpdir(), 'petmagic-rollout-tooling-'));
try {
  testAuthSubjectValidator();
  testAcceptanceVerifier(join(tempRoot, 'acceptance'));
  testBackupWithFakePostgresTools(join(tempRoot, 'backup'));
  console.log('generation rollout tooling contracts ok');
} finally {
  rmSync(tempRoot, { recursive: true, force: true });
}

function testAuthSubjectValidator() {
  const uniqueTokens = Array.from({ length: 50 }, (_, index) => fakeJwt(fakeUserId(index), `sig-${index}`));
  let result = spawnSync(process.execPath, [authSubjectValidator], {
    encoding: 'utf8',
    env: { ...process.env, AUTH_TOKENS: uniqueTokens.join(',') },
  });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.equal(result.stdout, '50');

  const duplicateSubjectTokens = Array.from(
    { length: 50 },
    (_, index) => fakeJwt(fakeUserId(index % 49), `different-token-${index}`),
  );
  result = spawnSync(process.execPath, [authSubjectValidator], {
    encoding: 'utf8',
    env: { ...process.env, AUTH_TOKENS: duplicateSubjectTokens.join(',') },
  });
  assert.equal(result.status, 2, result.stderr || result.stdout);
  assert(result.stderr.includes('50 unique JWT sub claims'));
  for (const token of duplicateSubjectTokens) {
    assert(!`${result.stdout}\n${result.stderr}`.includes(token));
  }
}

function testAcceptanceVerifier(runDir) {
  mkdirSync(runDir, { recursive: true });
  writeFileSync(join(runDir, 'acceptance-metadata.env'), [
    'PROFILE=mixed-acceptance',
    'MODE=user',
    'VUS=50',
    'ITERATIONS=200',
    'WORKER_COUNT=1',
    'AUTH_TOKEN_COUNT=50',
    'AUTH_SUBJECT_COUNT=50',
    'DISTINCT_TEMPLATE_ROLES=true',
    'RUN_ID=synthetic-core-load',
    'RUN_STARTED_AT_UTC=2026-07-29T12:00:00.000Z',
    'IDEMPOTENCY_PREFIX=coreload-synthetic-core-load',
    'SCOPE=core_load_only',
    'FULL_ACCEPTANCE=false',
    '',
  ].join('\n'));
  writeFileSync(join(runDir, 'k6-template-generation-summary.json'), JSON.stringify({
    metrics: {
      generation_mixed_submissions: { values: { count: 200 } },
      generation_mixed_image_submissions: { values: { count: 100 } },
      generation_mixed_video_submissions: { values: { count: 100 } },
      generation_create_accepted: { values: { rate: 1, passes: 200, fails: 0 } },
    },
  }));
  const header = 'sampled_at_utc,active_provider_attempts,queue_depth,postgres_connections,effective_global,active_worker_count,scheduler_v2_enabled_worker_count,dispatch_concurrency,reconciliation_concurrency,media_import_concurrency,maintenance_concurrency,worker_last_progress_epoch_ms';
  const progressEpochMs = Date.parse('2026-07-29T12:00:01.000Z');
  writeFileSync(join(runDir, 'runtime-series.csv'), [
    header,
    '2026-07-29T12:00:00.000Z,0,0,4,38,1,1,4,4,1,1,0',
    `2026-07-29T12:00:02.000Z,38,162,12,38,1,1,4,4,1,1,${progressEpochMs}`,
    '',
  ].join('\n'));

  let result = spawnSync(process.execPath, [acceptanceVerifier, '--run-dir', runDir], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  let verdict = JSON.parse(readFileSync(join(runDir, 'acceptance-verdict.json'), 'utf8'));
  assert.equal(verdict.status, 'CORE_LOAD_PASS');
  assert.equal(verdict.scope, 'core_load_only');
  assert.equal(verdict.fullAcceptance, false);
  assert.equal(verdict.observed.activeProviderAttemptsPeak, 38);
  assert.equal(verdict.observed.queueDepthPeak, 162);

  assertVerifierFails(runDir, header, [
    '2026-07-29T12:00:00.000Z,0,200,4,38,1,1,4,4,1,1,0',
    '2026-07-29T12:00:02.000Z,0,200,12,38,1,1,4,4,1,1,0',
  ], 'runtime.provider_saturated_38');
  assertVerifierFails(runDir, header, [
    '2026-07-29T12:00:00.000Z,0,0,4,8,1,1,4,4,1,1,0',
    `2026-07-29T12:00:02.000Z,8,192,12,8,1,1,4,4,1,1,${progressEpochMs}`,
  ], 'runtime.effective_global_exact_38');
  assertVerifierFails(runDir, header, [
    '2026-07-29T12:00:00.000Z,0,0,4,38,1,1,2,4,1,1,0',
    `2026-07-29T12:00:02.000Z,38,162,12,38,1,1,2,4,1,1,${progressEpochMs}`,
  ], 'runtime.worker_lanes_4_4_1_1');
  assertVerifierFails(runDir, header, [
    '2026-07-29T12:00:00.000Z,0,0,4,38,1,0,4,4,1,1,0',
    `2026-07-29T12:00:02.000Z,38,162,12,38,1,0,4,4,1,1,${progressEpochMs}`,
  ], 'runtime.scheduler_v2_enabled');
  assertVerifierFails(runDir, header, [
    '2026-07-29T12:00:00.000Z,0,0,4,38,1,1,4,4,1,1,0',
    `2026-07-29T12:00:02.000Z,39,161,12,38,1,1,4,4,1,1,${progressEpochMs}`,
  ], 'runtime.provider_attempts_never_exceed_effective');
  assertVerifierFails(runDir, header, [
    '2026-07-29T12:00:00.000Z,0,0,4,38,1,1,4,4,1,1,0',
    `2026-07-29T12:00:02.000Z,38,162,70,38,1,1,4,4,1,1,${progressEpochMs}`,
  ], 'runtime.postgres_connections_below_70');
}

function assertVerifierFails(runDir, header, rows, expectedFailedCheck) {
  writeFileSync(join(runDir, 'runtime-series.csv'), `${[header, ...rows, ''].join('\n')}`);
  const result = spawnSync(process.execPath, [acceptanceVerifier, '--run-dir', runDir], { encoding: 'utf8' });
  assert.equal(result.status, 1, result.stderr || result.stdout);
  const verdict = JSON.parse(readFileSync(join(runDir, 'acceptance-verdict.json'), 'utf8'));
  assert.equal(verdict.status, 'CORE_LOAD_FAIL');
  assert.equal(verdict.scope, 'core_load_only');
  assert.equal(verdict.fullAcceptance, false);
  assert.equal(verdict.checks.find(item => item.name === expectedFailedCheck)?.ok, false);
}

function fakeJwt(subject, signature) {
  const header = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(JSON.stringify({ sub: subject })).toString('base64url');
  return `${header}.${payload}.${Buffer.from(signature).toString('base64url')}`;
}

function fakeUserId(index) {
  return `00000000-0000-4000-8000-${index.toString(16).padStart(12, '0')}`;
}

function testBackupWithFakePostgresTools(testRoot) {
  const fakeTools = join(testRoot, 'tools');
  const outputDir = join(testRoot, 'success');
  const failedOutputDir = join(testRoot, 'failure');
  mkdirSync(fakeTools, { recursive: true });
  const { fakeDump, fakeRestore, failingDump } = writeFakePostgresTools(fakeTools);

  const secret = 'super-secret-backup-password';
  const env = {
    ...process.env,
    RENDER_POSTGRES_DATABASE_URL: `postgresql://backup_user:${secret}@dpg-test.oregon-postgres.render.com/petmagic?sslmode=require`,
  };
  const shell = findPowerShell();
  const missingUrlEnv = { ...process.env };
  delete missingUrlEnv.RENDER_POSTGRES_DATABASE_URL;
  let result = runBackup(shell, outputDir, fakeDump, fakeRestore, missingUrlEnv);
  assert.notEqual(result.status, 0);
  assert(`${result.stdout}\n${result.stderr}`.includes('RENDER_POSTGRES_DATABASE_URL must be supplied'));

  const nonRenderSecret = 'must-not-be-printed';
  result = runBackup(shell, outputDir, fakeDump, fakeRestore, {
    ...process.env,
    RENDER_POSTGRES_DATABASE_URL: `postgresql://backup_user:${nonRenderSecret}@localhost/petmagic`,
  });
  assert.notEqual(result.status, 0);
  assert(!`${result.stdout}\n${result.stderr}`.includes(nonRenderSecret));

  result = runBackup(shell, outputDir, fakeDump, fakeRestore, env);
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert(!`${result.stdout}\n${result.stderr}`.includes(secret));

  const files = readdirSync(outputDir);
  const backupFile = exactlyOne(files, name => name.endsWith('.custom.dump'));
  const manifestFile = exactlyOne(files, name => name.endsWith('.manifest.json'));
  exactlyOne(files, name => name.endsWith('.restore-list.txt'));
  assert(!files.some(name => name.endsWith('.partial')));
  const manifestText = readFileSync(join(outputDir, manifestFile), 'utf8');
  const manifest = JSON.parse(manifestText.replace(/^\uFEFF/, ''));
  const backupBytes = readFileSync(join(outputDir, backupFile));
  assert.equal(manifest.format, 'PostgreSQL custom');
  assert.equal(manifest.pgRestoreListVerified, true);
  assert.equal(manifest.sha256, createHash('sha256').update(backupBytes).digest('hex'));
  for (const forbidden of [secret, 'backup_user', 'dpg-test.oregon-postgres.render.com']) {
    assert(!manifestText.includes(forbidden), `manifest leaked ${forbidden}`);
  }

  result = runBackup(shell, failedOutputDir, failingDump, fakeRestore, env);
  assert.notEqual(result.status, 0);
  assert(!`${result.stdout}\n${result.stderr}`.includes(secret));
  assert(existsSync(failedOutputDir));
  assert(!readdirSync(failedOutputDir).some(name => name.endsWith('.partial') || name.endsWith('.custom.dump')));
}

function runBackup(shell, outputDir, fakeDump, fakeRestore, env) {
  return spawnSync(shell, [
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', backupScript,
    '-OutputDir', outputDir,
    '-PgDumpCommand', fakeDump,
    '-PgRestoreCommand', fakeRestore,
  ], { encoding: 'utf8', env });
}

function writeFakePostgresTools(fakeTools) {
  if (process.platform === 'win32') {
    const fakeDump = join(fakeTools, 'fake-pg-dump.cmd');
    const fakeRestore = join(fakeTools, 'fake-pg-restore.cmd');
    const failingDump = join(fakeTools, 'failing-pg-dump.cmd');
    writeFileSync(fakeDump, [
      '@echo off',
      'if "%~1"=="--version" (',
      '  echo pg_dump PostgreSQL 16.test',
      '  exit /b 0',
      ')',
      'set "outfile="',
      ':args',
      'if "%~1"=="" goto done',
      'if /i "%~1"=="--file" (',
      '  set "outfile=%~2"',
      '  shift',
      ')',
      'shift',
      'goto args',
      ':done',
      'if not defined outfile exit /b 8',
      '> "%outfile%" echo PGDMPfake',
      'exit /b 0',
      '',
    ].join('\r\n'));
    writeFileSync(fakeRestore, [
      '@echo off',
      'if "%~1"=="--version" (',
      '  echo pg_restore PostgreSQL 16.test',
      '  exit /b 0',
      ')',
      'set "outfile="',
      'set "listed=false"',
      ':args',
      'if "%~1"=="" goto done',
      'if "%~1"=="--list" set "listed=true"',
      'if /i "%~1"=="--file" (',
      '  set "outfile=%~2"',
      '  shift',
      ')',
      'shift',
      'goto args',
      ':done',
      'if not defined outfile exit /b 8',
      'if "%listed%"=="false" exit /b 8',
      '> "%outfile%" echo ; archive list',
      '>> "%outfile%" echo 1; 0 0 TABLE public templates_generation_jobs petmagic',
      'exit /b 0',
      '',
    ].join('\r\n'));
    writeFileSync(failingDump, [
      '@echo off',
      'if "%~1"=="--version" (',
      '  echo pg_dump PostgreSQL 16.test',
      '  exit /b 0',
      ')',
      'set "outfile="',
      ':args',
      'if "%~1"=="" goto done',
      'if /i "%~1"=="--file" (',
      '  set "outfile=%~2"',
      '  shift',
      ')',
      'shift',
      'goto args',
      ':done',
      'if defined outfile > "%outfile%" echo partial',
      'exit /b 9',
      '',
    ].join('\r\n'));
    return { fakeDump, fakeRestore, failingDump };
  }

  const fakeDump = join(fakeTools, 'fake-pg-dump');
  const fakeRestore = join(fakeTools, 'fake-pg-restore');
  const failingDump = join(fakeTools, 'failing-pg-dump');
  writeFileSync(fakeDump, [
    '#!/usr/bin/env bash',
    'if [[ "${1:-}" == "--version" ]]; then echo "pg_dump PostgreSQL 16.test"; exit 0; fi',
    "outfile=''",
    'while [[ "$#" -gt 0 ]]; do',
    '  if [[ "$1" == "--file" ]]; then outfile="$2"; shift; fi',
    '  shift',
    'done',
    '[[ -n "$outfile" ]] || exit 8',
    'printf "PGDMPfake" > "$outfile"',
    '',
  ].join('\n'));
  writeFileSync(fakeRestore, [
    '#!/usr/bin/env bash',
    'if [[ "${1:-}" == "--version" ]]; then echo "pg_restore PostgreSQL 16.test"; exit 0; fi',
    "outfile=''",
    'listed=false',
    'while [[ "$#" -gt 0 ]]; do',
    '  [[ "$1" == "--list" ]] && listed=true',
    '  if [[ "$1" == "--file" ]]; then outfile="$2"; shift; fi',
    '  shift',
    'done',
    '[[ -n "$outfile" && "$listed" == true ]] || exit 8',
    'printf "; archive list\\n1; 0 0 TABLE public templates_generation_jobs petmagic\\n" > "$outfile"',
    '',
  ].join('\n'));
  writeFileSync(failingDump, [
    '#!/usr/bin/env bash',
    'if [[ "${1:-}" == "--version" ]]; then echo "pg_dump PostgreSQL 16.test"; exit 0; fi',
    "outfile=''",
    'while [[ "$#" -gt 0 ]]; do',
    '  if [[ "$1" == "--file" ]]; then outfile="$2"; shift; fi',
    '  shift',
    'done',
    '[[ -z "$outfile" ]] || printf "partial" > "$outfile"',
    'exit 9',
    '',
  ].join('\n'));
  for (const path of [fakeDump, fakeRestore, failingDump]) {
    chmodSync(path, 0o755);
  }
  return { fakeDump, fakeRestore, failingDump };
}

function findPowerShell() {
  const candidates = [process.env.PWSH_COMMAND, 'pwsh', 'powershell'].filter(Boolean);
  for (const candidate of candidates) {
    const probe = spawnSync(candidate, ['-NoProfile', '-Command', '$PSVersionTable.PSVersion.ToString()'], {
      encoding: 'utf8',
    });
    if (!probe.error && probe.status === 0) {
      return candidate;
    }
  }
  throw new Error('PowerShell is required for backup tooling contracts.');
}

function exactlyOne(values, predicate) {
  const matches = values.filter(predicate);
  assert.equal(matches.length, 1, `expected one matching artifact, found: ${matches.join(', ')}`);
  return matches[0];
}

function read(path) {
  return readFileSync(join(repoRoot, path), 'utf8');
}
