#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

if (process.argv.includes('--help') || process.argv.includes('-h')) {
  printHelp();
  process.exit(0);
}

const envFilePath = process.env.ECONOMY_GATE_ENV_FILE || process.env.STAGING_ENV_FILE || '.env.staging.local';
loadLocalEnvFile(envFilePath);

const startedAt = new Date();
const runId = process.env.ECONOMY_GATE_RUN_ID || `economy-staging-infra-gate-${formatTimestamp(startedAt)}`;
const artifactDir = process.env.ECONOMY_GATE_ARTIFACT_DIR || join('artifacts', 'economy-staging-infra-gate', runId);
const evidencePath = join(artifactDir, 'summary.json');
mkdirSync(artifactDir, { recursive: true });

const checks = [];
const evidence = {
  runId,
  startedAtUtc: startedAt.toISOString(),
  envFileLoaded: existsSync(envFilePath),
  database: anonymizeDatabaseUrl(process.env.STAGING_DATABASE_URL || ''),
  apiBaseUrl: anonymizeUrl(process.env.STAGING_API_BASE_URL || ''),
  migrationMode: boolEnv('ECONOMY_GATE_RUN_MIGRATIONS', false) ? 'apply' : 'read_only',
  checks
};

try {
  requireEnv('STAGING_DATABASE_URL');

  if (boolEnv('ECONOMY_GATE_RUN_MIGRATIONS', false)) {
    if (!boolEnv('ECONOMY_GATE_BACKUP_CONFIRMED', false)) {
      fail('ECONOMY_GATE_BACKUP_CONFIRMED=true is required before applying migrations.');
    }

    await runEfDatabaseUpdate();
  } else {
    record('ef_database_update', 'skipped', 'Set ECONOMY_GATE_RUN_MIGRATIONS=true after backup/snapshot confirmation.');
  }

  await runEfPendingModelCheck();
  runSqlInvariantChecks();
  await runRuntimeChecks();

  evidence.completedAtUtc = new Date().toISOString();
  evidence.status = checks.some((check) => check.status === 'failed')
    ? 'failed'
    : checks.some((check) => check.status === 'blocked')
      ? 'blocked'
      : 'passed';
  writeEvidence();

  if (evidence.status !== 'passed') {
    process.exitCode = 1;
  }
} catch (error) {
  record('runner', 'failed', error instanceof Error ? error.message : String(error));
  evidence.completedAtUtc = new Date().toISOString();
  evidence.status = 'failed';
  writeEvidence();
  process.exitCode = 1;
}

async function runEfDatabaseUpdate() {
  const env = {
    ...process.env,
    PETMAGIC_ECONOMY_MIGRATIONS_CONNECTION_STRING: requiredEnv('STAGING_DATABASE_URL')
  };

  const result = run(
    'dotnet',
    [
      'ef',
      'database',
      'update',
      '--project',
      'src/Modules/Economy/PetMagic.Modules.Economy.Infrastructure/PetMagic.Modules.Economy.Infrastructure.csproj',
      '--startup-project',
      'src/Modules/Economy/PetMagic.Modules.Economy.Infrastructure/PetMagic.Modules.Economy.Infrastructure.csproj',
      '--context',
      'EconomyDbContext'
    ],
    { env });

  record(
    'ef_database_update',
    result.status === 0 ? 'passed' : 'failed',
    result.status === 0 ? 'Economy migrations applied.' : sanitizeOutput(result.stderr || result.stdout));
}

async function runEfPendingModelCheck() {
  const env = {
    ...process.env,
    PETMAGIC_ECONOMY_MIGRATIONS_CONNECTION_STRING: requiredEnv('STAGING_DATABASE_URL')
  };

  const result = run(
    'dotnet',
    [
      'ef',
      'migrations',
      'has-pending-model-changes',
      '--project',
      'src/Modules/Economy/PetMagic.Modules.Economy.Infrastructure/PetMagic.Modules.Economy.Infrastructure.csproj',
      '--startup-project',
      'src/Modules/Economy/PetMagic.Modules.Economy.Infrastructure/PetMagic.Modules.Economy.Infrastructure.csproj',
      '--context',
      'EconomyDbContext'
    ],
    { env });

  record(
    'ef_pending_model_changes',
    result.status === 0 ? 'passed' : 'failed',
    result.status === 0 ? 'No pending Economy model changes.' : sanitizeOutput(result.stderr || result.stdout));
}

