#!/usr/bin/env node

import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

if (process.argv.includes('--help') || process.argv.includes('-h')) {
  printHelp();
  process.exit(0);
}

const envFilePath = process.env.TEMPLATE_FEED_SNAPSHOT_ENV_FILE || process.env.STAGING_ENV_FILE || '.env.staging.local';
loadLocalEnvFile(envFilePath);

const mode = resolveMode();
const missing = findMissingRequiredInputs();
if (missing.length > 0) {
  console.error(`Missing required staging snapshot input names: ${missing.join(', ')}`);
  console.error('Load them from .env.staging.local, TEMPLATE_FEED_SNAPSHOT_ENV_FILE, CI secrets, 1Password, or Vault. Values were not printed.');
  process.exit(1);
}

const startedAt = new Date();
const runId = process.env.TEMPLATE_FEED_SNAPSHOT_RUN_ID || `template-feed-staging-snapshot-${formatTimestamp(startedAt)}`;
const artifactDir = process.env.TEMPLATE_FEED_SNAPSHOT_ARTIFACT_DIR || join('artifacts', 'template-feed-staging-snapshots', runId);
mkdirSync(artifactDir, { recursive: true });

const prometheusBaseUrl = requiredEnv('STAGING_PROMETHEUS_BASE_URL').replace(/\/$/, '');
const prometheusBearerToken = process.env.STAGING_PROMETHEUS_BEARER_TOKEN || process.env.TEMPLATE_FEED_PROMETHEUS_BEARER_TOKEN || '';
const prometheusExtraHeaders = parseJsonObjectEnv('TEMPLATE_FEED_PROMETHEUS_HEADERS_JSON');
const routeRegex = process.env.TEMPLATE_FEED_ROUTE_REGEX || '.*(/api/templates/feed|templates.*feed|ListFeedAsync).*';
const methodRegex = process.env.TEMPLATE_FEED_METHOD_REGEX || 'GET';
const latencyRateWindow = process.env.TEMPLATE_FEED_LATENCY_RATE_WINDOW || '5m';
const sseWindow = process.env.TEMPLATE_FEED_SSE_WINDOW || '15m';
const waitSeconds = intEnv('TEMPLATE_FEED_SNAPSHOT_WAIT_SECONDS', 0);
const beforeAt = process.env.TEMPLATE_FEED_BEFORE_AT_UTC || '';
const afterAt = process.env.TEMPLATE_FEED_AFTER_AT_UTC || '';
const maxP95RegressionSeconds = nonNegativeNumberEnv('TEMPLATE_FEED_MAX_P95_REGRESSION_SECONDS', 0);
const maxP99RegressionSeconds = nonNegativeNumberEnv('TEMPLATE_FEED_MAX_P99_REGRESSION_SECONDS', 0);
const allowCurrentLatencyOnly = boolEnv('TEMPLATE_FEED_ALLOW_CURRENT_LATENCY_ONLY', false);
const allowZeroWaitSseOnly = boolEnv('TEMPLATE_FEED_ALLOW_ZERO_WAIT_SSE', false);
const actionLabels = parseList(process.env.TEMPLATE_FEED_ADMIN_ACTION_LABELS || 'text_update,media_update,category_rename');

const checks = [];
const evidence = {
  runId,
  mode,
  startedAtUtc: startedAt.toISOString(),
  envFileLoaded: existsSync(envFilePath),
  prometheusBaseUrl: anonymizeUrl(prometheusBaseUrl),
  prometheusAuthConfigured: Boolean(prometheusBearerToken) || Object.keys(prometheusExtraHeaders).length > 0,
  prometheusExtraHeaderNames: Object.keys(prometheusExtraHeaders),
  routeRegex,
  methodRegex,
  latencyRateWindow,
  sseWindow,
  waitSeconds,
  actionLabels,
  checks,
  latency: {
    regressionBudget: {
      maxP95RegressionSeconds,
      maxP99RegressionSeconds
    },
    routeCandidates: []
  },
  sseFullInvalidations: {}
};

main().catch(error => {
  checks.push({
    name: 'runner.completed_without_unhandled_error',
    ok: false,
    detail: error.stack || String(error)
  });
  finish(1);
});

async function main() {
  console.log(`[${runId}] template feed staging snapshot started`);

  if (mode === 'latency' || mode === 'all') {
    await collectLatencySnapshots();
  }

  if (mode === 'sse' || mode === 'all') {
    await collectSseSnapshots();
  }

  finish(hasFailedChecks() ? 1 : 0);
}

