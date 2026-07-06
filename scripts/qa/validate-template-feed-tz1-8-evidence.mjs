#!/usr/bin/env node

import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { relative, resolve, join } from 'node:path';

const repoRoot = process.cwd();
const artifactsRoot = join(repoRoot, 'artifacts');
const checks = [];

checkCuratedFollowupEvidence();
checkLongScrollArtifact();
checkStagingLatencyArtifact();
checkStagingSseArtifact();
checkAdminQaReport();

for (const check of checks) {
  console.log(`[${check.ok ? 'PASS' : 'FAIL'}] ${check.name}: ${check.detail}`);
}

const failed = checks.filter(check => !check.ok);
if (failed.length > 0) {
  console.error(`Template feed TZ1-8 evidence gate failed: ${failed.length} missing or invalid item(s).`);
  process.exitCode = 1;
} else {
  console.log('Template feed TZ1-8 evidence gate passed.');
}

function checkCuratedFollowupEvidence() {
  const path = join(artifactsRoot, 'templates-feed-tz1-8-followup-evidence-2026-07-02.md');
  if (!existsSync(path)) {
    addCheck('followup.curated_evidence_exists', false, path);
    return;
  }

  const text = readFileSync(path, 'utf8');
  addCheck(
    'followup.curated_evidence_exists',
    true,
    'found artifacts/templates-feed-tz1-8-followup-evidence-2026-07-02.md');
  addCheck(
    'followup.external_gate_tasks_are_tracked',
    text.includes('Task 4. Feed latency baseline')
      && text.includes('Task 6. `sse_full_invalidation_count` snapshot')
      && text.includes('Task 8. Admin manual QA guard rails'),
    'follow-up evidence must track Task 4, Task 6, and Task 8 status rows');
}

function checkLongScrollArtifact() {
  const path = join(artifactsRoot, 'templates-feed-tz1-8-long-scroll-500-2026-07-02.md');
  if (!existsSync(path)) {
    addCheck('mobile.long_scroll_artifact_exists', false, path);
    return;
  }

  const text = readFileSync(path, 'utf8');
  addCheck('mobile.long_scroll_artifact_exists', true, 'found curated 500+ long-scroll artifact');
  addCheck(
    'mobile.long_scroll_plateau_recorded',
    text.includes('plateau_likely=true') && text.includes('mixed `520`') && text.includes('video-only `520`'),
    'requires plateau_likely=true plus 500+ mixed/video-only loaded items');
  addCheck(
    'mobile.weak_device_or_low_memory_signoff',
    hasAcceptedMobileReleaseSignoff(text),
    'requires weak-device or low-memory emulator signoff with concrete device evidence for Task 2 acceptance');
  addCheck(
    'mobile.video_only_budget_exceeds_mixed',
    parseActivePreviewMetric(text, 'mixed') < parseActivePreviewMetric(text, 'video-only'),
    'requires active video preview average video-only > mixed');
}

function checkStagingLatencyArtifact() {
  const evidenceFiles = findStagingEvidenceFiles();
  const accepted = evidenceFiles.find(file => {
    const evidence = readJson(file);
    return isAcceptedLatencyEvidence(evidence)
      && matchesRequiredRunId(evidence, 'TEMPLATE_FEED_REQUIRED_LATENCY_RUN_ID');
  });

  addCheck(
    'staging.feed_latency_before_after_artifact',
    Boolean(accepted),
    accepted
      ? relativeArtifactPath(accepted)
      : missingScopedArtifactDetail(
        'latency',
        'TEMPLATE_FEED_REQUIRED_LATENCY_RUN_ID',
        'missing artifacts/template-feed-staging-snapshots/*/evidence.json with passing before/after p95/p99 and no-regression checks'));
}

function checkStagingSseArtifact() {
  const evidenceFiles = findStagingEvidenceFiles();
  const accepted = evidenceFiles.find(file => {
    const evidence = readJson(file);
    return isAcceptedSseEvidence(evidence)
      && matchesRequiredRunId(evidence, 'TEMPLATE_FEED_REQUIRED_SSE_RUN_ID');
  });

  addCheck(
    'staging.sse_full_invalidation_admin_window_artifact',
    Boolean(accepted),
    accepted
      ? relativeArtifactPath(accepted)
      : missingScopedArtifactDetail(
        'SSE',
        'TEMPLATE_FEED_REQUIRED_SSE_RUN_ID',
        'missing artifacts/template-feed-staging-snapshots/*/evidence.json with passing admin-window zero-delta SSE checks and required admin action labels'));
}

