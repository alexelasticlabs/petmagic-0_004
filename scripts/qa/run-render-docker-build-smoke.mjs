#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
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

const dryRun = args.has('--dry-run');
const noCache = args.has('--no-cache');
const pull = args.has('--pull');
const platform = getOptionValue('--platform');
const runId = getOptionValue('--run-id') ?? `render-docker-build-smoke-${formatTimestamp(new Date())}`;
const artifactDir = getOptionValue('--artifact-dir') ?? join('artifacts', 'render-docker-build-smoke', runId);
const requestedServices = parseServiceSelection(getOptionValue('--service') ?? 'api,worker,admin');

const services = [
  {
    name: 'api',
    tag: 'petmagic-render-smoke-api:local',
    dockerfile: 'Dockerfile.api',
    context: '.',
    buildArgs: []
  },
  {
    name: 'worker',
    tag: 'petmagic-render-smoke-generation-worker:local',
    dockerfile: 'Dockerfile.generation-worker',
    context: '.',
    buildArgs: []
  },
  {
    name: 'admin',
    tag: 'petmagic-render-smoke-admin-web:local',
    dockerfile: 'apps/admin-web/Dockerfile',
    context: 'apps/admin-web',
    buildArgs: [
      ['NEXT_PUBLIC_API_BASE_URL', 'https://api.staging.petmagic.app'],
      ['INTERNAL_API_BASE_URL', 'https://api.staging.petmagic.app'],
      ['ALLOW_LOCALHOST_API_BASE_URL_IN_PRODUCTION', 'false'],
      ['NEXT_PUBLIC_ALLOW_LOCALHOST_API_BASE_URL_IN_PRODUCTION', 'false']
    ]
  }
].filter((service) => requestedServices.has(service.name));

if (services.length === 0) {
  fail(`No services selected. Use --service api,worker,admin.`);
}

mkdirSync(artifactDir, { recursive: true });

const evidence = {
  runId,
  startedAtUtc: new Date().toISOString(),
  dryRun,
  noCache,
  pull,
  platform: platform ?? null,
  services: []
};

try {
  ensureDockerAvailable();
  for (const service of services) {
    runDockerBuild(service);
  }

  evidence.completedAtUtc = new Date().toISOString();
  evidence.status = 'passed';
  writeEvidence();
  console.log(`Render Docker build smoke ok: ${services.map((service) => service.name).join(', ')}.`);
} catch (error) {
  evidence.completedAtUtc = new Date().toISOString();
  evidence.status = 'failed';
  evidence.error = error instanceof Error ? error.message : String(error);
  writeEvidence();
  console.error(`Render Docker build smoke failed: ${evidence.error}`);
  process.exit(1);
}

function runDockerBuild(service) {
  requirePath(service.dockerfile, `${service.name} Dockerfile`);
  requirePath(service.context, `${service.name} Docker context`);

  const commandArgs = [
    'build',
    '--file',
    service.dockerfile,
    '--tag',
    service.tag
  ];

  if (platform) {
    commandArgs.push('--platform', platform);
  }

  if (noCache) {
    commandArgs.push('--no-cache');
  }

  if (pull) {
    commandArgs.push('--pull');
  }

  for (const [key, value] of service.buildArgs) {
    commandArgs.push('--build-arg', `${key}=${value}`);
  }

  commandArgs.push(service.context);

  console.log(`[${service.name}] docker ${commandArgs.join(' ')}`);
  const startedAt = new Date();
  const serviceEvidence = {
    name: service.name,
    tag: service.tag,
    dockerfile: service.dockerfile,
    context: service.context,
    startedAtUtc: startedAt.toISOString(),
    command: `docker ${commandArgs.join(' ')}`,
    status: dryRun ? 'skipped' : 'running'
  };
  evidence.services.push(serviceEvidence);

  if (dryRun) {
    serviceEvidence.completedAtUtc = new Date().toISOString();
    return;
  }

  const result = spawnSync('docker', commandArgs, {
    cwd: repoRoot,
    env: {
      ...process.env,
      DOCKER_BUILDKIT: process.env.DOCKER_BUILDKIT || '1'
    },
    encoding: 'utf8',
    maxBuffer: 20 * 1024 * 1024
  });

  serviceEvidence.completedAtUtc = new Date().toISOString();
  serviceEvidence.exitCode = result.status ?? 1;
  serviceEvidence.status = result.status === 0 ? 'passed' : 'failed';
  serviceEvidence.stdoutTail = tail(result.stdout, 4000);
  serviceEvidence.stderrTail = tail(result.stderr, 4000);

  if (result.status !== 0) {
    throw new Error(`${service.name} docker build failed with exit code ${serviceEvidence.exitCode}`);
  }
}

function ensureDockerAvailable() {
  if (dryRun) {
    return;
  }

  const result = spawnSync('docker', ['version', '--format', '{{.Server.Version}}'], {
    cwd: repoRoot,
    encoding: 'utf8'
  });

  if (result.status !== 0) {
    throw new Error(`Docker is not available: ${tail(result.stderr || result.stdout, 1000)}`);
  }
}

function requirePath(path, label) {
  if (!existsSync(join(repoRoot, path))) {
    throw new Error(`${label} does not exist: ${path}`);
  }
}

function writeEvidence() {
  writeFileSync(join(artifactDir, 'evidence.json'), `${JSON.stringify(evidence, null, 2)}\n`);
  writeFileSync(join(artifactDir, 'summary.md'), renderSummary());
  console.log(`Evidence written to ${join(artifactDir, 'summary.md')}`);
}

function renderSummary() {
  return [
    '# Render Docker Build Smoke',
    '',
    `Run ID: ${runId}`,
    `Status: ${evidence.status ?? 'running'}`,
    `Started: ${evidence.startedAtUtc}`,
    `Completed: ${evidence.completedAtUtc ?? 'n/a'}`,
    `Dry run: ${dryRun}`,
    `Platform: ${platform ?? 'docker default'}`,
    '',
    '| Service | Result | Tag |',
    '| --- | --- | --- |',
    ...evidence.services.map((service) => `| ${service.name} | ${service.status} | ${service.tag} |`),
    ''
  ].join('\n');
}

function parseServiceSelection(value) {
  const allowed = new Set(['api', 'worker', 'admin']);
  const selected = new Set();
  for (const item of String(value).split(',')) {
    const service = item.trim();
    if (!service) {
      continue;
    }

    if (!allowed.has(service)) {
      fail(`Unsupported service: ${service}. Use api, worker, or admin.`);
    }

    selected.add(service);
  }

  return selected;
}

function fail(message) {
  console.error(message);
  process.exit(1);
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

function tail(value, maxLength) {
  const text = String(value || '');
  return text.length > maxLength ? text.slice(text.length - maxLength) : text;
}

function formatTimestamp(date) {
  return date.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z');
}

function printUsage() {
  console.log(`
Render Docker build smoke.

Usage:
  node scripts/qa/run-render-docker-build-smoke.mjs
  node scripts/qa/run-render-docker-build-smoke.mjs --service api,worker --platform linux/amd64

Options:
  --service <list>      Comma-separated services: api, worker, admin. Defaults to all.
  --platform <value>    Optional Docker platform, for example linux/amd64.
  --no-cache            Pass --no-cache to docker build.
  --pull                Pass --pull to docker build.
  --dry-run             Print commands and write evidence without building.
  --run-id <id>         Artifact run id.
  --artifact-dir <dir>  Evidence output directory.
  --help, -h            Print this help.

The smoke builds the same Dockerfiles and contexts declared in render.yaml.
It does not pass secrets as Docker build args.
`.trim());
}