function runSqlInvariantChecks() {
  const result = runPsql(invariantSql());
  if (result.status !== 0) {
    record('sql_invariants', 'failed', sanitizeOutput(result.stderr || result.stdout));
    return;
  }

  let rows;
  try {
    rows = JSON.parse(result.stdout.trim());
  } catch (error) {
    record('sql_invariants', 'failed', `Could not parse SQL JSON output: ${error.message}`);
    return;
  }

  const data = Array.isArray(rows) ? rows[0] : rows;
  evidence.sql = data;

  const hardFailures = [
    ['balance_bucket_mismatches', data.balance_bucket_mismatches],
    ['negative_wallets', data.negative_wallets],
    ['negative_buckets', data.negative_buckets],
    ['wallets_without_bucket_projection', data.wallets_without_bucket_projection],
    ['ledger_default_gaps', data.ledger_default_gaps],
    ['duplicate_source_transaction_ids', data.duplicate_source_transaction_ids],
    ['open_incident_duplicate_keys', data.open_incident_duplicate_keys]
  ].filter(([, value]) => Number(value) !== 0);

  const status = hardFailures.length === 0 ? 'passed' : 'failed';
  const message = status === 'passed'
    ? 'Wallet, bucket, ledger, idempotency, and incident invariants passed.'
    : `Invariant failures: ${hardFailures.map(([name, value]) => `${name}=${value}`).join(', ')}`;

  record('sql_invariants', status, message);

  if (Number(data.unsettled_succeeded_purchases) > 0) {
    record(
      'purchase_settlement_review',
      'blocked',
      `Succeeded purchase orders without pack-purchase ledger: ${data.unsettled_succeeded_purchases}. Review list in SQL evidence before release.`);
  } else {
    record('purchase_settlement_review', 'passed', 'No succeeded purchases missing settlement ledger.');
  }

  if (Number(data.subscription_state_anomalies) > 0) {
    record(
      'subscription_state_review',
      'blocked',
      `Subscription state anomalies: ${data.subscription_state_anomalies}. Review before release.`);
  } else {
    record('subscription_state_review', 'passed', 'No obvious subscription state anomalies.');
  }
}

async function runRuntimeChecks() {
  const apiBaseUrl = process.env.STAGING_API_BASE_URL?.replace(/\/+$/, '');
  if (!apiBaseUrl) {
    record('runtime_health', 'blocked', 'STAGING_API_BASE_URL is missing.');
    record('admin_runtime', 'blocked', 'STAGING_API_BASE_URL is missing.');
    return;
  }

  const health = await fetchJson(`${apiBaseUrl}/health`);
  record(
    'runtime_health',
    health.ok && health.status === 200 ? 'passed' : 'failed',
    health.ok ? `HTTP ${health.status}` : `HTTP ${health.status}: ${health.bodySnippet}`);

  const unauthenticatedAdmin = await fetchRaw(`${apiBaseUrl}/api/admin/economy/incidents`);
  record(
    'admin_unauthenticated_guard',
    [401, 403].includes(unauthenticatedAdmin.status) ? 'passed' : 'failed',
    `HTTP ${unauthenticatedAdmin.status}`);

  const adminToken = process.env.STAGING_ADMIN_AUTH_TOKEN;
  if (!adminToken) {
    record('admin_authenticated_incidents', 'blocked', 'STAGING_ADMIN_AUTH_TOKEN is missing.');
    record('manual_reconciliation_run', 'blocked', 'STAGING_ADMIN_AUTH_TOKEN is missing.');
    return;
  }

  const incidents = await fetchJson(`${apiBaseUrl}/api/admin/economy/incidents`, adminToken);
  record(
    'admin_authenticated_incidents',
    incidents.ok && incidents.status === 200 ? 'passed' : 'failed',
    incidents.ok ? 'Incident list returned HTTP 200.' : `HTTP ${incidents.status}: ${incidents.bodySnippet}`);

  if (boolEnv('ECONOMY_GATE_RUN_RECONCILIATION', false)) {
    const reconciliation = await fetchJson(`${apiBaseUrl}/api/admin/economy/reconciliation/run`, adminToken, 'POST');
    record(
      'manual_reconciliation_run',
      reconciliation.ok && reconciliation.status === 200 ? 'passed' : 'failed',
      reconciliation.ok ? 'Manual reconciliation returned HTTP 200.' : `HTTP ${reconciliation.status}: ${reconciliation.bodySnippet}`);
  } else {
    record('manual_reconciliation_run', 'skipped', 'Set ECONOMY_GATE_RUN_RECONCILIATION=true to execute the admin action.');
  }
}

