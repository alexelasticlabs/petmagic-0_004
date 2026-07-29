#!/usr/bin/env node

import { createRequire } from 'node:module';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const rawArgs = process.argv.slice(2);
const args = new Set(rawArgs);
const repoRoot = resolve(getOptionValue('--root') ?? resolve(scriptDir, '..', '..'));
const blueprintPath = resolve(repoRoot, getOptionValue('--file') ?? 'render.yaml');
const environment = (getOptionValue('--environment')
  ?? (blueprintPath.endsWith('render.production.yaml') ? 'production' : 'staging')).toLowerCase();
if (!['staging', 'production'].includes(environment)) {
  throw new Error('--environment must be staging or production.');
}
const prefix = `petmagic-${environment}`;
const apiDomain = environment === 'production' ? 'api.petgpt.app' : 'api.staging.petmagic.app';
const adminDomain = environment === 'production' ? 'admin.petgpt.app' : 'admin.staging.petmagic.app';

if (args.has('--help') || args.has('-h')) {
  printUsage();
  process.exit(0);
}

const require = createRequire(import.meta.url);
const yaml = require(resolve(repoRoot, 'apps/admin-web/node_modules/js-yaml'));

const failures = [];

if (!existsSync(blueprintPath)) {
  fail(`Blueprint file does not exist: ${blueprintPath}`);
  finish();
}

const blueprint = yaml.load(readFileSync(blueprintPath, 'utf8'));
if (!blueprint || typeof blueprint !== 'object') {
  fail('Blueprint must parse to a YAML object.');
  finish();
}

const services = Array.isArray(blueprint.services) ? blueprint.services : [];
const databases = Array.isArray(blueprint.databases) ? blueprint.databases : [];
const envVarGroups = Array.isArray(blueprint.envVarGroups) ? blueprint.envVarGroups : [];
const schedulerFingerprintFields = [
  schedulerField('schedulerV2.enabled', 'GenerationSchedulerV2Enabled', 'bool', false),
  schedulerField('admission.cancelQueuedGenerationEnabled', 'CancelQueuedGenerationEnabled', 'bool', true),
  schedulerField('admission.freeUserMaxActiveGenerations', 'FreeUserMaxActiveGenerations', 'positiveInt', 1),
  schedulerField('admission.premiumUserMaxActiveGenerations', 'PremiumUserMaxActiveGenerations', 'positiveInt', 3),
  schedulerField('admission.privilegedUserMaxActiveGenerations', 'PrivilegedUserMaxActiveGenerations', 'positiveInt', 10),
  schedulerField('admission.queueMaxSize', 'QueueMaxSize', 'nonNegativeInt', 1_000),
  schedulerField('concurrency.maxAiProviderRequestsPerMinute', 'MaxAiProviderRequestsPerMinute', 'nonNegativeInt', 60),
  schedulerField('elasticBorrowing.allowVideoBorrowWhenImageEstimatedWaitBelowSeconds', 'AllowVideoBorrowWhenImageEstimatedWaitBelowSeconds', 'positiveInt', 120),
  schedulerField('elasticBorrowing.allowVideoBorrowWhenImageQueueEmpty', 'AllowVideoBorrowWhenImageQueueEmpty', 'bool', true),
  schedulerField('elasticBorrowing.borrowedVideoMaxAgeSeconds', 'BorrowedVideoMaxAgeSeconds', 'nonNegativeInt', 0),
  schedulerField('elasticBorrowing.borrowingPriorityTiers', 'BorrowingPriorityTiers', 'csv', 'premium,privileged,admin,free'),
  schedulerField('elasticBorrowing.enableElasticLaneBorrowing', 'EnableElasticLaneBorrowing', 'bool', false),
  schedulerField('elasticBorrowing.videoBorrowReleaseMode', 'VideoBorrowReleaseMode', 'text', 'natural_completion'),
  schedulerField('estimates.estimatedImageGenerationSeconds', 'EstimatedImageGenerationSeconds', 'positiveInt', 90),
  schedulerField('estimates.estimatedVideoGenerationSeconds', 'EstimatedVideoGenerationSeconds', 'positiveInt', 420),
  schedulerField('estimates.estimatedVideoPreprocessingSeconds', 'EstimatedVideoPreprocessingSeconds', 'positiveInt', 90),
  schedulerField('provider.aiProvider', 'AiProvider', 'text', 'Fake'),
  schedulerField('provider.falCancelMaxAttempts', 'Fal.CancelMaxAttempts', 'positiveInt', 3),
  schedulerField('provider.falImageMaxPollingAttempts', 'Fal.ImageMaxPollingAttempts', 'positiveInt', 180),
  schedulerField('provider.falImagePreprocessingMaxPollingAttempts', 'Fal.ImagePreprocessingMaxPollingAttempts', 'positiveInt', 180),
  schedulerField('provider.falMaxPollingAttempts', 'Fal.MaxPollingAttempts', 'int', 180),
  schedulerField('provider.falPollIntervalMilliseconds', 'Fal.PollIntervalMilliseconds', 'int', 2_000),
  schedulerField('provider.falStartTimeoutSeconds', 'Fal.StartTimeoutSeconds', 'int', 120),
  schedulerField('provider.falVideoMaxPollingAttempts', 'Fal.VideoMaxPollingAttempts', 'positiveInt', 300),
  schedulerField('queuePriority.adminQueuePriorityScore', 'AdminQueuePriorityScore', 'positiveInt', 10_000),
  schedulerField('queuePriority.freeQueuePriorityScore', 'FreeQueuePriorityScore', 'positiveInt', 1_000),
  schedulerField('queuePriority.premiumQueuePriorityScore', 'PremiumQueuePriorityScore', 'positiveInt', 4_000),
  schedulerField('queuePriority.privilegedQueuePriorityScore', 'PrivilegedQueuePriorityScore', 'positiveInt', 8_000),
  schedulerField('queuePriority.queuePriorityAgingBoost', 'QueuePriorityAgingBoost', 'nonNegativeInt', 500),
  schedulerField('queuePriority.queuePriorityAgingIntervalSeconds', 'QueuePriorityAgingIntervalSeconds', 'positiveInt', 60),
  schedulerField('recovery.jobLockTimeoutMilliseconds', 'JobLockTimeoutMilliseconds', 'positiveInt', 900_000, 'StaleProcessingRecoveryDelayMilliseconds'),
  schedulerField('recovery.providerReconciliationClaimLeaseMilliseconds', 'ProviderReconciliationClaimLeaseMilliseconds', 'positiveInt', 90_000),
  schedulerField('recovery.maxGenerationAttempts', 'MaxGenerationAttempts', 'positiveInt', 3),
  schedulerField('recovery.maxRefundAttempts', 'MaxRefundAttempts', 'positiveInt', 5),
  schedulerField('recovery.orphanQueuedJobTimeoutMilliseconds', 'OrphanQueuedJobTimeoutMilliseconds', 'positiveInt', 120_000),
  schedulerField('recovery.refundRetryDelayMilliseconds', 'RefundRetryDelayMilliseconds', 'nonNegativeInt', 30_000),
  schedulerField('recovery.staleProcessingRecoveryDelayMilliseconds', 'StaleProcessingRecoveryDelayMilliseconds', 'positiveInt', 900_000),
  schedulerField('waitThresholds.freeImageMaxEstimatedWaitSeconds', 'FreeImageMaxEstimatedWaitSeconds', 'positiveInt', 1_800),
  schedulerField('waitThresholds.freeVideoMaxEstimatedWaitSeconds', 'FreeVideoMaxEstimatedWaitSeconds', 'positiveInt', 3_600),
  schedulerField('waitThresholds.premiumImageMaxEstimatedWaitSeconds', 'PremiumImageMaxEstimatedWaitSeconds', 'positiveInt', 900),
  schedulerField('waitThresholds.premiumVideoMaxEstimatedWaitSeconds', 'PremiumVideoMaxEstimatedWaitSeconds', 'positiveInt', 1_800),
  schedulerField('waitThresholds.privilegedImageMaxEstimatedWaitSeconds', 'PrivilegedImageMaxEstimatedWaitSeconds', 'positiveInt', 900),
  schedulerField('waitThresholds.privilegedVideoMaxEstimatedWaitSeconds', 'PrivilegedVideoMaxEstimatedWaitSeconds', 'positiveInt', 1_800)
];

