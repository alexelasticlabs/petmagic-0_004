#!/usr/bin/env node

import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn, spawnSync } from 'node:child_process';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const checkerPath = join(scriptDir, 'check-markdown-local-links.mjs');

try {
  await assertCleanLinksPass();
  await assertBrokenLinksFail();
  await assertVendoredDocsAreSkippedByDefault();
  console.log('markdown local-link checker self-test passed');
} catch (error) {
  console.error(error.stack || String(error));
  process.exitCode = 1;
}

async function assertCleanLinksPass() {
  const root = createFixture('ok');
  try {
    writeFile('README.md', '[Guide](docs/guide.md)\n[Section](docs/guide.md#intro)\n[External](https://example.com)\n');
    writeFile('docs/guide.md', '# Guide\n');

    const result = await runChecker(root);
    assertExitCode(result, 0);
    assert(result.stdout.includes('Markdown local links ok'), 'clean run did not report success');
  } finally {
    rmSync(root, { recursive: true, force: true });
  }

  function writeFile(path, content) {
    writeFixtureFile(root, path, content);
  }
}

async function assertBrokenLinksFail() {
  const root = createFixture('broken');
  try {
    writeFixtureFile(root, 'README.md', '[Missing](docs/missing.md)\n');

    const result = await runChecker(root);
    assert(result.code !== 0, `broken link should fail\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`);
    assert(result.stderr.includes('README.md -> docs/missing.md'), 'missing link was not reported');
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

async function assertVendoredDocsAreSkippedByDefault() {
  const root = createFixture('vendored');
  try {
    writeFixtureFile(root, 'README.md', '[Guide](docs/guide.md)\n');
    writeFixtureFile(root, 'docs/guide.md', '# Guide\n');
    writeFixtureFile(
      root,
      'apps/petmagic-mobile/third_party/plugin/README.md',
      '[Upstream asset](missing-upstream-asset.png)\n',
    );

    const defaultResult = await runChecker(root);
    assertExitCode(defaultResult, 0);

    const vendoredResult = await runChecker(root, ['--include-vendored']);
    assert(
      vendoredResult.code !== 0,
      `include-vendored should fail on fixture upstream asset\nstdout:\n${vendoredResult.stdout}\nstderr:\n${vendoredResult.stderr}`,
    );
    assert(
      vendoredResult.stderr.includes('apps/petmagic-mobile/third_party/plugin/README.md -> missing-upstream-asset.png'),
      'vendored broken link was not reported when included',
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

function createFixture(label) {
  const root = mkdtempSync(join(tmpdir(), `markdown-link-check-${label}-`));
  const result = spawnSync('git', ['init', '-q'], {
    cwd: root,
    encoding: 'utf8',
  });

  if (result.status !== 0) {
    throw new Error(`git init failed:\n${result.stdout}\n${result.stderr}`);
  }

  return root;
}

function writeFixtureFile(root, path, content) {
  const absolutePath = join(root, path);
  mkdirSync(dirname(absolutePath), { recursive: true });
  writeFileSync(absolutePath, content);
}

function runChecker(root, extraArgs = []) {
  return spawnNode([checkerPath, '--root', root, ...extraArgs]);
}

function spawnNode(args) {
  return new Promise((resolvePromise) => {
    const child = spawn(process.execPath, args, {
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
    `expected exit ${expected}, got ${result.code}\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`,
  );
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}
