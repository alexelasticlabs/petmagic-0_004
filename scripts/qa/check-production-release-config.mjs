#!/usr/bin/env node

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const rawArgs = process.argv.slice(2);
const blueprint = option('--blueprint') ?? 'render.production.yaml';
const source = readFileSync(resolve(blueprint), 'utf8');
const failures = [];

for (const [label, pattern] of [
  ['staging URL', /https?:\/\/[^\s]+staging\.petmagic\.app/i],
  ['Stripe test key', /(?:sk|pk)_test_/i],
  ['sandbox store mode', /^\s*value:\s*["']?sandbox["']?\s*$/im],
  ['placeholder secret', /CHANGE_ME|DEV_ONLY|replace-with-|petmagic-placeholder/i],
]) {
  if (pattern.test(source)) failures.push(label);
}

for (const required of [
  'api.petgpt.app',
  'admin.petgpt.app',
  'STRIPE_LIVE_SECRET_KEY',
  'FAL_ACCOUNT_BILLING_ADMIN_KEY',
  'FAL_EXPECTED_ACCOUNT_USERNAME',
  'GOOGLE_PLAY_PACKAGE_NAME',
  'APP_STORE_BUNDLE_ID',
  'GOOGLE_PLAY_PREMIUM_MONTHLY_PRODUCT_ID',
  'GOOGLE_PLAY_PREMIUM_YEARLY_PRODUCT_ID',
  'APP_STORE_PREMIUM_MONTHLY_PRODUCT_ID',
  'APP_STORE_PREMIUM_YEARLY_PRODUCT_ID',
  'ExternalAuth__MobileRedirectScheme',
  'mountPath: /var/petmagic',
  'Identity__AvatarStorage__LocalMediaRootPath',
  '/var/petmagic/wwwroot/user-avatars',
  'SupportChat__AttachmentStorage__LocalMediaRootPath',
  '/var/petmagic/wwwroot/support-attachments',
  '/payments/success?session_id={CHECKOUT_SESSION_ID}',
  '/payments/cancel',
  '/payments/return',
  'PETMAGIC_APP_DEEP_LINK_SCHEME',
]) {
  if (!source.includes(required)) failures.push(`missing ${required}`);
}

if (failures.length) {
  console.error(`Production release configuration is invalid: ${failures.join(', ')}`);
  process.exit(1);
}
console.log(`Production release configuration passed for ${blueprint}.`);

function option(name) {
  const index = rawArgs.indexOf(name);
  return index >= 0 ? rawArgs[index + 1] : undefined;
}
