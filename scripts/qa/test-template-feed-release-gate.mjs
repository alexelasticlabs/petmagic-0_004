#!/usr/bin/env node

import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, '..', '..');
const releaseGatePath = join(scriptDir, 'run-template-feed-tz1-8-release-gate.ps1');

try {
  await assertPowerShellParses();
  await assertValidateStagingInputsFailsFastWhenEnvIsIncomplete();
  await assertValidateStagingInputsRejectsInvalidUrlsAndLoadProbeConcurrency();
  await assertValidateStagingInputsRejectsInvalidAdminDraftUrl();
  await assertValidateStagingInputsRejectsInvalidAdminReportPath();
  await assertValidateStagingInputsRejectsInvalidLatencyTimes();
  await assertValidateStagingInputsPassesWithoutRunningPreflight();
  await assertSkipModeRequiresScopedRunIds();
  await assertMissingAdminReportCanCreateDraftAndFail();
  await assertSkipModePassesWithScopedAcceptedArtifacts();
  console.log('template feed release gate self-test passed');
} catch (error) {
  console.error(error.stack || String(error));
  process.exitCode = 1;
}

async function assertPowerShellParses() {
  const result = await runPowerShell([
    '-NoProfile',
    '-Command',
    [
      '$tokens=$null',
      '$errors=$null',
      `[System.Management.Automation.Language.Parser]::ParseFile("${escapePowerShellPath(releaseGatePath)}", [ref]$tokens, [ref]$errors) | Out-Null`,
      'if ($errors.Count -gt 0) { $errors | ForEach-Object { Write-Error $_.Message }; exit 1 }',
    ].join('; '),
  ]);

  assert(result.code === 0, `release gate PowerShell parse failed\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`);
}

async function assertSkipModeRequiresScopedRunIds() {
  const fixture = mkdtempSync(join(tmpdir(), 'template-feed-release-gate-'));
  try {
    mkdirSync(fixture, { recursive: true });
    const envFile = join(fixture, '.env.staging.local');
    writeFileSync(envFile, 'STAGING_PROMETHEUS_BASE_URL=http://127.0.0.1:9\n');

    const result = await runPowerShell([
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      releaseGatePath,
      '-EnvFile',
      envFile,
      '-SkipLatency',
      '-SkipSse',
      '-SkipBackendGuardTests',
      '-SkipAdminGuardTests',
      '-AdminQaReportPath',
      'artifacts/templates-feed-tz1-8-admin-qa-report.template.md',
    ], {
      TEMPLATE_FEED_SKIP_RELEASE_GATE_SELF_TEST: 'true',
    });

    assert(
      result.code !== 0,
      `skip-mode without required run ids should fail, got exit 0\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
    );
    assert(
      result.stdout.includes('TEMPLATE_FEED_REQUIRED_LATENCY_RUN_ID')
        || result.stderr.includes('TEMPLATE_FEED_REQUIRED_LATENCY_RUN_ID'),
      `skip-mode failure did not mention TEMPLATE_FEED_REQUIRED_LATENCY_RUN_ID\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
    );
  } finally {
    rmSync(fixture, { recursive: true, force: true });
  }
}

async function assertValidateStagingInputsFailsFastWhenEnvIsIncomplete() {
  const fixture = mkdtempSync(join(tmpdir(), 'template-feed-release-gate-inputs-fail-'));
  try {
    const envFile = join(fixture, '.env.staging.local');
    const releaseGateArtifactDir = join(fixture, 'release-gate-artifacts');
    writeFileSync(envFile, 'TEMPLATE_FEED_BEFORE_AT_UTC=2026-07-02T11:55:00Z\nTEMPLATE_FEED_AFTER_AT_UTC=2026-07-02T12:05:00Z\n');

    const result = await runPowerShell([
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      releaseGatePath,
      '-EnvFile',
      envFile,
      '-ValidateStagingInputsOnly',
      '-ReleaseGateArtifactDir',
      releaseGateArtifactDir,
      '-AdminQaReportPath',
      'artifacts/templates-feed-tz1-8-admin-qa-report.template.md',
    ]);

    assert(
      result.code !== 0,
      `input validation should fail when STAGING_PROMETHEUS_BASE_URL is missing\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
    );
    assert(
      result.stdout.includes('STAGING_PROMETHEUS_BASE_URL') || result.stderr.includes('STAGING_PROMETHEUS_BASE_URL'),
      `input validation failure did not mention missing Prometheus URL\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
    );
    const summaryPath = join(releaseGateArtifactDir, 'summary.json');
    assert(existsSync(summaryPath), 'failed input validation did not write release gate summary.json');
    const summary = JSON.parse(readFileSync(summaryPath, 'utf8').replace(/^\uFEFF/, ''));
    assert(summary.status === 'failed', `expected failed summary status, got ${summary.status}`);
  } finally {
    rmSync(fixture, { recursive: true, force: true });
  }
}

