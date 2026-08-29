#!/usr/bin/env node

import assert from 'node:assert/strict';
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const scriptsRoot = join(repoRoot, 'scripts');
const scriptExtensions = new Set(['.cmd', '.js', '.mjs', '.ps1', '.py', '.sh', '.sql']);
const scripts = collectScripts(scriptsRoot);

for (const required of [
  'scripts/ci/bootstrap-macos-runner.sh',
  'scripts/ci/repair-macos-runner-toolcache.sh',
  'scripts/qa/check-production-release-config.mjs',
  'scripts/qa/check-vps-deployment.mjs',
  'scripts/qa/check-repository-sensitive-files.mjs',
  'scripts/qa/check-repository-structure.mjs',
  'scripts/qa/test-markdown-local-links.mjs',
  'scripts/qa/test-script-safety-inventory.mjs',
]) {
  assert.ok(existsSync(join(repoRoot, required)), `missing required operator script: ${required}`);
}

for (const script of scripts) {
  const relativePath = relative(repoRoot, script).replaceAll('\\', '/');
  assert.ok(!/render/i.test(relativePath), `obsolete managed-host script is still tracked: ${relativePath}`);

  const source = readFileSync(script, 'utf8');
  assert.ok(!/sk_(?:live|test)_[A-Za-z0-9]+/.test(source), `possible Stripe secret in ${relativePath}`);
  assert.ok(!/whsec_[A-Za-z0-9]+/.test(source), `possible webhook secret in ${relativePath}`);
}

console.log(`Script safety inventory passed for ${scripts.length} tracked scripts.`);

function collectScripts(directory) {
  const files = [];
  for (const entry of readdirSync(directory)) {
    const path = join(directory, entry);
    const stat = statSync(path);
    if (stat.isDirectory()) {
      files.push(...collectScripts(path));
      continue;
    }

    const extension = entry.slice(entry.lastIndexOf('.'));
    if (scriptExtensions.has(extension)) files.push(path);
  }
  return files;
}
