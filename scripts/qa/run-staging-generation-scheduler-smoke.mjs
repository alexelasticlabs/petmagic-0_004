#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const png1x1 = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAANSURBVBhXY/j///9/AAn7A/0FQ0XKAAAAAElFTkSuQmCC',
  'base64');

const statusNames = new Map([
  ['1', 'queued'],
  ['2', 'processing'],
  ['3', 'completed'],
  ['4', 'failed'],
  ['5', 'cancelled'],
  ['6', 'retrying'],
  ['7', 'submittingToProvider'],
  ['8', 'providerQueued'],
  ['9', 'providerProcessing'],
  ['10', 'importingMedia']
]);

if (process.argv.includes('--help') || process.argv.includes('-h')) {
  printHelp();
  process.exit(0);
}

const smokeMode = resolveSmokeMode();
const envFilePath = process.env.STAGING_ENV_FILE || '.env.staging.local';
loadLocalEnvFile(envFilePath);
const missingInputs = findMissingRequiredInputs();
if (missingInputs.length > 0) {
  console.error(`Missing required staging input names: ${missingInputs.join(', ')}`);
  console.error('Load them from .env.staging.local, STAGING_ENV_FILE, CI secrets, 1Password, or Vault. Values were not printed.');
  process.exit(1);
}

const startedAt = new Date();
const runId = process.env.STAGING_SMOKE_RUN_ID || `staging-generation-smoke-${formatTimestamp(startedAt)}`;
const artifactDir = process.env.STAGING_ARTIFACT_DIR || join('artifacts', 'staging-generation-scheduler-smoke', runId);
mkdirSync(artifactDir, { recursive: true });

const apiBaseUrl = requiredEnv('STAGING_API_BASE_URL').replace(/\/$/, '');
const databaseUrl = requiredEnv('STAGING_DATABASE_URL');
const imageTemplateId = requiredEnv('STAGING_IMAGE_TEMPLATE_ID');
const videoTemplateId = requiredEnv('STAGING_VIDEO_TEMPLATE_ID');
const failingTemplateId = process.env.STAGING_FAILING_TEMPLATE_ID || '';
const failingTemplateMediaType = (process.env.STAGING_FAILING_TEMPLATE_MEDIA_TYPE || 'image').toLowerCase();
const cancelTemplateId = process.env.STAGING_CANCEL_TEMPLATE_ID || videoTemplateId;
const cancelTemplateMediaType = (process.env.STAGING_CANCEL_MEDIA_TYPE || 'video').toLowerCase();
const freeTokens = parseList(requiredEnvAny('STAGING_FREE_AUTH_TOKENS', ['STAGING_FREE_JWT']));
const premiumTokens = parseList(requiredEnvAny('STAGING_PREMIUM_AUTH_TOKENS', ['STAGING_PREMIUM_JWT']));
const adminToken = process.env.STAGING_ADMIN_AUTH_TOKEN || premiumTokens[0] || freeTokens[0];
const psqlCommand = process.env.STAGING_PSQL_COMMAND || 'psql';
const smokeTotal = intEnv('STAGING_SMOKE_TOTAL', smokeMode === 'local' ? 20 : 60);
const minExistingGenerations = intEnv('STAGING_MIN_EXISTING_GENERATIONS', smokeMode === 'local' ? 0 : 100);
const submitConcurrency = intEnv('STAGING_SUBMIT_CONCURRENCY', 8);
const pollAttempts = intEnv('STAGING_POLL_ATTEMPTS', 60);
const pollDelayMs = intEnv('STAGING_POLL_DELAY_MS', 1000);
const expectFailedStatus = boolEnv('STAGING_EXPECT_FAILED_STATUS', false);
const requireFailedStatus = expectFailedStatus || Boolean(failingTemplateId);
const allowIncomplete = boolEnv('STAGING_ALLOW_INCOMPLETE', false);
const realtimeGrowthBudget = intEnv('STAGING_REALTIME_GROWTH_BUDGET', Math.max(200, smokeTotal * 6));
const sourceBytes = process.env.STAGING_SOURCE_IMAGE_PATH
  ? readFileSync(process.env.STAGING_SOURCE_IMAGE_PATH)
  : png1x1;

const checks = [];
const createdGenerations = [];
const generationAuthTokens = new Map();
const rejectedResponses = [];
const matrixResponses = [];
const runtimeSnapshots = {};
const evidence = {
  runId,
  startedAtUtc: startedAt.toISOString(),
  mode: smokeMode,
  warning: smokeMode === 'local'
    ? 'LOCAL DEVELOPMENT SMOKE ONLY - NOT STAGING OR PRODUCTION EVIDENCE'
    : null,
  apiBaseUrl: anonymize(apiBaseUrl),
  imageTemplateId,
  videoTemplateId,
  failingTemplateId,
  failingTemplateMediaType,
  cancelTemplateMediaType,
  envFileLoaded: existsSync(envFilePath),
  operator: {
    apiProcess: anonymize(process.env.STAGING_API_PROCESS_ID),
    workerProcess: anonymize(process.env.STAGING_WORKER_PROCESS_ID),
    migrationTooling: sanitizeLabel(process.env.STAGING_MIGRATION_TOOLING_LABEL)
  },
  minExistingGenerations,
  smokeTotal,
  submitConcurrency,
  pollAttempts,
  pollDelayMs,
  checks,
  createdGenerations,
  rejectedResponses,
  sql: {},
  prometheus: {}
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
  console.log(`[${runId}] staging generation scheduler smoke started`);
  if (smokeMode === 'local') {
    console.log('LOCAL DEVELOPMENT SMOKE ONLY - NOT STAGING OR PRODUCTION EVIDENCE');
  }
  verifyTokenSubjects();
  await runPreflightChecks();

  const sseProbe = startSseProbe();
  await sseProbe.connectedPromise;

  const before = collectDatabaseSnapshot('before');
  evidence.sql.before = before;

  verifyMigrationsAndConcurrentIndexes();
  verifyConcurrentMigrationSource();

  const waitTooLongProbe = await tryProduceWaitTooLong(before);
  evidence.waitTooLongProbe = waitTooLongProbe;

  const cancelProbe = await runCancelProbe();
  evidence.cancelProbe = cancelProbe;

  await createGenerationMatrix();
  const failingProbe = await runFailingProbe();
  evidence.failingProbe = failingProbe;
  await pollCreatedGenerations();
  await delay(Math.min(5000, Math.max(1000, pollDelayMs)));
  sseProbe.stop();
  evidence.sse = sseProbe.summary();

  const after = collectDatabaseSnapshot('after');
  evidence.sql.after = after;
  verifyDatabaseOutcomes(before, after, waitTooLongProbe, cancelProbe, failingProbe, sseProbe);

  await queryPrometheus();

  finish(hasFailedChecks() && !allowIncomplete ? 1 : 0);
}