async function assertValidateStagingInputsRejectsInvalidUrlsAndLoadProbeConcurrency() {
  await assertInvalidReadinessInputFails({
    envLines: [
      'STAGING_PROMETHEUS_BASE_URL=prometheus.staging.example.test',
      'TEMPLATE_FEED_BEFORE_AT_UTC=2026-07-02T11:55:00Z',
      'TEMPLATE_FEED_AFTER_AT_UTC=2026-07-02T12:05:00Z',
    ],
    args: [],
    expectedMessage: 'STAGING_PROMETHEUS_BASE_URL must be an absolute http/https URL',
  });
  await assertInvalidReadinessInputFails({
    envLines: [
      'STAGING_PROMETHEUS_BASE_URL=http://127.0.0.1:9',
      'TEMPLATE_FEED_BEFORE_AT_UTC=2026-07-02T11:55:00Z',
      'TEMPLATE_FEED_AFTER_AT_UTC=2026-07-02T12:05:00Z',
    ],
    args: ['-FeedLoadApiBase', 'ftp://staging-api.example.test'],
    expectedMessage: 'TEMPLATE_FEED_LOAD_PROBE_API_BASE must use http or https',
  });
  await assertInvalidReadinessInputFails({
    envLines: [
      'STAGING_PROMETHEUS_BASE_URL=http://127.0.0.1:9',
      'TEMPLATE_FEED_BEFORE_AT_UTC=2026-07-02T11:55:00Z',
      'TEMPLATE_FEED_AFTER_AT_UTC=2026-07-02T12:05:00Z',
    ],
    args: ['-FeedLoadApiBase', 'https://api.staging.example.test', '-FeedLoadProbeConcurrency', '0'],
    expectedMessage: 'FeedLoadProbeConcurrency must be greater than 0',
  });
}

async function assertInvalidReadinessInputFails({ envLines, args, expectedMessage }) {
  const fixture = mkdtempSync(join(tmpdir(), 'template-feed-release-gate-inputs-invalid-'));
  try {
    const envFile = join(fixture, '.env.staging.local');
    const releaseGateArtifactDir = join(fixture, 'release-gate-artifacts');
    writeFileSync(envFile, envLines.join('\n'));

    const result = await runPowerShell([
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      releaseGatePath,
      '-EnvFile',
      envFile,
      '-ValidateStagingInputsOnly',
      '-ReleaseGateArtifactDir',
      releaseGateArtifactDir,
      '-AdminQaReportPath',
      'artifacts/templates-feed-tz1-8-admin-qa-report.template.md',
      ...args,
    ]);

    assert(
      result.code !== 0,
      `input validation should fail for invalid readiness input\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
    );
    assert(
      result.stdout.includes(expectedMessage) || result.stderr.includes(expectedMessage),
      `input validation failure did not mention expected error "${expectedMessage}"\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
    );
    const summaryPath = join(releaseGateArtifactDir, 'summary.json');
    assert(existsSync(summaryPath), 'failed invalid readiness input did not write release gate summary.json');
    const summary = JSON.parse(readFileSync(summaryPath, 'utf8').replace(/^\uFEFF/, ''));
    assert(summary.status === 'failed', `expected failed summary status, got ${summary.status}`);
  } finally {
    rmSync(fixture, { recursive: true, force: true });
  }
}

