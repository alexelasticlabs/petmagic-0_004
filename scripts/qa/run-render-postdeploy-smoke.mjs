#!/usr/bin/env node

import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(scriptDir, '..', '..');
const rawArgs = process.argv.slice(2);
const args = new Set(rawArgs);

if (args.has('--help') || args.has('-h')) {
  printUsage();
  process.exit(0);
}

let envFilePath;
let startedAt;
let runId;
let artifactDir;
let apiBaseUrl;
let adminBaseUrl;
let adminAuthToken;
let timeoutMs;
let environment;
let expectedSchedulerV2Enabled;

try {
  environment = (getOptionValue('--environment') ?? 'staging').toLowerCase();
  if (!['staging', 'production'].includes(environment)) {
    throw new Error('--environment must be staging or production.');
  }
  envFilePath = getOptionValue('--env-file')
    ?? process.env.PETMAGIC_ENV_FILE
    ?? (environment === 'staging' ? process.env.STAGING_ENV_FILE : process.env.PRODUCTION_ENV_FILE)
    ?? (environment === 'staging' ? '.env.staging.local' : '.env.production.local');
  loadLocalEnvFile(envFilePath);

  startedAt = new Date();
  runId = getOptionValue('--run-id') ?? `render-postdeploy-smoke-${formatTimestamp(startedAt)}`;
  artifactDir = getOptionValue('--artifact-dir') ?? join('artifacts', 'render-postdeploy-smoke', runId);
  apiBaseUrl = normalizeBaseUrl(
    getOptionValue('--api-base-url')
    ?? process.env.PETMAGIC_API_BASE_URL
    ?? (environment === 'staging' ? process.env.STAGING_API_BASE_URL : process.env.PRODUCTION_API_BASE_URL)
    ?? (environment === 'staging' ? 'https://api.staging.petmagic.app' : 'https://api.petgpt.app'));
  adminBaseUrl = normalizeBaseUrl(
    getOptionValue('--admin-base-url')
    ?? process.env.PETMAGIC_ADMIN_BASE_URL
    ?? (environment === 'staging' ? process.env.STAGING_ADMIN_BASE_URL : process.env.PRODUCTION_ADMIN_BASE_URL)
    ?? (environment === 'staging' ? 'https://admin.staging.petmagic.app' : 'https://admin.petgpt.app'));
  adminAuthToken = process.env.PETMAGIC_ADMIN_AUTH_TOKEN
    ?? (environment === 'staging'
      ? process.env.STAGING_ADMIN_AUTH_TOKEN
      : process.env.PRODUCTION_ADMIN_AUTH_TOKEN)
    ?? '';
  timeoutMs = positiveIntegerOption('--timeout-ms', 15_000);
  expectedSchedulerV2Enabled = booleanOption(
    '--expected-scheduler-v2-enabled',
    process.env.PETMAGIC_EXPECTED_GENERATION_SCHEDULER_V2_ENABLED,
    false);

  mkdirSync(artifactDir, { recursive: true });
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}

const checks = [];
const evidence = {
  runId,
  startedAtUtc: startedAt.toISOString(),
  envFileLoaded: existsSync(envFilePath),
  apiBaseUrl: anonymizeUrl(apiBaseUrl),
  adminBaseUrl: anonymizeUrl(adminBaseUrl),
  adminAuthTokenProvided: Boolean(adminAuthToken),
  timeoutMs,
  environment,
  expectedSchedulerV2Enabled,
  checks
};

main().catch((error) => {
  record('runner.completed_without_unhandled_error', false, error instanceof Error ? error.message : String(error));
  finish(1);
});

async function main() {
  const apiUrlValid = validateRemoteHttpsUrl('apiBaseUrl', apiBaseUrl);
  const adminUrlValid = validateRemoteHttpsUrl('adminBaseUrl', adminBaseUrl);
  if (!apiUrlValid || !adminUrlValid) {
    finish(1);
    return;
  }

  await checkApiHealth();
  await checkAdminRoute();
  await checkGenerationWorkerRuntime();

  finish(hasFailedChecks() ? 1 : 0);
}