async function collectLatencySnapshots() {
  addCheck(
    'latency.before_after_times_configured',
    allowCurrentLatencyOnly || Boolean(beforeAt && afterAt),
    allowCurrentLatencyOnly
      ? 'current-only latency sampling explicitly allowed for route discovery'
      : `beforeAt=${beforeAt ? 'present' : 'missing'}, afterAt=${afterAt ? 'present' : 'missing'}`);

  evidence.latency.routeCandidates = await queryFeedRouteCandidates();
  const beforeTime = beforeAt ? parsePrometheusTime(beforeAt) : null;
  const afterTime = afterAt ? parsePrometheusTime(afterAt) : null;
  const before = beforeTime
    ? await queryLatencyPoint('before', beforeTime)
    : null;
  const after = afterTime
    ? await queryLatencyPoint('after', afterTime)
    : await queryLatencyPoint('current', null);

  evidence.latency.before = before;
  evidence.latency.after = after;

  addCheck(
    'latency.feed_route_sample_present',
    Boolean(after?.p95?.length || before?.p95?.length),
    `beforeRoutes=${before?.p95?.length ?? 0}, afterRoutes=${after?.p95?.length ?? 0}, candidates=${formatRouteCandidates(evidence.latency.routeCandidates)}`);

  if (before && after) {
    const beforeP95 = maxMetricValue(before.p95);
    const afterP95 = maxMetricValue(after.p95);
    const beforeP99 = maxMetricValue(before.p99);
    const afterP99 = maxMetricValue(after.p99);
    evidence.latency.comparison = {
      beforeP95,
      afterP95,
      beforeP99,
      afterP99,
      p95DeltaSeconds: numberOrNull(afterP95 - beforeP95),
      p99DeltaSeconds: numberOrNull(afterP99 - beforeP99)
    };

    const p95Ok = Number.isFinite(beforeP95)
      && Number.isFinite(afterP95)
      && afterP95 <= beforeP95 + maxP95RegressionSeconds;
    const p99Ok = Number.isFinite(beforeP99)
      && Number.isFinite(afterP99)
      && afterP99 <= beforeP99 + maxP99RegressionSeconds;
    addCheck(
      'latency.before_after_points_present',
      Number.isFinite(beforeP95) && Number.isFinite(afterP95) && Number.isFinite(beforeP99) && Number.isFinite(afterP99),
      JSON.stringify(evidence.latency.comparison));
    addCheck(
      'latency.no_material_regression',
      p95Ok && p99Ok,
      JSON.stringify({
        ...evidence.latency.comparison,
        maxP95RegressionSeconds,
        maxP99RegressionSeconds
      }));
  }
}

async function collectSseSnapshots() {
  addCheck(
    'sse.admin_action_window_configured',
    allowZeroWaitSseOnly || waitSeconds > 0,
    allowZeroWaitSseOnly
      ? 'zero-wait SSE sampling explicitly allowed for metric discovery'
      : `waitSeconds=${waitSeconds}`);

  const before = await querySseSnapshot('before');
  evidence.sseFullInvalidations.before = before;

  if (waitSeconds > 0) {
    console.log('');
    console.log(`Perform the staging admin actions now: ${actionLabels.join(', ') || 'text update, media update, category rename, status update if available'}`);
    console.log(`Waiting ${waitSeconds}s before the after snapshot...`);
    await delay(waitSeconds * 1000);
  }

  const after = await querySseSnapshot('after');
  evidence.sseFullInvalidations.after = after;
  evidence.sseFullInvalidations.deltaTotal = numberOrNull(after.total - before.total);
  evidence.sseFullInvalidations.windowIncreaseAfter = after.windowIncrease;

  addCheck(
    'sse_full_invalidation_metric_present',
    Number.isFinite(after.total) || Number.isFinite(after.windowIncrease),
    `total=${after.total}, increase_${sseWindow}=${after.windowIncrease}`);

  if (waitSeconds > 0) {
    addCheck(
      'sse_full_invalidation_delta_zero_during_admin_window',
      after.total - before.total === 0,
      `before=${before.total}, after=${after.total}, delta=${after.total - before.total}`);
  }
}

async function queryLatencyPoint(label, time) {
  const p95Query = latencyPromql('0.95');
  const p99Query = latencyPromql('0.99');
  const [p95, p99] = await Promise.all([
    queryPrometheusVector(p95Query, time),
    queryPrometheusVector(p99Query, time)
  ]);
  return {
    label,
    timeUtc: time ? new Date(time * 1000).toISOString() : new Date().toISOString(),
    p95,
    p99
  };
}

