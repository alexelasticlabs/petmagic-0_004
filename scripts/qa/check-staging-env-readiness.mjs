#!/usr/bin/env node

import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const rawArgs = process.argv.slice(2);
const args = new Set(rawArgs);
const repoRoot = resolve(getOptionValue('--root') ?? resolve(scriptDir, '..', '..'));
const envFilePath = resolve(repoRoot, getOptionValue('--file') ?? process.env.STAGING_ENV_FILE ?? '.env.staging.local');
const exampleMode = args.has('--example');

if (args.has('--help') || args.has('-h')) {
  printUsage();
  process.exit(0);
}

const failures = [];
const warnings = [];

if (!existsSync(envFilePath)) {
  fail(`Env file does not exist: ${envFilePath}`);
  finish();
}

const env = parseEnvFile(envFilePath);

const requiredInputs = [
  'STAGING_API_BASE_URL',
  'STAGING_DATABASE_URL',
  'STAGING_IMAGE_TEMPLATE_ID',
  'STAGING_VIDEO_TEMPLATE_ID',
  'STAGING_FAILING_TEMPLATE_ID',
  'STAGING_ADMIN_AUTH_TOKEN',
  'STAGING_PROMETHEUS_BASE_URL',
  'STAGING_API_PROCESS_ID',
  'STAGING_WORKER_PROCESS_ID',
  'STAGING_MIGRATION_TOOLING_LABEL',
  'STAGING_PSQL_COMMAND'
];

for (const key of requiredInputs) {
  requireKey(key);
}

requireAnyKey(['STAGING_FREE_AUTH_TOKENS', 'STAGING_FREE_JWT']);
requireAnyKey(['STAGING_PREMIUM_AUTH_TOKENS', 'STAGING_PREMIUM_JWT']);

if (!exampleMode) {
  requireHttpUrl('STAGING_API_BASE_URL', { rejectLocal: true });
  requireOptionalHttpUrl('STAGING_ADMIN_BASE_URL', { rejectLocal: true });
  requireHttpUrl('STAGING_PROMETHEUS_BASE_URL', { rejectLocal: true });
  requireDatabaseTarget('STAGING_DATABASE_URL', { rejectLocal: true });
  requireJwtLike('STAGING_ADMIN_AUTH_TOKEN');
  requireJwtGroup(['STAGING_FREE_AUTH_TOKENS', 'STAGING_FREE_JWT']);
  requireJwtGroup(['STAGING_PREMIUM_AUTH_TOKENS', 'STAGING_PREMIUM_JWT']);
  requireDistinctValues('STAGING_API_PROCESS_ID', 'STAGING_WORKER_PROCESS_ID');
  rejectLocalPsqlWrappers('STAGING_PSQL_COMMAND');
}

for (const key of [
  'STAGING_MIN_EXISTING_GENERATIONS',
  'STAGING_SMOKE_TOTAL',
  'STAGING_SUBMIT_CONCURRENCY',
  'STAGING_POLL_ATTEMPTS',
  'STAGING_POLL_DELAY_MS'
]) {
  requireNonNegativeIntegerIfPresent(key);
}

for (const key of [
  'ECONOMY_GATE_RUN_MIGRATIONS',
  'ECONOMY_GATE_BACKUP_CONFIRMED',
  'ECONOMY_GATE_RUN_RECONCILIATION',
  'STAGING_USE_QA_FIXTURES'
]) {
  requireBooleanIfPresent(key);
}

finish();

function parseEnvFile(path) {
  const values = new Map();
  const content = readFileSync(path, 'utf8');
  for (const [index, line] of content.split(/\r?\n/).entries()) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) {
      continue;
    }

    const match = trimmed.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
    if (!match) {
      warn(`Line ${index + 1} is not a simple KEY=value entry and was ignored.`);
      continue;
    }

    const key = match[1];
    if (values.has(key)) {
      warn(`${key} is defined more than once; the last value wins.`);
    }

    values.set(key, stripQuotes(match[2].trim()));
  }

  return values;
}

function requireKey(key) {
  if (!env.has(key)) {
    fail(`Missing ${key}.`);
    return false;
  }

  if (!exampleMode && isBlankOrPlaceholder(env.get(key))) {
    fail(`${key} is empty or still contains a placeholder.`);
    return false;
  }

  return true;
}

function requireAnyKey(keys) {
  const present = keys.filter((key) => env.has(key));
  if (present.length === 0) {
    fail(`Missing one of: ${keys.join(', ')}.`);
    return false;
  }

  if (!exampleMode && !present.some((key) => !isBlankOrPlaceholder(env.get(key)))) {
    fail(`One of ${keys.join(', ')} must contain a non-placeholder value.`);
    return false;
  }

  return true;
}

function requireHttpUrl(key, options) {
  if (!requireKey(key)) {
    return;
  }

  validateHttpUrlValue(key, env.get(key), options);
}

function requireOptionalHttpUrl(key, options) {
  if (!env.has(key) || !env.get(key)) {
    return;
  }

  validateHttpUrlValue(key, env.get(key), options);
}