async function assertValidateStagingInputsRejectsInvalidAdminDraftUrl() {
  const fixture = mkdtempSync(join(tmpdir(), 'template-feed-release-gate-inputs-draft-url-fail-'));
  const id = `self-test-${Date.now()}-bad-draft-url`;
  const reportPath = join(repoRoot, 'artifacts', `templates-feed-tz1-8-admin-qa-report-${id}.md`);
  try {
    const envFile = join(fixture, '.env.staging.local');
    const releaseGateArtifactDir = join(fixture, 'release-gate-artifacts');
    writeFileSync(
      envFile,
      [
        'STAGING_PROMETHEUS_BASE_URL=http://127.0.0.1:9',
        'TEMPLATE_FEED_BEFORE_AT_UTC=2026-07-02T11:55:00Z',
        'TEMPLATE_FEED_AFTER_AT_UTC=2026-07-02T12:05:00Z',
      ].join('\n')
    );

    const result = await runPowerShell([
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      releaseGatePath,
      '-EnvFile',
      envFile,
      '-ValidateStagingInputsOnly',
      '-ReleaseGateArtifactDir',
      releaseGateArtifactDir,
      '-AdminQaReportPath',
      `artifacts/templates-feed-tz1-8-admin-qa-report-${id}.md`,
      '-CreateAdminQaDraftIfMissing',
      '-AdminQaDraftAdminUrl',
      'admin.staging.example.test',
      '-AdminQaDraftApiHealth',
      'build 2026.07.02+test',
      '-AdminQaDraftOperator',
      'QA Operator',
    ]);

    assert(
      result.code !== 0,
      `input validation should fail for invalid Admin QA draft URL\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
    );
    assert(
      result.stdout.includes('AdminQaDraftAdminUrl must be an absolute http/https URL')
        || result.stderr.includes('AdminQaDraftAdminUrl must be an absolute http/https URL'),
      `input validation failure did not mention invalid Admin QA draft URL\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
    );
    const summaryPath = join(releaseGateArtifactDir, 'summary.json');
    assert(existsSync(summaryPath), 'failed Admin draft URL validation did not write release gate summary.json');
    const summary = JSON.parse(readFileSync(summaryPath, 'utf8').replace(/^\uFEFF/, ''));
    assert(summary.status === 'failed', `expected failed summary status, got ${summary.status}`);
  } finally {
    rmSync(reportPath, { force: true });
    rmSync(fixture, { recursive: true, force: true });
  }
}

async function assertValidateStagingInputsRejectsInvalidAdminReportPath() {
  const fixture = mkdtempSync(join(tmpdir(), 'template-feed-release-gate-inputs-report-path-fail-'));
  try {
    const envFile = join(fixture, '.env.staging.local');
    const releaseGateArtifactDir = join(fixture, 'release-gate-artifacts');
    const reportPath = join(fixture, 'admin-qa-report.md');
    writeFileSync(
      envFile,
      [
        'STAGING_PROMETHEUS_BASE_URL=http://127.0.0.1:9',
        'TEMPLATE_FEED_BEFORE_AT_UTC=2026-07-02T11:55:00Z',
        'TEMPLATE_FEED_AFTER_AT_UTC=2026-07-02T12:05:00Z',
      ].join('\n')
    );
    writeAdminQaReport(
      reportPath,
      'artifacts/template-feed-staging-snapshots/self-test-sse/summary.md',
      'artifacts/template-feed-load-probes/self-test-rename-load/summary.md');

    const result = await runPowerShell([
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      releaseGatePath,
      '-EnvFile',
      envFile,
      '-ValidateStagingInputsOnly',
      '-ReleaseGateArtifactDir',
      releaseGateArtifactDir,
      '-AdminQaReportPath',
      reportPath,
    ]);

    assert(
      result.code !== 0,
      `input validation should fail for Admin QA report outside artifacts\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
    );
    assert(
      result.stdout.includes('Admin QA report path must be inside artifacts/templates-feed-tz1-8-admin-qa-report*.md')
        || result.stderr.includes('Admin QA report path must be inside artifacts/templates-feed-tz1-8-admin-qa-report*.md'),
      `input validation failure did not mention invalid Admin QA report path\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
    );
    const summaryPath = join(releaseGateArtifactDir, 'summary.json');
    assert(existsSync(summaryPath), 'failed Admin report path validation did not write release gate summary.json');
    const summary = JSON.parse(readFileSync(summaryPath, 'utf8').replace(/^\uFEFF/, ''));
    assert(summary.status === 'failed', `expected failed summary status, got ${summary.status}`);
  } finally {
    rmSync(fixture, { recursive: true, force: true });
  }
}