function checkAdminQaReport() {
  const scopedReportPath = process.env.TEMPLATE_FEED_ADMIN_QA_REPORT_PATH || '';
  const reports = scopedReportPath
    ? [resolve(repoRoot, scopedReportPath)]
    : findFiles(artifactsRoot, /^templates-feed-tz1-8-admin-qa-report(?!\.template).*\.md$/);
  const reportResults = reports.map(file => ({
    file,
    reason: getAdminQaReportRejectionReason(file),
  }));
  const accepted = reportResults.find(result => !result.reason)?.file;

  addCheck(
    'admin.manual_qa_report_complete',
    Boolean(accepted),
    accepted
      ? relativeArtifactPath(accepted)
      : formatAdminQaReportFailure(scopedReportPath, reportResults));
}

function getAdminQaReportRejectionReason(file) {
  if (!isAllowedAdminQaReportPath(file)) {
    return 'report path is outside artifacts/templates-feed-tz1-8-admin-qa-report*.md';
  }

  if (!existsSync(file)) {
    return 'report file does not exist';
  }

  const text = readFileSync(file, 'utf8');
  if (/\bTODO\b/i.test(text)) {
    return 'report still contains TODO';
  }

  if (/\bFAIL\b/i.test(text)) {
    return 'report contains FAIL';
  }

  const missingMetadata = [
    'Admin URL',
    'API build/health',
    'Operator',
    'Date/time UTC',
    'Staging snapshot artifact',
  ].filter(label => !hasFilledMetadata(text, label));
  if (missingMetadata.length > 0) {
    return `missing metadata: ${missingMetadata.join(', ')}`;
  }

  const acceptedSseEvidence = getAcceptedSseSnapshotMetadataEvidence(text, 'Staging snapshot artifact');
  if (!acceptedSseEvidence) {
    return 'staging snapshot artifact path is missing, stale, not accepted SSE evidence, or does not match TEMPLATE_FEED_REQUIRED_SSE_RUN_ID';
  }

  if (!hasCategoryRenameLoadProbeEvidence(text, acceptedSseEvidence)) {
    return 'category rename row is missing PASS evidence, missing an accepted feed-load probe summary, or references a probe that does not match the integrated SSE snapshot';
  }

  if (!hasScenarioResultWithEvidence(text, 'Bulk status update', 'PASS', 'N/A')) {
    return 'bulk status update row is missing PASS/N/A with concrete evidence';
  }

  if (!hasScenarioResultWithEvidence(text, 'Activate without required media through UI', 'PASS')) {
    return 'activate without required media row is missing PASS with concrete evidence';
  }

  if (!hasScenarioResultWithEvidence(text, 'Archive category with public templates', 'PASS')) {
    return 'archive category row is missing PASS with concrete evidence';
  }

  return '';
}

function formatAdminQaReportFailure(scopedReportPath, reportResults) {
  if (scopedReportPath) {
    const scopedResult = reportResults[0];
    return `configured TEMPLATE_FEED_ADMIN_QA_REPORT_PATH is not accepted: ${scopedReportPath}; reason: ${scopedResult?.reason || 'unknown'}`;
  }

  if (reportResults.length === 0) {
    return 'missing completed artifacts/templates-feed-tz1-8-admin-qa-report*.md with filled metadata, accepted SSE snapshot artifact path, accepted feed-load probe evidence, and required PASS/N/A scenario evidence';
  }

  const firstRejected = reportResults[0];
  return `checked ${reportResults.length} report(s); first rejected ${relativeArtifactPath(firstRejected.file)}: ${firstRejected.reason}`;
}

function findStagingEvidenceFiles() {
  return findFiles(join(artifactsRoot, 'template-feed-staging-snapshots'), /^evidence\.json$/);
}

function isAllowedAdminQaReportPath(path) {
  const relativePath = relative(repoRoot, resolve(path)).replaceAll('\\', '/');
  return !relativePath.startsWith('..')
    && /^artifacts\/templates-feed-tz1-8-admin-qa-report(?!\.template).*\.md$/.test(relativePath);
}