requireServiceCount(3);
requireDatabaseCount(1);
requireEnvGroupCount(1);
requireDatabase(`${prefix}-db`, 'basic-1gb');
requireEnvGroup(`${prefix}-shared`);

const api = requireService(`${prefix}-api`, {
  type: 'web',
  runtime: 'docker',
  region: 'frankfurt',
  plan: 'standard',
  numInstances: 1,
  dockerfilePath: './Dockerfile.api',
  dockerContext: '.',
  healthCheckPath: '/health'
});

const worker = requireService(`${prefix}-generation-worker`, {
  type: 'worker',
  runtime: 'docker',
  region: 'frankfurt',
  plan: 'standard',
  numInstances: 1,
  maxShutdownDelaySeconds: 300,
  dockerfilePath: './Dockerfile.generation-worker',
  dockerContext: '.'
});

const admin = requireService(`${prefix}-admin-web`, {
  type: 'web',
  runtime: 'docker',
  region: 'frankfurt',
  plan: 'starter',
  numInstances: 1,
  dockerfilePath: './apps/admin-web/Dockerfile',
  dockerContext: './apps/admin-web',
  healthCheckPath: '/ru'
});

if (api) {
  requireDockerfile(api, {
    expectedAppDll: 'PetMagic.Host.Api.dll',
    expectedExpose: '5000',
    requiredCopy: 'scripts/docker/run-dotnet-app.sh'
  });
  requireBuildFilterPath(api, 'global.json');
  requireBuildFilterPath(api, 'shared/**');
  requireDomain(api, apiDomain);
  requirePersistentDisk(api, `${prefix}-api-data`, '/var/petmagic');
  requireEnvValue(api, 'PORT', '5000');
  requireEnvValue(api, 'ASPNETCORE_HTTP_PORTS', '5000');
  requireEnvValue(api, 'STORE_ACCOUNT_BINDING_MODE', 'compatibility');
  requireEnvValue(
    api,
    'ExternalAuth__MobileRedirectScheme',
    environment === 'production' ? 'petmagic' : 'petmagic-staging'
  );
  requireEnvValue(api, 'Templates__GenerationWorkerEnabled', 'false');
  requireEnvValue(api, 'FAL_WEBHOOK_URL', `https://${apiDomain}/api/templates/provider/fal/webhook`);
  requireEnvValue(api, 'Templates__TemplateOfTheDayAutoPickWorkerEnabled', 'true');
  requireEnvValue(api, 'APP_VOLUME_DIRS', '/var/petmagic');
  requireEnvValue(api, 'DataProtection__KeysPath', '/var/petmagic/DataProtection-Keys');
  requireEnvValue(api, 'StaticFiles__ExtraWebRootPath', '/var/petmagic/wwwroot');
  requireEnvValue(api, 'Identity__AvatarStorage__PublicBaseUrl', `https://${apiDomain}`);
  requireEnvValue(api, 'Identity__AvatarStorage__LocalMediaRootPath', '/var/petmagic/wwwroot/user-avatars');
  requireEnvValue(api, 'SupportChat__AttachmentStorage__PublicBaseUrl', `https://${apiDomain}`);
  requireEnvValue(api, 'SupportChat__AttachmentStorage__LocalMediaRootPath', '/var/petmagic/wwwroot/support-attachments');
  requireEnvValue(api, 'Templates__LocalMediaRootPath', '/var/petmagic/wwwroot/templates-media');
  requireEnvValue(
    api,
    'STRIPE_CHECKOUT_SUCCESS_URL',
    `https://${adminDomain}/payments/success?session_id={CHECKOUT_SESSION_ID}`
  );
  requireEnvValue(api, 'STRIPE_CHECKOUT_CANCEL_URL', `https://${adminDomain}/payments/cancel`);
  requireEnvValue(api, 'STRIPE_BILLING_PORTAL_RETURN_URL', `https://${adminDomain}/payments/return`);
  requireEnvContains(api, 'AllowedHosts', apiDomain);
  requireDatabaseBinding(api, 'ConnectionStrings__DefaultConnection', `${prefix}-db`);
  requireSecretKeys(api, [
    'Jwt__SigningKey',
    'FAL_AI_API_KEY',
    'R2_ACCOUNT_ID',
    'R2_ACCESS_KEY',
    'R2_SECRET_KEY',
    'R2_BUCKET_NAME',
    'R2_PUBLIC_URL',
    environment === 'production' ? 'STRIPE_LIVE_SECRET_KEY' : 'STRIPE_TEST_SECRET_KEY',
    environment === 'production' ? 'STRIPE_LIVE_PUBLISHABLE_KEY' : 'STRIPE_TEST_PUBLISHABLE_KEY',
    environment === 'production' ? 'STRIPE_LIVE_WEBHOOK_SECRET' : 'STRIPE_TEST_WEBHOOK_SECRET',
    'GOOGLE_PLAY_PREMIUM_MONTHLY_PRODUCT_ID',
    'GOOGLE_PLAY_PREMIUM_YEARLY_PRODUCT_ID',
    'APP_STORE_PREMIUM_MONTHLY_PRODUCT_ID',
    'APP_STORE_PREMIUM_YEARLY_PRODUCT_ID',
    'GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL',
    'GOOGLE_PLAY_PRIVATE_KEY_PEM',
    'GOOGLE_PLAY_PUBSUB_AUDIENCE',
    'GOOGLE_PLAY_PUBSUB_EXPECTED_EMAIL',
    'APP_STORE_SHARED_SECRET',
    'FIREBASE_PROJECT_ID',
    'FIREBASE_SERVICE_ACCOUNT_JSON',
    'GOOGLE_CLIENT_ID',
    'GOOGLE_CLIENT_SECRET',
    'GOOGLE_AUDIENCES',
    'APPLE_CLIENT_ID',
    'APPLE_CLIENT_SECRET',
    'APPLE_AUDIENCES',
    'EMAIL_HOST',
    'EMAIL_PORT',
    'EMAIL_USERNAME',
    'EMAIL_PASSWORD',
    'EMAIL_FROM_ADDRESS',
    'OTEL_EXPORTER_OTLP_ENDPOINT'
  ]);
}