async function queryFeedRouteCandidates() {
  try {
    const query = `sort_desc(sum by (route, method) (rate(request_duration_seconds_count{method=~"${escapePromRegex(methodRegex)}"}[${latencyRateWindow}])))`;
    return (await queryPrometheusVector(query, null)).slice(0, 20);
  } catch (error) {
    checks.push({
      name: 'latency.route_candidates_query',
      ok: false,
      detail: error.message || String(error)
    });
    return [];
  }
}

async function querySseSnapshot(label) {
  const [total, windowIncrease] = await Promise.all([
    queryPrometheusScalar('sum(sse_full_invalidation_count)', null),
    queryPrometheusScalar(`sum(increase(sse_full_invalidation_count[${sseWindow}]))`, null)
  ]);
  return {
    label,
    timeUtc: new Date().toISOString(),
    total,
    windowIncrease
  };
}

function latencyPromql(quantile) {
  return `histogram_quantile(${quantile}, sum by (le, route, method) (rate(request_duration_seconds_bucket{method=~"${escapePromRegex(methodRegex)}",route=~"${escapePromRegex(routeRegex)}"}[${latencyRateWindow}])))`;
}

async function queryPrometheusVector(query, time) {
  const json = await queryPrometheus(query, time);
  const result = json?.data?.result;
  if (!Array.isArray(result)) {
    throw new Error(`Prometheus did not return a vector for query: ${query}`);
  }

  return result.map(item => ({
    metric: sanitizeMetricLabels(item.metric),
    value: Number(item.value?.[1] ?? Number.NaN)
  }));
}

async function queryPrometheusScalar(query, time) {
  const vector = await queryPrometheusVector(query, time);
  if (vector.length === 0) {
    return Number.NaN;
  }

  return vector.reduce((sum, item) => sum + (Number.isFinite(item.value) ? item.value : 0), 0);
}

async function queryPrometheus(query, time) {
  const url = new URL(`${prometheusBaseUrl}/api/v1/query`);
  url.searchParams.set('query', query);
  if (time) {
    url.searchParams.set('time', String(time));
  }

  const response = await fetchWithTimeout(url, 15000);
  const text = await response.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    throw new Error(`Prometheus returned non-JSON response. status=${response.status}`);
  }

  if (!response.ok || json.status !== 'success') {
    throw new Error(`Prometheus query failed. status=${response.status} body=${JSON.stringify(json).slice(0, 1000)}`);
  }

  return json;
}

async function fetchWithTimeout(url, timeoutMs) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { signal: controller.signal, headers: buildPrometheusHeaders() });
  } finally {
    clearTimeout(timeout);
  }
}

function buildPrometheusHeaders() {
  const headers = { ...prometheusExtraHeaders };
  if (prometheusBearerToken) {
    headers.Authorization = `Bearer ${prometheusBearerToken}`;
  }

  return headers;
}

function sanitizeMetricLabels(metric) {
  const sanitized = {};
  for (const [key, value] of Object.entries(metric || {})) {
    sanitized[key] = String(value).slice(0, 200);
  }
  return sanitized;
}

function maxMetricValue(items) {
  const values = (items || []).map(item => item.value).filter(Number.isFinite);
  return values.length === 0 ? Number.NaN : Math.max(...values);
}

function formatRouteCandidates(items) {
  if (!items || items.length === 0) {
    return 'none';
  }

  return items
    .slice(0, 5)
    .map(item => `${item.metric.method || '?'} ${item.metric.route || '?'}=${formatNumber(item.value)}`)
    .join('; ');
}

function addCheck(name, ok, detail) {
  const check = { name, ok: Boolean(ok), detail };
  checks.push(check);
  console.log(`[${check.ok ? 'ok' : 'fail'}] ${name}: ${detail}`);
}

function hasFailedChecks() {
  return checks.some(check => !check.ok);
}

function finish(exitCode) {
  evidence.finishedAtUtc = new Date().toISOString();
  evidence.failedChecks = checks.filter(check => !check.ok);
  writeFileSync(join(artifactDir, 'evidence.json'), JSON.stringify(evidence, jsonNumberReplacer, 2));
  writeFileSync(join(artifactDir, 'summary.md'), renderSummary());
  console.log(`[${runId}] wrote ${join(artifactDir, 'evidence.json')}`);
  console.log(`[${runId}] wrote ${join(artifactDir, 'summary.md')}`);
  process.exitCode = exitCode;
}