async function runPreflightChecks() {
  addCheck(
    'mode.local_development_warning_present',
    smokeMode !== 'local' || evidence.warning === 'LOCAL DEVELOPMENT SMOKE ONLY - NOT STAGING OR PRODUCTION EVIDENCE',
    evidence.warning || 'staging mode');
  addCheck(
    'env.local_file_or_process_env_present',
    existsSync(envFilePath) || hasAnyStagingProcessEnv(),
    existsSync(envFilePath) ? `${envFilePath} loaded` : 'using process environment');
  addCheck(
    'env.api_and_worker_process_labels_are_distinct',
    process.env.STAGING_API_PROCESS_ID !== process.env.STAGING_WORKER_PROCESS_ID,
    'sanitized API and worker labels are distinct');
  addCheck(
    'env.production_migration_tooling_declared',
    Boolean(process.env.STAGING_MIGRATION_TOOLING_LABEL),
    `tooling=${sanitizeLabel(process.env.STAGING_MIGRATION_TOOLING_LABEL)}`);
  addCheck(
    'env.not_local_development_targets',
    smokeMode === 'local'
      ? boolEnv('STAGING_ALLOW_LOCALHOST', false) && (isLocalApiTarget(apiBaseUrl) || isLocalDatabaseTarget(databaseUrl))
      : (!boolEnv('STAGING_ALLOW_LOCALHOST', false) && !isLocalApiTarget(apiBaseUrl) && !isLocalDatabaseTarget(databaseUrl)),
    smokeMode === 'local' ? 'local mode allows localhost/local compose' : 'staging mode rejects localhost/local compose');

  if (smokeMode === 'local') {
    verifyLocalDockerComposeEnvironment();
  }

  const health = await fetchWithTimeout(`${apiBaseUrl}/health`, { method: 'GET' }, 10000);
  evidence.preflight = {
    apiHealthStatus: health.status,
    databaseConnectivity: null,
    existingGenerationRows: null
  };
  addCheck(
    'preflight.api_health_available',
    health.ok,
    `status=${health.status}`);

  const dbConnectivity = queryScalar('SELECT 1;');
  evidence.preflight.databaseConnectivity = dbConnectivity === '1';
  addCheck('preflight.database_connectivity', dbConnectivity === '1', `SELECT 1 -> ${dbConnectivity}`);

  const existingGenerations = Number(queryScalar('SELECT count(*) FROM templates_generation_jobs;'));
  evidence.preflight.existingGenerationRows = existingGenerations;
  addCheck(
    'preflight.database_has_production_like_generation_rows',
    existingGenerations >= minExistingGenerations,
    `existing=${existingGenerations}, minimum=${minExistingGenerations}`);

  verifyMigrationLogEvidence();
}

function verifyTokenSubjects() {
  const freeUsers = freeTokens.map(decodeUserIdFromJwt);
  const premiumUsers = premiumTokens.map(decodeUserIdFromJwt);
  evidence.freeUserIds = freeUsers.map(anonymize);
  evidence.premiumUserIds = premiumUsers.map(anonymize);
  addCheck('tokens.free_subjects_are_guid', freeUsers.every(Boolean), JSON.stringify(evidence.freeUserIds));
  addCheck('tokens.premium_subjects_are_guid', premiumUsers.every(Boolean), JSON.stringify(evidence.premiumUserIds));
  addCheck(
    'tokens.enough_users_for_queue_smoke',
    freeTokens.length + premiumTokens.length >= (smokeMode === 'local' ? 2 : 4),
    `free=${freeTokens.length}, premium=${premiumTokens.length}; more users make wait-too-long evidence stronger`);
}

function collectDatabaseSnapshot(label) {
  const snapshot = {};
  snapshot.generatedAtUtc = new Date().toISOString();
  const walletsByUserId = new Map(
    [...freeTokens, ...premiumTokens]
      .map(decodeUserIdFromJwt)
      .filter(Boolean)
      .map(userId => [userId, Number(queryScalar(`
        SELECT COALESCE((SELECT "Balance" FROM economy_wallets WHERE "UserId" = ${sqlString(userId)}::uuid), 0);
      `))]));
  snapshot.wallets = Object.fromEntries(
    [...walletsByUserId.entries()].map(([userId, balance]) => [anonymize(userId), balance]));
  snapshot.realtimeEvents = queryRows(`
    SELECT count(*)::text,
           COALESCE(to_char(min("CreatedAtUtc"), 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'), ''),
           COALESCE(to_char(max("CreatedAtUtc"), 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'), '')
    FROM templates_realtime_events;
  `)[0] || ['0', '', ''];
  snapshot.statusCountsSinceRun = queryRows(`
    SELECT "Status"::text, "QueueMediaType", "QueueTier", count(*)::text
    FROM templates_generation_jobs
    WHERE "CreatedAtUtc" >= ${sqlString(startedAt.toISOString())}::timestamptz
    GROUP BY "Status", "QueueMediaType", "QueueTier"
    ORDER BY "QueueMediaType", "QueueTier", "Status";
  `).map(row => ({
    status: statusNames.get(row[0]) || row[0],
    mediaType: row[1],
    tier: row[2],
    count: Number(row[3])
  }));
  snapshot.duplicateGenerationRefundLedger = queryRows(`
    SELECT "UserId"::text, "Reason", count(*)::text
    FROM economy_wallet_ledger
    WHERE "Source" = 'generation_refund'
    GROUP BY "UserId", "Reason"
    HAVING count(*) > 1
    ORDER BY count(*) DESC, "UserId", "Reason";
  `).map(row => ({ userId: anonymize(row[0]), reason: row[1], count: Number(row[2]) }));
  runtimeSnapshots[label] = { walletsByUserId };
  console.log(`[${runId}] collected ${label} DB snapshot`);
  return snapshot;
}

function verifyMigrationsAndConcurrentIndexes() {
  const migrationRows = queryRows(`
    SELECT "MigrationId"
    FROM "__EFMigrationsHistory"
    WHERE "MigrationId" IN (
      '20260630230458_AddTemplateRealtimeEvents',
      '20260630234809_AddGenerationSchedulerQueueFields',
      '20260630230638_AddGenerationRefundLedgerIdempotencyIndex'
    )
    ORDER BY "MigrationId";
  `).flat();
  evidence.sql.appliedMigrations = migrationRows;
  addCheck(
    'migrations.required_scheduler_migrations_applied',
    migrationRows.includes('20260630230458_AddTemplateRealtimeEvents')
      && migrationRows.includes('20260630234809_AddGenerationSchedulerQueueFields')
      && migrationRows.includes('20260630230638_AddGenerationRefundLedgerIdempotencyIndex'),
    migrationRows.join(', '));

  const indexRows = queryRows(`
    SELECT c.relname, i.indisvalid::text, i.indisready::text
    FROM pg_class c
    JOIN pg_index i ON i.indexrelid = c.oid
    WHERE c.relname IN (
      'IX_tgj_Status_QueueMediaType_QueueTier_QueuedAtUtc',
      'IX_tgj_Status_QueueMediaType_StartedAtUtc'
    )
    ORDER BY c.relname;
  `).map(row => ({ name: row[0], valid: parsePgBool(row[1]), ready: parsePgBool(row[2]) }));
  evidence.sql.concurrentIndexes = indexRows;
  addCheck(
    'migrations.concurrent_indexes_exist_and_are_valid',
    indexRows.length === 2 && indexRows.every(index => index.valid && index.ready),
    JSON.stringify(indexRows));
}

function verifyConcurrentMigrationSource() {
  const migrationSource = readFileSync(
    'src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/Data/Migrations/20260630234809_AddGenerationSchedulerQueueFields.cs',
    'utf8');
  const concurrentlyCount = (migrationSource.match(/CONCURRENTLY/g) || []).length;
  const suppressCount = (migrationSource.match(/suppressTransaction:\s*true/g) || []).length;
  evidence.concurrentMigrationSource = { concurrentlyCount, suppressCount };
  addCheck(
    'migrations.concurrent_index_sql_suppresses_transaction',
    concurrentlyCount >= 4 && suppressCount >= 4,
    `CONCURRENTLY=${concurrentlyCount}, suppressTransaction=${suppressCount}`);
}

