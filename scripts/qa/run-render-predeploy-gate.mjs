#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
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

const withDockerBuild = args.has('--with-docker-build');
const skipDotnetBuild = args.has('--skip-dotnet-build');
const runId = getOptionValue('--run-id') ?? `render-predeploy-gate-${formatTimestamp(new Date())}`;
const artifactDir = getOptionValue('--artifact-dir') ?? join('artifacts', 'render-predeploy-gate', runId);
const dockerPlatform = getOptionValue('--docker-platform') ?? 'linux/amd64';

mkdirSync(artifactDir, { recursive: true });

const evidence = {
  runId,
  startedAtUtc: new Date().toISOString(),
  withDockerBuild,
  skipDotnetBuild,
  dockerPlatform,
  steps: []
};

const steps = [
  {
    name: 'repository_sensitive_files',
    command: ['node', ['scripts/qa/check-repository-sensitive-files.mjs']],
    required: true
  },
  {
    name: 'render_blueprint',
    command: ['node', ['scripts/qa/check-render-blueprint.mjs']],
    required: true
  },
  {
    name: 'staging_env_example',
    command: ['node', ['scripts/qa/check-staging-env-readiness.mjs', '--file', '.env.staging.local.example', '--example']],
    required: true
  },
  {
    name: 'markdown_local_links',
    command: ['node', ['scripts/qa/check-markdown-local-links.mjs']],
    required: true
  },
  {
    name: 'script_safety_inventory',
    command: ['node', ['scripts/qa/test-script-safety-inventory.mjs']],
    required: true
  },
  {
    name: 'compose_staging_example_config',
    command: ['docker', ['compose', '--env-file', '.env.staging.local.example', 'config', '--quiet']],
    required: true
  },
  {
    name: 'backend_api_build',
    command: [
      'dotnet',
      [
        'build',
        'src/Host/PetMagic.Host.Api/PetMagic.Host.Api.csproj',
        '--disable-build-servers',
        '-m:1',
        '-nr:false',
        '-p:UseSharedCompilation=false'
      ]
    ],
    required: !skipDotnetBuild,
    skippedReason: 'Skipped by --skip-dotnet-build.'
  },
  {
    name: 'render_docker_build_smoke',
    command: ['node', ['scripts/qa/run-render-docker-build-smoke.mjs', '--platform', dockerPlatform]],
    required: withDockerBuild,
    skippedReason: 'Skipped by default. Pass --with-docker-build before first deploy or after Dockerfile changes.'
  }
];

for (const step of steps) {
  runStep(step);
}

evidence.completedAtUtc = new Date().toISOString();
evidence.status = evidence.steps.some((step) => step.status === 'failed') ? 'failed' : 'passed';
writeEvidence();

if (evidence.status !== 'passed') {
  process.exitCode = 1;
}

function runStep(step) {
  if (!step.required) {
    const skipped = {
      name: step.name,
      status: 'skipped',
      detail: step.skippedReason,
      startedAtUtc: new Date().toISOString(),
      completedAtUtc: new Date().toISOString()
    };
    evidence.steps.push(skipped);
    console.log(`[skip] ${step.name}: ${step.skippedReason}`);
    return;
  }

  const [command, commandArgs] = step.command;
  const commandLine = `${command} ${commandArgs.join(' ')}`;
  console.log(`[run] ${step.name}: ${commandLine}`);

  const startedAt = new Date();
  const result = spawnSync(command, commandArgs, {
    cwd: repoRoot,
    encoding: 'utf8',
    maxBuffer: 20 * 1024 * 1024
  });

  const stepEvidence = {
    name: step.name,
    command: commandLine,
    startedAtUtc: startedAt.toISOString(),
    completedAtUtc: new Date().toISOString(),
    exitCode: result.status ?? 1,
    status: result.status === 0 ? 'passed' : 'failed',
    stdoutTail: tail(result.stdout, 4000),
    stderrTail: tail(result.stderr, 4000)
  };
  evidence.steps.push(stepEvidence);

  if (result.status === 0) {
    console.log(`[ok] ${step.name}`);
    return;
  }

  console.error(`[fail] ${step.name}: exit ${stepEvidence.exitCode}`);
}

function writeEvidence() {
  writeFileSync(join(artifactDir, 'evidence.json'), `${JSON.stringify(evidence, null, 2)}\n`);
  writeFileSync(join(artifactDir, 'summary.md'), renderSummary());
  console.log(`Evidence written to ${join(artifactDir, 'summary.md')}`);
}

function renderSummary() {
  return [
    '# Render Predeploy Gate',
    '',
    `Run ID: ${runId}`,
    `Status: ${evidence.status ?? 'running'}`,
    `Started: ${evidence.startedAtUtc}`,
    `Completed: ${evidence.completedAtUtc ?? 'n/a'}`,
    `Docker build smoke: ${withDockerBuild ? `enabled (${dockerPlatform})` : 'skipped'}`,
    `Backend build: ${skipDotnetBuild ? 'skipped' : 'enabled'}`,
    '',
    '| Step | Result | Detail |',
    '| --- | --- | --- |',
    ...evidence.steps.map((step) => {
      const detail = step.status === 'skipped'
        ? step.detail
        : `exit ${step.exitCode}`;
      return `| ${step.name} | ${step.status} | ${String(detail).replaceAll('|', '\\|')} |`;
    }),
    ''
  ].join('\n');
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
Render predeploy gate.

Usage:
  node scripts/qa/run-render-predeploy-gate.mjs
  node scripts/qa/run-render-predeploy-gate.mjs --with-docker-build --docker-platform linux/amd64

Options:
  --with-docker-build      Also build API, worker, and admin Docker images with Render Dockerfile/context settings.
  --docker-platform <val>  Platform passed to the Docker build smoke. Defaults to linux/amd64.
  --skip-dotnet-build      Skip the backend API dotnet build.
  --run-id <id>            Artifact run id.
  --artifact-dir <dir>     Evidence output directory.
  --help, -h               Print this help.

The default gate runs only checks that do not require staging secrets and do not
mutate a database. It is intended before pushing Render Blueprint changes or
manually triggering a Render deploy.
`.trim());
}
