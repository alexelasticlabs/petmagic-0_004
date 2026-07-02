#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

if (process.argv.includes('--help') || process.argv.includes('-h')) {
  printHelp();
  process.exit(0);
}

const envFilePath = process.env.LOCAL_SMOKE_ENV_FILE || '.env.local-smoke';
loadLocalEnvFile(envFilePath);

const missing = findMissingRequiredInputs();
if (missing.length > 0) {
  console.error(`Missing required local smoke input names: ${missing.join(', ')}`);
  console.error('Create .env.local-smoke from .env.local-smoke.example or load equivalent LOCAL_* variables. Values were not printed.');
  process.exit(1);
}

const runId = process.env.LOCAL_SMOKE_RUN_ID || `local-generation-smoke-${formatTimestamp(new Date())}`;
const artifactDir = process.env.LOCAL_ARTIFACT_DIR || join('artifacts', 'local-generation-scheduler-smoke', runId);
const stagingRunnerEnv = {
  ...process.env,
  GENERATION_SCHEDULER_SMOKE_MODE: 'local',
  STAGING_ALLOW_LOCALHOST: 'true',
  STAGING_ENV_FILE: '__local_smoke_env_loaded_by_wrapper__',
  STAGING_SMOKE_RUN_ID: runId,
  STAGING_ARTIFACT_DIR: artifactDir,
  STAGING_API_BASE_URL: requiredEnv('LOCAL_API_BASE_URL'),
  STAGING_DATABASE_URL: requiredEnv('LOCAL_DATABASE_URL'),
  STAGING_IMAGE_TEMPLATE_ID: requiredEnv('LOCAL_IMAGE_TEMPLATE_ID'),
  STAGING_VIDEO_TEMPLATE_ID: requiredEnv('LOCAL_VIDEO_TEMPLATE_ID'),
  STAGING_FAILING_TEMPLATE_ID: requiredEnv('LOCAL_FAILING_TEMPLATE_ID'),
  STAGING_CANCEL_TEMPLATE_ID: process.env.LOCAL_CANCEL_TEMPLATE_ID || requiredEnv('LOCAL_IMAGE_TEMPLATE_ID'),
  STAGING_CANCEL_MEDIA_TYPE: process.env.LOCAL_CANCEL_MEDIA_TYPE || 'image',
  STAGING_FREE_JWT: requiredEnv('LOCAL_FREE_JWT'),
  STAGING_PREMIUM_JWT: requiredEnv('LOCAL_PREMIUM_JWT'),
  STAGING_FREE_AUTH_TOKENS: process.env.LOCAL_FREE_AUTH_TOKENS || process.env.LOCAL_FREE_JWT,
  STAGING_PREMIUM_AUTH_TOKENS: process.env.LOCAL_PREMIUM_AUTH_TOKENS || process.env.LOCAL_PREMIUM_JWT,
  STAGING_FAILING_TEMPLATE_MEDIA_TYPE: process.env.LOCAL_FAILING_TEMPLATE_MEDIA_TYPE || 'image',
  STAGING_MIN_EXISTING_GENERATIONS: process.env.LOCAL_MIN_EXISTING_GENERATIONS || '0',
  STAGING_API_PROCESS_ID: process.env.LOCAL_API_PROCESS_ID || 'local-compose-backend',
  STAGING_WORKER_PROCESS_ID: process.env.LOCAL_WORKER_PROCESS_ID || 'local-compose-generation-worker',
  STAGING_MIGRATION_TOOLING_LABEL: process.env.LOCAL_MIGRATION_TOOLING_LABEL || 'local-development-compose',
  STAGING_SMOKE_TOTAL: process.env.LOCAL_SMOKE_TOTAL || '20',
  STAGING_SUBMIT_CONCURRENCY: process.env.LOCAL_SUBMIT_CONCURRENCY || process.env.STAGING_SUBMIT_CONCURRENCY || '4',
  STAGING_POLL_ATTEMPTS: process.env.LOCAL_POLL_ATTEMPTS || process.env.STAGING_POLL_ATTEMPTS || '60',
  STAGING_POLL_DELAY_MS: process.env.LOCAL_POLL_DELAY_MS || process.env.STAGING_POLL_DELAY_MS || '1000',
  STAGING_REALTIME_GROWTH_BUDGET: process.env.LOCAL_REALTIME_GROWTH_BUDGET || process.env.STAGING_REALTIME_GROWTH_BUDGET || '200',
  STAGING_USE_QA_FIXTURES: process.env.LOCAL_USE_QA_FIXTURES || process.env.PETMAGIC_QA_FIXTURES_ENABLED || process.env.STAGING_USE_QA_FIXTURES || 'true',
  STAGING_PSQL_COMMAND: process.env.LOCAL_PSQL_COMMAND || process.env.STAGING_PSQL_COMMAND || 'docker-compose-psql'
};