async function checkApiHealth() {
  const response = await fetchWithTimeout(`${apiBaseUrl}/health`);
  evidence.apiHealth = summarizeResponse(response);
  record('api.health.http_200', response.status === 200, `HTTP ${response.status}`);

  let payload = null;
  try {
    payload = response.text ? JSON.parse(response.text) : null;
  } catch {
    // Recorded below.
  }

  evidence.apiHealth.payload = sanitizeHealthPayload(payload);
  record('api.health.json', Boolean(payload && typeof payload === 'object'), payload ? 'valid JSON' : 'missing or invalid JSON');

  const status = readCaseInsensitive(payload, 'status');
  record('api.health.status_healthy', status === 'Healthy', `status=${status ?? 'missing'}`);

  const build = readCaseInsensitive(payload, 'build');
  const application = readCaseInsensitive(build, 'application');
  record('api.health.application_name', application === 'PetMagic.Host.Api', `application=${application ?? 'missing'}`);

  const checksValue = readCaseInsensitive(payload, 'checks');
  record(
    'api.health.checks_present',
    Array.isArray(checksValue) && checksValue.length > 0,
    `checks=${Array.isArray(checksValue) ? checksValue.length : 'missing'}`);

  const schedulerCheck = Array.isArray(checksValue)
    ? checksValue.find((check) => readCaseInsensitive(check, 'name') === 'templates_scheduler_config')
    : null;
  const schedulerStatus = readCaseInsensitive(schedulerCheck, 'status');
  const schedulerConfig = readCaseInsensitive(payload, 'schedulerConfig');
  const schedulerMismatchDetected = readCaseInsensitive(schedulerConfig, 'isMismatchDetected');
  record(
    'api.health.scheduler_fingerprint_present',
    Boolean(schedulerCheck),
    schedulerCheck ? `status=${schedulerStatus ?? 'missing'}` : 'templates_scheduler_config missing');
  record(
    'api.health.scheduler_fingerprint_healthy',
    schedulerStatus === 'Healthy',
    `status=${schedulerStatus ?? 'missing'}`);
  record(
    'api.health.scheduler_fingerprint_mismatch_absent',
    schedulerMismatchDetected === false,
    `isMismatchDetected=${schedulerMismatchDetected ?? 'missing'}`);
}

async function checkAdminRoute() {
  const response = await fetchWithTimeout(`${adminBaseUrl}/ru`);
  evidence.adminRoute = summarizeResponse(response);
  record('admin.ru.http_200', response.status === 200, `HTTP ${response.status}`);
  record(
    'admin.ru.html',
    /<html[\s>]/i.test(response.text) || /<!doctype html>/i.test(response.text),
    `bodyLength=${response.text.length}`);
}