function renderSummary() {
  const rows = [
    '# Template Feed Staging Snapshot',
    '',
    `Run ID: ${runId}`,
    `Mode: ${mode}`,
    `Started: ${evidence.startedAtUtc}`,
    `Finished: ${evidence.finishedAtUtc}`,
    '',
    '## Checks',
    '',
    '| Check | Result | Detail |',
    '| --- | --- | --- |',
    ...checks.map(check => `| ${check.name} | ${check.ok ? 'PASS' : 'FAIL'} | ${String(check.detail).replaceAll('|', '\\|')} |`),
    '',
    '## Feed Latency',
    '',
    `Route regex: \`${routeRegex}\``,
    `Rate window: \`${latencyRateWindow}\``,
    `Before p95 max: ${formatNumber(evidence.latency.comparison?.beforeP95)}`,
    `After/current p95 max: ${formatNumber(evidence.latency.comparison?.afterP95 ?? maxMetricValue(evidence.latency.after?.p95))}`,
    `Before p99 max: ${formatNumber(evidence.latency.comparison?.beforeP99)}`,
    `After/current p99 max: ${formatNumber(evidence.latency.comparison?.afterP99 ?? maxMetricValue(evidence.latency.after?.p99))}`,
    `p95 regression budget seconds: ${formatNumber(maxP95RegressionSeconds)}`,
    `p99 regression budget seconds: ${formatNumber(maxP99RegressionSeconds)}`,
    '',
    '## SSE Full Invalidation',
    '',
    `Window: \`${sseWindow}\``,
    `Before total: ${formatNumber(evidence.sseFullInvalidations.before?.total)}`,
    `After total: ${formatNumber(evidence.sseFullInvalidations.after?.total)}`,
    `Delta total: ${formatNumber(evidence.sseFullInvalidations.deltaTotal)}`,
    `After window increase: ${formatNumber(evidence.sseFullInvalidations.windowIncreaseAfter)}`,
    ''
  ];

  return rows.join('\n');
}

function resolveMode() {
  const modeArg = process.argv.find(argument => argument.startsWith('--mode='));
  const raw = modeArg ? modeArg.split('=', 2)[1] : process.env.TEMPLATE_FEED_SNAPSHOT_MODE || 'all';
  if (['all', 'latency', 'sse'].includes(raw)) {
    return raw;
  }

  console.error(`Unsupported mode: ${raw}. Use all, latency, or sse.`);
  process.exit(1);
}

function findMissingRequiredInputs() {
  return ['STAGING_PROMETHEUS_BASE_URL'].filter(name => !process.env[name]);
}

function requiredEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} is required.`);
  }
  return value;
}

function intEnv(name, fallback) {
  const raw = process.env[name];
  if (!raw) {
    return fallback;
  }
  const parsed = Number.parseInt(raw, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function nonNegativeNumberEnv(name, fallback) {
  const raw = process.env[name];
  if (!raw) {
    return fallback;
  }

  const parsed = Number(raw);
  if (!Number.isFinite(parsed) || parsed < 0) {
    throw new Error(`${name} must be a non-negative number.`);
  }

  return parsed;
}

function boolEnv(name, fallback) {
  const raw = process.env[name];
  if (!raw) {
    return fallback;
  }

  return ['1', 'true', 'yes', 'on'].includes(raw.trim().toLowerCase());
}

function parseJsonObjectEnv(name) {
  const raw = process.env[name];
  if (!raw) {
    return {};
  }

  try {
    const parsed = JSON.parse(raw);
    if (!parsed || Array.isArray(parsed) || typeof parsed !== 'object') {
      throw new Error('value must be a JSON object');
    }

    return Object.fromEntries(
      Object.entries(parsed)
        .filter(([, value]) => value !== null && value !== undefined)
        .map(([key, value]) => [String(key), String(value)])
    );
  } catch (error) {
    throw new Error(`${name} must be a JSON object with string-compatible values: ${error.message || String(error)}`);
  }
}

function parseList(raw) {
  if (!raw) {
    return [];
  }

  return raw.split(',').map(value => value.trim()).filter(Boolean);
}

function loadLocalEnvFile(envFile) {
  if (!existsSync(envFile)) {
    return;
  }

  const content = readFileSync(envFile, 'utf8');
  for (const line of content.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) {
      continue;
    }

    const match = trimmed.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
    if (!match || process.env[match[1]]) {
      continue;
    }

    process.env[match[1]] = stripEnvQuotes(match[2].trim());
  }
}

function stripEnvQuotes(value) {
  if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
    return value.slice(1, -1);
  }

  return value;
}

function parsePrometheusTime(value) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new Error(`Invalid UTC time: ${value}`);
  }

  return date.getTime() / 1000;
}

function escapePromRegex(value) {
  return String(value).replaceAll('\\', '\\\\').replaceAll('"', '\\"');
}

function anonymizeUrl(raw) {
  try {
    const url = new URL(raw);
    return `${url.protocol}//${url.hostname}${url.port ? `:${url.port}` : ''}`;
  } catch {
    return 'invalid';
  }
}

