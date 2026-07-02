#!/usr/bin/env node

import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

if (process.argv.includes('--help') || process.argv.includes('-h')) {
  printHelp();
  process.exit(0);
}

const args = parseArgs(process.argv.slice(2));
const startedAt = new Date();
const runId = args['run-id'] || `template-feed-load-probe-${formatTimestamp(startedAt)}`;
const artifactDir = args['artifact-dir'] || join('artifacts', 'template-feed-load-probes', runId);
const apiBase = requiredArg(args, 'api-base').replace(/\/$/, '');
const path = args.path || '/api/templates/feed?take=20';
const durationSeconds = positiveIntArg(args, 'duration-seconds', 180);
const concurrency = positiveIntArg(args, 'concurrency', 4);
const intervalMs = nonNegativeIntArg(args, 'interval-ms', 250);
const timeoutMs = positiveIntArg(args, 'timeout-ms', 10000);
const maxErrors = nonNegativeIntArg(args, 'max-errors', 0);
const bearerToken = args['bearer-token'] || process.env.TEMPLATE_FEED_LOAD_BEARER_TOKEN || '';
const extraHeaders = parseJsonObject(args['headers-json'] || process.env.TEMPLATE_FEED_LOAD_HEADERS_JSON || '{}', 'headers-json');
const url = new URL(path, `${apiBase}/`).toString();
const samples = [];

mkdirSync(artifactDir, { recursive: true });

console.log(`[${runId}] probing ${url}`);
console.log(`[${runId}] duration=${durationSeconds}s concurrency=${concurrency} interval=${intervalMs}ms timeout=${timeoutMs}ms maxErrors=${maxErrors}`);
console.log(`[${runId}] perform Admin category rename while this probe is running`);

const deadline = Date.now() + durationSeconds * 1000;

await Promise.all(
  Array.from({ length: concurrency }, (_, index) => worker(index + 1))
);

const finishedAt = new Date();
const summary = buildSummary(startedAt, finishedAt);
writeFileSync(join(artifactDir, 'evidence.json'), `${JSON.stringify(summary, null, 2)}\n`);
writeFileSync(join(artifactDir, 'summary.md'), renderSummary(summary));

console.log(`[${runId}] wrote ${join(artifactDir, 'evidence.json')}`);
console.log(`[${runId}] wrote ${join(artifactDir, 'summary.md')}`);
console.log(`[${runId}] requests=${summary.requests.total} ok=${summary.requests.ok} failed=${summary.requests.failed} p95=${summary.latencyMs.p95}`);

if (summary.requests.failed > maxErrors) {
  console.error(`[${runId}] failed request count ${summary.requests.failed} exceeded max-errors=${maxErrors}`);
  process.exitCode = 1;
}

async function worker(workerId) {
  while (Date.now() < deadline) {
    const sample = await runRequest(workerId);
    samples.push(sample);

    if (intervalMs > 0 && Date.now() < deadline) {
      await delay(intervalMs);
    }
  }
}

async function runRequest(workerId) {
  const requestStartedAt = new Date();
  const timerStartedAt = performance.now();
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, {
      method: 'GET',
      headers: buildHeaders(),
      signal: controller.signal,
    });
    const bodyText = await response.text();
    const parsedBody = parseJson(bodyText);
    const durationMs = Math.round(performance.now() - timerStartedAt);
    return {
      workerId,
      startedAtUtc: requestStartedAt.toISOString(),
      durationMs,
      status: response.status,
      ok: response.ok,
      itemCount: extractItemCount(parsedBody),
      nextCursorPresent: Boolean(parsedBody?.nextCursor),
      error: response.ok ? '' : truncate(bodyText, 300),
    };
  } catch (error) {
    const durationMs = Math.round(performance.now() - timerStartedAt);
    return {
      workerId,
      startedAtUtc: requestStartedAt.toISOString(),
      durationMs,
      status: 0,
      ok: false,
      itemCount: null,
      nextCursorPresent: false,
      error: error?.name === 'AbortError' ? `timeout after ${timeoutMs}ms` : truncate(error?.message || String(error), 300),
    };
  } finally {
    clearTimeout(timeout);
  }
}

function buildHeaders() {
  const headers = {
    accept: 'application/json',
    ...extraHeaders,
  };
  if (bearerToken) {
    headers.authorization = `Bearer ${bearerToken}`;
  }
  return headers;
}

function buildSummary(startedAtValue, finishedAtValue) {
  const sortedDurations = samples.map(sample => sample.durationMs).filter(Number.isFinite).sort((left, right) => left - right);
  const failed = samples.filter(sample => !sample.ok);
  const statuses = {};
  for (const sample of samples) {
    const key = String(sample.status);
    statuses[key] = (statuses[key] || 0) + 1;
  }

  return {
    runId,
    apiBase: anonymizeUrl(apiBase),
    path,
    url: anonymizeUrl(url),
    startedAtUtc: startedAtValue.toISOString(),
    finishedAtUtc: finishedAtValue.toISOString(),
    durationSeconds,
    concurrency,
    intervalMs,
    timeoutMs,
    maxErrors,
    bearerAuthConfigured: Boolean(bearerToken),
    extraHeaderNames: Object.keys(extraHeaders),
    requests: {
      total: samples.length,
      ok: samples.length - failed.length,
      failed: failed.length,
      statuses,
    },
    latencyMs: {
      min: percentile(sortedDurations, 0),
      p50: percentile(sortedDurations, 0.5),
      p95: percentile(sortedDurations, 0.95),
      p99: percentile(sortedDurations, 0.99),
      max: percentile(sortedDurations, 1),
    },
    itemCounts: {
      min: minNumber(samples.map(sample => sample.itemCount)),
      max: maxNumber(samples.map(sample => sample.itemCount)),
    },
    failedSamples: failed.slice(0, 20),
    samples,
  };
}

