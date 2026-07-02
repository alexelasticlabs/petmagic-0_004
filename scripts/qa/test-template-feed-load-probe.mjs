#!/usr/bin/env node

import { createServer } from 'node:http';
import { existsSync, mkdtempSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const probePath = join(scriptDir, 'run-template-feed-load-probe.mjs');

try {
  await assertSuccessfulProbeWritesEvidence();
  await assertFailedFeedExitsNonZero();
  console.log('template feed load probe self-test passed');
} catch (error) {
  console.error(error.stack || String(error));
  process.exitCode = 1;
}

async function assertSuccessfulProbeWritesEvidence() {
  const observations = { authorization: false, customHeader: false };
  const server = createServer((request, response) => {
    observations.authorization ||= request.headers.authorization === 'Bearer api-token';
    observations.customHeader ||= request.headers['x-test-scope'] === 'template-feed';
    response.writeHead(200, { 'content-type': 'application/json' });
    response.end(JSON.stringify({
      items: [{ id: 'template-1' }, { id: 'template-2' }],
      nextCursor: 'cursor-2',
      hasMore: true,
    }));
  });

  const { baseUrl, close } = await listen(server);
  try {
    const artifactDir = mkdtempSync(join(tmpdir(), 'template-feed-load-probe-ok-'));
    const result = await runProbe({
      artifactDir,
      apiBase: baseUrl,
      extraArgs: [
        '--duration-seconds=1',
        '--concurrency=2',
        '--interval-ms=25',
        '--timeout-ms=1000',
        '--max-errors=0',
        '--bearer-token=api-token',
        '--headers-json={"X-Test-Scope":"template-feed"}',
      ],
    });

    assertExitCode(result, 0);
    assert(observations.authorization, 'probe did not send bearer auth');
    assert(observations.customHeader, 'probe did not send custom header');
    const evidencePath = join(artifactDir, 'evidence.json');
    const summaryPath = join(artifactDir, 'summary.md');
    assert(existsSync(evidencePath), 'missing evidence.json');
    assert(existsSync(summaryPath), 'missing summary.md');
    const evidence = JSON.parse(readFileSync(evidencePath, 'utf8'));
    assert(evidence.requests.total > 0, 'expected at least one request');
    assert(evidence.requests.failed === 0, `expected zero failures, got ${evidence.requests.failed}`);
    assert(evidence.itemCounts.max === 2, `expected item count max 2, got ${evidence.itemCounts.max}`);
  } finally {
    await close();
  }
}

async function assertFailedFeedExitsNonZero() {
  const server = createServer((_request, response) => {
    response.writeHead(500, { 'content-type': 'application/json' });
    response.end(JSON.stringify({ error: 'feed failed' }));
  });

  const { baseUrl, close } = await listen(server);
  try {
    const artifactDir = mkdtempSync(join(tmpdir(), 'template-feed-load-probe-fail-'));
    const result = await runProbe({
      artifactDir,
      apiBase: baseUrl,
      extraArgs: [
        '--duration-seconds=1',
        '--concurrency=1',
        '--interval-ms=25',
        '--timeout-ms=1000',
        '--max-errors=0',
      ],
    });

    assert(
      result.code !== 0,
      `failed feed should produce non-zero exit\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
    );
    const evidence = JSON.parse(readFileSync(join(artifactDir, 'evidence.json'), 'utf8'));
    assert(evidence.requests.failed > 0, 'expected failed request count');
  } finally {
    await close();
  }
}

function runProbe({ artifactDir, apiBase, extraArgs }) {
  return spawnNode([
    probePath,
    `--api-base=${apiBase}`,
    `--artifact-dir=${artifactDir}`,
    '--run-id=self-test-load-probe',
    ...extraArgs,
  ]);
}

function listen(server) {
  return new Promise((resolvePromise, reject) => {
    server.on('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const port = server.address().port;
      resolvePromise({
        baseUrl: `http://127.0.0.1:${port}`,
        close: () => new Promise(closeResolve => server.close(closeResolve)),
      });
    });
  });
}

function spawnNode(args) {
  return new Promise((resolvePromise) => {
    const child = spawn(process.execPath, args, {
      cwd: dirname(scriptDir),
      env: process.env,
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    let stdout = '';
    let stderr = '';
    child.stdout.on('data', chunk => {
      stdout += chunk;
    });
    child.stderr.on('data', chunk => {
      stderr += chunk;
    });
    child.on('exit', code => {
      resolvePromise({ code, stdout, stderr });
    });
  });
}

function assertExitCode(result, expected) {
  assert(
    result.code === expected,
    `expected exit ${expected}, got ${result.code}\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`
  );
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}
