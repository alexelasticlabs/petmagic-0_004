#!/usr/bin/env node
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { basename, join, resolve } from 'node:path';

if (process.argv.includes('--help') || process.argv.includes('-h')) {
  printHelp();
  process.exit(0);
}

const runDir = resolve(optionValue('--run-dir') || '');
if (!optionValue('--run-dir')) {
  fail('Missing required --run-dir.');
}

const summaryPath = join(runDir, 'k6-template-generation-summary.json');
const seriesPath = join(runDir, 'runtime-series.csv');
const metadataPath = join(runDir, 'acceptance-metadata.env');
for (const path of [summaryPath, seriesPath, metadataPath]) {
  if (!existsSync(path)) {
    fail(`Required acceptance artifact is missing: ${basename(path)}`);
  }
}

const summary = parseJson(summaryPath);
const metadata = parseMetadata(metadataPath);
const series = parseRuntimeSeries(seriesPath);
const checks = [];

check('topology.worker_count_one', metadata.WORKER_COUNT === '1', `actual=${metadata.WORKER_COUNT || 'missing'}`);
check('load.virtual_users_exact', metadata.VUS === '50', `actual=${metadata.VUS || 'missing'}`);
check('load.jobs_exact', metadata.ITERATIONS === '200', `actual=${metadata.ITERATIONS || 'missing'}`);
check('load.profile_mixed_acceptance', metadata.PROFILE === 'mixed-acceptance', `actual=${metadata.PROFILE || 'missing'}`);
check('scope.core_load_only', metadata.SCOPE === 'core_load_only', `actual=${metadata.SCOPE || 'missing'}`);
check('scope.full_acceptance_false', metadata.FULL_ACCEPTANCE === 'false', `actual=${metadata.FULL_ACCEPTANCE || 'missing'}`);
check('load.distinct_template_roles', metadata.DISTINCT_TEMPLATE_ROLES === 'true', `actual=${metadata.DISTINCT_TEMPLATE_ROLES || 'missing'}`);
check('load.auth_tokens_exact', numberMetadata(metadata, 'AUTH_TOKEN_COUNT') === 50, `actual=${metadata.AUTH_TOKEN_COUNT || 'missing'}`);
check('load.auth_subjects_unique_exact', numberMetadata(metadata, 'AUTH_SUBJECT_COUNT') === 50, `actual=${metadata.AUTH_SUBJECT_COUNT || 'missing'}`);
check(
  'load.idempotency_scope_matches_run',
  Boolean(metadata.RUN_ID) && metadata.IDEMPOTENCY_PREFIX === `coreload-${metadata.RUN_ID}`,
  `run=${metadata.RUN_ID || 'missing'}, prefix=${metadata.IDEMPOTENCY_PREFIX || 'missing'}`,
);

const mixedCount = metricValue(summary, 'generation_mixed_submissions', 'count');
const imageCount = metricValue(summary, 'generation_mixed_image_submissions', 'count');
const videoCount = metricValue(summary, 'generation_mixed_video_submissions', 'count');
const acceptedRate = metricValue(summary, 'generation_create_accepted', 'rate');
check('k6.mixed_submissions_200', mixedCount === 200, `actual=${format(mixedCount)}`);
check('k6.image_submissions_100', imageCount === 100, `actual=${format(imageCount)}`);
check('k6.video_submissions_100', videoCount === 100, `actual=${format(videoCount)}`);
check('k6.accepted_rate_100_percent', acceptedRate === 1, `actual=${format(acceptedRate)}`);

const activeProviderPeak = maxOrZero(series.map(row => row.activeProviderAttempts));
const queueDepthPeak = maxOrZero(series.map(row => row.queueDepth));
const postgresConnectionsPeak = maxOrZero(series.map(row => row.postgresConnections));
const effectiveGlobalValues = new Set(series.map(row => row.effectiveGlobal));
const workerCounts = new Set(series.map(row => row.activeWorkerCount));
const schedulerV2WorkerCounts = new Set(series.map(row => row.schedulerV2EnabledWorkerCount));
const dispatchConcurrencies = new Set(series.map(row => row.dispatchConcurrency));
const reconciliationConcurrencies = new Set(series.map(row => row.reconciliationConcurrency));
const mediaImportConcurrencies = new Set(series.map(row => row.mediaImportConcurrency));
const maintenanceConcurrencies = new Set(series.map(row => row.maintenanceConcurrency));
const runStartedAtMs = Date.parse(metadata.RUN_STARTED_AT_UTC || '');
const workerProgressObserved = Number.isFinite(runStartedAtMs) && series.some(row => {
  const sampledAtMs = Date.parse(row.sampledAtUtc);
  return row.workerLastProgressEpochMs >= runStartedAtMs
    && row.workerLastProgressEpochMs <= sampledAtMs + 30000;
});