if (worker) {
  requireDockerfile(worker, {
    expectedAppDll: 'PetMagic.Host.GenerationWorker.dll',
    requiredCopy: 'scripts/docker/run-dotnet-app.sh'
  });
  requireBuildFilterPath(worker, 'global.json');
  requireBuildFilterPath(worker, 'shared/**');
  requireWorkerIsPrivateAndEphemeral(worker);

  requireEnvValue(worker, 'Templates__GenerationWorkerEnabled', 'true');
  requireEnvValue(worker, 'FAL_WEBHOOK_URL', `https://${apiDomain}/api/templates/provider/fal/webhook`);
  requireEnvValue(worker, 'Templates__GenerationWorkerPollIntervalMilliseconds', '500');
  requireEnvValue(worker, 'Templates__GenerationDispatchConcurrency', '4');
  requireEnvValue(worker, 'Templates__ProviderReconciliationConcurrency', '4');
  requireEnvValue(worker, 'Templates__MediaImportConcurrency', '1');
  requireEnvValue(worker, 'Templates__GenerationMaintenanceConcurrency', '1');
  requireEnvValue(worker, 'Templates__MediaCleanupWorkerEnabled', 'false');
  requireEnvValue(worker, 'Templates__TemplateOfTheDayAutoPickWorkerEnabled', 'false');
  requireDatabaseBinding(worker, 'ConnectionStrings__DefaultConnection', `${prefix}-db`);
  requireSecretKeys(worker, [
    'Jwt__SigningKey',
    'FAL_AI_API_KEY',
    'R2_ACCOUNT_ID',
    'R2_ACCESS_KEY',
    'R2_SECRET_KEY',
    'R2_BUCKET_NAME',
    'R2_PUBLIC_URL',
    'OTEL_EXPORTER_OTLP_ENDPOINT'
  ]);
  rejectWorkerExternalBillingConfiguration(worker);
}

