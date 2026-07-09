#!/usr/bin/env node

import { execFileSync } from 'node:child_process';
import { existsSync, rmSync, statSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, '..', '..');
const rawArgs = process.argv.slice(2);
const args = new Set(rawArgs);

if (args.has('--help') || args.has('-h')) {
  printUsage();
  process.exit(0);
}

const apply = args.has('--apply');
const includeNodeModules = args.has('--include-node-modules');

const staticTargets = [
  '.vs',
  '.idea',
  'apps/.idea',
  'apps/petmagic-mobile/.idea',
  'apps/petmagic-mobile/.dart_tool',
  'apps/petmagic-mobile/android/.gradle',
  'apps/petmagic-mobile/android/build',
  'apps/petmagic-mobile/android/app/src/main/java',
  'apps/petmagic-mobile/android/app/src/debug/google-services.json',
  'apps/petmagic-mobile/android/app/src/profile/google-services.json',
  'apps/petmagic-mobile/android/local.properties',
  'apps/petmagic-mobile/android/petmagic_mobile_android.iml',
  'apps/petmagic-mobile/build',
  'apps/petmagic-mobile/ios/Flutter/Generated.xcconfig',
  'apps/petmagic-mobile/ios/Flutter/ephemeral',
  'apps/petmagic-mobile/ios/Flutter/flutter_export_environment.sh',
  'apps/petmagic-mobile/ios/Runner/GeneratedPluginRegistrant.h',
  'apps/petmagic-mobile/ios/Runner/GeneratedPluginRegistrant.m',
  'apps/petmagic-mobile/petmagic_mobile.iml',
  'artifacts',
  'backend/artifacts',
  'src/backend/artifacts',
  'src/Modules/backend/artifacts',
  'tests/PetMagic.Modules.Identity.Tests/bin',
  'tests/PetMagic.Modules.Identity.Tests/obj',
  'tests/PetMagic.Modules.Identity.Tests/artifacts'
];

const neverRemove = new Set([
  '.env',
  '.env.local-smoke',
  '.env.staging.local',
  '.projects/vault',
  '.git'
]);

const targets = new Set(staticTargets);
for (const projectDir of collectProjectDirectories()) {
  targets.add(`${projectDir}/bin`);
  targets.add(`${projectDir}/obj`);
  targets.add(`${projectDir}/artifacts`);
}

if (includeNodeModules) {
  targets.add('apps/admin-web/node_modules');
}

const existingTargets = [...targets]
  .map((path) => normalizePath(path))
  .filter((path) => existsSync(join(repoRoot, path)))
  .sort();

if (existingTargets.length === 0) {
  console.log('No local generated artifacts found.');
  process.exit(0);
}

for (const target of existingTargets) {
  assertSafeTarget(target);
}

for (const target of existingTargets) {
  const absolutePath = join(repoRoot, target);
  if (!existsSync(absolutePath)) {
    continue;
  }

  const kind = statSync(absolutePath).isDirectory() ? 'dir' : 'file';
  if (apply) {
    rmSync(absolutePath, { force: true, recursive: true });
    console.log(`[removed] ${kind} ${target}`);
  } else {
    console.log(`[dry-run] ${kind} ${target}`);
  }
}

if (!apply) {
  console.log('Dry run only. Pass --apply to remove these paths.');
}

function collectProjectDirectories() {
  const projectFiles = gitLsFiles()
    .filter((path) => path.endsWith('.csproj'));
  return [...new Set(projectFiles.map((path) => path.slice(0, path.lastIndexOf('/'))))];
}

function gitLsFiles(extraArgs = []) {
  const output = execFileSync('git', ['ls-files', ...extraArgs], {
    cwd: repoRoot,
    encoding: 'utf8'
  });
  return output
    .split(/\r?\n/)
    .map((path) => path.trim().replaceAll('\\', '/'))
    .filter(Boolean);
}

function assertSafeTarget(target) {
  const normalized = normalizePath(target);
  if (neverRemove.has(normalized)) {
    throw new Error(`Refusing to remove protected path: ${normalized}`);
  }

  const absolutePath = resolve(repoRoot, normalized);
  if (absolutePath !== repoRoot && !absolutePath.startsWith(`${repoRoot}\\`) && !absolutePath.startsWith(`${repoRoot}/`)) {
    throw new Error(`Refusing to remove path outside repository: ${normalized}`);
  }

  const trackedFiles = gitLsFiles(['--', normalized]);
  if (trackedFiles.length > 0) {
    throw new Error(`Refusing to remove ${normalized}; tracked files exist under it.`);
  }
}

function normalizePath(path) {
  return relative(repoRoot, resolve(repoRoot, path)).replaceAll('\\', '/');
}

function printUsage() {
  console.log(`
Clean local generated artifacts.

Usage:
  node scripts/qa/clean-local-generated-artifacts.mjs
  node scripts/qa/clean-local-generated-artifacts.mjs --apply

Options:
  --apply                 Remove detected generated/cache paths. Default is dry-run.
  --include-node-modules  Also remove apps/admin-web/node_modules.
  --help, -h              Print this help.

The script refuses to remove targets outside the repository, protected local
secret paths, or directories containing tracked files. It intentionally does not
remove .env files, .projects/vault, or node_modules unless explicitly requested.
`.trim());
}