check('runtime.samples_at_least_two', series.length >= 2, `actual=${series.length}`);
check(
  'runtime.effective_global_exact_38',
  effectiveGlobalValues.size === 1 && effectiveGlobalValues.has(38),
  `observed=${formatSet(effectiveGlobalValues)}`,
);
check(
  'runtime.provider_attempts_never_exceed_effective',
  series.length > 0 && series.every(row => row.activeProviderAttempts <= row.effectiveGlobal),
  `peak=${activeProviderPeak}, effective=${formatSet(effectiveGlobalValues)}`,
);
check(
  'runtime.provider_saturated_38',
  activeProviderPeak === 38,
  `peak=${activeProviderPeak}, required=38`,
);
check(
  'runtime.single_worker_observed',
  workerCounts.size === 1 && workerCounts.has(1),
  `observed=${[...workerCounts].sort((a, b) => a - b).join(',')}`,
);
check(
  'runtime.scheduler_v2_enabled',
  schedulerV2WorkerCounts.size === 1 && schedulerV2WorkerCounts.has(1),
  `enabledWorkerCount=${formatSet(schedulerV2WorkerCounts)}`,
);
check(
  'runtime.worker_lanes_4_4_1_1',
  setEquals(dispatchConcurrencies, 4)
    && setEquals(reconciliationConcurrencies, 4)
    && setEquals(mediaImportConcurrencies, 1)
    && setEquals(maintenanceConcurrencies, 1),
  `dispatch=${formatSet(dispatchConcurrencies)}, reconciliation=${formatSet(reconciliationConcurrencies)}, import=${formatSet(mediaImportConcurrencies)}, maintenance=${formatSet(maintenanceConcurrencies)}`,
);
check(
  'runtime.worker_progress_after_run_start',
  workerProgressObserved,
  `runStartedAtUtc=${metadata.RUN_STARTED_AT_UTC || 'missing'}, maxProgressEpochMs=${maxOrZero(series.map(row => row.workerLastProgressEpochMs))}`,
);
check('runtime.postgres_connections_below_70', postgresConnectionsPeak < 70, `peak=${postgresConnectionsPeak}`);

const passed = checks.every(item => item.ok);
const verdict = {
  schemaVersion: 2,
  scope: 'core_load_only',
  fullAcceptance: false,
  status: passed ? 'CORE_LOAD_PASS' : 'CORE_LOAD_FAIL',
  generatedAtUtc: new Date().toISOString(),
  sourceArtifacts: [basename(metadataPath), basename(summaryPath), basename(seriesPath)],
  expected: {
    workerCount: 1,
    virtualUsers: 50,
    mixedJobs: 200,
    imageJobs: 100,
    videoJobs: 100,
    uniqueJwtSubjects: 50,
    effectiveGlobal: 38,
    activeProviderAttemptsPeak: 38,
    schedulerV2Enabled: true,
    workerLanes: {
      dispatch: 4,
      reconciliation: 4,
      mediaImport: 1,
      maintenance: 1,
    },
    postgresConnectionsExclusiveUpperBound: 70,
  },
  observed: {
    runtimeSamples: series.length,
    activeProviderAttemptsPeak: activeProviderPeak,
    queueDepthPeak,
    postgresConnectionsPeak,
    effectiveGlobalValues: [...effectiveGlobalValues].sort((a, b) => a - b),
    schedulerV2EnabledWorkerCounts: [...schedulerV2WorkerCounts].sort((a, b) => a - b),
    workerProgressObserved,
  },
  checks,
};

writeFileSync(join(runDir, 'acceptance-verdict.json'), `${JSON.stringify(verdict, null, 2)}\n`, 'utf8');
writeFileSync(join(runDir, 'acceptance-verdict.md'), renderMarkdown(verdict), 'utf8');
console.log(`Generation Scheduler V2 core load verifier: ${verdict.status}`);
console.log(`Artifacts: ${join(runDir, 'acceptance-verdict.json')}`);
process.exit(passed ? 0 : 1);

function optionValue(name) {
  const index = process.argv.indexOf(name);
  if (index < 0) {
    return '';
  }
  const value = process.argv[index + 1];
  if (!value || value.startsWith('--')) {
    fail(`${name} requires a value.`);
  }
  return value;
}

function parseJson(path) {
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch (error) {
    fail(`Invalid JSON artifact ${basename(path)}: ${error.message}`);
  }
}

function parseMetadata(path) {
  const result = {};
  for (const rawLine of readFileSync(path, 'utf8').split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) {
      continue;
    }
    const separator = line.indexOf('=');
    if (separator <= 0) {
      fail(`Malformed metadata line in ${basename(path)}.`);
    }
    result[line.slice(0, separator)] = line.slice(separator + 1);
  }
  return result;
}