function runPsql(sql) {
  const command = process.env.STAGING_PSQL_COMMAND || 'psql';
  return run(command, [
    requiredEnv('STAGING_DATABASE_URL'),
    '-v',
    'ON_ERROR_STOP=1',
    '-P',
    'pager=off',
    '-At',
    '-c',
    sql
  ]);
}

function invariantSql() {
  return `
WITH bucket_totals AS (
  SELECT "UserId", COALESCE(SUM("RemainingAmount"), 0)::int AS bucket_balance
  FROM economy_wallet_token_buckets
  GROUP BY "UserId"
), wallet_checks AS (
  SELECT w."UserId", w."Balance", COALESCE(b.bucket_balance, 0) AS bucket_balance
  FROM economy_wallets w
  LEFT JOIN bucket_totals b ON b."UserId" = w."UserId"
), duplicate_source_transactions AS (
  SELECT "SourceProvider", "SourceTransactionId"
  FROM economy_wallet_ledger
  WHERE "SourceProvider" IS NOT NULL AND "SourceTransactionId" IS NOT NULL
  GROUP BY "SourceProvider", "SourceTransactionId"
  HAVING COUNT(*) > 1
), unsettled_purchases AS (
  SELECT p."Id"
  FROM economy_purchase_orders p
  WHERE p."Status" = 'succeeded'
    AND NOT EXISTS (
      SELECT 1
      FROM economy_wallet_ledger l
      WHERE l."UserId" = p."UserId"
        AND l."Source" = 'pack_purchase'
        AND (
          l."Reason" = ('purchase:' || p."Id"::text)
          OR (p."ExternalPaymentId" IS NOT NULL AND l."SourceTransactionId" = p."ExternalPaymentId")
        )
    )
), subscription_anomalies AS (
  SELECT "Id"
  FROM economy_user_subscriptions
  WHERE COALESCE("Status", '') = ''
     OR ("Status" IN ('Active', 'GracePeriod', 'PastDue') AND "CurrentPeriodEndUtc" IS NOT NULL AND "CurrentPeriodEndUtc" < NOW() - INTERVAL '1 day')
), open_incident_duplicate_keys AS (
  SELECT "Type", "DeduplicationKey"
  FROM economy_incidents
  WHERE "Status" = 'Open'
  GROUP BY "Type", "DeduplicationKey"
  HAVING COUNT(*) > 1
), migrations AS (
  SELECT COUNT(*) AS migration_count, MAX("MigrationId") AS latest_migration
  FROM "__EFMigrationsHistory"
)
SELECT json_build_array(json_build_object(
  'migration_count', (SELECT migration_count FROM migrations),
  'latest_migration', (SELECT latest_migration FROM migrations),
  'wallets', (SELECT COUNT(*) FROM economy_wallets),
  'ledger_entries', (SELECT COUNT(*) FROM economy_wallet_ledger),
  'buckets', (SELECT COUNT(*) FROM economy_wallet_token_buckets),
  'legacy_buckets', (SELECT COUNT(*) FROM economy_wallet_token_buckets WHERE "Kind" = 'legacy'),
  'balance_bucket_mismatches', (SELECT COUNT(*) FROM wallet_checks WHERE "Balance" <> bucket_balance),
  'wallets_without_bucket_projection', (SELECT COUNT(*) FROM wallet_checks WHERE "Balance" > 0 AND bucket_balance = 0),
  'negative_wallets', (SELECT COUNT(*) FROM economy_wallets WHERE "Balance" < 0),
  'negative_buckets', (SELECT COUNT(*) FROM economy_wallet_token_buckets WHERE "RemainingAmount" < 0),
  'ledger_default_gaps', (SELECT COUNT(*) FROM economy_wallet_ledger WHERE "TokenKind" IS NULL OR "OperationKind" IS NULL),
  'duplicate_source_transaction_ids', (SELECT COUNT(*) FROM duplicate_source_transactions),
  'unsettled_succeeded_purchases', (SELECT COUNT(*) FROM unsettled_purchases),
  'subscription_state_anomalies', (SELECT COUNT(*) FROM subscription_anomalies),
  'open_incident_duplicate_keys', (SELECT COUNT(*) FROM open_incident_duplicate_keys)
));`;
}