async function assertValidateStagingInputsRejectsInvalidLatencyTimes() {
  await assertInvalidLatencyInputFails({
    beforeAt: '2026-07-02T12:05:00Z',
    afterAt: '2026-07-02T11:55:00Z',
    expectedMessage: 'TEMPLATE_FEED_AFTER_AT_UTC must be later',
  });
  await assertInvalidLatencyInputFails({
    beforeAt: '2026-07-02T11:55:00+03:00',
    afterAt: '2026-07-02T12:05:00Z',
    expectedMessage: 'TEMPLATE_FEED_BEFORE_AT_UTC must be a UTC timestamp',
  });
}

async function assertInvalidLatencyInputFails({ beforeAt, afterAt, expectedMessage }) {
  const fixture = mkdtempSync(join(tmpdir(), 'template-feed-release-gate-inputs-time-fail-'));
  try {
    const envFile = join(fixture, '.env.staging.local');
    const releaseGateArtifactDir = join(fixture, 'release-gate-artifacts');
    writeFileSync(
      envFile,
      [
        'STAGING_PROMETHEUS_BASE_URL=http://127.0.0.1:9',
        `TEMPLATE_FEED_BEFORE_AT_UTC=${beforeAt}`,
        `TEMPLATE_FEED_AFTER_AT_UTC=${afterAt}`,
      ].join('\n')
    );

    const result = await runPowerShell([
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      releaseGatePath,
      '-EnvFile',
      envFile,
      '-ValidateStagingInputsOnly',
      '-ReleaseGateArtifactDir',
      releaseGateArtifactDir,
      '-AdminQaReportPath',
      'artifacts/templates-feed-tz1-8-admin-qa-report.template.md',
    ]);

    assert(
      result.code !== 0,
      `input validation should fail for invalid latency times\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
    );
    assert(
      result.stdout.includes(expectedMessage) || result.stderr.includes(expectedMessage),
      `input validation failure did not mention expected latency-time error "${expectedMessage}"\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
    );
    const summaryPath = join(releaseGateArtifactDir, 'summary.json');
    assert(existsSync(summaryPath), 'failed latency-time input validation did not write release gate summary.json');
    const summary = JSON.parse(readFileSync(summaryPath, 'utf8').replace(/^\uFEFF/, ''));
    assert(summary.status === 'failed', `expected failed summary status, got ${summary.status}`);
  } finally {
    rmSync(fixture, { recursive: true, force: true });
  }
}

