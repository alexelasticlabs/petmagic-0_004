#!/usr/bin/env node

import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';

const repoRoot = process.cwd();

if (process.argv.includes('--help') || process.argv.includes('-h')) {
  printHelp();
  process.exit(0);
}

const args = parseArgs(process.argv.slice(2));
const sseSummaryPath = resolveSseSummaryPath(args);
const sseEvidencePath = resolve(dirname(sseSummaryPath), 'evidence.json');

const missing = [];
for (const name of ['admin-url', 'api-health', 'operator']) {
  if (!args[name]) {
    missing.push(`--${name}`);
  }
}

if (!sseSummaryPath) {
  missing.push('--sse-summary or --sse-run-id');
}

if (missing.length > 0) {
  fail(`Missing required input(s): ${missing.join(', ')}`);
}

if (!existsSync(sseSummaryPath)) {
  fail(`SSE summary not found: ${sseSummaryPath}`);
}

if (!existsSync(sseEvidencePath)) {
  fail(`SSE evidence not found next to summary: ${sseEvidencePath}`);
}

const sseEvidence = readJson(sseEvidencePath);
if (!isAcceptedSseEvidence(sseEvidence)) {
  fail(`SSE evidence is not accepted for Admin QA draft: ${sseEvidencePath}`);
}

const outputPath = resolve(
  repoRoot,
  args.output || join('artifacts', `templates-feed-tz1-8-admin-qa-report-${formatTimestamp(new Date())}.md`)
);
const relativeOutputPath = relative(repoRoot, outputPath).replaceAll('\\', '/');
if (relativeOutputPath.startsWith('..')
  || !/^artifacts\/templates-feed-tz1-8-admin-qa-report(?!\.template).*\.md$/.test(relativeOutputPath)) {
  fail('Output must be under artifacts/templates-feed-tz1-8-admin-qa-report*.md and must not be the .template file.');
}

mkdirSync(dirname(outputPath), { recursive: true });
writeFileSync(outputPath, renderReport({
  adminUrl: args['admin-url'],
  apiHealth: args['api-health'],
  operator: args.operator,
  dateTimeUtc: args['date-time-utc'] || new Date().toISOString(),
  sseSummaryPath: relative(repoRoot, sseSummaryPath).replaceAll('\\', '/'),
  sseEvidence,
}));

console.log(`Wrote Admin QA draft: ${relativeOutputPath}`);
console.log('Complete every TODO row with PASS/FAIL/N/A plus concrete UI evidence before running the final release gate.');

function parseArgs(rawArgs) {
  const parsed = {};
  for (const arg of rawArgs) {
    const match = arg.match(/^--([^=]+)=(.*)$/);
    if (!match) {
      fail(`Unsupported argument format: ${arg}. Use --name=value.`);
    }
    parsed[match[1]] = match[2];
  }
  return parsed;
}

function resolveSseSummaryPath(parsedArgs) {
  if (parsedArgs['sse-summary']) {
    return resolve(repoRoot, parsedArgs['sse-summary']);
  }

  if (parsedArgs['sse-run-id']) {
    return resolve(repoRoot, 'artifacts', 'template-feed-staging-snapshots', parsedArgs['sse-run-id'], 'summary.md');
  }

  return '';
}

function readJson(path) {
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch (error) {
    fail(`Invalid JSON in ${path}: ${error.message || String(error)}`);
  }
}

function isAcceptedSseEvidence(evidence) {
  return hasSnapshotRunnerMetadata(evidence)
    && evidence?.mode && ['sse', 'all'].includes(evidence.mode)
    && hasCheck(evidence, 'sse.admin_action_window_configured', true)
    && hasCheck(evidence, 'sse_full_invalidation_metric_present', true)
    && hasCheck(evidence, 'sse_full_invalidation_delta_zero_during_admin_window', true)
    && hasRequiredActionLabels(evidence, ['text_update', 'media_update', 'category_rename'])
    && Number.isFinite(evidence.sseFullInvalidations?.before?.total)
    && Number.isFinite(evidence.sseFullInvalidations?.after?.total)
    && evidence.sseFullInvalidations?.deltaTotal === 0;
}

function hasSnapshotRunnerMetadata(evidence) {
  return typeof evidence?.runId === 'string'
    && evidence.runId.trim().length > 0
    && isIsoDateString(evidence.startedAtUtc)
    && isIsoDateString(evidence.finishedAtUtc)
    && typeof evidence.prometheusBaseUrl === 'string'
    && evidence.prometheusBaseUrl.trim().length > 0
    && evidence.prometheusBaseUrl !== 'invalid';
}

function hasCheck(evidence, name, expected) {
  return Array.isArray(evidence?.checks)
    && evidence.checks.some(check => check.name === name && check.ok === expected);
}