async function checkGenerationWorkerRuntime() {
  record(
    'input.admin_auth_token_present',
    Boolean(adminAuthToken),
    adminAuthToken ? 'provided' : 'missing; set STAGING_ADMIN_AUTH_TOKEN, PRODUCTION_ADMIN_AUTH_TOKEN, or PETMAGIC_ADMIN_AUTH_TOKEN');
  if (!adminAuthToken) {
    return;
  }

  const response = await fetchWithTimeout(`${apiBaseUrl}/api/admin/system/operations`, {
    redirect: 'manual',
    headers: {
      Accept: 'application/json',
      Authorization: `Bearer ${adminAuthToken}`
    }
  });
  let payload = null;
  try {
    payload = response.text ? JSON.parse(response.text) : null;
  } catch {
    // Recorded below.
  }

  const workers = readCaseInsensitive(payload, 'workers');
  const workerStatus = readCaseInsensitive(workers, 'status');
  const heartbeatAtUtc = readCaseInsensitive(workers, 'generationWorkerHeartbeatAtUtc');
  const heartbeatAgeSeconds = readCaseInsensitive(workers, 'generationWorkerHeartbeatAgeSeconds');
  const unavailableSources = readCaseInsensitive(payload, 'unavailableSources');
  evidence.operations = {
    response: summarizeResponse(response),
    overallStatus: readCaseInsensitive(payload, 'overallStatus') ?? null,
    workerStatus: workerStatus ?? null,
    generationWorkerHeartbeatAtUtc: heartbeatAtUtc ?? null,
    generationWorkerHeartbeatAgeSeconds: heartbeatAgeSeconds ?? null,
    unavailableSources: Array.isArray(unavailableSources) ? unavailableSources.slice(0, 4) : null
  };

  record('api.operations.http_200', response.status === 200, `HTTP ${response.status}`);
  recordAuthenticatedResponseSafety('api.operations', response, apiBaseUrl);
  record('api.operations.json', Boolean(payload && typeof payload === 'object'), payload ? 'valid JSON' : 'missing or invalid JSON');
  record(
    'api.operations.templates_source_available',
    Array.isArray(unavailableSources) && !unavailableSources.includes('templates'),
    `unavailableSources=${Array.isArray(unavailableSources) ? unavailableSources.join(',') || 'none' : 'missing'}`);
  record(
    'api.operations.generation_worker_heartbeat_present',
    Boolean(heartbeatAtUtc),
    `heartbeatAtUtc=${heartbeatAtUtc ?? 'missing'}`);
  record(
    'api.operations.generation_worker_heartbeat_fresh',
    Number.isFinite(heartbeatAgeSeconds) && heartbeatAgeSeconds <= 75 && workerStatus === 'healthy',
    `status=${workerStatus ?? 'missing'}, ageSeconds=${heartbeatAgeSeconds ?? 'missing'}`);

  const controlResponse = await fetchWithTimeout(`${apiBaseUrl}/api/admin/templates/generation-control`, {
    redirect: 'manual',
    headers: {
      Accept: 'application/json',
      Authorization: `Bearer ${adminAuthToken}`
    }
  });
  let control = null;
  try {
    control = controlResponse.text ? JSON.parse(controlResponse.text) : null;
  } catch {
    // Recorded below.
  }

  const worker = readCaseInsensitive(control, 'worker');
  const revision = readCaseInsensitive(control, 'revision');
  const instanceCount = readCaseInsensitive(worker, 'instanceCount');
  const appliedPolicyRevision = readCaseInsensitive(worker, 'appliedPolicyRevision');
  const schedulerV2Enabled = readCaseInsensitive(worker, 'schedulerV2Enabled');
  const dispatchConcurrency = readCaseInsensitive(worker, 'dispatchConcurrency');
  const reconciliationConcurrency = readCaseInsensitive(worker, 'reconciliationConcurrency');
  const mediaImportConcurrency = readCaseInsensitive(worker, 'mediaImportConcurrency');
  const maintenanceConcurrency = readCaseInsensitive(worker, 'maintenanceConcurrency');
  const alerts = readCaseInsensitive(control, 'alerts');
  const criticalAlerts = Array.isArray(alerts)
    ? alerts.filter((alert) => String(readCaseInsensitive(alert, 'severity')).toLowerCase() === 'critical')
    : null;
  evidence.generationControl = {
    response: summarizeResponse(controlResponse),
    revision: revision ?? null,
    worker: worker && typeof worker === 'object'
      ? {
        instanceCount: instanceCount ?? null,
        appliedPolicyRevision: appliedPolicyRevision ?? null,
        schedulerV2Enabled: schedulerV2Enabled ?? null,
        dispatchConcurrency: dispatchConcurrency ?? null,
        reconciliationConcurrency: reconciliationConcurrency ?? null,
        mediaImportConcurrency: mediaImportConcurrency ?? null,
        maintenanceConcurrency: maintenanceConcurrency ?? null
      }
      : null,
    alertIds: Array.isArray(alerts)
      ? alerts.map((alert) => readCaseInsensitive(alert, 'alertId')).filter(Boolean)
      : null
  };

  record('api.generation_control.http_200', controlResponse.status === 200, `HTTP ${controlResponse.status}`);
  recordAuthenticatedResponseSafety('api.generation_control', controlResponse, apiBaseUrl);
  record(
    'api.generation_control.json',
    Boolean(control && typeof control === 'object'),
    control ? 'valid JSON' : 'missing or invalid JSON');
  record(
    'api.generation_control.single_worker',
    instanceCount === 1,
    `instanceCount=${instanceCount ?? 'missing'}`);
  record(
    'api.generation_control.policy_revision_applied',
    Number.isInteger(revision) && appliedPolicyRevision === revision,
    `revision=${revision ?? 'missing'}, applied=${appliedPolicyRevision ?? 'missing'}`);
  record(
    'api.generation_control.scheduler_v2_mode',
    schedulerV2Enabled === expectedSchedulerV2Enabled,
    `expected=${expectedSchedulerV2Enabled}, actual=${schedulerV2Enabled ?? 'missing'}`);
  record(
    'api.generation_control.lanes',
    dispatchConcurrency === 4
      && reconciliationConcurrency === 4
      && mediaImportConcurrency === 1
      && maintenanceConcurrency === 1,
    `dispatch=${dispatchConcurrency ?? 'missing'}, reconciliation=${reconciliationConcurrency ?? 'missing'}, import=${mediaImportConcurrency ?? 'missing'}, maintenance=${maintenanceConcurrency ?? 'missing'}`);
  record(
    'api.generation_control.no_critical_alerts',
    Array.isArray(criticalAlerts) && criticalAlerts.length === 0,
    `criticalAlerts=${Array.isArray(criticalAlerts)
      ? criticalAlerts.map((alert) => readCaseInsensitive(alert, 'alertId')).join(',') || 'none'
      : 'missing'}`);
}

