#!/usr/bin/env node

import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, '..', '..');
const releaseGatePath = join(scriptDir, 'run-template-feed-tz1-8-release-gate.ps1');

try {
  await assertPowerShellParses();
  await assertSkipModeRequiresScopedRunIds();
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

async function assertSkipModePassesWithScopedAcceptedArtifacts() {
  const id = `self-test-${Date.now()}`;
  const latencyRunId = `${id}-latency`;
  const sseRunId = `${id}-sse`;
  const createdPaths = [];
  const fixture = mkdtempSync(join(tmpdir(), 'template-feed-release-gate-pass-'));
  try {
    mkdirSync(fixture, { recursive: true });
    const envFile = join(fixture, '.env.staging.local');
    writeFileSync(envFile, 'STAGING_PROMETHEUS_BASE_URL=http://127.0.0.1:9\n');

    const latencyDir = join(repoRoot, 'artifacts', 'template-feed-staging-snapshots', latencyRunId);
    const sseDir = join(repoRoot, 'artifacts', 'template-feed-staging-snapshots', sseRunId);
    const reportPath = join(repoRoot, 'artifacts', `templates-feed-tz1-8-admin-qa-report-${id}.md`);
    createdPaths.push(latencyDir, sseDir, reportPath);

    mkdirSync(latencyDir, { recursive: true });
    mkdirSync(sseDir, { recursive: true });
    writeJson(join(latencyDir, 'evidence.json'), acceptedLatencyEvidence(latencyRunId));
    writeFileSync(join(latencyDir, 'summary.md'), '# Latency snapshot\n\nNo material regression.\n');
    writeJson(join(sseDir, 'evidence.json'), acceptedSseEvidence(sseRunId));
    writeFileSync(join(sseDir, 'summary.md'), '# SSE snapshot\n\nDelta total: 0\n');
    writeAdminQaReport(reportPath, `artifacts/template-feed-staging-snapshots/${sseRunId}/summary.md`);

    const result = await runPowerShell([
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      releaseGatePath,
      '-EnvFile',
      envFile,
      '-SkipLatency',
      '-SkipSse',
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
        timeUtc: '2026-07-02T11:55:00.000Z',
        p95: [{ metric: { route: '/api/templates/feed', method: 'GET' }, value: 0.21 }],
        p99: [{ metric: { route: '/api/templates/feed', method: 'GET' }, value: 0.34 }],
      },
      after: {
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

function acceptedSseEvidence(runId) {
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
        timeUtc: '2026-07-02T12:00:00.000Z',
        total: 7,
        windowIncrease: 0,
      },
      after: {
        timeUtc: '2026-07-02T12:03:00.000Z',
        total: 7,
        windowIncrease: 0,
      },
      deltaTotal: 0,
      windowIncreaseAfter: 0,
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

function writeAdminQaReport(path, sseSummaryPath) {
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
      '| Category rename under feed load | PASS | feed-load log and category rename screenshot attached |',
      '| Bulk status update | N/A | no bulk template status operation exists |',
      '| Activate without required media through UI | PASS | UI validation screenshot and unchanged status response attached |',
      '| Archive category with public templates | PASS | admin archive action plus public feed response attached |',
    ].join('\n')
  );
}

function writeJson(path, value) {
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