function hasRequiredActionLabels(evidence, requiredLabels) {
  const labels = new Set((evidence?.actionLabels || []).map(value => String(value).trim().toLowerCase()));
  return requiredLabels.every(label => labels.has(label));
}

function isIsoDateString(value) {
  if (typeof value !== 'string' || !value) {
    return false;
  }

  const timestamp = Date.parse(value);
  return Number.isFinite(timestamp) && value.includes('T');
}

function renderReport({ adminUrl, apiHealth, operator, dateTimeUtc, sseSummaryPath, sseEvidence }) {
  const beforeTotal = formatNumber(sseEvidence.sseFullInvalidations?.before?.total);
  const afterTotal = formatNumber(sseEvidence.sseFullInvalidations?.after?.total);
  const deltaTotal = formatNumber(sseEvidence.sseFullInvalidations?.deltaTotal);
  const actionLabels = (sseEvidence.actionLabels || []).join(', ');
  const categoryRenameEvidence = buildCategoryRenameEvidence(sseEvidence);

  return [
    '# Templates Feed TZ1-8 Admin QA Report',
    '',
    'Environment:',
    '',
    `- Admin URL: ${adminUrl}`,
    `- API build/health: ${apiHealth}`,
    `- Operator: ${operator}`,
    `- Date/time UTC: ${dateTimeUtc}`,
    `- Staging snapshot artifact: ${sseSummaryPath}`,
    '',
    '## Results',
    '',
    '| Scenario | Result | Evidence |',
    '| --- | --- | --- |',
    `| Category rename under feed load | TODO | ${categoryRenameEvidence} |`,
    '| Bulk status update | TODO | Use `N/A` only while Admin/API has no bulk template status operation. If present, link batching test. |',
    '| Activate without required media through UI | TODO | Screenshot/log showing UI/API validation error and unchanged template status. |',
    '| Archive category with public templates | TODO | Before/after admin action plus public feed/category response evidence. |',
    '',
    '## SSE Snapshot',
    '',
    `- Run ID: ${sseEvidence.runId}`,
    `- Action labels: ${actionLabels}`,
    `- sse_full_invalidation_count before total: ${beforeTotal}`,
    `- sse_full_invalidation_count after total: ${afterTotal}`,
    `- Delta total: ${deltaTotal}`,
    '',
    '## Notes',
    '',
    '- This is a draft, not release evidence, until every TODO row is replaced with PASS, FAIL, or allowed N/A plus concrete evidence.',
    '- The final release validator rejects TODO, FAIL, empty metadata, missing snapshot artifacts, and generic Evidence cells.',
    ''
  ].join('\n');
}

function buildCategoryRenameEvidence(sseEvidence) {
  const summaryPath = sseEvidence?.sseFullInvalidations?.feedLoadProbe?.summaryPath;
  if (sseEvidence?.sseFullInvalidations?.feedLoadProbe?.exitCode === 0
    && typeof summaryPath === 'string'
    && summaryPath.trim()
    && hasSiblingEvidence(summaryPath)) {
    return `${summaryPath.replaceAll('\\', '/')} plus category id, before/after screenshot or API response, realtime event evidence.`;
  }

  return 'Feed load probe summary, category id, before/after screenshot or API response, realtime event evidence.';
}

function hasSiblingEvidence(summaryPath) {
  const resolved = resolve(repoRoot, summaryPath);
  const relativeSummary = relative(repoRoot, resolved).replaceAll('\\', '/');
  if (relativeSummary.startsWith('..')
    || !relativeSummary.startsWith('artifacts/template-feed-load-probes/')
    || !existsSync(resolved)) {
    return false;
  }

  return existsSync(resolve(resolved, '..', 'evidence.json'));
}

function formatNumber(value) {
  return Number.isFinite(value) ? String(value) : 'n/a';
}

function formatTimestamp(date) {
  return date.toISOString().replaceAll(':', '').replace(/\.\d{3}Z$/, 'Z');
}

function fail(message) {
  console.error(message);
  process.exit(1);
}

function printHelp() {
  console.log(`
Create a draft Admin QA report for Templates Feed TZ1-8.

Required:
  --sse-summary=artifacts/template-feed-staging-snapshots/<run>/summary.md
    or --sse-run-id=<run>
  --admin-url=<staging admin URL>
  --api-health=<health/build evidence summary>
  --operator=<operator name or initials>

Optional:
  --date-time-utc=<ISO UTC timestamp>
  --output=artifacts/templates-feed-tz1-8-admin-qa-report-<date>.md

The script requires an accepted SSE evidence.json next to the summary. It
creates a TODO-filled report draft; it never marks manual QA scenarios as PASS.
`);
}
