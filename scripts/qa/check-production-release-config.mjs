#!/usr/bin/env node

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const rawArgs = process.argv.slice(2);
const environmentFile = option('--env-file') ?? 'deploy/vps/.env.vps.example';
const source = readFileSync(resolve(environmentFile), 'utf8');
const failures = [];
const entries = new Map();

for (const [index, line] of source.split(/\r?\n/).entries()) {
  const match = line.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
  if (!match) continue;

  const [, key, value] = match;
  if (entries.has(key)) {
    failures.push(`duplicate ${key} (lines ${entries.get(key).line} and ${index + 1})`);
  }
  entries.set(key, { line: index + 1, value });
}

for (const required of [
  'ASPNETCORE_ENVIRONMENT',
  'DOTNET_ENVIRONMENT',
  'SOURCE_REVISION',
  'DOCKER_BIND_ADDRESS',
  'BACKEND_PUBLIC_BASE_URL',
  'CORS_ALLOWED_ORIGIN',
  'FAL_AI_API_KEY',
  'R2_ACCOUNT_ID',
  'R2_ACCESS_KEY',
  'R2_SECRET_KEY',
  'PETMAGIC_BACKUP_R2_BUCKET',
  'STRIPE_LIVE_SECRET_KEY',
  'GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL',
  'APP_STORE_SHARED_SECRET',
  'FIREBASE_SERVICE_ACCOUNT_JSON',
  'APPLE_CLIENT_ID',
  'EMAIL_HOST',
]) {
  if (!entries.has(required)) failures.push(`missing ${required}`);
}

for (const [key, expected] of [
  ['ASPNETCORE_ENVIRONMENT', 'Production'],
  ['DOTNET_ENVIRONMENT', 'Production'],
  ['DOCKER_BIND_ADDRESS', '127.0.0.1'],
  ['BACKEND_PUBLIC_BASE_URL', 'https://api.petgpt.app'],
  ['CORS_ALLOWED_ORIGIN', 'https://admin.petgpt.app'],
]) {
  if (entries.get(key)?.value !== expected) {
    failures.push(`unsafe ${key}; expected ${expected}`);
  }
}

for (const [label, pattern] of [
  ['staging URL', /https?:\/\/[^\s]+staging\.petmagic\.app/i],
  ['Stripe test key', /(?:sk|pk)_test_/i],
  ['hard-coded live secret', /(?:sk_live|rk_live|whsec_)\w{8,}/i],
]) {
  if (pattern.test(source)) failures.push(label);
}

if (failures.length) {
  console.error(`Production VPS configuration template is invalid: ${failures.join(', ')}`);
  process.exit(1);
}

console.log(`Production VPS configuration template passed for ${environmentFile}.`);

function option(name) {
  const index = rawArgs.indexOf(name);
  return index >= 0 ? rawArgs[index + 1] : undefined;
}
