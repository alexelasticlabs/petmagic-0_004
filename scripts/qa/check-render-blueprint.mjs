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

requireServiceCount(3);
requireDatabase(`${prefix}-db`, 'basic-1gb');
requireEnvGroup(`${prefix}-shared`);

const api = requireService(`${prefix}-api`, {
  type: 'web',
  runtime: 'docker',
  dockerfilePath: './Dockerfile.api',
  dockerContext: '.',
  healthCheckPath: '/health'
});

const worker = requireService(`${prefix}-generation-worker`, {
  type: 'worker',
  runtime: 'docker',
  dockerfilePath: './Dockerfile.generation-worker',
  dockerContext: '.'
});

const admin = requireService(`${prefix}-admin-web`, {
  type: 'web',
  runtime: 'docker',
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
  requireEnvValue(
    api,
    'ExternalAuth__MobileRedirectScheme',
    environment === 'production' ? 'petmagic' : 'petmagic-staging'
  );
  requireEnvValue(api, 'Templates__GenerationWorkerEnabled', 'false');
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
    environment === 'production'
      ? 'Templates__FalProviderSpendDailyLimitUsd'
      : 'FAL_PROVIDER_SPEND_DAILY_LIMIT_USD',
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
  if (Array.isArray(worker.domains) && worker.domains.length > 0) {
    fail(`${prefix}-generation-worker must not define public domains.`);
  }

  requireEnvValue(worker, 'Templates__GenerationWorkerEnabled', 'true');
  requireEnvValue(worker, 'Templates__MediaCleanupWorkerEnabled', 'false');
  requireEnvValue(worker, 'Templates__TemplateOfTheDayAutoPickWorkerEnabled', 'false');
  requireEnvValue(worker, 'Templates__MaxConcurrentJobsPerWorker', '2');
  requireDatabaseBinding(worker, 'ConnectionStrings__DefaultConnection', `${prefix}-db`);
  requireSecretKeys(worker, [
    'Jwt__SigningKey',
    environment === 'production'
      ? 'Templates__FalProviderSpendDailyLimitUsd'
      : 'FAL_PROVIDER_SPEND_DAILY_LIMIT_USD',
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
    'OTEL_EXPORTER_OTLP_ENDPOINT'
  ]);
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

function requireDatabase(name, plan) {
  const database = databases.find((candidate) => candidate.name === name);
  if (!database) {
    fail(`Missing database: ${name}.`);
    return;
  }

  if (database.plan !== plan) {
    fail(`${name} must use plan ${plan}, found ${database.plan ?? '<missing>'}.`);
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

  if (environment === 'production') {
    requireGroupValue(group, 'Templates__GlobalMaxConcurrentGenerations', '8');
    requireGroupValue(group, 'Templates__ImageProtectedConcurrentGenerations', '3');
    requireGroupValue(group, 'Templates__VideoBorrowMaxConcurrentGenerations', '2');
    requireGroupValue(group, 'Templates__FalProviderConcurrencyLimit', '10');
    requireGroupValue(group, 'Templates__FalProviderReservedConcurrency', '2');
    requireGroupValue(group, 'Templates__FalProviderBalanceLowThresholdUsd', '10');
    requireGroupValue(group, 'Templates__FalProviderBalanceCriticalThresholdUsd', '5');
  }
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

  const expectedAutoDeploy = environment === 'production' ? 'off' : 'checksPass';
  if (service.autoDeployTrigger !== expectedAutoDeploy) {
    fail(`${name} must use autoDeployTrigger: ${expectedAutoDeploy}.`);
  }

  if (!hasEnvGroup(service, `${prefix}-shared`) && name !== `${prefix}-admin-web`) {
    fail(`${name} must include env group ${prefix}-shared.`);
  }

  return service;
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
  if (!Number.isFinite(disk.sizeGB) || disk.sizeGB < 1) {
    fail(`${service.name} disk sizeGB must be at least 1.`);
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