function findFiles(root, fileNamePattern) {
  if (!existsSync(root)) {
    return [];
  }

  const results = [];
  for (const entry of readdirSync(root, { withFileTypes: true })) {
    const path = join(root, entry.name);
    if (entry.isDirectory()) {
      results.push(...findFiles(path, fileNamePattern));
    } else if (fileNamePattern.test(entry.name)) {
      results.push(path);
    }
  }
  return results;
}

function readJson(path) {
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch {
    return null;
  }
}

function hasCheck(evidence, name, expected) {
  return Array.isArray(evidence?.checks)
    && evidence.checks.some(check => check.name === name && check.ok === expected);
}

function isAcceptedLatencyEvidence(evidence) {
  return hasSnapshotRunnerMetadata(evidence)
    && evidence?.mode && ['latency', 'all'].includes(evidence.mode)
    && hasCheck(evidence, 'latency.before_after_times_configured', true)
    && hasCheck(evidence, 'latency.before_after_points_present', true)
    && hasCheck(evidence, 'latency.no_material_regression', true)
    && hasLatencyMeasurementStructure(evidence)
    && Number.isFinite(evidence.latency?.comparison?.beforeP95)
    && Number.isFinite(evidence.latency?.comparison?.afterP95)
    && Number.isFinite(evidence.latency?.comparison?.beforeP99)
    && Number.isFinite(evidence.latency?.comparison?.afterP99);
}

function isAcceptedSseEvidence(evidence) {
  return hasSnapshotRunnerMetadata(evidence)
    && evidence?.mode && ['sse', 'all'].includes(evidence.mode)
    && hasCheck(evidence, 'sse.admin_action_window_configured', true)
    && hasCheck(evidence, 'sse_full_invalidation_metric_present', true)
    && hasCheck(evidence, 'sse_full_invalidation_delta_zero_during_admin_window', true)
    && hasSseMeasurementStructure(evidence)
    && hasRequiredActionLabels(evidence, ['text_update', 'media_update', 'category_rename'])
    && evidence.sseFullInvalidations?.deltaTotal === 0;
}

function hasLatencyMeasurementStructure(evidence) {
  const comparison = evidence?.latency?.comparison;
  return isIsoDateString(evidence?.latency?.before?.timeUtc)
    && isIsoDateString(evidence?.latency?.after?.timeUtc)
    && evidence.latency.before.label === 'before'
    && evidence.latency.after.label === 'after'
    && isBeforeOrSame(evidence.latency.before.timeUtc, evidence.latency.after.timeUtc)
    && hasMetricSamples(evidence?.latency?.before?.p95)
    && hasMetricSamples(evidence?.latency?.before?.p99)
    && hasMetricSamples(evidence?.latency?.after?.p95)
    && hasMetricSamples(evidence?.latency?.after?.p99)
    && Number.isFinite(comparison?.p95DeltaSeconds)
    && Number.isFinite(comparison?.p99DeltaSeconds)
    && numbersClose(comparison.beforeP95, maxMetricValue(evidence.latency.before.p95))
    && numbersClose(comparison.afterP95, maxMetricValue(evidence.latency.after.p95))
    && numbersClose(comparison.beforeP99, maxMetricValue(evidence.latency.before.p99))
    && numbersClose(comparison.afterP99, maxMetricValue(evidence.latency.after.p99))
    && numbersClose(comparison.p95DeltaSeconds, comparison.afterP95 - comparison.beforeP95)
    && numbersClose(comparison.p99DeltaSeconds, comparison.afterP99 - comparison.beforeP99);
}

function hasSseMeasurementStructure(evidence) {
  const invalidations = evidence?.sseFullInvalidations;
  return isIsoDateString(invalidations?.before?.timeUtc)
    && isIsoDateString(invalidations?.after?.timeUtc)
    && invalidations.before.label === 'before'
    && invalidations.after.label === 'after'
    && isBeforeOrSame(invalidations.before.timeUtc, invalidations.after.timeUtc)
    && Number.isFinite(invalidations?.before?.total)
    && Number.isFinite(invalidations?.after?.total)
    && Number.isFinite(invalidations?.windowIncreaseAfter)
    && Number.isFinite(invalidations?.deltaTotal)
    && numbersClose(invalidations.deltaTotal, invalidations.after.total - invalidations.before.total)
    && numbersClose(invalidations.windowIncreaseAfter, invalidations.after.windowIncrease);
}