function parseRuntimeSeries(path) {
  const lines = readFileSync(path, 'utf8')
    .split(/\r?\n/)
    .map(line => line.trim())
    .filter(Boolean);
  const expectedHeader = 'sampled_at_utc,active_provider_attempts,queue_depth,postgres_connections,effective_global,active_worker_count,scheduler_v2_enabled_worker_count,dispatch_concurrency,reconciliation_concurrency,media_import_concurrency,maintenance_concurrency,worker_last_progress_epoch_ms';
  if (lines[0] !== expectedHeader) {
    fail(`Unexpected runtime series header in ${basename(path)}.`);
  }

  return lines.slice(1).map((line, index) => {
    const fields = line.split(',');
    if (fields.length !== 12 || !Number.isFinite(Date.parse(fields[0]))) {
      fail(`Malformed runtime series row ${index + 2}.`);
    }
    if (fields.slice(1).some(value => !/^\d+$/.test(value))) {
      fail(`Runtime series row ${index + 2} contains a non-negative integer violation.`);
    }
    const values = fields.slice(1).map(value => Number(value));
    if (values.some(value => !Number.isSafeInteger(value))) {
      fail(`Runtime series row ${index + 2} contains an unsafe integer.`);
    }
    return {
      sampledAtUtc: fields[0],
      activeProviderAttempts: values[0],
      queueDepth: values[1],
      postgresConnections: values[2],
      effectiveGlobal: values[3],
      activeWorkerCount: values[4],
      schedulerV2EnabledWorkerCount: values[5],
      dispatchConcurrency: values[6],
      reconciliationConcurrency: values[7],
      mediaImportConcurrency: values[8],
      maintenanceConcurrency: values[9],
      workerLastProgressEpochMs: values[10],
    };
  });
}

function metricValue(summary, name, valueName) {
  const value = summary?.metrics?.[name]?.values?.[valueName];
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function numberMetadata(metadata, name) {
  const raw = metadata[name] || '';
  if (!/^\d+$/.test(raw)) {
    return -1;
  }
  const value = Number(raw);
  return Number.isSafeInteger(value) ? value : -1;
}

function check(name, ok, detail) {
  checks.push({ name, ok: Boolean(ok), detail });
}

function renderMarkdown(verdict) {
  const lines = [
    '# Generation Scheduler V2 Core Load Verdict',
    '',
    `Status: **${verdict.status}**`,
    `Scope: \`${verdict.scope}\`; full acceptance: \`${verdict.fullAcceptance}\``,
    '',
    '> This verdict covers only the 50-user/200-job core load gate from this run directory. It does not prove strict video reserve, blocked-import progress, restart recovery, host resource limits, or end-to-end exactly-once behavior.',
    '',
    '## Runtime peaks',
    '',
    `- Active provider attempts: ${verdict.observed.activeProviderAttemptsPeak}`,
    `- Effective global values: ${verdict.observed.effectiveGlobalValues.join(', ') || 'none'}`,
    `- Scheduler V2 enabled worker counts: ${verdict.observed.schedulerV2EnabledWorkerCounts.join(', ') || 'none'}`,
    `- Worker progress after run start: ${verdict.observed.workerProgressObserved}`,
    `- Queue depth: ${verdict.observed.queueDepthPeak}`,
    `- PostgreSQL connections: ${verdict.observed.postgresConnectionsPeak}`,
    `- Samples: ${verdict.observed.runtimeSamples}`,
    '',
    '## Checks',
    '',
    '| Check | Result | Detail |',
    '| --- | --- | --- |',
    ...verdict.checks.map(item => `| ${item.name} | ${item.ok ? 'PASS' : 'FAIL'} | ${String(item.detail).replaceAll('|', '\\|')} |`),
    '',
  ];
  return `${lines.join('\n')}\n`;
}

function format(value) {
  return value === null ? 'missing' : String(value);
}

function maxOrZero(values) {
  return values.length > 0 ? Math.max(...values) : 0;
}

function setEquals(values, expected) {
  return values.size === 1 && values.has(expected);
}

function formatSet(values) {
  return [...values].sort((a, b) => a - b).join(',') || 'none';
}

function fail(message) {
  console.error(message);
  process.exit(2);
}

function printHelp() {
  console.log(`
Generation Scheduler V2 core load artifact verifier.

Usage:
  node scripts/load/verify-generation-scheduler-v2-acceptance.mjs --run-dir <artifact-directory>

It validates exactly 50 unique JWT subjects / 50 VUs / 200 mixed jobs, one
Scheduler V2 worker with lanes 4/4/1/1, scoped provider saturation at effective
global 38, worker progress, and PostgreSQL connection peak. It does not run k6
or contact an API/database by itself. Its verdict always remains
scope=core_load_only and fullAcceptance=false.
`);
}
