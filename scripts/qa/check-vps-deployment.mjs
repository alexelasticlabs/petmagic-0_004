#!/usr/bin/env node

import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(fileURLToPath(new URL('../..', import.meta.url)));
const failures = [];
const requiredFiles = [
  'deploy/vps/README.md',
  'deploy/vps/.env.vps.example',
  'deploy/vps/.env.vps.staging.example',
  'deploy/vps/Caddyfile',
  'deploy/vps/compose.vps.yaml',
  'deploy/vps/compose.staging.vps.yaml',
  'deploy/vps/scripts/deploy-release.sh',
  'deploy/vps/scripts/preflight.sh',
  'docs/release-readiness.md',
];

for (const relativePath of requiredFiles) {
  if (!existsSync(resolve(root, relativePath))) failures.push(`missing ${relativePath}`);
}

for (const obsoletePath of [
  'render.yaml',
  'render.production.yaml',
  'docs/render-staging-deployment.md',
  'docs/render-staging-secrets-checklist.md',
]) {
  if (existsSync(resolve(root, obsoletePath))) failures.push(`obsolete deployment source still exists: ${obsoletePath}`);
}

const caddyfile = read('deploy/vps/Caddyfile');
for (const hostname of ['api.petgpt.app', 'admin.petgpt.app', 'api.staging.petgpt.app']) {
  if (!caddyfile.includes(hostname)) failures.push(`Caddyfile does not route ${hostname}`);
}

const runbook = read('deploy/vps/README.md');
for (const expected of ['vps-fea3ac06', 'Ubuntu 26.04', '/opt/petmagic/current', 'Resend']) {
  if (!runbook.includes(expected)) failures.push(`VPS runbook does not document ${expected}`);
}

const preflight = read('deploy/vps/scripts/preflight.sh');
if (!preflight.includes("'TEMPLATES_WATERMARK_ENABLED=true'")) {
  failures.push('production preflight does not require watermark rendering');
}

const compose = read('docker-compose.yml');
if (compose.includes('TEMPLATES_WATERMARK_ENABLED:-false')) {
  failures.push('Docker Compose still disables watermark rendering by default');
}

if (/\bMailtrap\b/i.test(runbook)) failures.push('VPS runbook still describes Mailtrap');

if (failures.length) {
  console.error(`VPS deployment validation failed:\n- ${failures.join('\n- ')}`);
  process.exit(1);
}

console.log('VPS deployment validation passed.');

function read(relativePath) {
  return readFileSync(resolve(root, relativePath), 'utf8');
}