function hasSnapshotRunnerMetadata(evidence) {
  return typeof evidence?.runId === 'string'
    && evidence.runId.trim().length > 0
    && isIsoDateString(evidence.startedAtUtc)
    && isIsoDateString(evidence.finishedAtUtc)
    && isBeforeOrSame(evidence.startedAtUtc, evidence.finishedAtUtc)
    && typeof evidence.prometheusBaseUrl === 'string'
    && evidence.prometheusBaseUrl.trim().length > 0
    && evidence.prometheusBaseUrl !== 'invalid'
    && !isLocalHttpUrl(evidence.prometheusBaseUrl);
}

function hasMetricSamples(items) {
  return Array.isArray(items)
    && items.length > 0
    && items.every(item => Number.isFinite(item?.value));
}

function maxMetricValue(items) {
  const values = (items || []).map(item => item.value).filter(Number.isFinite);
  return values.length === 0 ? Number.NaN : Math.max(...values);
}

function numbersClose(left, right) {
  return Number.isFinite(left)
    && Number.isFinite(right)
    && Math.abs(left - right) < 0.000001;
}

function isIsoDateString(value) {
  if (typeof value !== 'string' || !value) {
    return false;
  }

  const timestamp = Date.parse(value);
  return Number.isFinite(timestamp) && value.includes('T');
}

function isBeforeOrSame(before, after) {
  const beforeTimestamp = Date.parse(before);
  const afterTimestamp = Date.parse(after);
  return Number.isFinite(beforeTimestamp)
    && Number.isFinite(afterTimestamp)
    && beforeTimestamp <= afterTimestamp;
}

function matchesRequiredRunId(evidence, envName) {
  const required = process.env[envName] || '';
  return !required || evidence?.runId === required;
}

function missingScopedArtifactDetail(label, envName, fallback) {
  const required = process.env[envName] || '';
  return required
    ? `missing accepted ${label} artifact for ${envName}=${required}`
    : fallback;
}

function hasRequiredActionLabels(evidence, requiredLabels) {
  const labels = new Set((evidence?.actionLabels || []).map(value => String(value).trim().toLowerCase()));
  return requiredLabels.every(label => labels.has(label));
}

function hasScenarioResultWithEvidence(text, scenario, ...allowedResults) {
  return isFilledEvidenceValue(getScenarioEvidence(text, scenario, ...allowedResults));
}

function getScenarioEvidence(text, scenario, ...allowedResults) {
  const escaped = escapeRegExp(scenario);
  const row = text.match(new RegExp(`^\\|\\s*${escaped}\\s*\\|\\s*(${allowedResults.join('|')})\\s*\\|\\s*([^|\\r\\n]*)\\|?\\s*$`, 'im'));
  if (!row) {
    return '';
  }

  return row[2].trim();
}

function hasCategoryRenameLoadProbeEvidence(text, acceptedSseEvidence) {
  const evidence = getScenarioEvidence(text, 'Category rename under feed load', 'PASS');
  if (!isFilledEvidenceValue(evidence)) {
    return false;
  }

  const expectedSummaryPath = acceptedSseEvidence?.sseFullInvalidations?.feedLoadProbe?.summaryPath;
  if (typeof expectedSummaryPath === 'string' && expectedSummaryPath.trim()) {
    return hasAcceptedLoadProbeSummaryPath(evidence, expectedSummaryPath);
  }

  return hasAcceptedLoadProbeSummaryPath(evidence);
}