if (api && worker) {
  requireWorkerOnlyLaneSettings(api, worker);
  requireSchedulerFingerprintParity(api, worker);
}

if (admin) {
  requireDockerfile(admin, {
    expectedExpose: '3000',
    mustBindHost: '0.0.0.0',
    buildArgsFromEnv: [
      'NEXT_PUBLIC_API_BASE_URL',
      'INTERNAL_API_BASE_URL',
      'ALLOW_LOCALHOST_API_BASE_URL_IN_PRODUCTION',
      'NEXT_PUBLIC_ALLOW_LOCALHOST_API_BASE_URL_IN_PRODUCTION'
    ]
  });
  requireDomain(admin, adminDomain);
  requireEnvValue(admin, 'PORT', '3000');
  requireEnvValue(admin, 'NODE_ENV', 'production');
  requireEnvValue(admin, 'NEXT_PUBLIC_API_BASE_URL', `https://${apiDomain}`);
  requireEnvValue(admin, 'INTERNAL_API_BASE_URL', `https://${apiDomain}`);
  requireDeferredEnvValue(admin, 'ADMIN_MEDIA_ORIGINS');
  requireEnvValue(
    admin,
    'PETMAGIC_APP_DEEP_LINK_SCHEME',
    environment === 'production' ? 'petmagic' : 'petmagic-staging'
  );
  rejectPublicSecrets(admin);
}

if (environment === 'staging') {
  requireSecretCoverageInFiles([
    'docs/render-staging-deployment.md',
    'docs/render-staging-secrets-checklist.md',
    '.env.staging.local.example'
  ]);
}

finish();

function requireServiceCount(expected) {
  if (services.length !== expected) {
    fail(`Expected ${expected} Render services, found ${services.length}.`);
  }
}

function requireDatabaseCount(expected) {
  if (databases.length !== expected) {
    fail(`Expected ${expected} Render database, found ${databases.length}.`);
  }
}

function requireEnvGroupCount(expected) {
  if (envVarGroups.length !== expected) {
    fail(`Expected ${expected} Render env var group, found ${envVarGroups.length}.`);
  }
}

function requireDatabase(name, plan) {
  const database = databases.find((candidate) => candidate.name === name);
  if (!database) {
    fail(`Missing database: ${name}.`);
    return;
  }

  if (database.plan !== plan) {
    fail(`${name} must use plan ${plan}, found ${database.plan ?? '<missing>'}.`);
  }

  if (database.region !== 'frankfurt') {
    fail(`${name} region must be frankfurt, found ${database.region ?? '<missing>'}.`);
  }

  if (String(database.postgresMajorVersion ?? '') !== '16') {
    fail(`${name} postgresMajorVersion must be 16, found ${database.postgresMajorVersion ?? '<missing>'}.`);
  }

  if (!Array.isArray(database.ipAllowList) || database.ipAllowList.length !== 0) {
    fail(`${name} must define an empty ipAllowList to block public database access.`);
  }
}

function requireEnvGroup(name) {
  const group = envVarGroups.find((candidate) => candidate.name === name);
  if (!group) {
    fail(`Missing env var group: ${name}.`);
    return;
  }

  const expectedEnvironment = environment === 'production' ? 'Production' : 'Staging';
  requireGroupValue(group, 'ASPNETCORE_ENVIRONMENT', expectedEnvironment);
  requireGroupValue(group, 'DOTNET_ENVIRONMENT', expectedEnvironment);
  requireGroupValue(group, 'TEMPLATES_STORAGE_PROVIDER', 'R2');
  requireGroupValue(group, 'TEMPLATES_AI_PROVIDER', 'Fal');
  requireGroupBoolean(group, 'Templates__GenerationSchedulerV2Enabled');
  if (findEnv(group.envVars, 'Templates__MaxConcurrentJobsPerWorker')) {
    fail(`Env group ${group.name} uses obsolete scheduler setting Templates__MaxConcurrentJobsPerWorker.`);
  }
  requireGroupValue(group, 'Templates__FalProviderSpendDailyLimitUsd', '0');

  const expectedSchedulerValues = {
    Templates__GlobalMaxConcurrentGenerations: '8',
    Templates__ImageReservedConcurrentGenerations: '3',
    Templates__ImageProtectedConcurrentGenerations: '3',
    Templates__ImageMaxConcurrentGenerations: '7',
    Templates__VideoReservedConcurrentGenerations: '2',
    Templates__VideoMaxConcurrentGenerations: '4',
    Templates__VideoBorrowMaxConcurrentGenerations: '2',
    Templates__EnableElasticLaneBorrowing: 'true',
    Templates__VideoPreprocessingMaxConcurrentGenerations: '1',
    Templates__FalProviderConcurrencyLimit: '10',
    Templates__FalProviderReservedConcurrency: '2',
    Templates__QueueMaxSize: '1000',
    Templates__EstimatedImageGenerationSeconds: '90',
    Templates__EstimatedVideoGenerationSeconds: '420',
    Templates__EstimatedVideoPreprocessingSeconds: '90',
    Templates__FreeImageMaxEstimatedWaitSeconds: '1800',
    Templates__PremiumImageMaxEstimatedWaitSeconds: '900',
    Templates__PrivilegedImageMaxEstimatedWaitSeconds: '900',
    Templates__FreeVideoMaxEstimatedWaitSeconds: '3600',
    Templates__PremiumVideoMaxEstimatedWaitSeconds: '1800',
    Templates__PrivilegedVideoMaxEstimatedWaitSeconds: '1800'
  };
  for (const [key, value] of Object.entries(expectedSchedulerValues)) {
    requireGroupValue(group, key, value);
  }

  requireGroupValue(group, 'Templates__FalProviderBalanceLowThresholdUsd', '10');
  requireGroupValue(group, 'Templates__FalProviderBalanceCriticalThresholdUsd', '5');
  rejectLegacySchedulerGroupKeys(group);
}