function formatTimestamp(date) {
  return date.toISOString().replaceAll(':', '').replace(/\.\d{3}Z$/, 'Z');
}

function formatNumber(value) {
  return Number.isFinite(value) ? String(Math.round(value * 1000) / 1000) : 'n/a';
}

function numberOrNull(value) {
  return Number.isFinite(value) ? value : null;
}

function jsonNumberReplacer(_key, value) {
  return typeof value === 'number' && !Number.isFinite(value) ? null : value;
}

function delay(milliseconds) {
  return new Promise(resolve => setTimeout(resolve, milliseconds));
}

function printHelp() {
  console.log(`
Template feed staging snapshot runner.

Required environment:
  STAGING_PROMETHEUS_BASE_URL             Prometheus base URL for staging metrics.
  STAGING_PROMETHEUS_BEARER_TOKEN         Optional bearer token for Prometheus.

Optional environment:
  TEMPLATE_FEED_SNAPSHOT_ENV_FILE         Env file path, defaults to STAGING_ENV_FILE or .env.staging.local.
  TEMPLATE_FEED_SNAPSHOT_MODE             all, latency, or sse. Default: all.
  TEMPLATE_FEED_SNAPSHOT_RUN_ID           Artifact run id.
  TEMPLATE_FEED_SNAPSHOT_ARTIFACT_DIR     Output dir, default artifacts/template-feed-staging-snapshots/<run>.
  TEMPLATE_FEED_ROUTE_REGEX               Prometheus route label regex for /api/templates/feed.
  TEMPLATE_FEED_METHOD_REGEX              Prometheus method label regex. Default: GET.
  TEMPLATE_FEED_LATENCY_RATE_WINDOW       Prometheus rate window. Default: 5m.
  TEMPLATE_FEED_BEFORE_AT_UTC             Optional before instant for latency comparison.
  TEMPLATE_FEED_AFTER_AT_UTC              Optional after instant for latency comparison.
  TEMPLATE_FEED_MAX_P95_REGRESSION_SECONDS Optional allowed p95 regression budget. Default: 0.
  TEMPLATE_FEED_MAX_P99_REGRESSION_SECONDS Optional allowed p99 regression budget. Default: 0.
  TEMPLATE_FEED_ALLOW_CURRENT_LATENCY_ONLY Set true only for route discovery without before/after baseline.
  TEMPLATE_FEED_PROMETHEUS_BEARER_TOKEN   Optional bearer token override for Prometheus.
  TEMPLATE_FEED_PROMETHEUS_HEADERS_JSON   Optional JSON object with extra Prometheus headers.
  TEMPLATE_FEED_SSE_WINDOW                Prometheus increase window for sse_full_invalidation_count. Default: 15m.
  TEMPLATE_FEED_SNAPSHOT_WAIT_SECONDS     If >0, capture SSE before, wait while operator performs admin actions, capture after.
  TEMPLATE_FEED_ALLOW_ZERO_WAIT_SSE       Set true only for SSE metric discovery without admin action window.
  TEMPLATE_FEED_ADMIN_ACTION_LABELS       Comma-separated labels for the actions performed during the wait window.

Examples:
  node scripts/qa/run-template-feed-staging-snapshot.mjs --mode=latency
  TEMPLATE_FEED_BEFORE_AT_UTC=2026-07-02T10:00:00Z TEMPLATE_FEED_AFTER_AT_UTC=2026-07-02T11:00:00Z node scripts/qa/run-template-feed-staging-snapshot.mjs --mode=latency
  TEMPLATE_FEED_SNAPSHOT_WAIT_SECONDS=180 TEMPLATE_FEED_ADMIN_ACTION_LABELS=text_update,media_update,category_rename node scripts/qa/run-template-feed-staging-snapshot.mjs --mode=sse
`);
}