async function assertValidateStagingInputsPassesWithoutRunningPreflight() {
  const fixture = mkdtempSync(join(tmpdir(), 'template-feed-release-gate-inputs-pass-'));
  const id = `self-test-${Date.now()}-inputs`;
  const reportPath = join(repoRoot, 'artifacts', `templates-feed-tz1-8-admin-qa-report-${id}.md`);
  try {
    const envFile = join(fixture, '.env.staging.local');
    const releaseGateArtifactDir = join(fixture, 'release-gate-artifacts');
    writeFileSync(
      envFile,
      [
        'STAGING_PROMETHEUS_BASE_URL=http://127.0.0.1:9',
        'TEMPLATE_FEED_BEFORE_AT_UTC=2026-07-02T11:55:00Z',
        'TEMPLATE_FEED_AFTER_AT_UTC=2026-07-02T12:05:00Z',
        `TEMPLATE_FEED_ADMIN_QA_REPORT_PATH=artifacts/templates-feed-tz1-8-admin-qa-report-${id}.md`,
      ].join('\n')
    );
    writeAdminQaReport(
      reportPath,
      `artifacts/template-feed-staging-snapshots/${id}-sse/summary.md`,
      `artifacts/template-feed-load-probes/${id}-rename-load/summary.md`);

    const result = await runPowerShell([
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      releaseGatePath,
      '-RunId',
      id,
      '-EnvFile',
      envFile,
      '-ValidateStagingInputsOnly',
      '-ReleaseGateArtifactDir',
      releaseGateArtifactDir,
    ]);

    assert(
      result.code === 0,
      `input validation should pass with required staging/admin inputs\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
    );
    assert(
      result.stdout.includes('Staging/Admin release-gate inputs are present'),
      `input validation pass did not print success message\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
    );
    assert(
      !result.stdout.includes('snapshot runner self-test'),
      `input validation should not run preflight self-tests\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
    );
    const summaryPath = join(releaseGateArtifactDir, 'summary.json');
    assert(existsSync(summaryPath), 'input validation did not write release gate summary.json');
    const summary = JSON.parse(readFileSync(summaryPath, 'utf8').replace(/^\uFEFF/, ''));
    assert(summary.status === 'input_validation_passed', `expected input_validation_passed summary, got ${summary.status}`);
    assert(
      Array.isArray(summary.steps)
        && summary.steps.length === 1
        && summary.steps[0].name === 'staging input readiness'
        && summary.steps[0].status === 'passed',
      'input validation summary should contain exactly the staging input readiness step'
    );
  } finally {
    rmSync(reportPath, { force: true });
    rmSync(fixture, { recursive: true, force: true });
  }
}

async function assertSkipModePassesWithScopedAcceptedArtifacts() {
  const id = `self-test-${Date.now()}`;
  const latencyRunId = `${id}-latency`;
  const sseRunId = `${id}-sse`;
  const createdPaths = [];
  const fixture = mkdtempSync(join(tmpdir(), 'template-feed-release-gate-pass-'));
  try {
    mkdirSync(fixture, { recursive: true });
    const envFile = join(fixture, '.env.staging.local');
    const releaseGateArtifactDir = join(fixture, 'release-gate-artifacts');
    writeFileSync(envFile, 'STAGING_PROMETHEUS_BASE_URL=http://127.0.0.1:9\n');

    const latencyDir = join(repoRoot, 'artifacts', 'template-feed-staging-snapshots', latencyRunId);
    const sseDir = join(repoRoot, 'artifacts', 'template-feed-staging-snapshots', sseRunId);
    const loadProbeDir = join(repoRoot, 'artifacts', 'template-feed-load-probes', `${id}-rename-load`);
    const reportPath = join(repoRoot, 'artifacts', `templates-feed-tz1-8-admin-qa-report-${id}.md`);
    const followupPath = join(repoRoot, 'artifacts', 'templates-feed-tz1-8-followup-evidence-2026-07-02.md');
    const longScrollPath = join(repoRoot, 'artifacts', 'templates-feed-tz1-8-long-scroll-500-2026-07-02.md');
    createdPaths.push(latencyDir, sseDir, loadProbeDir, reportPath, followupPath, longScrollPath);

    mkdirSync(latencyDir, { recursive: true });
    mkdirSync(sseDir, { recursive: true });
    mkdirSync(loadProbeDir, { recursive: true });
    writeFollowupEvidence(followupPath);
    writeLongScrollArtifact(longScrollPath);
    writeJson(join(latencyDir, 'evidence.json'), acceptedLatencyEvidence(latencyRunId));
    writeFileSync(join(latencyDir, 'summary.md'), '# Latency snapshot\n\nNo material regression.\n');
    writeJson(
      join(sseDir, 'evidence.json'),
      acceptedSseEvidence(sseRunId, `artifacts/template-feed-load-probes/${id}-rename-load/summary.md`));
    writeFileSync(join(sseDir, 'summary.md'), '# SSE snapshot\n\nDelta total: 0\n');
    writeJson(join(loadProbeDir, 'evidence.json'), acceptedLoadProbeEvidence(`${id}-rename-load`));
    writeFileSync(join(loadProbeDir, 'summary.md'), '# Template Feed Load Probe\n\nFailed requests: 0\n');
    writeAdminQaReport(
      reportPath,
      `artifacts/template-feed-staging-snapshots/${sseRunId}/summary.md`,
      `artifacts/template-feed-load-probes/${id}-rename-load/summary.md`);

    const result = await runPowerShell([
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      releaseGatePath,
      '-EnvFile',
      envFile,
      '-SkipLatency',
      '-SkipSse',
      '-SkipBackendGuardTests',
      '-SkipAdminGuardTests',
      '-ReleaseGateArtifactDir',
      releaseGateArtifactDir,
      '-AdminQaReportPath',
      `artifacts/templates-feed-tz1-8-admin-qa-report-${id}.md`,
    ], {
      TEMPLATE_FEED_SKIP_RELEASE_GATE_SELF_TEST: 'true',
      TEMPLATE_FEED_REQUIRED_LATENCY_RUN_ID: latencyRunId,
      TEMPLATE_FEED_REQUIRED_SSE_RUN_ID: sseRunId,
    });

    assert(
      result.code === 0,
      `skip-mode with scoped accepted artifacts should pass, got exit ${result.code}\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
    );
    assert(
      result.stdout.includes('Templates feed TZ1-8 release gate completed.'),
      `skip-mode success did not complete release gate\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
    );
    const summaryPath = join(releaseGateArtifactDir, 'summary.json');
    assert(existsSync(summaryPath), 'release gate summary.json was not written');
    const summary = JSON.parse(readFileSync(summaryPath, 'utf8').replace(/^\uFEFF/, ''));
    assert(summary.status === 'passed', `expected summary status passed, got ${summary.status}`);
    assert(Array.isArray(summary.steps) && summary.steps.length > 0, 'release gate summary did not include steps');
    assert(summary.steps.every(step => step.status === 'passed'), 'release gate summary contains a non-passing step');
  } finally {
    for (const path of createdPaths.reverse()) {
      rmSync(path, { recursive: true, force: true });
    }
    rmSync(fixture, { recursive: true, force: true });
  }
}

async function assertMissingAdminReportCanCreateDraftAndFail() {
  const id = `self-test-${Date.now()}-draft`;
  const latencyRunId = `${id}-latency`;
  const sseRunId = `${id}-sse`;
  const createdPaths = [];
  const fixture = mkdtempSync(join(tmpdir(), 'template-feed-release-gate-draft-'));
  try {
    mkdirSync(fixture, { recursive: true });
    const envFile = join(fixture, '.env.staging.local');
    const releaseGateArtifactDir = join(fixture, 'release-gate-artifacts');
    writeFileSync(envFile, 'STAGING_PROMETHEUS_BASE_URL=http://127.0.0.1:9\n');

    const sseDir = join(repoRoot, 'artifacts', 'template-feed-staging-snapshots', sseRunId);
    const loadProbeDir = join(repoRoot, 'artifacts', 'template-feed-load-probes', `${id}-rename-load`);
    const reportPath = join(repoRoot, 'artifacts', `templates-feed-tz1-8-admin-qa-report-${id}.md`);
    createdPaths.push(sseDir, loadProbeDir, reportPath);

    mkdirSync(sseDir, { recursive: true });
    mkdirSync(loadProbeDir, { recursive: true });
    writeJson(
      join(sseDir, 'evidence.json'),
      acceptedSseEvidence(sseRunId, `artifacts/template-feed-load-probes/${id}-rename-load/summary.md`));
    writeFileSync(join(sseDir, 'summary.md'), '# SSE snapshot\n\nDelta total: 0\n');
    writeJson(join(loadProbeDir, 'evidence.json'), acceptedLoadProbeEvidence(`${id}-rename-load`));
    writeFileSync(join(loadProbeDir, 'summary.md'), '# Template Feed Load Probe\n\nFailed requests: 0\n');

    const result = await runPowerShell([
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      releaseGatePath,
      '-RunId',
      id,
      '-EnvFile',
      envFile,
      '-SkipLatency',
      '-SkipSse',
      '-SkipBackendGuardTests',
      '-SkipAdminGuardTests',
      '-ReleaseGateArtifactDir',
      releaseGateArtifactDir,
      '-AdminQaReportPath',
      `artifacts/templates-feed-tz1-8-admin-qa-report-${id}.md`,
      '-CreateAdminQaDraftIfMissing',
      '-AdminQaDraftAdminUrl',
      'https://admin.staging.example.test',
      '-AdminQaDraftApiHealth',
      'build 2026.07.02+test',
      '-AdminQaDraftOperator',
      'QA Operator',
    ], {
      TEMPLATE_FEED_SKIP_RELEASE_GATE_SELF_TEST: 'true',
      TEMPLATE_FEED_REQUIRED_LATENCY_RUN_ID: latencyRunId,
      TEMPLATE_FEED_REQUIRED_SSE_RUN_ID: sseRunId,
    });

    assert(
      result.code !== 0,
      `draft creation path should fail until manual QA is completed\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
    );
    assert(existsSync(reportPath), 'Admin QA draft report was not created');
    const report = readFileSync(reportPath, 'utf8');
    assert(report.includes('| Category rename under feed load | TODO |'), 'draft report should keep manual rows as TODO');
    assert(report.includes(`artifacts/template-feed-load-probes/${id}-rename-load/summary.md`), 'draft report did not include integrated load-probe summary path');
    assert(
      result.stderr.includes('Admin QA draft created') || result.stdout.includes('Admin QA draft created'),
      `draft creation failure did not explain next action\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
    );
    const summaryPath = join(releaseGateArtifactDir, 'summary.json');
    assert(existsSync(summaryPath), 'failed release gate summary.json was not written after draft creation');
    const summary = JSON.parse(readFileSync(summaryPath, 'utf8').replace(/^\uFEFF/, ''));
    assert(summary.status === 'failed', `expected summary status failed, got ${summary.status}`);
  } finally {
    for (const path of createdPaths.reverse()) {
      rmSync(path, { recursive: true, force: true });
    }
    rmSync(fixture, { recursive: true, force: true });
  }
}

function acceptedLatencyEvidence(runId) {
  return {
    ...snapshotMetadata(runId),
    runId,
    mode: 'latency',
    checks: [
      { name: 'latency.before_after_times_configured', ok: true },
      { name: 'latency.before_after_points_present', ok: true },
      { name: 'latency.no_material_regression', ok: true },
    ],
    latency: {
      before: {
        label: 'before',
        timeUtc: '2026-07-02T11:55:00.000Z',
        p95: [{ metric: { route: '/api/templates/feed', method: 'GET' }, value: 0.21 }],
        p99: [{ metric: { route: '/api/templates/feed', method: 'GET' }, value: 0.34 }],
      },
      after: {
        label: 'after',
        timeUtc: '2026-07-02T12:05:00.000Z',
        p95: [{ metric: { route: '/api/templates/feed', method: 'GET' }, value: 0.2 }],
        p99: [{ metric: { route: '/api/templates/feed', method: 'GET' }, value: 0.32 }],
      },
      comparison: {
        beforeP95: 0.21,
        afterP95: 0.2,
        beforeP99: 0.34,
        afterP99: 0.32,
        p95DeltaSeconds: -0.01,
        p99DeltaSeconds: -0.02,
      },
    },
  };
}

function acceptedSseEvidence(runId, loadProbeSummaryPath = '') {
  return {
    ...snapshotMetadata(runId),
    runId,
    mode: 'sse',
    actionLabels: ['text_update', 'media_update', 'category_rename'],
    checks: [
      { name: 'sse.admin_action_window_configured', ok: true },
      { name: 'sse_full_invalidation_metric_present', ok: true },
      { name: 'sse_full_invalidation_delta_zero_during_admin_window', ok: true },
    ],
    sseFullInvalidations: {
      before: {
        label: 'before',
        timeUtc: '2026-07-02T12:00:00.000Z',
        total: 7,
        windowIncrease: 0,
      },
      after: {
        label: 'after',
        timeUtc: '2026-07-02T12:03:00.000Z',
        total: 7,
        windowIncrease: 0,
      },
      deltaTotal: 0,
      windowIncreaseAfter: 0,
      ...(loadProbeSummaryPath ? {
        feedLoadProbe: {
          runId: `${runId}-rename-load`,
          artifactDir: loadProbeSummaryPath.replace(/\/summary\.md$/, ''),
          summaryPath: loadProbeSummaryPath,
          evidencePath: loadProbeSummaryPath.replace(/\/summary\.md$/, '/evidence.json'),
          exitCode: 0,
        },
      } : {}),
    },
  };
}

function snapshotMetadata(runId) {
  return {
    runId,
    startedAtUtc: '2026-07-02T12:00:00.000Z',
    finishedAtUtc: '2026-07-02T12:00:05.000Z',
    prometheusBaseUrl: 'https://prometheus.staging.example.test',
  };
}

function acceptedLoadProbeEvidence(runId) {
  return {
    runId,
    apiBase: 'https://api.staging.example.test',
    path: '/api/templates/feed?take=20',
    url: 'https://api.staging.example.test/api/templates/feed?...',
    startedAtUtc: '2026-07-02T12:00:00.000Z',
    finishedAtUtc: '2026-07-02T12:03:00.000Z',
    durationSeconds: 180,
    concurrency: 4,
    intervalMs: 250,
    timeoutMs: 10000,
    maxErrors: 0,
    requests: {
      total: 24,
      ok: 24,
      failed: 0,
      statuses: { 200: 24 },
    },
  };
}

function writeAdminQaReport(path, sseSummaryPath, loadProbeSummaryPath) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(
    path,
    [
      '# Admin QA',
      '',
      'Environment:',
      '',
      '- Admin URL: https://admin.staging.example.test',
      '- API build/health: build 2026.07.02+test',
      '- Operator: QA Operator',
      '- Date/time UTC: 2026-07-02T12:00:00Z',
      `- Staging snapshot artifact: ${sseSummaryPath}`,
      '',
      '| Scenario | Result | Evidence |',
      '| --- | --- | --- |',
      `| Category rename under feed load | PASS | ${loadProbeSummaryPath} plus category rename screenshot attached |`,
      '| Bulk status update | N/A | no bulk template status operation exists |',
      '| Activate without required media through UI | PASS | UI validation screenshot and unchanged status response attached |',
      '| Archive category with public templates | PASS | admin archive action plus public feed response attached |',
    ].join('\n')
  );
}

function writeFollowupEvidence(path) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(
    path,
    [
      '# Follow-up evidence',
      '',
      '| Task | Status | Evidence |',
      '| --- | --- | --- |',
      '| Task 4. Feed latency baseline | Done | self-test latency fixture |',
      '| Task 6. `sse_full_invalidation_count` snapshot | Done | self-test SSE fixture |',
      '| Task 8. Admin manual QA guard rails | Done | self-test Admin QA fixture |',
    ].join('\n')
  );
}

function writeLongScrollArtifact(path) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(
    path,
    [
      '# Long scroll',
      '',
      '- Device: `Pixel_3a_API_35 low-memory emulator`',
      '- memory: selected pid `15336`, 48 selected PSS samples, `plateau_likely=true`',
      '- Low-memory emulator signoff: PASS',
      '- loaded items: mixed `520`, video-only `520`',
      '- active video preview average: mixed `2.0`, video-only `3.0`',
    ].join('\n')
  );
}

function writeJson(path, value) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, JSON.stringify(value, null, 2));
}

function runPowerShell(args, envOverrides = {}) {
  return new Promise(resolvePromise => {
    const child = spawn('powershell', args, {
      cwd: repoRoot,
      env: {
        ...process.env,
        ...envOverrides,
      },
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    let stdout = '';
    let stderr = '';
    child.stdout.on('data', chunk => {
      stdout += chunk;
    });
    child.stderr.on('data', chunk => {
      stderr += chunk;
    });
    child.on('exit', code => {
      resolvePromise({ code, stdout, stderr });
    });
  });
}

function escapePowerShellPath(path) {
  return path.replaceAll('`', '``').replaceAll('"', '`"');
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}