function requireGroupValue(group, key, expectedValue) {
  const entry = findEnv(group.envVars, key);
  if (!entry) {
    fail(`Env group ${group.name} is missing ${key}.`);
    return;
  }

  if (entry.value !== expectedValue) {
    fail(`Env group ${group.name} ${key} must be ${expectedValue}, found ${entry.value ?? '<missing>'}.`);
  }
}

function requireGroupBoolean(group, key) {
  const entry = findEnv(group.envVars, key);
  if (!entry) {
    fail(`Env group ${group.name} is missing ${key}.`);
    return;
  }

  if (entry.value !== 'true' && entry.value !== 'false') {
    fail(`Env group ${group.name} ${key} must be true or false, found ${entry.value ?? '<missing>'}.`);
  }
}

function rejectLegacySchedulerGroupKeys(group) {
  const legacyPrefixes = [
    'GENERATION_',
    'FAL_PROVIDER_',
    'TEMPLATES_REALTIME_'
  ];
  for (const entry of Array.isArray(group.envVars) ? group.envVars : []) {
    if (legacyPrefixes.some((prefix) => String(entry.key ?? '').startsWith(prefix))) {
      fail(`Env group ${group.name} uses inert legacy scheduler key ${entry.key}; use Templates__ configuration keys.`);
    }
  }
}

function requireWorkerOnlyLaneSettings(apiService, workerService) {
  const workerOnlyKeys = [
    'Templates__GenerationWorkerPollIntervalMilliseconds',
    'Templates__GenerationDispatchConcurrency',
    'Templates__ProviderReconciliationConcurrency',
    'Templates__MediaImportConcurrency',
    'Templates__GenerationMaintenanceConcurrency'
  ];
  const group = envVarGroups.find((candidate) => candidate.name === `${prefix}-shared`);
  for (const key of workerOnlyKeys) {
    if (findEnv(group?.envVars, key)) {
      fail(`Env group ${prefix}-shared must not define worker-only setting ${key}.`);
    }
    if (findEnv(apiService.envVars, key)) {
      fail(`${apiService.name} must not define worker-only setting ${key}.`);
    }
    if (!findEnv(workerService.envVars, key)) {
      fail(`${workerService.name} must define worker-only setting ${key}.`);
    }
  }
}

function requireSchedulerFingerprintParity(apiService, workerService) {
  requireSchedulerFingerprintFieldCoverage();
  const apiConfig = loadEffectiveSchedulerConfig(apiService, 'PetMagic.Host.Api');
  const workerConfig = loadEffectiveSchedulerConfig(workerService, 'PetMagic.Host.GenerationWorker');

  for (const field of schedulerFingerprintFields) {
    const apiValue = resolveSchedulerField(apiConfig, field);
    const workerValue = resolveSchedulerField(workerConfig, field);
    if (JSON.stringify(apiValue) !== JSON.stringify(workerValue)) {
      fail(
        `Scheduler fingerprint mismatch for ${field.name}: `
        + `${apiService.name}=${JSON.stringify(apiValue)}, ${workerService.name}=${JSON.stringify(workerValue)}.`
      );
    }
  }
}

function requireSchedulerFingerprintFieldCoverage() {
  const fingerprintPath = resolve(
    repoRoot,
    'src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/TemplateSchedulerConfigFingerprint.cs'
  );
  if (!existsSync(fingerprintPath)) {
    fail('TemplateSchedulerConfigFingerprint.cs is missing; Blueprint parity cannot be verified.');
    return;
  }

  const source = readFileSync(fingerprintPath, 'utf8');
  const implementationFields = new Set(
    [...source.matchAll(/options\.(Fal\.)?([A-Za-z][A-Za-z0-9]*)/g)]
      .map((match) => `${match[1] ?? ''}${match[2]}`)
  );
  const checkerFields = new Set(schedulerFingerprintFields.map((field) => field.path.join('.')));

  for (const path of implementationFields) {
    if (!checkerFields.has(path)) {
      fail(`Blueprint checker is missing scheduler fingerprint field Templates:${path.replaceAll('.', ':')}.`);
    }
  }
  for (const path of checkerFields) {
    if (!implementationFields.has(path)) {
      fail(`Blueprint checker has stale scheduler fingerprint field Templates:${path.replaceAll('.', ':')}.`);
    }
  }
}