async function fetchJson(url, token, method = 'GET') {
  const response = await fetchRaw(url, token, method);
  return response;
}

async function fetchRaw(url, token, method = 'GET') {
  const headers = token ? { Authorization: `Bearer ${token}` } : {};
  try {
    const response = await fetch(url, { method, headers });
    const text = await response.text();
    return {
      ok: response.ok,
      status: response.status,
      bodySnippet: sanitizeOutput(text).slice(0, 240)
    };
  } catch (error) {
    return {
      ok: false,
      status: 0,
      bodySnippet: error instanceof Error ? error.message : String(error)
    };
  }
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: process.cwd(),
    encoding: 'utf8',
    ...options
  });

  return {
    status: result.status ?? 1,
    stdout: result.stdout ?? '',
    stderr: result.stderr ?? ''
  };
}

function record(name, status, message) {
  checks.push({
    name,
    status,
    message,
    recordedAtUtc: new Date().toISOString()
  });
  console.log(`[${status}] ${name}: ${message}`);
}

function writeEvidence() {
  writeFileSync(evidencePath, `${JSON.stringify(evidence, null, 2)}\n`);
  console.log(`Evidence written to ${evidencePath}`);
}

function loadLocalEnvFile(path) {
  if (!existsSync(path)) {
    return;
  }

  const content = readFileSync(path, 'utf8');
  for (const line of content.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#') || !trimmed.includes('=')) {
      continue;
    }

    const index = trimmed.indexOf('=');
    const key = trimmed.slice(0, index).trim();
    const value = trimmed.slice(index + 1).trim().replace(/^"|"$/g, '');
    if (key && process.env[key] === undefined) {
      process.env[key] = value;
    }
  }
}

function requireEnv(name) {
  const value = process.env[name]?.trim();
  if (!value) {
    fail(`Missing required env: ${name}`);
  }

  return value;
}

function boolEnv(name, fallback) {
  const value = process.env[name];
  if (value === undefined || value === '') {
    return fallback;
  }

  return ['1', 'true', 'yes', 'on'].includes(value.trim().toLowerCase());
}

function fail(message) {
  throw new Error(message);
}

function sanitizeOutput(value) {
  return String(value)
    .replace(/(Password=)[^;\s]+/gi, '$1***')
    .replace(/(Bearer\s+)[A-Za-z0-9._-]+/gi, '$1***')
    .replace(/(postgres(?:ql)?:\/\/[^:\s]+:)[^@\s]+/gi, '$1***');
}

function anonymizeDatabaseUrl(value) {
  if (!value) {
    return null;
  }

  return sanitizeOutput(value)
    .replace(/Host=([^;]+)/i, 'Host=$1')
    .replace(/Database=([^;]+)/i, 'Database=$1');
}

function anonymizeUrl(value) {
  if (!value) {
    return null;
  }

  try {
    const url = new URL(value);
    return `${url.protocol}//${url.host}`;
  } catch {
    return sanitizeOutput(value);
  }
}

function formatTimestamp(date) {
  return date.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z');
}

function printHelp() {
  console.log(`
Usage:
  node scripts/qa/run-economy-staging-infra-gate.mjs

Required:
  STAGING_DATABASE_URL                  PostgreSQL connection string for staging/prod-like clone.

Optional runtime checks:
  STAGING_API_BASE_URL                  Staging backend base URL.
  STAGING_ADMIN_AUTH_TOKEN              Admin JWT for authenticated admin probes.
  ECONOMY_GATE_RUN_RECONCILIATION=true  Execute POST /api/admin/economy/reconciliation/run.

Optional migration apply:
  ECONOMY_GATE_RUN_MIGRATIONS=true      Run dotnet ef database update for Economy.
  ECONOMY_GATE_BACKUP_CONFIRMED=true    Required with ECONOMY_GATE_RUN_MIGRATIONS=true.

Other:
  ECONOMY_GATE_ENV_FILE                 Env file path, defaults to STAGING_ENV_FILE or .env.staging.local.
  STAGING_PSQL_COMMAND                  psql command, defaults to psql.
  ECONOMY_GATE_ARTIFACT_DIR             Evidence output directory.
`);
}