async function fetchWithTimeout(url, options = {}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(url, {
      ...options,
      redirect: options.redirect ?? 'follow',
      signal: controller.signal,
      headers: {
        Accept: 'text/html,application/json;q=0.9,*/*;q=0.8',
        'User-Agent': 'petmagic-render-postdeploy-smoke',
        ...(options.headers ?? {})
      }
    });
    const text = await response.text();
    return {
      ok: response.ok,
      status: response.status,
      url: response.url,
      text
    };
  } catch (error) {
    return {
      ok: false,
      status: 0,
      url,
      text: error instanceof Error ? error.message : String(error)
    };
  } finally {
    clearTimeout(timeout);
  }
}

function summarizeResponse(response) {
  return {
    ok: response.ok,
    status: response.status,
    url: anonymizeUrl(response.url),
    bodySnippet: sanitizeText(response.text).slice(0, 300)
  };
}

function sanitizeHealthPayload(payload) {
  if (!payload || typeof payload !== 'object') {
    return null;
  }

  const build = readCaseInsensitive(payload, 'build');
  const schedulerConfig = readCaseInsensitive(payload, 'schedulerConfig');
  const checksValue = readCaseInsensitive(payload, 'checks');
  return {
    status: readCaseInsensitive(payload, 'status') ?? null,
    build: build && typeof build === 'object'
      ? {
        application: readCaseInsensitive(build, 'application') ?? null,
        environment: readCaseInsensitive(build, 'environment') ?? null,
        version: readCaseInsensitive(build, 'version') ?? null
      }
      : null,
    schedulerConfig: schedulerConfig && typeof schedulerConfig === 'object'
      ? {
        initialized: readCaseInsensitive(schedulerConfig, 'initialized') ?? null,
        isMismatchDetected: readCaseInsensitive(schedulerConfig, 'isMismatchDetected') ?? null
      }
      : null,
    checks: Array.isArray(checksValue)
      ? checksValue.map((check) => ({
        name: readCaseInsensitive(check, 'name') ?? null,
        status: readCaseInsensitive(check, 'status') ?? null
      }))
      : null
  };
}

function validateRemoteHttpsUrl(name, value) {
  let url;
  try {
    url = new URL(value);
  } catch {
    record(`input.${name}.absolute_https_url`, false, `${name} must be an absolute HTTPS URL`);
    return false;
  }

  const validProtocol = url.protocol === 'https:';
  const hasCleanAuthority = !url.username && !url.password && !url.search && !url.hash;
  const remoteHost = !isLocalHost(url.hostname);
  record(`input.${name}.absolute_https_url`, validProtocol, `${url.protocol}//${url.hostname}`);
  record(
    `input.${name}.clean_authority`,
    hasCleanAuthority,
    hasCleanAuthority ? 'no userinfo, query, or fragment' : 'userinfo, query, or fragment is not allowed');
  record(`input.${name}.not_localhost`, validProtocol && remoteHost, url.hostname);
  return validProtocol && hasCleanAuthority && remoteHost;
}

function recordAuthenticatedResponseSafety(prefix, response, expectedBaseUrl) {
  const redirectStatus = response.status >= 300 && response.status < 400;
  let sameOrigin = false;
  try {
    sameOrigin = new URL(response.url).origin === new URL(expectedBaseUrl).origin;
  } catch {
    // Recorded as false below.
  }

  record(`${prefix}.redirect_absent`, !redirectStatus, `HTTP ${response.status}`);
  record(`${prefix}.same_origin`, sameOrigin, anonymizeUrl(response.url));
}

function normalizeBaseUrl(value) {
  return String(value || '').trim().replace(/\/+$/, '');
}

function loadLocalEnvFile(path) {
  if (!existsSync(path)) {
    return;
  }

  const content = readFileSync(path, 'utf8');
  for (const line of content.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) {
      continue;
    }

    const match = trimmed.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
    if (!match || process.env[match[1]] !== undefined) {
      continue;
    }

    process.env[match[1]] = stripQuotes(match[2].trim());
  }
}

function stripQuotes(value) {
  if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
    return value.slice(1, -1);
  }

  return value;
}

function readCaseInsensitive(value, key) {
  if (!value || typeof value !== 'object') {
    return undefined;
  }

  const entry = Object.entries(value).find(([candidate]) => candidate.toLowerCase() === key.toLowerCase());
  return entry?.[1];
}

function isLocalHost(host) {
  const normalized = host.trim().toLowerCase().replace(/^\[|\]$/g, '');
  return [
    'localhost',
    '127.0.0.1',
    '::1',
    '0.0.0.0',
    'host.docker.internal',
    'postgres',
    'db',
    'petmagic-postgres'
  ].includes(normalized) || normalized.endsWith('.localhost');
}