function loadEffectiveSchedulerConfig(service, hostName) {
  const hostDir = resolve(repoRoot, 'src', 'Host', hostName);
  const basePath = resolve(hostDir, 'appsettings.json');
  const environmentPath = resolve(
    hostDir,
    `appsettings.${environment === 'production' ? 'Production' : 'Staging'}.json`
  );
  if (!existsSync(basePath)) {
    fail(`${service.name} base appsettings file is missing: ${relative(repoRoot, basePath)}.`);
    return {};
  }

  let config = JSON.parse(readFileSync(basePath, 'utf8'));
  if (existsSync(environmentPath)) {
    config = deepMerge(config, JSON.parse(readFileSync(environmentPath, 'utf8')));
  }

  const templates = structuredClone(config.Templates ?? {});
  const group = envVarGroups.find((candidate) => candidate.name === `${prefix}-shared`);
  applyTemplatesEnvironment(templates, group?.envVars);
  applyTemplatesEnvironment(templates, service.envVars);
  return templates;
}

function applyTemplatesEnvironment(templates, envVars) {
  for (const entry of Array.isArray(envVars) ? envVars : []) {
    if (entry.value === undefined) {
      continue;
    }

    if (entry.key === 'TEMPLATES_AI_PROVIDER') {
      setNestedValue(templates, ['AiProvider'], entry.value);
      continue;
    }

    if (!String(entry.key ?? '').startsWith('Templates__')) {
      continue;
    }

    const path = entry.key.slice('Templates__'.length).split('__').filter(Boolean);
    if (path.length > 0) {
      setNestedValue(templates, path, entry.value);
    }
  }
}

function resolveSchedulerField(config, field) {
  let raw = getNestedValue(config, field.path);
  if ((raw === undefined || raw === null) && field.alternatePath) {
    raw = getNestedValue(config, field.alternatePath);
  }
  return normalizeSchedulerValue(raw, field.kind, field.fallback, field.name);
}

function normalizeSchedulerValue(raw, kind, fallback, fieldName) {
  const missing = raw === undefined || raw === null;
  if (missing) {
    raw = fallback;
  } else if (String(raw).trim() === '') {
    fail(`Scheduler fingerprint field ${fieldName} must not be empty.`);
    return fallback;
  }

  if (kind === 'bool') {
    if (typeof raw === 'boolean') return raw;
    if (/^true$/i.test(String(raw))) return true;
    if (/^false$/i.test(String(raw))) return false;
    fail(`Scheduler fingerprint field ${fieldName} must be a boolean, found ${raw}.`);
    return fallback;
  }

  if (kind === 'text') {
    const normalized = String(raw).trim().toLowerCase();
    if (!normalized) {
      fail(`Scheduler fingerprint field ${fieldName} must not be empty.`);
      return String(fallback).trim().toLowerCase();
    }
    return normalized;
  }

  if (kind === 'csv') {
    const values = [...new Set(String(raw)
      .split(',')
      .map((value) => value.trim().toLowerCase())
      .filter(Boolean))]
      .sort();
    if (values.length === 0) {
      fail(`Scheduler fingerprint field ${fieldName} must contain at least one value.`);
      return String(fallback).split(',').map((value) => value.trim().toLowerCase()).filter(Boolean).sort();
    }
    return values;
  }

  const text = String(raw).trim();
  const parsed = /^[+-]?\d+$/.test(text) ? Number.parseInt(text, 10) : Number.NaN;
  if (!Number.isFinite(parsed)
      || (kind === 'positiveInt' && parsed <= 0)
      || (kind === 'nonNegativeInt' && parsed < 0)) {
    fail(`Scheduler fingerprint field ${fieldName} has invalid ${kind} value ${raw}.`);
    return fallback;
  }
  return parsed;
}

function schedulerField(name, path, kind, fallback, alternatePath) {
  return {
    name,
    path: path.split('.'),
    kind,
    fallback,
    alternatePath: alternatePath?.split('.')
  };
}

function getNestedValue(value, path) {
  let current = value;
  for (const segment of path) {
    if (!current || typeof current !== 'object') return undefined;
    const key = Object.keys(current).find((candidate) => candidate.toLowerCase() === segment.toLowerCase());
    if (!key) return undefined;
    current = current[key];
  }
  return current;
}

function setNestedValue(target, path, value) {
  let current = target;
  for (const segment of path.slice(0, -1)) {
    const existingKey = Object.keys(current).find((candidate) => candidate.toLowerCase() === segment.toLowerCase());
    const key = existingKey ?? segment;
    if (!current[key] || typeof current[key] !== 'object' || Array.isArray(current[key])) {
      current[key] = {};
    }
    current = current[key];
  }
  const lastSegment = path.at(-1);
  const existingKey = Object.keys(current).find((candidate) => candidate.toLowerCase() === lastSegment.toLowerCase());
  current[existingKey ?? lastSegment] = value;
}

function deepMerge(base, overlay) {
  const result = structuredClone(base);
  for (const [key, value] of Object.entries(overlay ?? {})) {
    if (value && typeof value === 'object' && !Array.isArray(value)
        && result[key] && typeof result[key] === 'object' && !Array.isArray(result[key])) {
      result[key] = deepMerge(result[key], value);
    } else {
      result[key] = structuredClone(value);
    }
  }
  return result;
}