async function tryProduceWaitTooLong(before) {
  const attempts = [];
  const tokens = [...freeTokens].reverse().concat([...premiumTokens].reverse());
  const maxAttempts = Math.max(8, Math.min(smokeTotal, tokens.length * 4));
  const jobs = [];
  for (let i = 0; i < maxAttempts; i += 1) {
    const token = tokens[i % tokens.length];
    jobs.push(() => submitGeneration(token, videoTemplateId, `wait-probe-${i}`));
  }

  for (const batch of chunk(jobs, submitConcurrency)) {
    const results = await Promise.all(batch.map(fn => fn()));
    attempts.push(...results);
    const waitTooLong = results.find(isWaitTooLongResponse) || attempts.find(isWaitTooLongResponse);
    if (waitTooLong) {
      rejectedResponses.push(summarizeResponse(waitTooLong));
      break;
    }
  }

  const rejected = attempts.find(isWaitTooLongResponse);
  if (rejected) {
    const userId = decodeUserIdFromJwt(rejected.token);
    const beforeBalance = runtimeSnapshots.before?.walletsByUserId.get(userId) ?? 0;
    const afterBalance = Number(queryScalar(`
      SELECT COALESCE((SELECT "Balance" FROM economy_wallets WHERE "UserId" = ${sqlString(userId)}::uuid), 0);
    `));
    const rejectedJobCount = Number(queryScalar(`
      SELECT count(*)
      FROM templates_generation_jobs
      WHERE "UserId" = ${sqlString(userId)}::uuid
        AND "IdempotencyKey" = ${sqlString(rejected.idempotencyKey)};
    `));
    addCheck(
      'billing.wait_too_long_does_not_spend_credits',
      beforeBalance === afterBalance,
      `user=${anonymize(userId)}, before=${beforeBalance}, after=${afterBalance}`);
    addCheck(
      'api.wait_too_long_does_not_create_active_job',
      rejectedJobCount === 0 && !rejected.body?.generationId,
      `idempotency=${anonymize(rejected.idempotencyKey)}, jobCount=${rejectedJobCount}, generationIdPresent=${Boolean(rejected.body?.generationId)}`);
    validateWaitTooLongMetadata(rejected);
  }

  addCheck(
    'api.generation_wait_too_long_observed',
    Boolean(rejected),
    rejected ? JSON.stringify(summarizeResponse(rejected)) : 'No GENERATION_WAIT_TOO_LONG response observed.');
  return { attempts: attempts.map(summarizeResponse), rejected: rejected ? summarizeResponse(rejected) : null };
}

async function runCancelProbe() {
  const token = premiumTokens[0] || freeTokens[0];
  const created = await submitGeneration(token, cancelTemplateId, 'cancel-probe');
  if (created.status !== 202 || !created.body?.generationId) {
    addCheck('api.cancel_probe_generation_accepted', false, JSON.stringify(summarizeResponse(created)));
    return { created: summarizeResponse(created), cancelled: null, duplicateCancel: null };
  }

  createdGenerations.push({
    generationId: created.body.generationId,
    tokenLabel: 'cancel-probe',
    mediaType: cancelTemplateMediaType,
    tier: token === premiumTokens[0] ? 'premium' : 'free'
  });
  generationAuthTokens.set(created.body.generationId, token);

  const firstCancel = await postJson(
    `/api/templates/generations/${created.body.generationId}/cancel`,
    token,
    {});
  const duplicateCancel = await postJson(
    `/api/templates/generations/${created.body.generationId}/cancel`,
    token,
    {});

  const userId = decodeUserIdFromJwt(token);
  const refundReason = `generation_refund:${created.body.generationId.replaceAll('-', '')}`;
  const cancelJobRow = queryRows(`
    SELECT "TokenCost"::text,
           ("ChargedAtUtc" IS NOT NULL)::text,
           ("RefundedAtUtc" IS NOT NULL)::text,
           "Status"::text
    FROM templates_generation_jobs
    WHERE "Id" = ${sqlString(created.body.generationId)}::uuid;
  `)[0] || ['0', 'f', 'f', ''];
  const cancelJob = {
    tokenCost: Number(cancelJobRow[0]),
    charged: parsePgBool(cancelJobRow[1]),
    refunded: parsePgBool(cancelJobRow[2]),
    status: statusNames.get(cancelJobRow[3]) || cancelJobRow[3]
  };
  const refundCount = Number(queryScalar(`
    SELECT count(*)
    FROM economy_wallet_ledger
    WHERE "UserId" = ${sqlString(userId)}::uuid
      AND "Source" = 'generation_refund'
      AND "Reason" = ${sqlString(refundReason)};
  `));

  addCheck(
    'api.cancel_queued_returns_success_or_clear_race',
    firstCancel.status === 200 || firstCancel.status === 409,
    JSON.stringify(summarizeResponse(firstCancel)));
  addCheck(
    'api.cancel_queued_response_has_refund_flag',
    firstCancel.status !== 200 || typeof firstCancel.body?.refunded === 'boolean',
    JSON.stringify(summarizeResponse(firstCancel)));
  addCheck(
    'billing.cancel_queued_charged_job_refunded_once',
    firstCancel.status !== 200
      || cancelJob.tokenCost <= 0
      || (cancelJob.charged && cancelJob.refunded && firstCancel.body?.refunded === true && refundCount === 1),
    `generation=${created.body.generationId}, tokenCost=${cancelJob.tokenCost}, charged=${cancelJob.charged}, refunded=${cancelJob.refunded}, responseRefunded=${firstCancel.body?.refunded}, refundCount=${refundCount}`);
  addCheck(
    'billing.cancel_queued_refund_not_duplicated',
    refundCount <= 1,
    `generation=${created.body.generationId}, refundCount=${refundCount}`);

  return {
    created: summarizeResponse(created),
    cancelled: summarizeResponse(firstCancel),
    duplicateCancel: summarizeResponse(duplicateCancel),
    cancelJob,
    refundReason,
    refundCount
  };
}

async function createGenerationMatrix() {
  const cohorts = [
    { mediaType: 'image', tier: 'free', templateId: imageTemplateId, tokens: freeTokens },
    { mediaType: 'video', tier: 'free', templateId: videoTemplateId, tokens: freeTokens },
    { mediaType: 'image', tier: 'premium', templateId: imageTemplateId, tokens: premiumTokens },
    { mediaType: 'video', tier: 'premium', templateId: videoTemplateId, tokens: premiumTokens }
  ];
  const perCohort = Math.max(1, Math.floor(smokeTotal / cohorts.length));
  const jobs = [];
  for (const cohort of cohorts) {
    for (let i = 0; i < perCohort; i += 1) {
      const token = cohort.tokens[i % cohort.tokens.length];
      const label = `${cohort.mediaType}-${cohort.tier}-${i}`;
      jobs.push(async () => {
        const result = await submitGeneration(token, cohort.templateId, label);
        const summarized = {
          ...summarizeResponse(result),
          mediaType: cohort.mediaType,
          tier: cohort.tier,
          idempotencyKey: anonymize(result.idempotencyKey)
        };
        matrixResponses.push(summarized);
        if (result.status === 202 && result.body?.generationId) {
          generationAuthTokens.set(result.body.generationId, token);
          createdGenerations.push({
            generationId: result.body.generationId,
            mediaType: cohort.mediaType,
            tier: cohort.tier,
            tokenLabel: label,
            idempotencyKey: anonymize(result.idempotencyKey),
            estimatedWaitSeconds: result.body?.estimatedWaitSeconds ?? null,
            queuePosition: result.body?.queuePosition ?? null,
            priorityClass: result.body?.priorityClass ?? null
          });
        } else {
          rejectedResponses.push(summarized);
          if (isPrechargeRejection(result)) {
            verifyRejectedBeforeCharge(result, cohort);
          }

          if (isWaitTooLongResponse(result)) {
            validateWaitTooLongMetadata(result);
          }
        }
      });
    }
  }

  for (const batch of chunk(jobs, submitConcurrency)) {
    await Promise.all(batch.map(fn => fn()));
  }

  addCheck(
    'api.created_50_to_100_fake_generation_attempts',
    smokeMode === 'local' ? smokeTotal > 0 : smokeTotal >= 50 && smokeTotal <= 100,
    `configured=${smokeTotal}, accepted=${createdGenerations.length}, rejected=${rejectedResponses.length}`);
  addCheck(
    'api.accepted_generation_observed',
    createdGenerations.length > 0,
    `accepted=${createdGenerations.length}`);
  verifyMatrixLaneResponses();
  console.log(`[${runId}] generation matrix submitted: accepted=${createdGenerations.length}, rejected=${rejectedResponses.length}`);
}

