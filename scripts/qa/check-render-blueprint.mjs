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
requireDatabase('petmagic-staging-db', 'basic-1gb');
requireEnvGroup('petmagic-staging-shared');

const api = requireService('petmagic-staging-api', {
  type: 'web',
  runtime: 'docker',
  dockerfilePath: './Dockerfile.api',
  dockerContext: '.',
  healthCheckPath: '/health'
});

const worker = requireService('petmagic-staging-generation-worker', {
  type: 'worker',
  runtime: 'docker',
  dockerfilePath: './Dockerfile.generation-worker',
  dockerContext: '.'
});

const admin = requireService('petmagic-staging-admin-web', {
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
  requireDomain(api, 'api.staging.petmagic.app');
  requireEnvValue(api, 'PORT', '5000');
  requireEnvValue(api, 'ASPNETCORE_HTTP_PORTS', '5000');
  requireEnvValue(api, 'Templates__GenerationWorkerEnabled', 'false');
  requireEnvValue(api, 'Templates__TemplateOfTheDayAutoPickWorkerEnabled', 'true');
  requireEnvValue(api, 'DataProtection__KeysPath', '/var/petmagic/DataProtection-Keys');
  requireEnvValue(api, 'StaticFiles__ExtraWebRootPath', '/var/petmagic/wwwroot');
  requireEnvContains(api, 'AllowedHosts', 'api.staging.petmagic.app');
  requireEnvContains(api, 'AllowedHosts', 'petmagic-staging-api.onrender.com');
  requireDatabaseBinding(api, 'ConnectionStrings__DefaultConnection', 'petmagic-staging-db');
  requireSecretKeys(api, [
    'Jwt__SigningKey',
    'FAL_PROVIDER_SPEND_DAILY_LIMIT_USD',
    'FAL_AI_API_KEY',
    'R2_ACCOUNT_ID',
    'R2_ACCESS_KEY',
    'R2_SECRET_KEY',
    'R2_BUCKET_NAME',
    'R2_PUBLIC_URL',
    'STRIPE_TEST_SECRET_KEY',
    'STRIPE_TEST_PUBLISHABLE_KEY',
    'STRIPE_TEST_WEBHOOK_SECRET',
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
  if (Array.isArray(worker.domains) && worker.domains.length > 0) {
    fail('petmagic-staging-generation-worker must not define public domains.');
  }

  requireEnvValue(worker, 'Templates__GenerationWorkerEnabled', 'true');
  requireEnvValue(worker, 'Templates__MediaCleanupWorkerEnabled', 'false');
  requireEnvValue(worker, 'Templates__TemplateOfTheDayAutoPickWorkerEnabled', 'false');
  requireEnvValue(worker, 'Templates__MaxConcurrentJobsPerWorker', '2');
  requireDatabaseBinding(worker, 'ConnectionStrings__DefaultConnection', 'petmagic-staging-db');
  requireSecretKeys(worker, [
    'Jwt__SigningKey',
    'FAL_PROVIDER_SPEND_DAILY_LIMIT_USD',
    'FAL_AI_API_KEY',
    'R2_ACCOUNT_ID',
    'R2_ACCESS_KEY',
    'R2_SECRET_KEY',
    'R2_BUCKET_NAME',
    'R2_PUBLIC_URL',
    'STRIPE_TEST_SECRET_KEY',
    'STRIPE_TEST_PUBLISHABLE_KEY',
    'STRIPE_TEST_WEBHOOK_SECRET',
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
  requireDomain(admin, 'admin.staging.petmagic.app');
  requireEnvValue(admin, 'PORT', '3000');
  requireEnvValue(admin, 'NODE_ENV', 'production');
  requireEnvValue(admin, 'NEXT_PUBLIC_API_BASE_URL', 'https://api.staging.petmagic.app');
  requireEnvValue(admin, 'INTERNAL_API_BASE_URL', 'https://api.staging.petmagic.app');
  rejectPublicSecrets(admin);
}

requireSecretCoverageInFiles([
  'docs/render-staging-deployment.md',
  'docs/render-staging-secrets-checklist.md',
  '.env.staging.local.example'
]);

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
}

function requireEnvGroup(name) {
  const group = envVarGroups.find((candidate) => candidate.name === name);
  if (!group) {
    fail(`Missing env var group: ${name}.`);
    return;
  }

  requireGroupValue(group, 'ASPNETCORE_ENVIRONMENT', 'Staging');
  requireGroupValue(group, 'DOTNET_ENVIRONMENT', 'Staging');
  requireGroupValue(group, 'TEMPLATES_STORAGE_PROVIDER', 'R2');
  requireGroupValue(group, 'TEMPLATES_AI_PROVIDER', 'Fal');
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

  if (service.autoDeployTrigger !== 'checksPass') {
    fail(`${name} must use autoDeployTrigger: checksPass.`);
  }

  if (!hasEnvGroup(service, 'petmagic-staging-shared') && name !== 'petmagic-staging-admin-web') {
    fail(`${name} must include env group petmagic-staging-shared.`);
  }

  return service;
}

function requireDomain(service, domain) {
  if (!Array.isArray(service.domains) || !service.domains.includes(domain)) {
    fail(`${service.name} must define domain ${domain}.`);
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
  --help, -h     Print this help.

The checker validates PetMagic's expected Render staging topology, secret
placeholders, database bindings, and API/worker/admin role separation.
`.trim());
}

function escapeRegExp(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