function requireService(name, expected) {
  const service = services.find((candidate) => candidate.name === name);
  if (!service) {
    fail(`Missing service: ${name}.`);
    return null;
  }

  for (const [key, expectedValue] of Object.entries(expected)) {
    if (service[key] !== expectedValue) {
      fail(`${name} ${key} must be ${expectedValue}, found ${service[key] ?? '<missing>'}.`);
    }
  }

  const expectedAutoDeploy = 'off';
  if (service.autoDeployTrigger !== expectedAutoDeploy) {
    fail(`${name} must use autoDeployTrigger: ${expectedAutoDeploy}.`);
  }

  if (!hasEnvGroup(service, `${prefix}-shared`) && name !== `${prefix}-admin-web`) {
    fail(`${name} must include env group ${prefix}-shared.`);
  }

  if (Object.hasOwn(service, 'scaling')) {
    fail(`${name} must not define Render autoscaling; use fixed numInstances: 1.`);
  }

  return service;
}

function requireWorkerIsPrivateAndEphemeral(service) {
  for (const key of ['domains', 'disk', 'healthCheckPath']) {
    if (Object.hasOwn(service, key)) {
      fail(`${service.name} must not define ${key}.`);
    }
  }
}

function rejectWorkerExternalBillingConfiguration(service) {
  const forbiddenPrefixes = ['STRIPE_', 'GOOGLE_PLAY_', 'APP_STORE_', 'FIREBASE_'];
  const forbiddenKeys = new Set([
    'STORE_ACCOUNT_BINDING_MODE',
    'ECONOMY_RECONCILIATION_ENABLED',
    'ECONOMY_PUSH_OUTBOX_DISPATCHER_ENABLED'
  ]);

  for (const entry of effectiveServiceEnvVars(service)) {
    const key = String(entry.key ?? '');
    if (forbiddenKeys.has(key) || forbiddenPrefixes.some((prefix) => key.startsWith(prefix))) {
      fail(
        `${service.name} must not receive external billing/store/push setting ${key}; `
        + 'the generation worker uses bounded wallet-only Economy infrastructure.'
      );
    }
  }
}

function requireDomain(service, domain) {
  if (!Array.isArray(service.domains) || !service.domains.includes(domain)) {
    fail(`${service.name} must define domain ${domain}.`);
  }
}

function requireBuildFilterPath(service, expectedPath) {
  if (!Array.isArray(service.buildFilter?.paths) || !service.buildFilter.paths.includes(expectedPath)) {
    fail(`${service.name} buildFilter must include ${expectedPath}.`);
  }
}

function requireDockerfile(service, options) {
  const dockerfilePath = resolve(repoRoot, service.dockerfilePath ?? './Dockerfile');
  const dockerContext = resolve(repoRoot, service.dockerContext ?? '.');
  if (!existsSync(dockerfilePath)) {
    fail(`${service.name} Dockerfile does not exist: ${service.dockerfilePath}.`);
    return;
  }

  if (!existsSync(dockerContext)) {
    fail(`${service.name} dockerContext does not exist: ${service.dockerContext}.`);
    return;
  }

  const relativeDockerfile = relative(dockerContext, dockerfilePath);
  if (relativeDockerfile.startsWith('..')) {
    fail(`${service.name} Dockerfile must be inside dockerContext for Render: dockerfilePath=${service.dockerfilePath}, dockerContext=${service.dockerContext}.`);
  }

  const source = readFileSync(dockerfilePath, 'utf8');

  if (options.expectedAppDll && !source.includes(`ENV APP_DLL=${options.expectedAppDll}`)) {
    fail(`${service.name} Dockerfile must set ENV APP_DLL=${options.expectedAppDll}.`);
  }

  if (options.expectedExpose && !new RegExp(`^EXPOSE\\s+${escapeRegExp(options.expectedExpose)}\\s*$`, 'm').test(source)) {
    fail(`${service.name} Dockerfile must expose ${options.expectedExpose}.`);
  }

  if (options.requiredCopy && !source.includes(`COPY ${options.requiredCopy}`)) {
    fail(`${service.name} Dockerfile must copy ${options.requiredCopy}.`);
  }

  if (options.mustBindHost && !source.includes(options.mustBindHost)) {
    fail(`${service.name} Dockerfile must bind to ${options.mustBindHost}.`);
  }

  rejectSuspiciousBuildArgs(service, source);

  for (const buildArg of options.buildArgsFromEnv ?? []) {
    if (!new RegExp(`^ARG\\s+${escapeRegExp(buildArg)}(?:\\s*=.*)?\\s*$`, 'm').test(source)) {
      fail(`${service.name} Dockerfile must declare ARG ${buildArg}.`);
      continue;
    }

    if (!findEnv(service.envVars, buildArg)) {
      fail(`${service.name} render.yaml envVars must provide ${buildArg} for Docker build-time configuration.`);
    }
  }
}

function rejectSuspiciousBuildArgs(service, dockerfileSource) {
  const suspiciousArgs = [...dockerfileSource.matchAll(/^ARG\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s*=.*)?\s*$/gm)]
    .map((match) => match[1])
    .filter((name) => /SECRET|PRIVATE|TOKEN|PASSWORD|KEY/i.test(name))
    .filter((name) => !['TARGETARCH', 'DEBIAN_FRONTEND'].includes(name));

  for (const arg of suspiciousArgs) {
    fail(`${service.name} Dockerfile must not declare secret-like build arg ${arg}. Use runtime secrets instead.`);
  }
}

function requireEnvValue(service, key, expectedValue) {
  const entry = findEnv(service.envVars, key);
  if (!entry) {
    fail(`${service.name} is missing env ${key}.`);
    return;
  }

  if (entry.value !== expectedValue) {
    fail(`${service.name} ${key} must be ${expectedValue}, found ${entry.value ?? '<missing>'}.`);
  }
}