async function runFailingProbe() {
  if (!failingTemplateId) {
    addCheck(
      'api.failed_generation_probe_configured',
      !expectFailedStatus,
      'Set STAGING_FAILING_TEMPLATE_ID to force a Fake AI provider failure.');
    return { configured: false };
  }

  const token = premiumTokens[0] || freeTokens[0];
  const created = await submitGeneration(token, failingTemplateId, 'failing-probe');
  if (created.status !== 202 || !created.body?.generationId) {
    addCheck('api.failed_generation_probe_accepted', false, JSON.stringify(summarizeResponse(created)));
    return { configured: true, created: summarizeResponse(created), poll: [] };
  }

  const generation = {
    generationId: created.body.generationId,
    tokenLabel: 'failing-probe',
    mediaType: failingTemplateMediaType,
    tier: token === premiumTokens[0] ? 'premium' : 'free',
    expectedStatus: 'failed'
  };
  createdGenerations.push(generation);

  const poll = await pollGeneration(token, created.body.generationId);
  generation.poll = poll;
  const finalStatus = finalObservedStatus(poll);
  addCheck(
    'api.failed_generation_probe_reaches_failed_status',
    finalStatus === 'failed',
    `generation=${created.body.generationId}, finalStatus=${finalStatus || 'unknown'}`);

  const failureRefund = inspectGenerationRefund(created.body.generationId);
  addCheck(
    'billing.failed_generation_refund_safe',
    finalStatus !== 'failed'
      || failureRefund.tokenCost <= 0
      || (failureRefund.charged && failureRefund.refunded && failureRefund.refundLedgerRows === 1),
    `generation=${created.body.generationId}, tokenCost=${failureRefund.tokenCost}, charged=${failureRefund.charged}, refunded=${failureRefund.refunded}, refundRows=${failureRefund.refundLedgerRows}`);
  addCheck(
    'billing.failed_generation_refund_not_duplicated',
    failureRefund.refundLedgerRows <= 1,
    `generation=${created.body.generationId}, refundRows=${failureRefund.refundLedgerRows}`);

  return { configured: true, created: summarizeResponse(created), poll, finalStatus, failureRefund };
}

async function pollCreatedGenerations() {
  await Promise.all(createdGenerations.map(async item => {
    const token = generationAuthTokens.get(item.generationId) || adminToken;
    item.poll = await pollGeneration(token, item.generationId);
  }));
}

function verifyDatabaseOutcomes(before, after, waitTooLongProbe, cancelProbe, failingProbe, sseProbe) {
  const createdRows = queryCreatedGenerationRows();
  evidence.sql.createdGenerationRows = createdRows;
  const statuses = new Set(after.statusCountsSinceRun.map(row => row.status));
  const mediaTiers = new Set(after.statusCountsSinceRun.map(row => `${row.mediaType}:${row.tier}`));
  addCheck('db.status_cancelled_observed', statuses.has('cancelled'), JSON.stringify(after.statusCountsSinceRun));
  addCheck('db.status_completed_observed', statuses.has('completed'), JSON.stringify(after.statusCountsSinceRun));
  addCheck(
    'db.status_failed_observed',
    !requireFailedStatus || statuses.has('failed'),
    requireFailedStatus ? JSON.stringify(after.statusCountsSinceRun) : 'not required unless STAGING_FAILING_TEMPLATE_ID or STAGING_EXPECT_FAILED_STATUS=true');
  for (const mediaType of ['image', 'video']) {
    for (const tier of ['free', 'premium']) {
      const mediaTier = `${mediaType}:${tier}`;
      addCheck(
        `db.media_tier_${mediaType}_${tier}_observed`,
        mediaTiers.has(mediaTier) || laneHasPrechargeRejection(mediaType, tier),
        `dbObserved=${mediaTiers.has(mediaTier)}, prechargeRejected=${laneHasPrechargeRejection(mediaType, tier)}, statusCounts=${JSON.stringify(after.statusCountsSinceRun)}`);
    }
  }
  addCheck(
    'billing.no_duplicate_generation_refund_ledger_rows',
    after.duplicateGenerationRefundLedger.length === 0,
    JSON.stringify(after.duplicateGenerationRefundLedger));

  const beforeRealtime = Number(before.realtimeEvents[0]);
  const afterRealtime = Number(after.realtimeEvents[0]);
  const runPersistedEvents = countPersistedEventsForCreatedRows(createdRows);
  addCheck(
    'realtime.events_growth_bounded',
    afterRealtime - beforeRealtime <= realtimeGrowthBudget,
    `before=${beforeRealtime}, after=${afterRealtime}, growth=${afterRealtime - beforeRealtime}, budget=${realtimeGrowthBudget}`);
  addCheck(
    'realtime.persisted_events_created',
    runPersistedEvents > 0,
    `before=${beforeRealtime}, after=${afterRealtime}, persistedEventsForRun=${runPersistedEvents}`);

  verifyPriorityEvidence(createdRows);
  verifyProviderPipelineEvidence(createdRows);
  verifySseEvidence(sseProbe, createdRows);

  evidence.lifecycleSummary = {
    statuses: [...statuses],
    mediaTiers: [...mediaTiers],
    waitTooLongObserved: Boolean(waitTooLongProbe.rejected),
    failedProbeFinalStatus: failingProbe.finalStatus,
    cancelRefundCount: cancelProbe.refundCount
  };
}

async function queryPrometheus() {
  const base = process.env.STAGING_PROMETHEUS_BASE_URL;
  if (!base) {
    addCheck(
      'prometheus.configured',
      smokeMode === 'local',
      smokeMode === 'local'
        ? 'local Prometheus is optional and STAGING_PROMETHEUS_BASE_URL is not set.'
        : 'STAGING_PROMETHEUS_BASE_URL is not set.');
    return;
  }

  const queries = {
    queueDepthP95: 'histogram_quantile(0.95, sum by (le)(rate(generation_queue_depth_bucket[5m])))',
    activeJobsP95: 'histogram_quantile(0.95, sum by (le, media_type, tier, lane)(rate(generation_active_jobs_bucket[5m])))',
    oldestQueuedAgeP95: 'histogram_quantile(0.95, sum by (le)(rate(generation_oldest_queued_job_age_seconds_bucket[5m])))',
    rejectedJobsRate: 'sum(rate(generation_jobs_rejected_total[10m]))',
    cancelledJobs15m: 'increase(generation_jobs_cancelled_total[15m])',
    refundedJobs15m: 'increase(generation_jobs_refunded_total[15m])',
    duplicateRefundAttempts15m: 'increase(generation_duplicate_refund_attempts_total[15m])',
    falTimeouts15m: 'increase(generation_fal_timeouts_total[15m])',
    sseDeliveryFailures15m: 'increase(generation_sse_delivery_failures_total[15m])'
  };

  for (const [name, query] of Object.entries(queries)) {
    const response = await fetch(`${base.replace(/\/$/, '')}/api/v1/query?query=${encodeURIComponent(query)}`);
    const body = await response.json().catch(() => null);
    evidence.prometheus[name] = { status: response.status, body };
    addCheck(
      `prometheus.${name}.query_success`,
      response.ok && body?.status === 'success' && Array.isArray(body?.data?.result) && body.data.result.length > 0,
      JSON.stringify(body));
  }
}