function hasAcceptedLoadProbeSummaryPath(value, expectedSummaryPath = '') {
  const match = String(value || '').match(/artifacts[\\/]+template-feed-load-probes[\\/]+[^`|\]\s]+[\\/]+summary\.md/i);
  if (!match) {
    return false;
  }

  const cleaned = match[0].replaceAll('\\', '/');
  if (expectedSummaryPath && cleaned !== expectedSummaryPath.replaceAll('\\', '/')) {
    return false;
  }

  const resolved = resolve(repoRoot, cleaned);
  const relativePath = relative(repoRoot, resolved).replaceAll('\\', '/');
  if (relativePath.startsWith('..')
    || !relativePath.startsWith('artifacts/template-feed-load-probes/')
    || !existsSync(resolved)) {
    return false;
  }

  const evidencePath = resolve(resolved, '..', 'evidence.json');
  return isAcceptedLoadProbeEvidence(readJson(evidencePath));
}

function isAcceptedLoadProbeEvidence(evidence) {
  const total = evidence?.requests?.total;
  const ok = evidence?.requests?.ok;
  const failed = evidence?.requests?.failed;
  const maxErrors = evidence?.maxErrors;
  return typeof evidence?.runId === 'string'
    && evidence.runId.trim().length > 0
    && isIsoDateString(evidence.startedAtUtc)
    && isIsoDateString(evidence.finishedAtUtc)
    && isBeforeOrSame(evidence.startedAtUtc, evidence.finishedAtUtc)
    && typeof evidence?.apiBase === 'string'
    && evidence.apiBase.trim().length > 0
    && evidence.apiBase !== 'invalid'
    && !isLocalHttpUrl(evidence.apiBase)
    && Number.isInteger(total)
    && Number.isInteger(ok)
    && Number.isInteger(failed)
    && Number.isInteger(maxErrors)
    && total > 0
    && ok > 0
    && total === ok + failed
    && failed <= maxErrors
    && Number.isInteger(evidence?.concurrency)
    && evidence.concurrency > 0
    && Number.isInteger(evidence?.durationSeconds)
    && evidence.durationSeconds > 0;
}

function hasFilledMetadata(text, label) {
  return Boolean(getMetadataValue(text, label));
}

function hasAcceptedMobileReleaseSignoff(text) {
  const device = getMetadataValue(text, 'Device').replace(/^`|`$/g, '');
  if (!device || /^(unknown|ordinary device|test-device|test device)$/i.test(device)) {
    return false;
  }

  if (/low-memory (device|emulator) signoff:\s*PASS/i.test(text)) {
    return /(low[- ]memory|constrained[- ]memory)/i.test(device);
  }

  if (/weak-device release signoff:\s*PASS/i.test(text)) {
    return /(weak[- ]device|low[- ]end|entry[- ]level|low[- ]memory|constrained[- ]memory)/i.test(device);
  }

  return false;
}

function getMetadataValue(text, label) {
  const escaped = escapeRegExp(label);
  const match = text.match(new RegExp(`^(?:-\\s*)?${escaped}:[ \\t]*([^\\r\\n]*)$`, 'im'));
  if (!match) {
    return '';
  }

  const value = match[1].trim();
  return isFilledEvidenceValue(value) ? value : '';
}

function getAcceptedSseSnapshotMetadataEvidence(text, label) {
  const value = getMetadataValue(text, label);
  if (!value) {
    return null;
  }

  const cleaned = value.replace(/^`|`$/g, '');
  const resolved = resolve(repoRoot, cleaned);
  const relativePath = relative(repoRoot, resolved).replaceAll('\\', '/');
  if (relativePath.startsWith('..')
    || !relativePath.startsWith('artifacts/template-feed-staging-snapshots/')
    || !existsSync(resolved)) {
    return null;
  }

  const evidencePath = resolve(resolved, '..', 'evidence.json');
  const evidence = readJson(evidencePath);
  if (!isAcceptedSseEvidence(evidence)
    || !matchesRequiredRunId(evidence, 'TEMPLATE_FEED_REQUIRED_SSE_RUN_ID')) {
    return null;
  }

  return evidence;
}

function isFilledEvidenceValue(value) {
  const trimmed = String(value || '').trim();
  return Boolean(trimmed)
    && !/^<.*>$/.test(trimmed)
    && !/^TODO$/i.test(trimmed)
    && !/^evidence$/i.test(trimmed);
}

function parseActivePreviewMetric(text, label) {
  const escaped = escapeRegExp(label);
  const match = text.match(new RegExp(`active video preview average:.*${escaped}\\s+\`([0-9]+(?:\\.[0-9]+)?)\``, 'i'));
  return match ? Number(match[1]) : Number.NaN;
}

function relativeArtifactPath(path) {
  return path.replace(`${repoRoot}\\`, '').replaceAll('\\', '/');
}

function isLocalHttpUrl(value) {
  try {
    const hostname = new URL(value).hostname.toLowerCase().replace(/^\[|\]$/g, '');
    return [
      'localhost',
      '127.0.0.1',
      '::1',
      '0.0.0.0',
      'host.docker.internal',
    ].includes(hostname) || hostname.endsWith('.localhost');
  } catch {
    return true;
  }
}

function addCheck(name, ok, detail) {
  checks.push({ name, ok: Boolean(ok), detail });
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
