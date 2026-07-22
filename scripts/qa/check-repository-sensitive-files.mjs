#!/usr/bin/env node

import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, statSync } from 'node:fs';

const allowedEnvExamples = new Set([
  '.env.example',
  '.env.local-smoke.example',
  '.env.staging.local.example'
]);

const allowedFirebasePlaceholders = new Map([
  [
    'apps/petmagic-mobile/android/app/google-services.json',
    [
      'petmagic-placeholder',
      'replace-with-android-oauth-client-id.apps.googleusercontent.com',
      'replace-with-web-oauth-client-id.apps.googleusercontent.com',
      'A00000000000000000000000000000000000000'
    ]
  ],
  [
    'apps/petmagic-mobile/ios/Runner/GoogleService-Info.plist',
    [
      'petmagic-placeholder',
      'replace-with-ios-oauth-client-id.apps.googleusercontent.com',
      'replace-with-android-oauth-client-id.apps.googleusercontent.com',
      'A00000000000000000000000000000000000000'
    ]
  ]
]);

const requiredIgnoredFirebasePaths = [
  'apps/petmagic-mobile/android/app/google-services.json',
  'apps/petmagic-mobile/android/app/src/debug/google-services.json',
  'apps/petmagic-mobile/android/app/src/profile/google-services.json',
  'apps/petmagic-mobile/android/app/src/staging/google-services.json',
  'apps/petmagic-mobile/android/app/src/production/google-services.json',
  'apps/petmagic-mobile/ios/Runner/GoogleService-Info.plist',
  'apps/petmagic-mobile/ios/Flutter/FirebaseConfig.xcconfig'
];

const allowedSecretFixtures = new Map([
  [
    'tests/PetMagic.Modules.Identity.Tests/Economy/EconomyInfrastructureConfigurationTests.cs',
    ['-----BEGIN PRIVATE ' + 'KEY-----']
  ]
]);

const forbiddenPathPatterns = [
  /(^|\/)\.agents(\/|$)/,
  /(^|\/)skills-lock\.json$/,
  /(^|\/)key\.properties$/,
  /\.(?:jks|keystore|p12|pfx|pem|key)$/i,
  /(^|\/)service-account(?:\.|-)?.*\.json$/i,
  /(^|\/)[^/]*(?:firebase|google|gcp)[^/]*service[^/]*\.json$/i,
  /(^|\/)(?:bin|obj|node_modules|artifacts|coverage|dist|build|\.next|\.dart_tool|\.gradle)(\/|$)/
];

const highConfidenceSecretPatterns = [
  { name: 'private key block', pattern: new RegExp('-----BEGIN [A-Z ]*PRIVATE ' + 'KEY-----') },
  { name: 'Stripe live secret key', pattern: /\b(?:sk|rk)_live_[A-Za-z0-9]{16,}\b/ },
  { name: 'Stripe webhook secret', pattern: /\bwhsec_[A-Za-z0-9]{16,}\b/ },
  { name: 'GitHub token', pattern: /\bgithub_pat_[A-Za-z0-9_]{20,}\b|\bgh[pousr]_[A-Za-z0-9_]{20,}\b/ },
  { name: 'GitLab token', pattern: /\bglpat-[A-Za-z0-9_-]{20,}\b/ },
  { name: 'Slack token', pattern: /\bxox[baprs]-[A-Za-z0-9-]{20,}\b/ },
  { name: 'npm token', pattern: /\bnpm_[A-Za-z0-9]{20,}\b/ },
  { name: 'Firebase API key shape', pattern: /\bAIza[0-9A-Za-z_-]{20,}\b/ }
];

const failures = [];

validateFirebaseIgnoreRules();

for (const path of collectGitCandidateFiles()) {
  validatePath(path);
  validateContent(path);
}

if (failures.length > 0) {
  console.error('Repository sensitive-file check failed:');
  for (const failure of failures) {
    console.error(`- ${failure}`);
  }
  process.exit(1);
}

console.log('Repository sensitive-file check ok.');

function validateFirebaseIgnoreRules() {
  for (const path of requiredIgnoredFirebasePaths) {
    try {
      execFileSync('git', ['check-ignore', '--quiet', '--', path], { stdio: 'ignore' });
    } catch {
      failures.push(`${path}: generated Firebase configuration path must be gitignored.`);
    }
  }
}

function collectGitCandidateFiles() {
  const output = execFileSync('git', ['ls-files', '-co', '--exclude-standard'], {
    encoding: 'utf8'
  });

  return output
    .split(/\r?\n/)
    .map((path) => path.trim().replaceAll('\\', '/'))
    .filter(Boolean)
    .filter((path) => existsSync(path) && statSync(path).isFile())
    .sort();
}

function validatePath(path) {
  if (isAllowedEnvExample(path) || allowedFirebasePlaceholders.has(path)) {
    return;
  }

  const lower = path.toLowerCase();
  if (lower.endsWith('/.npmrc') || lower === '.npmrc') {
    failures.push(`${path}: .npmrc files must stay local; configure token-free npm behavior in scripts or Dockerfiles.`);
    return;
  }

  if (/(^|\/)\.env(?:\.|$)/.test(path)) {
    failures.push(`${path}: local env files must stay ignored; commit only .env*.example templates.`);
  }

  for (const pattern of forbiddenPathPatterns) {
    if (pattern.test(path)) {
      failures.push(`${path}: blocked by repository-sensitive path policy ${pattern}.`);
      return;
    }
  }

  const fileName = path.slice(path.lastIndexOf('/') + 1);
  if (fileName === 'google-services.json' || fileName === 'GoogleService-Info.plist') {
    failures.push(`${path}: Firebase config files must be reviewed and allowlisted before committing.`);
  }
}

function validateContent(path) {
  const content = readUtf8(path);
  if (content === null) {
    return;
  }

  if (allowedFirebasePlaceholders.has(path)) {
    for (const marker of allowedFirebasePlaceholders.get(path)) {
      if (!content.includes(marker)) {
        failures.push(`${path}: placeholder Firebase config is missing marker ${marker}.`);
      }
    }
    if (/private_key|client_email|auth_provider_x509_cert_url/i.test(content)) {
      failures.push(`${path}: Firebase client config must not contain service-account fields.`);
    }
  }

  for (const { name, pattern } of highConfidenceSecretPatterns) {
    const match = content.match(pattern);
    if (match && !isAllowedPlaceholderSecret(path, match[0])) {
      failures.push(`${path}: contains ${name}.`);
    }
  }
}

function readUtf8(path) {
  try {
    return readFileSync(path, 'utf8');
  } catch {
    return null;
  }
}

function isAllowedEnvExample(path) {
  if (allowedEnvExamples.has(path)) {
    return true;
  }

  return /\.env\..*\.example$/.test(path) || /\.env\.example$/.test(path);
}

function isAllowedPlaceholderSecret(path, value) {
  if ((allowedSecretFixtures.get(path) ?? []).includes(value)) {
    return true;
  }

  if (allowedFirebasePlaceholders.has(path) && value === 'A00000000000000000000000000000000000000') {
    return true;
  }

  return /example|placeholder|replace-with|000000|<secret/i.test(value);
}