function validateHttpUrlValue(key, value, options) {
  let url;
  try {
    url = new URL(value);
  } catch {
    fail(`${key} must be an absolute http/https URL.`);
    return;
  }

  if (!['http:', 'https:'].includes(url.protocol)) {
    fail(`${key} must use http or https.`);
  }

  if (options.rejectLocal && isLocalHost(url.hostname)) {
    fail(`${key} must not point to localhost/local infrastructure.`);
  }
}

function requireDatabaseTarget(key, options) {
  if (!requireKey(key)) {
    return;
  }

  const host = extractDatabaseHost(env.get(key));
  if (!host) {
    fail(`${key} must include a database host.`);
    return;
  }

  if (options.rejectLocal && isLocalHost(host)) {
    fail(`${key} must not point to localhost/local infrastructure.`);
  }
}

function requireJwtGroup(keys) {
  const key = keys.find((candidate) => env.has(candidate) && !isBlankOrPlaceholder(env.get(candidate)));
  if (!key) {
    fail(`One of ${keys.join(', ')} must contain a JWT.`);
    return;
  }

  for (const token of splitList(env.get(key))) {
    if (!looksLikeJwt(token)) {
      fail(`${key} contains a value that does not look like a JWT.`);
    }
  }
}

function requireJwtLike(key) {
  if (!requireKey(key)) {
    return;
  }

  if (!looksLikeJwt(env.get(key))) {
    fail(`${key} does not look like a JWT.`);
  }
}

function requireDistinctValues(firstKey, secondKey) {
  if (!requireKey(firstKey) || !requireKey(secondKey)) {
    return;
  }

  if (env.get(firstKey) === env.get(secondKey)) {
    fail(`${firstKey} and ${secondKey} must identify distinct runtime processes.`);
  }
}

function rejectLocalPsqlWrappers(key) {
  if (!requireKey(key)) {
    return;
  }

  const normalized = env.get(key).replaceAll('\\', '/').toLowerCase();
  if (
    normalized === 'docker-compose-psql'
    || normalized === 'scripts/qa/psql.cmd'
    || normalized === 'scripts/qa/psql.ps1'
    || normalized === 'scripts/qa/psql-docker-wrapper.sh'
    || normalized.endsWith('/docker-compose-psql')
    || normalized.endsWith('/scripts/qa/psql.cmd')
    || normalized.endsWith('/scripts/qa/psql.ps1')
    || normalized.endsWith('/scripts/qa/psql-docker-wrapper.sh')
  ) {
    fail(`${key} must not use repo-local Docker compose psql wrappers for staging.`);
  }
}

function requireNonNegativeIntegerIfPresent(key) {
  if (!env.has(key) || env.get(key) === '') {
    return;
  }

  if (!/^\d+$/.test(env.get(key))) {
    fail(`${key} must be a non-negative integer.`);
  }
}

function requireBooleanIfPresent(key) {
  if (!env.has(key) || env.get(key) === '') {
    return;
  }

  if (!['true', 'false', '1', '0', 'yes', 'no', 'on', 'off'].includes(env.get(key).toLowerCase())) {
    fail(`${key} must be boolean-like.`);
  }
}

function extractDatabaseHost(value) {
  const trimmed = String(value || '').trim();
  try {
    return new URL(trimmed).hostname;
  } catch {
    // Non-URL connection strings are handled below.
  }

  const hostMatch = trimmed.match(/(?:^|;)\s*Host\s*=\s*([^;]+)/i);
  if (hostMatch) {
    return hostMatch[1].trim();
  }

  const serverMatch = trimmed.match(/(?:^|;)\s*(?:Server|Data Source)\s*=\s*([^;]+)/i);
  if (serverMatch) {
    return serverMatch[1].trim();
  }

  return null;
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

function isBlankOrPlaceholder(value) {
  const normalized = String(value || '').trim().toLowerCase();
  return normalized === ''
    || normalized.includes('replace_with')
    || normalized.includes('your-')
    || normalized.includes('your_')
    || normalized.includes('<secret')
    || normalized.includes('<managed-')
    || normalized.includes('change_me');
}

function looksLikeJwt(value) {
  return /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(String(value || '').trim());
}

function splitList(value) {
  return String(value || '').split(',').map((item) => item.trim()).filter(Boolean);
}

function stripQuotes(value) {
  if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
    return value.slice(1, -1);
  }

  return value;
}

function fail(message) {
  failures.push(message);
}

function warn(message) {
  warnings.push(message);
}

function finish() {
  for (const warning of warnings) {
    console.warn(`Warning: ${warning}`);
  }

  if (failures.length > 0) {
    console.error('Staging env readiness check failed:');
    for (const failure of failures) {
      console.error(`- ${failure}`);
    }
    process.exit(1);
  }

  const mode = exampleMode ? 'example schema' : 'filled staging inputs';
  console.log(`Staging env readiness ok: ${mode}.`);
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

function printUsage() {
  console.log(`
Staging env readiness checker.

Usage:
  node scripts/qa/check-staging-env-readiness.mjs
  node scripts/qa/check-staging-env-readiness.mjs --file .env.staging.local.example --example

Options:
  --file <path>  Env file path. Defaults to STAGING_ENV_FILE or .env.staging.local.
  --root <path>  Repository root. Defaults to this repository.
  --example      Validate that an example file declares required keys without requiring secret values.
  --help, -h     Print this help.

The default mode validates that a local operator .env.staging.local file is
ready for staging smoke checks without printing secret values.
`.trim());
}
