#!/usr/bin/env node

import { createServer } from 'node:http';
import { mkdtempSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, '..', '..');
const runnerPath = join(scriptDir, 'run-template-feed-staging-snapshot.mjs');

const observations = {
  sawAuthorization: false,
  sawCustomHeader: false,
};

const server = createServer((request, response) => {
  const url = new URL(request.url ?? '/', 'http://127.0.0.1');
  const query = url.searchParams.get('query') || '';

  observations.sawAuthorization ||= request.headers.authorization === 'Bearer test-token';
  observations.sawCustomHeader ||= request.headers['x-scope-orgid'] === 'staging';

  response.writeHead(200, { 'content-type': 'application/json' });
  response.end(JSON.stringify({
    status: 'success',
    data: {
      resultType: 'vector',
      result: buildPrometheusResult(query, url.searchParams.get('time')),
    },
  }));
});

server.listen(0, '127.0.0.1', async () => {
  try {
    const port = server.address().port;
    const prometheusBaseUrl = `http://127.0.0.1:${port}`;

    await assertLatencyAcceptanceRun(prometheusBaseUrl);
    await assertLatencyRegressionFailsAcceptance(prometheusBaseUrl);
    await assertLatencyDiscoveryRunFailsAcceptance(prometheusBaseUrl);
    await assertSseAcceptanceRun(prometheusBaseUrl);
    await withFeedApiServer(async feedApiBaseUrl => {
      await assertSseAcceptanceRunWithFeedLoadProbe(prometheusBaseUrl, feedApiBaseUrl);
    });
    await assertSseDiscoveryRunFailsAcceptance(prometheusBaseUrl);

    console.log('template feed staging snapshot self-test passed');
  } catch (error) {
    console.error(error.stack || String(error));
    process.exitCode = 1;
  } finally {
    server.close();
  }
});

function buildPrometheusResult(query, time) {
  const isAfterPoint = Number(time) > Date.parse('2026-07-02T10:30:00Z') / 1000;
  const simulateRegression = query.includes('simulate_regression');

  if (query.includes('request_duration_seconds_count')) {
    return vector({ route: '/api/templates/feed', method: 'GET' }, '42');
  }

  if (query.includes('histogram_quantile(0.95')) {
    return vector(
      { route: '/api/templates/feed', method: 'GET' },
      simulateRegression && isAfterPoint ? '0.31' : '0.21');
  }

  if (query.includes('histogram_quantile(0.99')) {
    return vector(
      { route: '/api/templates/feed', method: 'GET' },
      simulateRegression && isAfterPoint ? '0.44' : '0.34');
  }

  if (query.includes('increase(') && query.includes('sse_full_invalidation_count')) {
    return vector({}, '0');
  }

  if (query.includes('sse_full_invalidation_count')) {
    return vector({}, '7');
  }

  return [];
}

function vector(metric, value) {
  return [{ metric, value: [Date.now() / 1000, value] }];
}

async function assertLatencyAcceptanceRun(prometheusBaseUrl) {
  const result = await runSnapshot('latency-acceptance', ['--mode=latency'], {
    STAGING_PROMETHEUS_BASE_URL: prometheusBaseUrl,
    STAGING_PROMETHEUS_BEARER_TOKEN: 'test-token',
    TEMPLATE_FEED_PROMETHEUS_HEADERS_JSON: JSON.stringify({ 'X-Scope-OrgID': 'staging' }),
    TEMPLATE_FEED_BEFORE_AT_UTC: '2026-07-02T10:00:00Z',
    TEMPLATE_FEED_AFTER_AT_UTC: '2026-07-02T11:00:00Z',
  });

  assertExitCode(result, 0);
  assert(observations.sawAuthorization, 'latency acceptance run did not send bearer auth');
  assert(observations.sawCustomHeader, 'latency acceptance run did not send custom Prometheus header');
  assertCheck(result.evidence, 'latency.before_after_times_configured', true);
  assertCheck(result.evidence, 'latency.before_after_points_present', true);
  assertCheck(result.evidence, 'latency.no_material_regression', true);
}

async function assertLatencyRegressionFailsAcceptance(prometheusBaseUrl) {
  const result = await runSnapshot('latency-regression', ['--mode=latency'], {
    STAGING_PROMETHEUS_BASE_URL: prometheusBaseUrl,
    TEMPLATE_FEED_ROUTE_REGEX: 'simulate_regression',
    TEMPLATE_FEED_BEFORE_AT_UTC: '2026-07-02T10:00:00Z',
    TEMPLATE_FEED_AFTER_AT_UTC: '2026-07-02T11:00:00Z',
  });

  assertNonZeroExitCode(result);
  assertCheck(result.evidence, 'latency.before_after_times_configured', true);
  assertCheck(result.evidence, 'latency.before_after_points_present', true);
  assertCheck(result.evidence, 'latency.no_material_regression', false);
}

async function assertLatencyDiscoveryRunFailsAcceptance(prometheusBaseUrl) {
  const result = await runSnapshot('latency-missing-times', ['--mode=latency'], {
    STAGING_PROMETHEUS_BASE_URL: prometheusBaseUrl,
  });

  assertNonZeroExitCode(result);
  assertCheck(result.evidence, 'latency.before_after_times_configured', false);
}