function requireEnvContains(service, key, expectedValue) {
  const entry = findEnv(service.envVars, key);
  if (!entry) {
    fail(`${service.name} is missing env ${key}.`);
    return;
  }

  if (!String(entry.value ?? '').includes(expectedValue)) {
    fail(`${service.name} ${key} must include ${expectedValue}.`);
  }
}

function requireDatabaseBinding(service, key, databaseName) {
  const entry = findEnv(service.envVars, key);
  if (!entry?.fromDatabase) {
    fail(`${service.name} ${key} must use fromDatabase.`);
    return;
  }

  if (entry.fromDatabase.name !== databaseName || entry.fromDatabase.property !== 'connectionString') {
    fail(`${service.name} ${key} must bind ${databaseName}.connectionString.`);
  }
}

function requireSecretKeys(service, keys) {
  for (const key of keys) {
    const entry = findEnv(service.envVars, key);
    if (!entry) {
      fail(`${service.name} is missing secret ${key}.`);
      continue;
    }

    if (entry.sync !== false) {
      fail(`${service.name} secret ${key} must use sync: false.`);
    }

    if (entry.value !== undefined) {
      fail(`${service.name} secret ${key} must not contain a value in render.yaml.`);
    }
  }
}

function requireDeferredEnvValue(service, key) {
  const entry = findEnv(service.envVars, key);
  if (!entry) {
    fail(`${service.name} is missing deferred env ${key}.`);
    return;
  }

  if (entry.sync !== false || entry.value !== undefined) {
    fail(`${service.name} ${key} must use sync: false without a committed value.`);
  }
}

function requirePersistentDisk(service, expectedName, expectedMountPath) {
  const disk = service.disk;
  if (!disk || typeof disk !== 'object' || Array.isArray(disk)) {
    fail(`${service.name} must define a persistent disk.`);
    return;
  }

  if (disk.name !== expectedName) {
    fail(`${service.name} disk name must be ${expectedName}.`);
  }
  if (disk.mountPath !== expectedMountPath) {
    fail(`${service.name} disk mountPath must be ${expectedMountPath}.`);
  }
  if (disk.sizeGB !== 10) {
    fail(`${service.name} disk sizeGB must be exactly 10, found ${disk.sizeGB ?? '<missing>'}.`);
  }
}

function rejectPublicSecrets(service) {
  const publicSecrets = service.envVars
    .filter((entry) => typeof entry.key === 'string' && entry.key.startsWith('NEXT_PUBLIC_'))
    .filter((entry) => /SECRET|PRIVATE|TOKEN|PASSWORD|KEY/i.test(entry.key));

  for (const entry of publicSecrets) {
    fail(`${service.name} exposes suspicious browser env ${entry.key}.`);
  }
}

function requireSecretCoverageInFiles(paths) {
  const secretKeys = collectSyncFalseSecretKeys();
  for (const path of paths) {
    const absolutePath = resolve(repoRoot, path);
    if (!existsSync(absolutePath)) {
      fail(`Secret coverage file is missing: ${path}.`);
      continue;
    }

    const source = readFileSync(absolutePath, 'utf8');
    for (const key of secretKeys) {
      if (!new RegExp(`(^|[^A-Za-z0-9_])${escapeRegExp(key)}([^A-Za-z0-9_]|$)`).test(source)) {
        fail(`${path} must mention Render sync:false secret ${key}.`);
      }
    }
  }
}

function collectSyncFalseSecretKeys() {
  return [...new Set(services.flatMap((service) =>
    (Array.isArray(service.envVars) ? service.envVars : [])
      .filter((entry) => entry.sync === false)
      .map((entry) => entry.key)
      .filter(Boolean)))]
    .sort();
}

function hasEnvGroup(service, groupName) {
  return Array.isArray(service.envVars)
    && service.envVars.some((entry) => entry.fromGroup === groupName);
}

function effectiveServiceEnvVars(service) {
  const effective = [];
  for (const entry of Array.isArray(service.envVars) ? service.envVars : []) {
    if (!entry.fromGroup) {
      effective.push(entry);
      continue;
    }

    const group = envVarGroups.find((candidate) => candidate.name === entry.fromGroup);
    if (!group) {
      fail(`${service.name} references missing env group ${entry.fromGroup}.`);
      continue;
    }

    effective.push(...(Array.isArray(group.envVars) ? group.envVars : []));
  }
  return effective;
}

function findEnv(envVars, key) {
  return Array.isArray(envVars)
    ? envVars.find((entry) => entry.key === key)
    : undefined;
}

function fail(message) {
  failures.push(message);
}

function finish() {
  if (failures.length > 0) {
    console.error('Render Blueprint check failed:');
    for (const failure of failures) {
      console.error(`- ${failure}`);
    }
    process.exit(1);
  }

  console.log(`Render Blueprint ok: ${services.length} services, ${databases.length} database, ${envVarGroups.length} env group.`);
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
Render Blueprint checker.

Usage:
  node scripts/qa/check-render-blueprint.mjs

Options:
  --file <path>  Blueprint path. Defaults to render.yaml.
  --root <path>  Repository root. Defaults to this repository.
  --environment <value>  staging or production.
  --help, -h     Print this help.

The checker validates PetMagic's expected Render staging topology, secret
placeholders, database bindings, and API/worker/admin role separation.
`.trim());
}

function escapeRegExp(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