function record(name, ok, detail) {
  const check = {
    name,
    ok: Boolean(ok),
    detail,
    recordedAtUtc: new Date().toISOString()
  };
  checks.push(check);
  console.log(`[${check.ok ? 'ok' : 'fail'}] ${name}: ${detail}`);
}

function hasFailedChecks() {
  return checks.some((check) => !check.ok);
}

function finish(exitCode) {
  evidence.completedAtUtc = new Date().toISOString();
  evidence.status = exitCode === 0 ? 'passed' : 'failed';
  evidence.failedChecks = checks.filter((check) => !check.ok);
  writeFileSync(join(artifactDir, 'evidence.json'), `${JSON.stringify(evidence, null, 2)}\n`);
  writeFileSync(join(artifactDir, 'summary.md'), renderSummary());
  console.log(`Evidence written to ${join(artifactDir, 'summary.md')}`);
  process.exitCode = exitCode;
}

function renderSummary() {
  return [
    '# Render Post-Deploy Smoke',
    '',
    `Run ID: ${runId}`,
    `Status: ${evidence.status ?? 'running'}`,
    `API: ${evidence.apiBaseUrl}`,
    `Admin: ${evidence.adminBaseUrl}`,
    '',
    '| Check | Result | Detail |',
    '| --- | --- | --- |',
    ...checks.map((check) => `| ${check.name} | ${check.ok ? 'PASS' : 'FAIL'} | ${String(check.detail).replaceAll('|', '\\|')} |`),
    ''
  ].join('\n');
}

function sanitizeText(value) {
  return String(value || '')
    .replace(/(Bearer\s+)[A-Za-z0-9._-]+/gi, '$1***')
    .replace(/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g, '[email]');
}

function anonymizeUrl(value) {
  try {
    const url = new URL(value);
    return `${url.protocol}//${url.host}${url.pathname === '/' ? '' : url.pathname}`;
  } catch {
    return sanitizeText(value);
  }
}

function positiveIntegerOption(name, fallback) {
  const raw = getOptionValue(name);
  if (!raw) {
    return fallback;
  }

  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new Error(`${name} must be a positive integer.`);
  }

  return parsed;
}

function booleanOption(name, environmentValue, fallback) {
  const raw = getOptionValue(name) ?? environmentValue;
  if (raw === undefined || raw === null || String(raw).trim() === '') {
    return fallback;
  }

  const normalized = String(raw).trim().toLowerCase();
  if (normalized === 'true' || normalized === '1') {
    return true;
  }

  if (normalized === 'false' || normalized === '0') {
    return false;
  }

  throw new Error(`${name} must be true or false.`);
}

function getOptionValue(name) {
  const prefix = `${name}=`;
  for (let index = 0; index < rawArgs.length; index += 1) {
    const arg = rawArgs[index];
    if (arg.startsWith(prefix)) {
      return arg.slice(prefix.length);
    }

    if (arg === name && index + 1 < rawArgs.length) {
      return rawArgs[index + 1];
    }
  }

  return undefined;
}

function formatTimestamp(date) {
  return date.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z');
}

function printUsage() {
  console.log(`
Render post-deploy smoke.

Usage:
  node scripts/qa/run-render-postdeploy-smoke.mjs
  node scripts/qa/run-render-postdeploy-smoke.mjs --api-base-url https://api.staging.petmagic.app --admin-base-url https://admin.staging.petmagic.app

Options:
  --api-base-url <url>    API base URL. Defaults to STAGING_API_BASE_URL or https://api.staging.petmagic.app.
  --admin-base-url <url>  Admin base URL. Defaults to STAGING_ADMIN_BASE_URL or https://admin.staging.petmagic.app.
  --env-file <path>       Optional env file. Defaults to STAGING_ENV_FILE or .env.staging.local.
  --environment <value>  staging or production. Defaults to staging.
  --timeout-ms <ms>       Per-request timeout. Defaults to 15000.
  --expected-scheduler-v2-enabled <bool>
                          Expected generation-worker rollout mode. Defaults to false.
  --run-id <id>           Artifact run id.
  --artifact-dir <dir>    Evidence output directory.
  --help, -h              Print this help.

The smoke is read-only: it checks API /health, admin /ru, scheduler fingerprint,
the authenticated generation-worker heartbeat, one-worker topology, policy revision,
lane concurrency, and critical generation-control alerts without creating users,
jobs, payments, or provider callbacks. HTTPS is mandatory for authenticated checks.
An admin token is required for a passing gate.
`.trim());
}
