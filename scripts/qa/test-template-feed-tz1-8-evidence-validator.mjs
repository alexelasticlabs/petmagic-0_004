#!/usr/bin/env node

import { mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const validatorPath = join(scriptDir, 'validate-template-feed-tz1-8-evidence.mjs');

try {
  await assertCompleteEvidencePasses();
  await assertMissingExternalEvidenceFails();
  await assertIncompleteAdminMetadataFails();
  await assertLatencyRegressionEvidenceFails();
  await assertIncompleteSseActionLabelsFail();
  await assertMissingAdminScenarioEvidenceFails();
  await assertMissingAdminLoadProbeEvidenceFails();
  await assertRejectedAdminLoadProbeEvidenceFails();
  await assertReversedAdminLoadProbeMetadataFails();
  await assertMismatchedAdminLoadProbeEvidenceFails();
  await assertMissingAdminSnapshotArtifactFails();
  await assertAdminSnapshotArtifactMustBeAcceptedSseFails();
  await assertScopedAdminReportPathFailsWhenSelectedReportIsInvalid();
  await assertScopedSnapshotRunIdsPassWhenArtifactsMatch();
  await assertScopedSnapshotRunIdsFailWhenArtifactsAreStale();
  await assertSnapshotRunnerMetadataIsRequired();
  await assertSnapshotRunnerMetadataChronologyIsRequired();
  await assertSnapshotMeasurementStructureIsRequired();
  await assertSnapshotMeasurementConsistencyIsRequired();
  await assertSnapshotComparisonMatchesRawSamples();
  await assertSnapshotChronologyIsRequired();
  await assertSnapshotLabelsAreRequired();
  console.log('template feed TZ1-8 evidence validator self-test passed');
} catch (error) {
  console.error(error.stack || String(error));
  process.exitCode = 1;
}

async function assertCompleteEvidencePasses() {
  const root = createTempRepoRoot('complete');
  writeCommonArtifacts(root);
  writeLatencyArtifact(root);
  writeSseArtifact(root);
  writeAdminQaReport(root);

  const result = await runValidator(root);
  assert(
    result.code === 0,
    `complete evidence should pass, got exit ${result.code}\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
  assert(result.stdout.includes('Template feed TZ1-8 evidence gate passed.'), 'missing pass message');
}

async function assertMissingExternalEvidenceFails() {
  const root = createTempRepoRoot('missing-external');
  writePendingCommonArtifacts(root);

  const result = await runValidator(root);
  assert(
    result.code !== 0,
    `missing external evidence should fail, got exit 0\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
  assert(result.stdout.includes('[FAIL] staging.feed_latency_before_after_artifact'), 'missing latency failure');
  assert(result.stdout.includes('[FAIL] staging.sse_full_invalidation_admin_window_artifact'), 'missing SSE failure');
  assert(result.stdout.includes('[FAIL] admin.manual_qa_report_complete'), 'missing admin QA failure');
}

async function assertIncompleteAdminMetadataFails() {
  const root = createTempRepoRoot('incomplete-admin-metadata');
  writeCommonArtifacts(root);
  writeLatencyArtifact(root);
  writeSseArtifact(root);
  writeAdminQaReport(root, { includeMetadataValues: false });

  const result = await runValidator(root);
  assert(
    result.code !== 0,
    `incomplete admin QA metadata should fail, got exit 0\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
  assert(result.stdout.includes('[FAIL] admin.manual_qa_report_complete'), 'missing admin metadata failure');
}

async function assertLatencyRegressionEvidenceFails() {
  const root = createTempRepoRoot('latency-regression');
  writeCommonArtifacts(root);
  writeLatencyArtifact(root, { noMaterialRegression: false });
  writeSseArtifact(root);
  writeAdminQaReport(root);

  const result = await runValidator(root);
  assert(
    result.code !== 0,
    `latency regression evidence should fail, got exit 0\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
  assert(result.stdout.includes('[FAIL] staging.feed_latency_before_after_artifact'), 'missing latency regression failure');
}

async function assertIncompleteSseActionLabelsFail() {
  const root = createTempRepoRoot('incomplete-sse-actions');
  writeCommonArtifacts(root);
  writeLatencyArtifact(root);
  writeSseArtifact(root, { actionLabels: ['text_update'] });
  writeAdminQaReport(root);

  const result = await runValidator(root);
  assert(
    result.code !== 0,
    `incomplete SSE action labels should fail, got exit 0\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
  assert(result.stdout.includes('[FAIL] staging.sse_full_invalidation_admin_window_artifact'), 'missing SSE action-label failure');
}

async function assertMissingAdminScenarioEvidenceFails() {
  const root = createTempRepoRoot('missing-admin-scenario-evidence');
  writeCommonArtifacts(root);
  writeLatencyArtifact(root);
  writeSseArtifact(root);
  writeAdminQaReport(root, {
    scenarioEvidence: {
      categoryRename: '',
    },
  });

  const result = await runValidator(root);
  assert(
    result.code !== 0,
    `missing admin scenario evidence should fail, got exit 0\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
  assert(result.stdout.includes('[FAIL] admin.manual_qa_report_complete'), 'missing admin scenario evidence failure');
}

async function assertMissingAdminLoadProbeEvidenceFails() {
  const root = createTempRepoRoot('missing-admin-load-probe-evidence');
  writeCommonArtifacts(root);
  writeLatencyArtifact(root);
  writeSseArtifact(root);
  writeAdminQaReport(root, {
    scenarioEvidence: {
      categoryRename: 'category rename screenshot attached without feed-load probe summary',
    },
  });

  const result = await runValidator(root);
  assert(
    result.code !== 0,
    `admin QA without accepted feed-load probe summary should fail, got exit 0\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
  assert(result.stdout.includes('[FAIL] admin.manual_qa_report_complete'), 'missing load-probe linked admin failure');
  assert(result.stdout.includes('missing an accepted feed-load probe summary'), 'missing diagnostic load-probe rejection reason');
}

async function assertRejectedAdminLoadProbeEvidenceFails() {
  const root = createTempRepoRoot('rejected-admin-load-probe-evidence');
  writeCommonArtifacts(root);
  writeFeedLoadProbeArtifact(root, { failed: 1, maxErrors: 0 });
  writeLatencyArtifact(root);
  writeSseArtifact(root);
  writeAdminQaReport(root);

  const result = await runValidator(root);
  assert(
    result.code !== 0,
    `admin QA with failed feed-load probe should fail, got exit 0\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
  assert(result.stdout.includes('[FAIL] admin.manual_qa_report_complete'), 'missing rejected load-probe linked admin failure');
}

async function assertReversedAdminLoadProbeMetadataFails() {
  const root = createTempRepoRoot('reversed-admin-load-probe-metadata');
  writeCommonArtifacts(root);
  writeFeedLoadProbeArtifact(root, { reverseMetadataTimes: true });
  writeLatencyArtifact(root);
  writeSseArtifact(root);
  writeAdminQaReport(root);

  const result = await runValidator(root);
  assert(
    result.code !== 0,
    `admin QA with reversed feed-load probe metadata should fail, got exit 0\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
  assert(result.stdout.includes('[FAIL] admin.manual_qa_report_complete'), 'missing reversed load-probe metadata admin failure');
}

async function assertMismatchedAdminLoadProbeEvidenceFails() {
  const root = createTempRepoRoot('mismatched-admin-load-probe-evidence');
  writeCommonArtifacts(root);
  writeFeedLoadProbeArtifact(root, { runId: 'stale-rename-load-probe' });
  writeLatencyArtifact(root);
  writeSseArtifact(root);
  writeAdminQaReport(root, {
    scenarioEvidence: {
      categoryRename: 'artifacts/template-feed-load-probes/stale-rename-load-probe/summary.md plus category rename screenshot attached',
    },
  });

  const result = await runValidator(root);
  assert(
    result.code !== 0,
    `admin QA with load-probe summary that differs from integrated SSE probe should fail, got exit 0\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
  assert(result.stdout.includes('[FAIL] admin.manual_qa_report_complete'), 'missing mismatched load-probe linked admin failure');
  assert(result.stdout.includes('does not match the integrated SSE snapshot'), 'missing diagnostic integrated-probe mismatch reason');
}

async function assertMissingAdminSnapshotArtifactFails() {
  const root = createTempRepoRoot('missing-admin-snapshot-artifact');
  writeCommonArtifacts(root);
  writeLatencyArtifact(root);
  writeSseArtifact(root);
  writeAdminQaReport(root, {
    stagingSnapshot: 'artifacts/template-feed-staging-snapshots/sse/missing-summary.md',
  });

  const result = await runValidator(root);
  assert(
    result.code !== 0,
    `missing admin snapshot artifact should fail, got exit 0\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
  assert(result.stdout.includes('[FAIL] admin.manual_qa_report_complete'), 'missing admin snapshot path failure');
}

async function assertAdminSnapshotArtifactMustBeAcceptedSseFails() {
  const root = createTempRepoRoot('admin-nonaccepted-sse-snapshot');
  writeCommonArtifacts(root);
  writeLatencyArtifact(root);
  writeSseArtifact(root, { actionLabels: ['text_update'] });
  writeAdminQaReport(root);

  const result = await runValidator(root);
  assert(
    result.code !== 0,
    `admin QA report linked to non-accepted SSE snapshot should fail, got exit 0\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
  assert(result.stdout.includes('[FAIL] staging.sse_full_invalidation_admin_window_artifact'), 'missing SSE artifact failure');
  assert(result.stdout.includes('[FAIL] admin.manual_qa_report_complete'), 'missing admin linked snapshot failure');
}

async function assertScopedAdminReportPathFailsWhenSelectedReportIsInvalid() {
  const root = createTempRepoRoot('scoped-invalid-admin-report');
  writeCommonArtifacts(root);
  writeLatencyArtifact(root);
  writeSseArtifact(root);
  writeAdminQaReport(root);
  writeAdminQaReport(root, {
    fileName: 'templates-feed-tz1-8-admin-qa-report-invalid-2026-07-02.md',
    includeMetadataValues: false,
  });

  const result = await runValidator(root, {
    TEMPLATE_FEED_ADMIN_QA_REPORT_PATH: 'artifacts/templates-feed-tz1-8-admin-qa-report-invalid-2026-07-02.md',
  });
  assert(
    result.code !== 0,
    `scoped invalid admin QA report should fail even when another complete report exists, got exit 0\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
  assert(result.stdout.includes('[FAIL] admin.manual_qa_report_complete'), 'missing scoped admin report failure');
}

async function assertScopedSnapshotRunIdsPassWhenArtifactsMatch() {
  const root = createTempRepoRoot('scoped-matching-snapshots');
  writeCommonArtifacts(root);
  writeLatencyArtifact(root, { runId: 'current-latency-run' });
  writeSseArtifact(root, { runId: 'current-sse-run' });
  writeAdminQaReport(root);

  const result = await runValidator(root, {
    TEMPLATE_FEED_REQUIRED_LATENCY_RUN_ID: 'current-latency-run',
    TEMPLATE_FEED_REQUIRED_SSE_RUN_ID: 'current-sse-run',
  });
  assert(
    result.code === 0,
    `scoped matching staging snapshots should pass, got exit ${result.code}\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
  assert(result.stdout.includes('Template feed TZ1-8 evidence gate passed.'), 'missing scoped pass message');
}

async function assertScopedSnapshotRunIdsFailWhenArtifactsAreStale() {
  const root = createTempRepoRoot('scoped-stale-snapshots');
  writeCommonArtifacts(root);
  writeLatencyArtifact(root, { runId: 'stale-latency-run' });
  writeSseArtifact(root, { runId: 'stale-sse-run' });
  writeAdminQaReport(root);

  const result = await runValidator(root, {
    TEMPLATE_FEED_REQUIRED_LATENCY_RUN_ID: 'current-latency-run',
    TEMPLATE_FEED_REQUIRED_SSE_RUN_ID: 'current-sse-run',
  });
  assert(
    result.code !== 0,
    `scoped stale staging snapshots should fail, got exit 0\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
  assert(result.stdout.includes('[FAIL] staging.feed_latency_before_after_artifact'), 'missing scoped latency failure');
  assert(result.stdout.includes('[FAIL] staging.sse_full_invalidation_admin_window_artifact'), 'missing scoped SSE failure');
  assert(result.stdout.includes('[FAIL] admin.manual_qa_report_complete'), 'missing admin linked scoped SSE failure');
}

async function assertSnapshotRunnerMetadataIsRequired() {
  const root = createTempRepoRoot('missing-snapshot-metadata');
  writeCommonArtifacts(root);
  writeLatencyArtifact(root, { includeMetadata: false });
  writeSseArtifact(root, { includeMetadata: false });
  writeAdminQaReport(root);

  const result = await runValidator(root);
  assert(
    result.code !== 0,
    `snapshot artifacts without runner metadata should fail, got exit 0\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
  assert(result.stdout.includes('[FAIL] staging.feed_latency_before_after_artifact'), 'missing metadata latency failure');
  assert(result.stdout.includes('[FAIL] staging.sse_full_invalidation_admin_window_artifact'), 'missing metadata SSE failure');
  assert(result.stdout.includes('[FAIL] admin.manual_qa_report_complete'), 'missing metadata linked admin failure');
}

async function assertSnapshotRunnerMetadataChronologyIsRequired() {
  const root = createTempRepoRoot('reversed-snapshot-runner-metadata');
  writeCommonArtifacts(root);
  writeLatencyArtifact(root, { reverseMetadataTimes: true });
  writeSseArtifact(root, { reverseMetadataTimes: true });
  writeAdminQaReport(root);

  const result = await runValidator(root);
  assert(
    result.code !== 0,
    `snapshot artifacts with finishedAtUtc before startedAtUtc should fail, got exit 0\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
  assert(result.stdout.includes('[FAIL] staging.feed_latency_before_after_artifact'), 'missing reversed runner metadata latency failure');
  assert(result.stdout.includes('[FAIL] staging.sse_full_invalidation_admin_window_artifact'), 'missing reversed runner metadata SSE failure');
  assert(result.stdout.includes('[FAIL] admin.manual_qa_report_complete'), 'missing reversed runner metadata linked admin failure');
}

async function assertSnapshotMeasurementStructureIsRequired() {
  const root = createTempRepoRoot('missing-snapshot-measurements');
  writeCommonArtifacts(root);
  writeLatencyArtifact(root, { includeMeasurements: false });
  writeSseArtifact(root, { includeMeasurements: false });
  writeAdminQaReport(root);

  const result = await runValidator(root);
  assert(
    result.code !== 0,
    `snapshot artifacts without measurement structure should fail, got exit 0\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
  assert(result.stdout.includes('[FAIL] staging.feed_latency_before_after_artifact'), 'missing measurement latency failure');
  assert(result.stdout.includes('[FAIL] staging.sse_full_invalidation_admin_window_artifact'), 'missing measurement SSE failure');
  assert(result.stdout.includes('[FAIL] admin.manual_qa_report_complete'), 'missing measurement linked admin failure');
}

async function assertSnapshotMeasurementConsistencyIsRequired() {
  const root = createTempRepoRoot('inconsistent-snapshot-measurements');
  writeCommonArtifacts(root);
  writeLatencyArtifact(root, { inconsistentMeasurements: true });
  writeSseArtifact(root, { inconsistentMeasurements: true });
  writeAdminQaReport(root);

  const result = await runValidator(root);
  assert(
    result.code !== 0,
    `snapshot artifacts with inconsistent measurements should fail, got exit 0\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
  assert(result.stdout.includes('[FAIL] staging.feed_latency_before_after_artifact'), 'missing inconsistent latency failure');
  assert(result.stdout.includes('[FAIL] staging.sse_full_invalidation_admin_window_artifact'), 'missing inconsistent SSE failure');
  assert(result.stdout.includes('[FAIL] admin.manual_qa_report_complete'), 'missing inconsistent linked admin failure');
}

async function assertSnapshotComparisonMatchesRawSamples() {
  const root = createTempRepoRoot('mismatched-snapshot-comparison');
  writeCommonArtifacts(root);
  writeLatencyArtifact(root, { mismatchedComparison: true });
  writeSseArtifact(root, { mismatchedComparison: true });
  writeAdminQaReport(root);

  const result = await runValidator(root);
  assert(
    result.code !== 0,
    `snapshot artifacts with mismatched comparison fields should fail, got exit 0\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
  assert(result.stdout.includes('[FAIL] staging.feed_latency_before_after_artifact'), 'missing mismatched latency comparison failure');
  assert(result.stdout.includes('[FAIL] staging.sse_full_invalidation_admin_window_artifact'), 'missing mismatched SSE window failure');
  assert(result.stdout.includes('[FAIL] admin.manual_qa_report_complete'), 'missing mismatched linked admin failure');
}

async function assertSnapshotChronologyIsRequired() {
  const root = createTempRepoRoot('reversed-snapshot-times');
  writeCommonArtifacts(root);
  writeLatencyArtifact(root, { reverseTimes: true });
  writeSseArtifact(root, { reverseTimes: true });
  writeAdminQaReport(root);

  const result = await runValidator(root);
  assert(
    result.code !== 0,
    `snapshot artifacts with after timestamps before before timestamps should fail, got exit 0\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
  assert(result.stdout.includes('[FAIL] staging.feed_latency_before_after_artifact'), 'missing reversed-time latency failure');
  assert(result.stdout.includes('[FAIL] staging.sse_full_invalidation_admin_window_artifact'), 'missing reversed-time SSE failure');
  assert(result.stdout.includes('[FAIL] admin.manual_qa_report_complete'), 'missing reversed-time linked admin failure');
}

async function assertSnapshotLabelsAreRequired() {
  const root = createTempRepoRoot('wrong-snapshot-labels');
  writeCommonArtifacts(root);
  writeLatencyArtifact(root, { wrongLabels: true });
  writeSseArtifact(root, { wrongLabels: true });
  writeAdminQaReport(root);

  const result = await runValidator(root);
  assert(
    result.code !== 0,
    `snapshot artifacts with wrong before/after labels should fail, got exit 0\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
  assert(result.stdout.includes('[FAIL] staging.feed_latency_before_after_artifact'), 'missing wrong-label latency failure');
  assert(result.stdout.includes('[FAIL] staging.sse_full_invalidation_admin_window_artifact'), 'missing wrong-label SSE failure');
  assert(result.stdout.includes('[FAIL] admin.manual_qa_report_complete'), 'missing wrong-label linked admin failure');
}

function createTempRepoRoot(label) {
  const root = mkdtempSync(join(tmpdir(), `template-feed-evidence-${label}-`));
  mkdirSync(join(root, 'artifacts'), { recursive: true });
  return root;
}

function writeCommonArtifacts(root) {
  writeFollowupEvidence(root, 'Done');
  writeFeedLoadProbeArtifact(root);
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

function writePendingCommonArtifacts(root) {
  writeFollowupEvidence(root, 'Pending');
  writeFeedLoadProbeArtifact(root);
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

function writeFollowupEvidence(root, status) {
  const taskStatus = status === 'Done' ? 'Done' : 'Runner validated / staging data required';
  const taskSixStatus = status === 'Done' ? 'Done' : 'Code guard done / staging admin run required';
  const taskEightStatus = status === 'Done' ? 'Done' : 'Local guard tests done / staging admin run required';

  writeFileSync(
    join(root, 'artifacts', 'templates-feed-tz1-8-followup-evidence-2026-07-02.md'),
    [
      '# Follow-up evidence',
      '',
      '| Task | Status | Evidence |',
      '| --- | --- | --- |',
      `| Task 4. Feed latency baseline | ${taskStatus} | evidence |`,
      `| Task 6. \`sse_full_invalidation_count\` snapshot | ${taskSixStatus} | evidence |`,
      `| Task 8. Admin manual QA guard rails | ${taskEightStatus} | evidence |`,
    ].join('\n')
  );
}

function writeLatencyArtifact(
  root,
  {
    noMaterialRegression = true,
    runId = 'latency-run',
    includeMetadata = true,
    includeMeasurements = true,
    inconsistentMeasurements = false,
    mismatchedComparison = false,
    reverseMetadataTimes = false,
    reverseTimes = false,
    wrongLabels = false,
  } = {}
) {
  const dir = join(root, 'artifacts', 'template-feed-staging-snapshots', 'latency');
  mkdirSync(dir, { recursive: true });
  writeJson(join(dir, 'evidence.json'), {
    ...(includeMetadata ? snapshotMetadata(runId) : {}),
    ...(includeMetadata && reverseMetadataTimes ? reversedSnapshotMetadataTimes() : {}),
    runId,
    mode: 'latency',
    checks: [
      { name: 'latency.before_after_times_configured', ok: true },
      { name: 'latency.before_after_points_present', ok: true },
      { name: 'latency.no_material_regression', ok: noMaterialRegression },
    ],
    latency: {
      ...(includeMeasurements ? {
        before: {
        label: wrongLabels ? 'current' : 'before',
        timeUtc: reverseTimes ? '2026-07-02T12:05:00.000Z' : '2026-07-02T11:55:00.000Z',
        p95: [{ metric: { route: '/api/templates/feed', method: 'GET' }, value: 0.21 }],
        p99: [{ metric: { route: '/api/templates/feed', method: 'GET' }, value: 0.34 }],
      },
      after: {
        label: wrongLabels ? 'current' : 'after',
        timeUtc: reverseTimes ? '2026-07-02T11:55:00.000Z' : '2026-07-02T12:05:00.000Z',
        p95: [{ metric: { route: '/api/templates/feed', method: 'GET' }, value: noMaterialRegression ? 0.2 : 0.31 }],
        p99: [{ metric: { route: '/api/templates/feed', method: 'GET' }, value: noMaterialRegression ? 0.32 : 0.44 }],
      },
      } : {}),
      comparison: {
        beforeP95: mismatchedComparison ? 0.99 : 0.21,
        afterP95: noMaterialRegression ? 0.2 : 0.31,
        beforeP99: 0.34,
        afterP99: noMaterialRegression ? 0.32 : 0.44,
        ...(includeMeasurements ? {
          p95DeltaSeconds: inconsistentMeasurements ? 0 : (noMaterialRegression ? -0.01 : 0.1),
          p99DeltaSeconds: inconsistentMeasurements ? 0 : (noMaterialRegression ? -0.02 : 0.1),
        } : {}),
      },
    },
  });
}

function writeSseArtifact(
  root,
  {
    actionLabels = ['text_update', 'media_update', 'category_rename'],
    runId = 'sse-run',
    includeMetadata = true,
    includeMeasurements = true,
    inconsistentMeasurements = false,
    mismatchedComparison = false,
    reverseMetadataTimes = false,
    reverseTimes = false,
    wrongLabels = false,
    feedLoadProbeSummaryPath = 'artifacts/template-feed-load-probes/rename-load-probe/summary.md',
  } = {}
) {
  const dir = join(root, 'artifacts', 'template-feed-staging-snapshots', 'sse');
  mkdirSync(dir, { recursive: true });
  writeJson(join(dir, 'evidence.json'), {
    ...(includeMetadata ? snapshotMetadata(runId) : {}),
    ...(includeMetadata && reverseMetadataTimes ? reversedSnapshotMetadataTimes() : {}),
    runId,
    mode: 'sse',
    actionLabels,
    checks: [
      { name: 'sse.admin_action_window_configured', ok: true },
      { name: 'sse_full_invalidation_metric_present', ok: true },
      { name: 'sse_full_invalidation_delta_zero_during_admin_window', ok: true },
    ],
    sseFullInvalidations: {
      ...(includeMeasurements ? {
        before: {
        label: wrongLabels ? 'current' : 'before',
        timeUtc: reverseTimes ? '2026-07-02T12:03:00.000Z' : '2026-07-02T12:00:00.000Z',
        total: inconsistentMeasurements ? 6 : 7,
        windowIncrease: 0,
      },
      after: {
        label: wrongLabels ? 'current' : 'after',
        timeUtc: reverseTimes ? '2026-07-02T12:00:00.000Z' : '2026-07-02T12:03:00.000Z',
        total: 7,
        windowIncrease: 0,
      },
      } : {}),
      deltaTotal: 0,
      ...(includeMeasurements ? { windowIncreaseAfter: mismatchedComparison ? 2 : 0 } : {}),
      ...(feedLoadProbeSummaryPath ? {
        feedLoadProbe: {
          runId: 'rename-load-probe',
          artifactDir: 'artifacts/template-feed-load-probes/rename-load-probe',
          summaryPath: feedLoadProbeSummaryPath,
          evidencePath: 'artifacts/template-feed-load-probes/rename-load-probe/evidence.json',
          exitCode: 0,
        },
      } : {}),
    },
  });
  writeFileSync(join(dir, 'summary.md'), '# SSE snapshot\n\nDelta total: 0\n');
}

function snapshotMetadata(runId) {
  return {
    runId,
    startedAtUtc: '2026-07-02T12:00:00.000Z',
    finishedAtUtc: '2026-07-02T12:00:05.000Z',
    prometheusBaseUrl: 'https://prometheus.staging.example.test',
  };
}

function reversedSnapshotMetadataTimes() {
  return {
    startedAtUtc: '2026-07-02T12:00:05.000Z',
    finishedAtUtc: '2026-07-02T12:00:00.000Z',
  };
}

function writeFeedLoadProbeArtifact(
  root,
  {
    runId = 'rename-load-probe',
    failed = 0,
    maxErrors = 0,
    reverseMetadataTimes = false,
  } = {}
) {
  const dir = join(root, 'artifacts', 'template-feed-load-probes', runId);
  mkdirSync(dir, { recursive: true });
  writeJson(join(dir, 'evidence.json'), {
    runId,
    apiBase: 'https://api.staging.example.test',
    path: '/api/templates/feed?take=20',
    url: 'https://api.staging.example.test/api/templates/feed?...',
    startedAtUtc: reverseMetadataTimes ? '2026-07-02T12:03:00.000Z' : '2026-07-02T12:00:00.000Z',
    finishedAtUtc: reverseMetadataTimes ? '2026-07-02T12:00:00.000Z' : '2026-07-02T12:03:00.000Z',
    durationSeconds: 180,
    concurrency: 4,
    intervalMs: 250,
    timeoutMs: 10000,
    maxErrors,
    bearerAuthConfigured: false,
    extraHeaderNames: [],
    requests: {
      total: 32,
      ok: 32 - failed,
      failed,
      statuses: failed > 0 ? { 200: 32 - failed, 500: failed } : { 200: 32 },
    },
    latencyMs: {
      min: 20,
      p50: 25,
      p95: 40,
      p99: 45,
      max: 50,
    },
    itemCounts: {
      min: 20,
      max: 20,
    },
    failedSamples: [],
    samples: [],
  });
  writeFileSync(join(dir, 'summary.md'), '# Template Feed Load Probe\n\nFailed requests: 0\n');
}

function writeAdminQaReport(
  root,
  {
    includeMetadataValues = true,
    fileName = 'templates-feed-tz1-8-admin-qa-report-2026-07-02.md',
    stagingSnapshot = 'artifacts/template-feed-staging-snapshots/sse/summary.md',
    scenarioEvidence = {},
  } = {}
) {
  const evidence = {
    categoryRename: 'artifacts/template-feed-load-probes/rename-load-probe/summary.md plus category rename screenshot attached',
    bulkStatus: 'no bulk template status operation exists',
    activateWithoutMedia: 'UI validation screenshot and unchanged status response attached',
    archiveCategory: 'admin archive action plus public feed response attached',
    ...scenarioEvidence,
  };
  const metadata = includeMetadataValues
    ? {
        adminUrl: 'https://admin.staging.example.test',
        apiBuild: 'build 2026.07.02+test',
        operator: 'QA Operator',
        dateTimeUtc: '2026-07-02T12:00:00Z',
        stagingSnapshot,
      }
    : {
        adminUrl: '',
        apiBuild: '',
        operator: '',
        dateTimeUtc: '',
        stagingSnapshot: '',
      };

  writeFileSync(
    join(root, 'artifacts', fileName),
    [
      '# Admin QA',
      '',
      'Environment:',
      '',
      `- Admin URL: ${metadata.adminUrl}`,
      `- API build/health: ${metadata.apiBuild}`,
      `- Operator: ${metadata.operator}`,
      `- Date/time UTC: ${metadata.dateTimeUtc}`,
      `- Staging snapshot artifact: ${metadata.stagingSnapshot}`,
      '',
      '| Scenario | Result | Evidence |',
      '| --- | --- | --- |',
      `| Category rename under feed load | PASS | ${evidence.categoryRename} |`,
      `| Bulk status update | N/A | ${evidence.bulkStatus} |`,
      `| Activate without required media through UI | PASS | ${evidence.activateWithoutMedia} |`,
      `| Archive category with public templates | PASS | ${evidence.archiveCategory} |`,
    ].join('\n')
  );
}

function writeJson(path, value) {
  writeFileSync(path, JSON.stringify(value, null, 2));
}

function runValidator(cwd, envOverrides = {}) {
  const env = {
    ...process.env,
    TEMPLATE_FEED_REQUIRED_LATENCY_RUN_ID: '',
    TEMPLATE_FEED_REQUIRED_SSE_RUN_ID: '',
    TEMPLATE_FEED_ADMIN_QA_REPORT_PATH: '',
    ...envOverrides,
  };

  return new Promise(resolvePromise => {
    const child = spawn(process.execPath, [resolve(validatorPath)], {
      cwd,
      env,
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

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}