copyOptionalEnv('LOCAL_PROMETHEUS_BASE_URL', 'STAGING_PROMETHEUS_BASE_URL', stagingRunnerEnv);
copyOptionalEnv('LOCAL_SOURCE_IMAGE_PATH', 'STAGING_SOURCE_IMAGE_PATH', stagingRunnerEnv);
copyOptionalEnv('LOCAL_MIGRATION_LOG_PATH', 'STAGING_MIGRATION_LOG_PATH', stagingRunnerEnv);
copyOptionalEnv('LOCAL_ADMIN_AUTH_TOKEN', 'STAGING_ADMIN_AUTH_TOKEN', stagingRunnerEnv);

console.log('LOCAL DEVELOPMENT SMOKE ONLY - NOT STAGING OR PRODUCTION EVIDENCE');
const result = spawnSync(process.execPath, [
  'scripts/qa/run-staging-generation-scheduler-smoke.mjs',
  '--mode=local'
], {
  env: stagingRunnerEnv,
  stdio: 'inherit'
});

process.exit(result.status ?? 1);

function findMissingRequiredInputs() {
  return [
    'LOCAL_API_BASE_URL',
    'LOCAL_DATABASE_URL',
    'LOCAL_IMAGE_TEMPLATE_ID',
    'LOCAL_VIDEO_TEMPLATE_ID',
    'LOCAL_FAILING_TEMPLATE_ID',
    'LOCAL_FREE_JWT',
    'LOCAL_PREMIUM_JWT'
  ].filter(name => !process.env[name]);
}

function requiredEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} is required.`);
  }
  return value;
}

function copyOptionalEnv(sourceName, targetName, targetEnv) {
  if (process.env[sourceName]) {
    targetEnv[targetName] = process.env[sourceName];
  }
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

function formatTimestamp(date) {
  return date.toISOString().replaceAll(':', '').replace(/\.\d{3}Z$/, 'Z');
}

function printHelp() {
  console.log(`
Local generation scheduler smoke runner.

LOCAL DEVELOPMENT SMOKE ONLY - NOT STAGING OR PRODUCTION EVIDENCE

Required environment, loaded from .env.local-smoke by default:
  LOCAL_API_BASE_URL             http://localhost:<api-port>
  LOCAL_DATABASE_URL             PostgreSQL connection string accepted by psql
  LOCAL_IMAGE_TEMPLATE_ID        active local image template id
  LOCAL_VIDEO_TEMPLATE_ID        active local video template id
  LOCAL_FAILING_TEMPLATE_ID      active local template configured with Fake AI failure sentinel
  LOCAL_FREE_JWT                 local free-user JWT
  LOCAL_PREMIUM_JWT              local premium-user JWT

Optional environment:
  LOCAL_SMOKE_ENV_FILE           env file path, default .env.local-smoke
  LOCAL_FREE_AUTH_TOKENS         comma-separated local free-user JWTs for wider queue smoke
  LOCAL_PREMIUM_AUTH_TOKENS      comma-separated local premium-user JWTs for wider queue smoke
  LOCAL_PROMETHEUS_BASE_URL      Prometheus base URL; optional for local smoke
  LOCAL_CANCEL_TEMPLATE_ID       cancel probe template id, default LOCAL_IMAGE_TEMPLATE_ID
  LOCAL_CANCEL_MEDIA_TYPE        cancel probe media type, default image
  LOCAL_SMOKE_TOTAL              default 20
  LOCAL_SUBMIT_CONCURRENCY       default 4
  LOCAL_MIN_EXISTING_GENERATIONS default 0
  LOCAL_USE_QA_FIXTURES          default true; backend must set PETMAGIC_QA_FIXTURES_ENABLED=true
  LOCAL_SOURCE_IMAGE_PATH        PNG/JPEG/WebP source image path
  LOCAL_PSQL_COMMAND             psql command path, default docker-compose-psql
  LOCAL_ARTIFACT_DIR             output dir, default artifacts/local-generation-scheduler-smoke/<run>

Example:
  node scripts/qa/run-local-generation-scheduler-smoke.mjs
`);
}
