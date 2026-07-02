#!/usr/bin/env node

import { existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const generatorPath = join(scriptDir, 'create-template-feed-admin-qa-report-draft.mjs');
const validatorPath = join(scriptDir, 'validate-template-feed-tz1-8-evidence.mjs');

try {
  await assertAcceptedSseSnapshotCreatesTodoDraft();
  await assertRejectedSseSnapshotFails();
  console.log('template feed Admin QA report draft self-test passed');
} catch (error) {
  console.error(error.stack || String(error));
  process.exitCode = 1;
}

async function assertAcceptedSseSnapshotCreatesTodoDraft() {
  const root = createTempRepoRoot('accepted');
  writeCommonArtifacts(root);
  writeAcceptedFeedLoadProbe(root);
  writeAcceptedSseSnapshot(root, {
    feedLoadProbeSummaryPath: 'artifacts/template-feed-load-probes/accepted-rename-load/summary.md',
  });

  const output = 'artifacts/templates-feed-tz1-8-admin-qa-report-draft.md';
  const result = await spawnNode([
    generatorPath,
    '--sse-run-id=accepted-sse',
    '--admin-url=https://admin.staging.example',
    '--api-health=health build 2026-07-02',
    '--operator=qa',
    '--date-time-utc=2026-07-02T12:00:00.000Z',
    `--output=${output}`,
  ], root);

  assertExitCode(result, 0);
  const reportPath = join(root, output);
  assert(existsSync(reportPath), 'draft report was not written');
  const report = readFileSync(reportPath, 'utf8');
  assert(report.includes('- Admin URL: https://admin.staging.example'), 'missing Admin URL metadata');
  assert(report.includes('- Staging snapshot artifact: artifacts/template-feed-staging-snapshots/accepted-sse/summary.md'), 'missing snapshot summary path');
  assert(report.includes('artifacts/template-feed-load-probes/accepted-rename-load/summary.md plus category id'), 'missing integrated feed-load probe evidence prefill');
  assert(report.includes('| Category rename under feed load | TODO |'), 'manual scenarios should remain TODO');

  const validatorResult = await spawnNode([validatorPath], root);
  assert(
    validatorResult.code !== 0,
    `draft report must not pass final evidence gate before manual evidence is filled\nstdout:\n${validatorResult.stdout}\nstderr:\n${validatorResult.stderr}`
  );
  assert(validatorResult.stdout.includes('[FAIL] admin.manual_qa_report_complete'), 'draft should fail Admin QA completion');
}

async function assertRejectedSseSnapshotFails() {
  const root = createTempRepoRoot('rejected');
  writeCommonArtifacts(root);
  writeAcceptedSseSnapshot(root, { deltaTotal: 1 });

  const result = await spawnNode([
    generatorPath,
    '--sse-run-id=accepted-sse',
    '--admin-url=https://admin.staging.example',
    '--api-health=health build 2026-07-02',
    '--operator=qa',
  ], root);

  assert(
    result.code !== 0,
    `rejected SSE snapshot should fail, got exit 0\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
  assert(result.stderr.includes('SSE evidence is not accepted'), 'missing rejected SSE error');
}

function createTempRepoRoot(label) {
  const root = mkdtempSync(join(tmpdir(), `template-feed-admin-qa-draft-${label}-`));
  mkdirSync(join(root, 'artifacts'), { recursive: true });
  return root;
}

function writeCommonArtifacts(root) {
  writeFileSync(
    join(root, 'artifacts', 'templates-feed-tz1-8-followup-evidence-2026-07-02.md'),
    [
      '# Follow-up evidence',
      '',
      '| Task | Status | Evidence |',
      '| --- | --- | --- |',
      '| Task 4. Feed latency baseline | Runner validated / staging data required | evidence |',
      '| Task 6. `sse_full_invalidation_count` snapshot | Code guard done / staging admin run required | evidence |',
      '| Task 8. Admin manual QA guard rails | Local guard tests done / staging admin run required | evidence |',
    ].join('\n')
  );
  writeFileSync(
    join(root, 'artifacts', 'templates-feed-tz1-8-long-scroll-500-2026-07-02.md'),
    [
      '# Long scroll',
      '',
      '- memory: selected pid `15336`, 48 selected PSS samples, `plateau_likely=true`',
      '- Weak-device release signoff: PASS',
      '- loaded items: mixed `520`, video-only `520`',
      '- active video preview average: mixed `2.0`, video-only `3.0`',
    ].join('\n')
  );
}

function writeAcceptedSseSnapshot(root, { deltaTotal = 0, feedLoadProbeSummaryPath = '' } = {}) {
  const dir = join(root, 'artifacts', 'template-feed-staging-snapshots', 'accepted-sse');
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, 'summary.md'), '# Template Feed Staging Snapshot\n');
  writeJson(join(dir, 'evidence.json'), {
    runId: 'accepted-sse',
    mode: 'sse',
    startedAtUtc: '2026-07-02T11:55:00.000Z',
    finishedAtUtc: '2026-07-02T12:05:00.000Z',
    prometheusBaseUrl: 'https://prometheus.staging.example',
    actionLabels: ['text_update', 'media_update', 'category_rename'],
    checks: [
      { name: 'sse.admin_action_window_configured', ok: true },
      { name: 'sse_full_invalidation_metric_present', ok: true },
      { name: 'sse_full_invalidation_delta_zero_during_admin_window', ok: deltaTotal === 0 },
    ],
    sseFullInvalidations: {
      before: {
        timeUtc: '2026-07-02T11:55:00.000Z',
        total: 7,
        windowIncrease: 0,
      },
      after: {
        timeUtc: '2026-07-02T12:05:00.000Z',
        total: 7 + deltaTotal,
        windowIncrease: deltaTotal,
      },
      deltaTotal,
      windowIncreaseAfter: deltaTotal,
      ...(feedLoadProbeSummaryPath ? {
        feedLoadProbe: {
          runId: 'accepted-rename-load',
          artifactDir: 'artifacts/template-feed-load-probes/accepted-rename-load',
          summaryPath: feedLoadProbeSummaryPath,
          evidencePath: 'artifacts/template-feed-load-probes/accepted-rename-load/evidence.json',
          exitCode: 0,
        },
      } : {}),
    },
  });
}

function writeAcceptedFeedLoadProbe(root) {
  const dir = join(root, 'artifacts', 'template-feed-load-probes', 'accepted-rename-load');
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, 'summary.md'), '# Template Feed Load Probe\n\nFailed requests: 0\n');
  writeJson(join(dir, 'evidence.json'), {
    runId: 'accepted-rename-load',
    requests: {
      total: 8,
      ok: 8,
      failed: 0,
    },
  });
}

function writeJson(path, value) {
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
}

function spawnNode(args, cwd) {
  return new Promise((resolvePromise) => {
    const child = spawn(process.execPath, args, {
      cwd,
      env: process.env,
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

function assertExitCode(result, expected) {
  assert(
    result.code === expected,
    `expected exit ${expected}, got ${result.code}\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}
