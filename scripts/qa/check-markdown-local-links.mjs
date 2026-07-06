#!/usr/bin/env node

import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const rawArgs = process.argv.slice(2);
const args = new Set(rawArgs);
const repoRoot = resolve(getOptionValue('--root') ?? resolve(scriptDir, '..', '..'));

if (args.has('--help') || args.has('-h')) {
  printUsage();
  process.exit(0);
}

const includeVendored = args.has('--include-vendored');
const markdownFiles = listMarkdownFiles()
  .filter(file => includeVendored || !isVendoredMarkdown(file))
  .filter(file => existsSync(resolve(repoRoot, file)));

const brokenLinks = [];
for (const file of markdownFiles) {
  brokenLinks.push(...findBrokenLinks(file));
}

if (brokenLinks.length > 0) {
  console.error('Broken local Markdown links found:');
  for (const broken of brokenLinks.sort()) {
    console.error(`- ${broken.file} -> ${broken.target}`);
  }
  process.exit(1);
}

console.log(`Markdown local links ok (${markdownFiles.length} files checked).`);

function listMarkdownFiles() {
  const result = spawnSync(
    'git',
    ['-c', 'core.quotePath=false', 'ls-files', '--cached', '--others', '--exclude-standard', '*.md'],
    {
      cwd: repoRoot,
      encoding: 'utf8',
    },
  );

  if (result.status !== 0) {
    throw new Error(`git ls-files failed:\n${result.stdout}\n${result.stderr}`);
  }

  return result.stdout
    .split(/\r?\n/)
    .map(line => line.trim())
    .filter(Boolean);
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

function isVendoredMarkdown(file) {
  return file.startsWith('apps/petmagic-mobile/third_party/');
}

function findBrokenLinks(file) {
  const source = readFileSync(resolve(repoRoot, file), 'utf8');
  const directory = dirname(file);
  const broken = [];
  const linkPattern = /!?\[[^\]]*]\(([^)]+)\)/g;

  for (const match of source.matchAll(linkPattern)) {
    const target = normalizeTarget(match[1]);
    if (!target || shouldSkipTarget(target)) {
      continue;
    }

    const targetPath = resolve(repoRoot, directory, target);
    if (!existsSync(targetPath)) {
      broken.push({ file, target });
    }
  }

  return broken;
}

function normalizeTarget(rawTarget) {
  let target = rawTarget.trim();
  if (target.startsWith('<') && target.endsWith('>')) {
    target = target.slice(1, -1);
  } else {
    const titleMatch = target.match(/^(\S+)\s+["'][^"']*["']$/);
    if (titleMatch) {
      target = titleMatch[1];
    }
  }

  target = target.split('#')[0].split('?')[0].trim();
  if (!target) {
    return '';
  }

  try {
    return decodeURIComponent(target);
  } catch {
    return target;
  }
}

function shouldSkipTarget(target) {
  return target.startsWith('#')
    || target.startsWith('mailto:')
    || /^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(target);
}

function printUsage() {
  console.log(`
Markdown local-link checker.

Usage:
  node scripts/qa/check-markdown-local-links.mjs

Options:
  --include-vendored  Include vendored third-party Markdown files.
  --root <path>       Repository root to scan. Defaults to this repository.
  --help, -h          Print this help.

The checker validates local links in tracked and untracked non-ignored Markdown files.
Vendored Flutter plugin docs are skipped by default because they may reference upstream-only assets.
Missing Markdown files are ignored so intentional working-tree deletions can be reviewed separately by git status.
`.trim());
}