async function assertSseAcceptanceRun(prometheusBaseUrl) {
  const result = await runSnapshot('sse-acceptance', ['--mode=sse'], {
    STAGING_PROMETHEUS_BASE_URL: prometheusBaseUrl,
    TEMPLATE_FEED_SNAPSHOT_WAIT_SECONDS: '1',
  });

  assertExitCode(result, 0);
  assertCheck(result.evidence, 'sse.admin_action_window_configured', true);
  assertCheck(result.evidence, 'sse_full_invalidation_metric_present', true);
  assertCheck(result.evidence, 'sse_full_invalidation_delta_zero_during_admin_window', true);
}

async function assertSseAcceptanceRunWithFeedLoadProbe(prometheusBaseUrl, feedApiBaseUrl) {
  const loadProbeArtifactDir = mkdtempSync(join(tmpdir(), 'template-feed-load-probe-integrated-'));
  const result = await runSnapshot('sse-feed-load', ['--mode=sse'], {
    STAGING_PROMETHEUS_BASE_URL: prometheusBaseUrl,
    TEMPLATE_FEED_SNAPSHOT_WAIT_SECONDS: '1',
    TEMPLATE_FEED_LOAD_PROBE_API_BASE: feedApiBaseUrl,
    TEMPLATE_FEED_LOAD_PROBE_ARTIFACT_DIR: loadProbeArtifactDir,
    TEMPLATE_FEED_LOAD_PROBE_RUN_ID: 'self-test-sse-feed-load',
    TEMPLATE_FEED_LOAD_PROBE_DURATION_SECONDS: '1',
    TEMPLATE_FEED_LOAD_PROBE_CONCURRENCY: '1',
    TEMPLATE_FEED_LOAD_PROBE_INTERVAL_MS: '25',
  });

  assertExitCode(result, 0);
  assertCheck(result.evidence, 'sse.admin_action_window_configured', true);
  assertCheck(result.evidence, 'sse_full_invalidation_delta_zero_during_admin_window', true);
  assertCheck(result.evidence, 'sse.feed_load_probe_completed', true);
  assert(result.evidence.sseFullInvalidations.feedLoadProbe?.exitCode === 0, 'missing successful feed-load probe result');
  const loadProbeEvidence = JSON.parse(readFileSync(join(loadProbeArtifactDir, 'evidence.json'), 'utf8'));
  assert(loadProbeEvidence.requests.ok > 0, 'integrated load probe did not record successful feed requests');
}

async function assertSseDiscoveryRunFailsAcceptance(prometheusBaseUrl) {
  const result = await runSnapshot('sse-zero-wait', ['--mode=sse'], {
    STAGING_PROMETHEUS_BASE_URL: prometheusBaseUrl,
  });

  assertNonZeroExitCode(result);
  assertCheck(result.evidence, 'sse.admin_action_window_configured', false);
}

function withFeedApiServer(callback) {
  const feedServer = createServer((_request, response) => {
    response.writeHead(200, { 'content-type': 'application/json' });
    response.end(JSON.stringify({
      items: [{ id: 'template-1' }, { id: 'template-2' }],
      nextCursor: 'cursor-2',
      hasMore: true,
    }));
  });

  return new Promise((resolvePromise, reject) => {
    feedServer.on('error', reject);
    feedServer.listen(0, '127.0.0.1', async () => {
      try {
        const port = feedServer.address().port;
        await callback(`http://127.0.0.1:${port}`);
        resolvePromise();
      } catch (error) {
        reject(error);
      } finally {
        feedServer.close();
      }
    });
  });
}

async function runSnapshot(label, args, envOverrides) {
  const artifactDir = mkdtempSync(join(tmpdir(), `template-feed-snapshot-${label}-`));
  const env = {
    ...process.env,
    ...envOverrides,
    TEMPLATE_FEED_SNAPSHOT_ARTIFACT_DIR: artifactDir,
    TEMPLATE_FEED_SNAPSHOT_RUN_ID: `self-test-${label}`,
  };

  const result = await spawnNode([runnerPath, ...args], env);
  const evidence = JSON.parse(readFileSync(join(artifactDir, 'evidence.json'), 'utf8'));
  return { ...result, artifactDir, evidence };
}

function spawnNode(args, env) {
  return new Promise((resolvePromise) => {
    const child = spawn(process.execPath, args, {
      cwd: repoRoot,
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

function assertExitCode(result, expected) {
  assert(
    result.code === expected,
    `expected exit ${expected}, got ${result.code}\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
}

function assertNonZeroExitCode(result) {
  assert(
    result.code !== 0,
    `expected non-zero exit, got 0\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
}

function assertCheck(evidence, name, expected) {
  const check = evidence.checks.find(item => item.name === name);
  assert(check, `missing check ${name}`);
  assert(check.ok === expected, `expected ${name}=${expected}, got ${check.ok}: ${check.detail}`);
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}