async function submitGeneration(token, templateId, label) {
  const form = new FormData();
  form.set('sourceImage', new Blob([sourceBytes], { type: 'image/png' }), `${runId}-${label}.png`);
  const idempotencyKey = `${runId}-${label}-${Date.now()}`;
  const response = await fetch(`${apiBaseUrl}/api/templates/${templateId}/generations`, {
    method: 'POST',
    body: form,
    headers: {
      Authorization: `Bearer ${token}`,
      'Idempotency-Key': idempotencyKey
    }
  });
  const body = await parseBody(response);
  return { status: response.status, body, token, label, idempotencyKey };
}

async function pollGeneration(token, generationId) {
  const observations = [];
  for (let attempt = 0; attempt < pollAttempts; attempt += 1) {
    const response = await fetch(`${apiBaseUrl}/api/templates/generations/${generationId}`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    const body = await parseBody(response);
    const status = String(body?.status || '').toLowerCase();
    observations.push({ httpStatus: response.status, status });
    if (['completed', 'failed', 'cancelled'].includes(status)) {
      return observations;
    }
    await delay(pollDelayMs);
  }
  return observations;
}

async function postJson(path, token, payload) {
  const response = await fetch(`${apiBaseUrl}${path}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(payload)
  });
  const body = await parseBody(response);
  return { status: response.status, body };
}

async function parseBody(response) {
  const text = await response.text();
  if (!text) {
    return null;
  }
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

function isWaitTooLongResponse(response) {
  const code = response.body?.code || response.body?.title || response.body?.extensions?.code;
  return response.status === 503 && code === 'GENERATION_WAIT_TOO_LONG';
}

function isPrechargeRejection(response) {
  const code = response.body?.code || response.body?.title || response.body?.extensions?.code;
  return isWaitTooLongResponse(response)
    || (response.status === 429 && code === 'ACTIVE_GENERATION_LIMIT_REACHED');
}

function summarizeResponse(response) {
  const body = response.body || {};
  const extensions = body.extensions || {};
  return {
    status: response.status,
    label: response.label,
    generationId: body.generationId,
    title: body.title,
    code: body.code || extensions.code,
    detail: body.detail,
    mediaType: body.mediaType || extensions.mediaType,
    tier: body.tier || extensions.tier,
    estimatedWaitSeconds: body.estimatedWaitSeconds ?? extensions.estimatedWaitSeconds,
    maxAllowedWaitSeconds: body.maxAllowedWaitSeconds ?? extensions.maxAllowedWaitSeconds,
    retryAfterSeconds: body.retryAfterSeconds ?? extensions.retryAfterSeconds,
    canRetry: body.canRetry ?? extensions.canRetry,
    canUpgradeForPriority: body.canUpgradeForPriority ?? extensions.canUpgradeForPriority,
    queuePosition: body.queuePosition,
    priorityClass: body.priorityClass
  };
}

function validateWaitTooLongMetadata(response) {
  const summarized = summarizeResponse(response);
  const requiredFields = [
    'code',
    'mediaType',
    'tier',
    'estimatedWaitSeconds',
    'maxAllowedWaitSeconds',
    'retryAfterSeconds',
    'canRetry',
    'canUpgradeForPriority'
  ];
  const missing = requiredFields.filter(field => summarized[field] === undefined || summarized[field] === null);
  addCheck(
    `api.wait_too_long_metadata_complete.${response.label || 'probe'}`,
    missing.length === 0 && summarized.code === 'GENERATION_WAIT_TOO_LONG',
    missing.length === 0 ? JSON.stringify(summarized) : `missing=${missing.join(',')}`);
}

function verifyRejectedBeforeCharge(response, cohort) {
  const userId = decodeUserIdFromJwt(response.token);
  const jobCount = Number(queryScalar(`
    SELECT count(*)
    FROM templates_generation_jobs
    WHERE "UserId" = ${sqlString(userId)}::uuid
      AND "IdempotencyKey" = ${sqlString(response.idempotencyKey)};
  `));
  addCheck(
    `api.rejected_before_charge_no_active_job.${cohort.mediaType}.${cohort.tier}.${response.label}`,
    jobCount === 0 && !response.body?.generationId,
    `user=${anonymize(userId)}, idempotency=${anonymize(response.idempotencyKey)}, jobCount=${jobCount}, generationIdPresent=${Boolean(response.body?.generationId)}`);
}

function verifyMatrixLaneResponses() {
  for (const mediaType of ['image', 'video']) {
    for (const tier of ['free', 'premium']) {
      const laneResponses = matrixResponses.filter(response => response.mediaType === mediaType && response.tier === tier);
      const accepted = laneResponses.some(response => response.status === 202 && response.generationId);
      const waitRejected = laneResponses.some(response => response.status === 503 && response.code === 'GENERATION_WAIT_TOO_LONG');
      const activeLimitRejected = laneResponses.some(response => response.status === 429 && response.code === 'ACTIVE_GENERATION_LIMIT_REACHED');
      const expected = accepted || waitRejected || activeLimitRejected;
      addCheck(
        `api.${tier}_${mediaType}_accepted_or_precharge_rejected`,
        expected,
        `accepted=${accepted}, waitTooLong=${waitRejected}, activeLimit=${activeLimitRejected}, responses=${laneResponses.length}`);
    }
  }
}

function laneHasPrechargeRejection(mediaType, tier) {
  return matrixResponses.some(response =>
    response.mediaType === mediaType
    && response.tier === tier
    && ((response.status === 503 && response.code === 'GENERATION_WAIT_TOO_LONG')
      || (response.status === 429 && response.code === 'ACTIVE_GENERATION_LIMIT_REACHED')));
}

function inspectGenerationRefund(generationId) {
  const row = queryRows(`
    SELECT "UserId"::text,
           "TokenCost"::text,
           ("ChargedAtUtc" IS NOT NULL)::text,
           ("RefundedAtUtc" IS NOT NULL)::text,
           "Status"::text
    FROM templates_generation_jobs
    WHERE "Id" = ${sqlString(generationId)}::uuid;
  `)[0] || ['', '0', 'f', 'f', ''];
  const refundReason = `generation_refund:${String(generationId).replaceAll('-', '')}`;
  const refundLedgerRows = row[0]
    ? Number(queryScalar(`
        SELECT count(*)
        FROM economy_wallet_ledger
        WHERE "UserId" = ${sqlString(row[0])}::uuid
          AND "Source" = 'generation_refund'
          AND "Reason" = ${sqlString(refundReason)};
      `))
    : 0;
  return {
    userId: anonymize(row[0]),
    tokenCost: Number(row[1]),
    charged: parsePgBool(row[2]),
    refunded: parsePgBool(row[3]),
    status: statusNames.get(row[4]) || row[4],
    refundLedgerRows
  };
}

function queryCreatedGenerationRows() {
  if (createdGenerations.length === 0) {
    return [];
  }

  const ids = createdGenerations.map(item => `${sqlString(item.generationId)}::uuid`).join(',');
  return queryRows(`
    SELECT "Id"::text,
           "Status"::text,
           "QueueMediaType",
           "QueueTier",
           COALESCE("EstimatedWaitSecondsAtQueue"::text, ''),
           ("ChargedAtUtc" IS NOT NULL)::text,
           ("RefundedAtUtc" IS NOT NULL)::text,
           COALESCE("IdempotencyKey", ''),
           COALESCE("ProviderStatus", ''),
           ("ProviderSubmittedAtUtc" IS NOT NULL)::text,
           ("ProviderCompletedAtUtc" IS NOT NULL)::text,
           ("ProviderStatusCheckedAtUtc" IS NOT NULL)::text,
           ("WebhookReceivedAtUtc" IS NOT NULL)::text,
           (
             "ProviderSubmittedAtUtc" IS NOT NULL
             AND "ProviderStatusCheckedAtUtc" IS NOT NULL
             AND "ProviderStatusCheckedAtUtc" > "ProviderSubmittedAtUtc"
           )::text,
           ("PreprocessingProviderRequestId" IS NOT NULL OR "MotionProviderRequestId" IS NOT NULL)::text,
           ("PreprocessingProviderStatusUrl" IS NOT NULL OR "MotionProviderStatusUrl" IS NOT NULL)::text
    FROM templates_generation_jobs
    WHERE "Id" IN (${ids})
    ORDER BY "CreatedAtUtc", "Id";
  `).map(row => ({
    generationId: row[0],
    status: statusNames.get(row[1]) || row[1],
    mediaType: row[2],
    tier: row[3],
    estimatedWaitSecondsAtQueue: row[4] === '' ? null : Number(row[4]),
    charged: parsePgBool(row[5]),
    refunded: parsePgBool(row[6]),
    idempotencyKey: anonymize(row[7]),
    providerStatus: row[8] || null,
    providerSubmitted: parsePgBool(row[9]),
    providerCompleted: parsePgBool(row[10]),
    providerStatusChecked: parsePgBool(row[11]),
    webhookReceived: parsePgBool(row[12]),
    providerStatusCheckedAfterSubmit: parsePgBool(row[13]),
    providerRequestTracked: parsePgBool(row[14]),
    providerStatusUrlTracked: parsePgBool(row[15])
  }));
}

function countPersistedEventsForCreatedRows(createdRows) {
  if (createdRows.length === 0) {
    return 0;
  }

  const predicates = createdRows.map(row =>
    `"Data" LIKE ${sqlString(`%"generationId":"${row.generationId}"%`)}`);
  return Number(queryScalar(`
    SELECT count(*)
    FROM templates_realtime_events
    WHERE "Topic" = 'templates.generation.status_changed'
      AND (${predicates.join(' OR ')});
  `));
}

function verifyPriorityEvidence(createdRows) {
  const premiumRows = createdRows.filter(row => row.tier === 'premium');
  addCheck(
    'db.priority_premium_queue_tier_observed',
    premiumRows.length > 0,
    `premiumRows=${premiumRows.length}`);

  for (const mediaType of ['image', 'video']) {
    const freeRows = createdRows
      .filter(row => row.mediaType === mediaType && row.tier === 'free' && Number.isFinite(row.estimatedWaitSecondsAtQueue));
    const mediaPremiumRows = createdRows
      .filter(row => row.mediaType === mediaType && row.tier === 'premium' && Number.isFinite(row.estimatedWaitSecondsAtQueue));
    const minFreeEta = Math.min(...freeRows.map(row => row.estimatedWaitSecondsAtQueue));
    const minPremiumEta = Math.min(...mediaPremiumRows.map(row => row.estimatedWaitSecondsAtQueue));
    const freeRejected = laneHasPrechargeRejection(mediaType, 'free');
    const premiumAccepted = matrixResponses.some(response =>
      response.mediaType === mediaType && response.tier === 'premium' && response.status === 202);
    const premiumRejected = laneHasPrechargeRejection(mediaType, 'premium');
    const ok = (Number.isFinite(minFreeEta) && Number.isFinite(minPremiumEta) && minPremiumEta <= minFreeEta)
      || (freeRejected && premiumAccepted)
      || (smokeMode === 'local' && freeRejected && premiumRejected);
    addCheck(
      `db.priority_premium_eta_not_worse_than_free.${mediaType}`,
      ok,
      `minFreeEta=${Number.isFinite(minFreeEta) ? minFreeEta : 'n/a'}, minPremiumEta=${Number.isFinite(minPremiumEta) ? minPremiumEta : 'n/a'}, freeRejected=${freeRejected}, premiumAccepted=${premiumAccepted}, premiumRejected=${premiumRejected}`);
  }
}

function verifyProviderPipelineEvidence(createdRows) {
  const providerRows = createdRows.filter(row => row.providerRequestTracked || row.providerStatusUrlTracked);
  const webhookRows = providerRows.filter(row => row.webhookReceived);
  const statusCheckedRows = providerRows.filter(row => row.providerStatusChecked);
  const postSubmitStatusCheckedRows = providerRows.filter(row => row.providerStatusCheckedAfterSubmit);
  addCheck(
    'provider.request_id_or_status_url_tracked',
    smokeMode === 'local' || providerRows.length > 0,
    `providerRows=${providerRows.length}, createdRows=${createdRows.length}`);
  addCheck(
    'provider.webhook_delivery_observed',
    smokeMode === 'local' || webhookRows.length > 0,
    `webhookRows=${webhookRows.length}, providerRows=${providerRows.length}`);
  addCheck(
    'provider.status_polling_evidence_observed',
    smokeMode === 'local' || statusCheckedRows.length > 0,
    `statusCheckedRows=${statusCheckedRows.length}, postSubmitStatusCheckedRows=${postSubmitStatusCheckedRows.length}, providerRows=${providerRows.length}`);
}

function verifySseEvidence(sseProbe, createdRows) {
  const createdIds = new Set(createdRows.map(row => row.generationId));
  const matchingEvents = sseProbe.events.filter(event =>
    event.topic === 'templates.generation.status_changed' && createdIds.has(event.generationId));
  addCheck(
    'realtime.sse_connected',
    sseProbe.connected,
    `events=${sseProbe.events.length}, errors=${sseProbe.errors.length}`);
  addCheck(
    'realtime.sse_generation_status_event_received',
    matchingEvents.length > 0,
    `matchingEvents=${matchingEvents.length}`);
  addCheck(
    'realtime.persisted_events_cross_checked_with_sse',
    matchingEvents.length > 0 && createdRows.length > 0,
    `createdRows=${createdRows.length}, matchingSseEvents=${matchingEvents.length}`);
}

function startSseProbe() {
  const controller = new AbortController();
  const decoder = new TextDecoder();
  const state = {
    connected: false,
    events: [],
    errors: []
  };
  let resolveConnected;
  const connectedPromise = new Promise(resolve => {
    resolveConnected = resolve;
  });
  const timeout = setTimeout(() => {
    if (!state.connected) {
      state.errors.push('connect_timeout');
      addCheck('realtime.sse_initial_connection', false, 'timed out waiting for connected comment');
      resolveConnected(false);
    }
  }, 10000);

  (async () => {
    let buffer = '';
    try {
      const response = await fetch(`${apiBaseUrl}/api/templates/events`, {
        headers: { Accept: 'text/event-stream' },
        signal: controller.signal
      });
      if (!response.ok || !response.body) {
        state.errors.push(`http_${response.status}`);
        clearTimeout(timeout);
        addCheck('realtime.sse_initial_connection', false, `status=${response.status}`);
        resolveConnected(false);
        return;
      }

      const reader = response.body.getReader();
      while (true) {
        const { value, done } = await reader.read();
        if (done) {
          break;
        }

        buffer += decoder.decode(value, { stream: true });
        if (!state.connected && buffer.includes(': connected')) {
          state.connected = true;
          clearTimeout(timeout);
          addCheck('realtime.sse_initial_connection', true, 'connected');
          resolveConnected(true);
        }

        let separatorIndex;
        while ((separatorIndex = buffer.indexOf('\n\n')) >= 0) {
          const block = buffer.slice(0, separatorIndex);
          buffer = buffer.slice(separatorIndex + 2);
          const event = parseSseBlock(block);
          if (event && state.events.length < 200) {
            state.events.push(event);
          }
        }
      }
    } catch (error) {
      if (controller.signal.aborted) {
        return;
      }

      state.errors.push(error.name || 'error');
      if (!state.connected) {
        clearTimeout(timeout);
        addCheck('realtime.sse_initial_connection', false, error.name || String(error));
        resolveConnected(false);
      }
    }
  })();

  return {
    get connected() {
      return state.connected;
    },
    get events() {
      return state.events;
    },
    get errors() {
      return state.errors;
    },
    connectedPromise,
    stop() {
      clearTimeout(timeout);
      controller.abort();
    },
    summary() {
      return {
        connected: state.connected,
        events: state.events,
        errors: state.errors
      };
    }
  };
}

function parseSseBlock(block) {
  if (!block || block.startsWith(':')) {
    return null;
  }

  const eventLine = block.split('\n').find(line => line.startsWith('event:'));
  const dataLine = block.split('\n').find(line => line.startsWith('data:'));
  const topic = eventLine?.slice('event:'.length).trim() || '';
  const rawData = dataLine?.slice('data:'.length).trim() || '{}';
  let data = {};
  try {
    data = JSON.parse(rawData);
  } catch {
    data = {};
  }

  return {
    topic,
    generationId: data.generationId || data.jobId || null,
    status: data.status || null,
    mediaType: data.mediaType || null,
    tier: data.priorityClass || data.userPlan || null
  };
}

function anonymize(value) {
  if (!value) {
    return null;
  }

  const digest = createHash('sha256').update(String(value)).digest('hex').slice(0, 12);
  return `anon_${digest}`;
}

function finalObservedStatus(observations) {
  for (let i = observations.length - 1; i >= 0; i -= 1) {
    if (observations[i].status) {
      return observations[i].status;
    }
  }
  return '';
}

function queryScalar(sql) {
  const row = queryRows(sql)[0];
  return row?.[0] ?? '';
}

function parsePgBool(value) {
  return value === 't' || value === 'true' || value === '1';
}

function queryRows(sql) {
  if (psqlCommand === 'docker-compose-psql') {
    if (smokeMode !== 'local') {
      throw new Error('docker-compose-psql is only allowed for local smoke mode.');
    }

    return queryRowsViaLocalDockerCompose(sql);
  }

  const result = spawnSync(psqlCommand, [
    '--no-psqlrc',
    '--set',
    'ON_ERROR_STOP=1',
    '--tuples-only',
    '--no-align',
    '--field-separator',
    '\t',
    databaseUrl,
    '--command',
    sql
  ], {
    encoding: 'utf8',
    maxBuffer: 20 * 1024 * 1024
  });

  if (result.status !== 0) {
    throw new Error(`psql failed: ${result.stderr || result.stdout}`);
  }

  return result.stdout
    .split(/\r?\n/)
    .map(line => line.endsWith('\r') ? line.slice(0, -1) : line)
    .filter(line => line.length > 0)
    .map(line => line.split('\t'));
}

function queryRowsViaLocalDockerCompose(sql) {
  const result = spawnSync('docker', [
    'compose',
    'exec',
    '-T',
    'postgres',
    'psql',
    '-U',
    process.env.LOCAL_POSTGRES_USER || 'petmagic_user',
    '-d',
    process.env.LOCAL_POSTGRES_DB || 'petmagic_db',
    '--no-psqlrc',
    '--set',
    'ON_ERROR_STOP=1',
    '--tuples-only',
    '--no-align',
    '--field-separator',
    '\t',
    '--command',
    sql
  ], {
    encoding: 'utf8',
    maxBuffer: 20 * 1024 * 1024
  });

  if (result.status !== 0) {
    throw new Error(`local docker compose psql failed: ${result.stderr || result.stdout}`);
  }

  return result.stdout
    .split(/\r?\n/)
    .map(line => line.endsWith('\r') ? line.slice(0, -1) : line)
    .filter(line => line.length > 0)
    .map(line => line.split('\t'));
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
  writeFileSync(join(artifactDir, 'evidence.json'), JSON.stringify(evidence, null, 2));
  writeFileSync(join(artifactDir, 'summary.md'), renderSummary());
  console.log(`[${runId}] wrote ${join(artifactDir, 'evidence.json')}`);
  console.log(`[${runId}] wrote ${join(artifactDir, 'summary.md')}`);
  process.exit(exitCode);
}

function renderSummary() {
  return [
    '# Staging Generation Scheduler Smoke',
    '',
    ...(smokeMode === 'local'
      ? ['**LOCAL DEVELOPMENT SMOKE ONLY - NOT STAGING OR PRODUCTION EVIDENCE**', '']
      : []),
    `Run ID: ${runId}`,
    `Mode: ${smokeMode}`,
    `Started: ${evidence.startedAtUtc}`,
    `Finished: ${evidence.finishedAtUtc}`,
    '',
    '## Checks',
    '',
    '| Check | Result | Detail |',
    '| --- | --- | --- |',
    ...checks.map(check => `| ${check.name} | ${check.ok ? 'PASS' : 'FAIL'} | ${String(check.detail).replaceAll('|', '\\|')} |`),
    '',
    '## Lifecycle',
    '',
    `Accepted generations: ${createdGenerations.length}`,
    `Rejected responses: ${rejectedResponses.length}`,
    `Observed statuses: ${(evidence.lifecycleSummary?.statuses || []).join(', ') || 'n/a'}`,
    `Observed media/tier lanes: ${(evidence.lifecycleSummary?.mediaTiers || []).join(', ') || 'n/a'}`,
    ''
  ].join('\n');
}

function decodeUserIdFromJwt(token) {
  try {
    const payload = JSON.parse(Buffer.from(token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString('utf8'));
    return payload.sub
      || payload.nameid
      || payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier']
      || null;
  } catch {
    return null;
  }
}

function sqlString(value) {
  return `'${String(value).replaceAll("'", "''")}'`;
}

function requiredEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} is required. Run with --help for required inputs.`);
  }
  return value;
}

function findMissingRequiredInputs() {
  const required = [
    ['STAGING_API_BASE_URL'],
    ['STAGING_DATABASE_URL'],
    ['STAGING_IMAGE_TEMPLATE_ID'],
    ['STAGING_VIDEO_TEMPLATE_ID'],
    ['STAGING_FAILING_TEMPLATE_ID'],
    ['STAGING_FREE_AUTH_TOKENS', 'STAGING_FREE_JWT'],
    ['STAGING_PREMIUM_AUTH_TOKENS', 'STAGING_PREMIUM_JWT']
  ];
  if (smokeMode !== 'local') {
    required.push(
      ['STAGING_PROMETHEUS_BASE_URL'],
      ['STAGING_API_PROCESS_ID'],
      ['STAGING_WORKER_PROCESS_ID'],
      ['STAGING_MIGRATION_TOOLING_LABEL']);
  }

  return required
    .filter(group => !envAny(group[0], group.slice(1)))
    .map(group => group.join(' or '));
}

function resolveSmokeMode() {
  const modeArg = process.argv.find(argument => argument.startsWith('--mode='));
  const raw = modeArg ? modeArg.split('=', 2)[1] : process.env.GENERATION_SCHEDULER_SMOKE_MODE;
  if (!raw) {
    return 'staging';
  }

  if (raw === 'local' || raw === 'staging') {
    return raw;
  }

  console.error(`Unsupported smoke mode: ${raw}. Use local or staging.`);
  process.exit(1);
}

function verifyLocalDockerComposeEnvironment() {
  const result = spawnSync('docker', ['compose', 'ps', '--format', 'json'], {
    encoding: 'utf8',
    maxBuffer: 10 * 1024 * 1024
  });
  if (result.status !== 0) {
    addCheck('local.docker_compose_ps_available', false, sanitizeCommandOutput(result.stderr || result.stdout));
    return;
  }

  const services = result.stdout
    .split(/\r?\n/)
    .map(line => line.trim())
    .filter(Boolean)
    .map(line => JSON.parse(line));
  const byService = new Map(services.map(service => [service.Service, service]));
  evidence.localDockerCompose = {
    services: services.map(service => ({
      service: service.Service,
      state: service.State,
      status: sanitizeLabel(service.Status)
    }))
  };

  for (const serviceName of ['backend', 'generation-worker', 'postgres']) {
    const service = byService.get(serviceName);
    addCheck(
      `local.compose_${serviceName}_running`,
      service?.State === 'running',
      service ? `state=${service.State}, status=${sanitizeLabel(service.Status)}` : 'missing');
  }

  const backendEnvironment = dockerComposeExecText('backend', ['printenv', 'ASPNETCORE_ENVIRONMENT']);
  const workerEnvironment = dockerComposeExecText('generation-worker', ['printenv', 'ASPNETCORE_ENVIRONMENT']);
  addCheck(
    'local.backend_environment_is_development',
    backendEnvironment.trim() === 'Development',
    `ASPNETCORE_ENVIRONMENT=${sanitizeLabel(backendEnvironment.trim())}`);
  addCheck(
    'local.worker_environment_is_development',
    workerEnvironment.trim() === 'Development',
    `ASPNETCORE_ENVIRONMENT=${sanitizeLabel(workerEnvironment.trim())}`);
}

function dockerComposeExecText(serviceName, command) {
  const result = spawnSync('docker', ['compose', 'exec', '-T', serviceName, ...command], {
    encoding: 'utf8',
    maxBuffer: 1024 * 1024
  });
  return result.status === 0 ? result.stdout : '';
}

function sanitizeCommandOutput(value) {
  return String(value || '')
    .replace(/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g, '[email]')
    .replace(/(password|pwd|token|secret|key)=?[^;\s]*/gi, '$1=[redacted]')
    .slice(0, 500);
}

function requiredEnvAny(name, aliases = []) {
  const value = envAny(name, aliases);
  if (!value) {
    throw new Error(`${name} is required. Run with --help for required inputs.`);
  }
  return value;
}

function envAny(name, aliases = []) {
  for (const candidate of [name, ...aliases]) {
    if (process.env[candidate]) {
      return process.env[candidate];
    }
  }

  return '';
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

async function fetchWithTimeout(url, options, timeoutMs) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...options, signal: controller.signal });
  } finally {
    clearTimeout(timeout);
  }
}

function verifyMigrationLogEvidence() {
  const logPath = process.env.STAGING_MIGRATION_LOG_PATH;
  if (!logPath) {
    evidence.migrationLog = { provided: false };
    return;
  }

  const content = readFileSync(logPath, 'utf8');
  const transactionBlockErrorAbsent = !/CREATE INDEX CONCURRENTLY cannot run inside a transaction block/i.test(content);
  const schedulerMigrationMentioned = /AddGenerationSchedulerQueueFields|20260630234809/i.test(content);
  evidence.migrationLog = {
    provided: true,
    schedulerMigrationMentioned,
    transactionBlockErrorAbsent
  };
  addCheck(
    'migrations.deployment_log_mentions_scheduler_migration',
    schedulerMigrationMentioned,
    `log=${anonymize(logPath)}`);
  addCheck(
    'migrations.deployment_log_has_no_concurrent_index_transaction_error',
    transactionBlockErrorAbsent,
    `log=${anonymize(logPath)}`);
}

function hasAnyStagingProcessEnv() {
  return Object.keys(process.env).some(name => name.startsWith('STAGING_'));
}

function isLocalApiTarget(value) {
  try {
    const hostname = new URL(value).hostname.toLowerCase();
    return ['localhost', '127.0.0.1', '::1'].includes(hostname);
  } catch {
    return true;
  }
}

function isLocalDatabaseTarget(value) {
  const normalized = String(value).toLowerCase();
  return normalized.includes('localhost')
    || normalized.includes('127.0.0.1')
    || normalized.includes('host=postgres')
    || normalized.includes('database=petmagic_db')
    || normalized.includes('/petmagic_db');
}

function sanitizeLabel(value) {
  if (!value) {
    return null;
  }

  return String(value)
    .replace(/[^A-Za-z0-9_.:@-]/g, '_')
    .slice(0, 120);
}

function parseList(raw) {
  return raw.split(',').map(value => value.trim()).filter(Boolean);
}

function intEnv(name, fallback) {
  const raw = process.env[name];
  if (!raw) {
    return fallback;
  }
  const parsed = Number.parseInt(raw, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function boolEnv(name, fallback) {
  const raw = process.env[name];
  if (!raw) {
    return fallback;
  }
  return ['1', 'true', 'yes', 'on'].includes(raw.toLowerCase());
}

function chunk(items, size) {
  const chunks = [];
  for (let i = 0; i < items.length; i += size) {
    chunks.push(items.slice(i, i + size));
  }
  return chunks;
}

function delay(milliseconds) {
  return new Promise(resolve => setTimeout(resolve, milliseconds));
}

function formatTimestamp(date) {
  return date.toISOString().replaceAll(':', '').replace(/\.\d{3}Z$/, 'Z');
}

function printHelp() {
  console.log(`
Staging generation scheduler smoke runner.

Required environment:
  STAGING_API_BASE_URL                  https://staging-api.example
  STAGING_DATABASE_URL                  PostgreSQL connection string accepted by psql
  STAGING_IMAGE_TEMPLATE_ID             active image template id
  STAGING_VIDEO_TEMPLATE_ID             active video template id
  STAGING_FAILING_TEMPLATE_ID           active template configured with Fake AI failure sentinel
  STAGING_FREE_AUTH_TOKENS              comma-separated free-user JWTs
  STAGING_PREMIUM_AUTH_TOKENS           comma-separated premium-user JWTs
  STAGING_FREE_JWT                      alias for one free-user JWT
  STAGING_PREMIUM_JWT                   alias for one premium-user JWT
  STAGING_PROMETHEUS_BASE_URL           Prometheus base URL for metric queries
  STAGING_API_PROCESS_ID                sanitized operator label for the API process/container
  STAGING_WORKER_PROCESS_ID             sanitized operator label for the generation worker process/container
  STAGING_MIGRATION_TOOLING_LABEL       sanitized label for production-equivalent migration tooling

Optional environment:
  STAGING_ENV_FILE                      env file path, default .env.staging.local
  STAGING_MIGRATION_LOG_PATH            local deployment log path; log content is summarized, not copied
  STAGING_MIN_EXISTING_GENERATIONS      production-like DB row minimum, default 100
  STAGING_ALLOW_LOCALHOST               allow localhost API/DB targets, default false
  STAGING_FAILING_TEMPLATE_MEDIA_TYPE   image or video, default image
  STAGING_ADMIN_AUTH_TOKEN              admin JWT for privileged probes
  STAGING_SMOKE_TOTAL                   50-100 generation attempts, default 60
  STAGING_SUBMIT_CONCURRENCY            default 8
  STAGING_EXPECT_FAILED_STATUS          require failed DB status evidence, default false
  STAGING_ALLOW_INCOMPLETE              write evidence but exit 0 on failed checks, default false
  STAGING_SOURCE_IMAGE_PATH             PNG/JPEG/WebP source image path
  STAGING_PSQL_COMMAND                  psql command path, default psql
  STAGING_ARTIFACT_DIR                  output dir, default artifacts/staging-generation-scheduler-smoke/<run>

Example:
  node scripts/qa/run-staging-generation-scheduler-smoke.mjs
`);
}