function renderSummary(summary) {
  return [
    '# Template Feed Load Probe',
    '',
    `Run ID: ${summary.runId}`,
    `Started: ${summary.startedAtUtc}`,
    `Finished: ${summary.finishedAtUtc}`,
    `API base: ${summary.apiBase}`,
    `Path: \`${summary.path}\``,
    `Duration seconds: ${summary.durationSeconds}`,
    `Concurrency: ${summary.concurrency}`,
    '',
    '## Result',
    '',
    `Total requests: ${summary.requests.total}`,
    `Successful requests: ${summary.requests.ok}`,
    `Failed requests: ${summary.requests.failed}`,
    `Status counts: ${JSON.stringify(summary.requests.statuses)}`,
    `Latency p95 ms: ${summary.latencyMs.p95}`,
    `Latency p99 ms: ${summary.latencyMs.p99}`,
    `Item count range: ${summary.itemCounts.min}..${summary.itemCounts.max}`,
    '',
    '## Admin QA Usage',
    '',
    '- Use this artifact as evidence for `Category rename under feed load` only when failed requests are within `maxErrors` and the matching Admin action evidence is attached.',
    '- This probe does not replace the required SSE snapshot or Admin UI screenshots/logs.',
    ''
  ].join('\n');
}

function parseArgs(rawArgs) {
  const parsed = {};
  for (const arg of rawArgs) {
    const match = arg.match(/^--([^=]+)=(.*)$/);
    if (!match) {
      fail(`Unsupported argument format: ${arg}. Use --name=value.`);
    }
    parsed[match[1]] = match[2];
  }
  return parsed;
}

function requiredArg(parsedArgs, name) {
  const value = parsedArgs[name];
  if (!value) {
    fail(`Missing required argument: --${name}`);
  }
  return value;
}

function positiveIntArg(parsedArgs, name, fallback) {
  const value = parsedArgs[name] ?? String(fallback);
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    fail(`--${name} must be a positive integer.`);
  }
  return parsed;
}

function nonNegativeIntArg(parsedArgs, name, fallback) {
  const value = parsedArgs[name] ?? String(fallback);
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed) || parsed < 0) {
    fail(`--${name} must be a non-negative integer.`);
  }
  return parsed;
}

function parseJsonObject(raw, label) {
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
    fail(`--${label} must be a JSON object with string-compatible values: ${error.message || String(error)}`);
  }
}

function parseJson(text) {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function extractItemCount(body) {
  if (Array.isArray(body?.items)) {
    return body.items.length;
  }
  if (Array.isArray(body)) {
    return body.length;
  }
  return null;
}

function percentile(sortedValues, quantile) {
  if (sortedValues.length === 0) {
    return null;
  }
  const index = Math.min(sortedValues.length - 1, Math.max(0, Math.ceil(sortedValues.length * quantile) - 1));
  return sortedValues[index];
}

function minNumber(values) {
  const finite = values.filter(Number.isFinite);
  return finite.length > 0 ? Math.min(...finite) : null;
}

function maxNumber(values) {
  const finite = values.filter(Number.isFinite);
  return finite.length > 0 ? Math.max(...finite) : null;
}

function anonymizeUrl(raw) {
  try {
    const parsed = new URL(raw);
    return `${parsed.protocol}//${parsed.hostname}${parsed.port ? `:${parsed.port}` : ''}${parsed.pathname}${parsed.search ? '?...' : ''}`;
  } catch {
    return 'invalid';
  }
}

function truncate(value, maxLength) {
  const text = String(value || '');
  return text.length > maxLength ? `${text.slice(0, maxLength)}...` : text;
}

function formatTimestamp(date) {
  return date.toISOString().replaceAll(':', '').replace(/\.\d{3}Z$/, 'Z');
}

function delay(milliseconds) {
  return new Promise(resolve => setTimeout(resolve, milliseconds));
}

function fail(message) {
  console.error(message);
  process.exit(1);
}

function printHelp() {
  console.log(`
Run repeated GET /api/templates/feed requests while an operator performs Admin QA actions.

Required:
  --api-base=<staging API base URL>

Optional:
  --path=/api/templates/feed?take=20
  --duration-seconds=180
  --concurrency=4
  --interval-ms=250
  --timeout-ms=10000
  --max-errors=0
  --run-id=<artifact run id>
  --artifact-dir=artifacts/template-feed-load-probes/<run>
  --bearer-token=<API bearer token>
  --headers-json='{"X-Header":"value"}'

The probe writes evidence.json and summary.md. Use the summary as Admin QA
evidence for category rename under feed load together with Admin UI/API action
evidence and the SSE snapshot.
`);
}
