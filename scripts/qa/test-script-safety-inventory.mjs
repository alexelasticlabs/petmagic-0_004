#!/usr/bin/env node
import assert from 'node:assert/strict';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptPath = fileURLToPath(import.meta.url);
const repoRoot = join(dirname(scriptPath), '..', '..');
const scriptsRoot = join(repoRoot, 'scripts');
const workflowsRoot = join(repoRoot, '.github', 'workflows');

const scriptExtensions = new Set(['.cmd', '.js', '.mjs', '.ps1', '.py', '.sh', '.sql']);
const expectedScriptFiles = [
  'scripts/audit_mobile_release_size.ps1',
  'scripts/backup-postgres.ps1',
  'scripts/db/capture-hot-query-plans.sh',
  'scripts/docker/compose-up-portfree.ps1',
  'scripts/docker/run-dotnet-app.cmd',
  'scripts/docker/run-dotnet-app.sh',
  'scripts/generate-brand-icons.ps1',
  'scripts/k6/template-generation-load-test.js',
  'scripts/load/run-minimal-template-generation-suite.sh',
  'scripts/load/run-template-generation-baseline.sh',
  'scripts/qa/audit-android-kotlin-legacy.ps1',
  'scripts/qa/check-markdown-local-links.mjs',
  'scripts/qa/check-repository-sensitive-files.mjs',
  'scripts/qa/check-render-blueprint.mjs',
  'scripts/qa/check-staging-env-readiness.mjs',
  'scripts/qa/clean-local-generated-artifacts.mjs',
  'scripts/qa/create-template-feed-admin-qa-report-draft.mjs',
  'scripts/qa/prepare-watermark-manual-qa-media.sh',
  'scripts/qa/prepare-watermark-qa-users.mjs',
  'scripts/qa/promote-template-feed-long-scroll-artifact.mjs',
  'scripts/qa/psql-docker-wrapper.sh',
  'scripts/qa/psql.cmd',
  'scripts/qa/psql.ps1',
  'scripts/qa/run-economy-staging-infra-gate.mjs',
  'scripts/qa/run-local-generation-scheduler-smoke.mjs',
  'scripts/qa/run-render-postdeploy-smoke.mjs',
  'scripts/qa/run-render-predeploy-gate.mjs',
  'scripts/qa/run-render-docker-build-smoke.mjs',
  'scripts/qa/run-staging-generation-scheduler-smoke.mjs',
  'scripts/qa/run-template-feed-device-qa.ps1',
  'scripts/qa/run-template-feed-device-qa.sh',
  'scripts/qa/run-template-feed-load-probe.mjs',
  'scripts/qa/run-template-feed-staging-snapshot.mjs',
  'scripts/qa/run-template-feed-tz1-8-release-gate.ps1',
  'scripts/qa/run-watermark-backend-qa.mjs',
  'scripts/qa/run-watermark-preflight-qa.mjs',
  'scripts/qa/seed-watermark-manual-qa.sql',
  'scripts/qa/template-feed-cache-budget-summary.py',
  'scripts/qa/template-feed-memory-plateau-summary.py',
  'scripts/qa/template-feed-metrics-summary.py',
  'scripts/qa/template-feed-video-log-summary.py',
  'scripts/qa/test-markdown-local-links.mjs',
  'scripts/qa/test-script-safety-inventory.mjs',
  'scripts/qa/test-template-feed-admin-qa-report-draft.mjs',
  'scripts/qa/test-template-feed-load-probe.mjs',
  'scripts/qa/test-template-feed-long-scroll-promoter.mjs',
  'scripts/qa/test-template-feed-release-gate.mjs',
  'scripts/qa/test-template-feed-staging-snapshot.mjs',
  'scripts/qa/test-template-feed-tz1-8-evidence-validator.mjs',
  'scripts/qa/test-watermark-qa-help.mjs',
  'scripts/qa/validate-template-feed-tz1-8-evidence.mjs',
].sort();
const expectedWorkflowFiles = [
  '.github/workflows/admin-web-ci.yml',
  '.github/workflows/backend-ci.yml',
  '.github/workflows/backend-security.yml',
  '.github/workflows/mobile-ci.yml',
  '.github/workflows/repo-hygiene-ci.yml',
].sort();
const expectedWorkflowActionUses = [
  '.github/workflows/admin-web-ci.yml:actions/checkout@v4',
  '.github/workflows/admin-web-ci.yml:actions/setup-node@v4',
  '.github/workflows/backend-ci.yml:actions/checkout@v4',
  '.github/workflows/backend-ci.yml:actions/checkout@v4',
  '.github/workflows/backend-ci.yml:actions/setup-dotnet@v4',
  '.github/workflows/backend-ci.yml:actions/upload-artifact@v4',
  '.github/workflows/backend-security.yml:actions/checkout@v4',
  '.github/workflows/backend-security.yml:actions/checkout@v4',
  '.github/workflows/backend-security.yml:actions/checkout@v4',
  '.github/workflows/backend-security.yml:actions/dependency-review-action@v4',
  '.github/workflows/backend-security.yml:actions/setup-dotnet@v4',
  '.github/workflows/backend-security.yml:actions/upload-artifact@v4',
  '.github/workflows/backend-security.yml:gitleaks/gitleaks-action@v2',
  '.github/workflows/mobile-ci.yml:actions/checkout@v4',
  '.github/workflows/mobile-ci.yml:subosito/flutter-action@v2',
  '.github/workflows/repo-hygiene-ci.yml:actions/checkout@v4',
  '.github/workflows/repo-hygiene-ci.yml:actions/setup-dotnet@v4',
  '.github/workflows/repo-hygiene-ci.yml:actions/setup-node@v4',
  '.github/workflows/repo-hygiene-ci.yml:actions/setup-python@v5',
].sort();
const expectedWorkflowSecretReferences = [
  '.github/workflows/backend-security.yml:secrets.GITHUB_TOKEN',
].sort();

const allowedRmRf = new Map([
  ['scripts/qa/prepare-watermark-manual-qa-media.sh', ['rm -rf "$TMP_DIR"']],
]);
const allowedRemoveItem = new Map([
  ['scripts/generate-brand-icons.ps1', ['Remove-Item $temporaryPng -ErrorAction SilentlyContinue']],
]);
const allowedDeleteFrom = new Map([
  [
    'scripts/qa/seed-watermark-manual-qa.sql',
    [
      'DELETE FROM templates_generation_watermark_unlocks',
      'DELETE FROM templates_analytics_events',
      'DELETE FROM economy_wallet_ledger',
    ],
  ],
]);

function collectScriptFiles(root) {
  const files = [];
  for (const entry of readdirSync(root)) {
    const path = join(root, entry);
    const stat = statSync(path);
    if (stat.isDirectory()) {
      files.push(...collectScriptFiles(path));
      continue;
    }

    const dotIndex = entry.lastIndexOf('.');
    const extension = dotIndex >= 0 ? entry.slice(dotIndex) : '';
    if (scriptExtensions.has(extension)) {
      files.push(path);
    }
  }

  return files;
}

function read(relativePath) {
  return readFileSync(join(repoRoot, relativePath), 'utf8');
}

function relativeScriptPath(path) {
  return relative(repoRoot, path).replaceAll('\\', '/');
}

function collectWorkflowFiles(root) {
  return readdirSync(root)
    .map((entry) => join(root, entry))
    .filter((path) => statSync(path).isFile() && /\.ya?ml$/i.test(path));
}

function safetyScanFiles() {
  return [...collectScriptFiles(scriptsRoot), ...collectWorkflowFiles(workflowsRoot)];
}

function collectWorkflowActionUses() {
  return collectWorkflowFiles(workflowsRoot)
    .flatMap((absolutePath) => {
      const relativePath = relativeScriptPath(absolutePath);
      const source = readFileSync(absolutePath, 'utf8');
      return [...source.matchAll(/^\s*uses:\s*([^#\s]+)/gm)].map(
        (match) => `${relativePath}:${match[1]}`,
      );
    })
    .sort();
}

function assertWorkflowActionsUseStableMajorTags(actionUses) {
  for (const actionUse of actionUses) {
    const actionReference = actionUse.slice(actionUse.lastIndexOf(':') + 1);
    assert(
      /@v\d+$/.test(actionReference),
      `${actionUse} must use a stable major-version tag such as @v4`,
    );
  }
}

function collectWorkflowSecretReferences() {
  return collectWorkflowFiles(workflowsRoot)
    .flatMap((absolutePath) => {
      const relativePath = relativeScriptPath(absolutePath);
      const source = readFileSync(absolutePath, 'utf8');
      return [...source.matchAll(/\bsecrets\.[A-Za-z0-9_]+\b/g)].map(
        (match) => `${relativePath}:${match[0]}`,
      );
    })
    .sort();
}

function assertWorkflowHasReadOnlyContentsPermission(relativePath) {
  const source = read(relativePath);
  assert(
    /^permissions:\r?\n\s+contents:\s+read\s*$/m.test(source),
    `${relativePath} must keep top-level permissions limited to contents: read`,
  );
}

function assertWorkflowDoesNotUseDangerousTriggersOrWriteScopes(relativePath) {
  const source = read(relativePath);
  for (const forbidden of [
    /\bpull_request_target\s*:/,
    /^permissions:\s*write-all\s*$/m,
    /^\s+[A-Za-z-]+:\s*write\s*$/m,
  ]) {
    assert(
      !forbidden.test(source),
      `${relativePath} must not use dangerous workflow trigger or write permission ${forbidden}`,
    );
  }
}

function assertNoUnapprovedPattern(pattern, allowlist, description) {
  for (const absolutePath of safetyScanFiles()) {
    const relativePath = relativeScriptPath(absolutePath);
    if (relativePath === 'scripts/qa/test-script-safety-inventory.mjs') {
      continue;
    }

    const source = readFileSync(absolutePath, 'utf8');
    const matches = source.match(pattern) ?? [];
    if (matches.length === 0) {
      continue;
    }

    const allowed = allowlist.get(relativePath) ?? [];
    for (const match of matches) {
      assert(
        allowed.includes(match),
        `${description} must be reviewed before it is committed: ${relativePath}: ${match}`,
      );
    }
  }
}

const actualScriptFiles = collectScriptFiles(scriptsRoot)
  .map(relativeScriptPath)
  .filter((path) => path !== 'scripts/qa/psql')
  .sort();

assert.deepEqual(
  actualScriptFiles,
  expectedScriptFiles,
  'scripts inventory changed; classify the new/removed script in test-script-safety-inventory.mjs',
);

const actualWorkflowFiles = collectWorkflowFiles(workflowsRoot).map(relativeScriptPath).sort();

assert.deepEqual(
  actualWorkflowFiles,
  expectedWorkflowFiles,
  'workflow inventory changed; classify the new/removed workflow in test-script-safety-inventory.mjs',
);

assert.deepEqual(
  collectWorkflowActionUses(),
  expectedWorkflowActionUses,
  'workflow action references changed; review added/removed GitHub Actions in test-script-safety-inventory.mjs',
);

assertWorkflowActionsUseStableMajorTags(collectWorkflowActionUses());

assert.deepEqual(
  collectWorkflowSecretReferences(),
  expectedWorkflowSecretReferences,
  'workflow secret references changed; review added/removed GitHub Actions secrets in test-script-safety-inventory.mjs',
);

for (const workflow of expectedWorkflowFiles) {
  assertWorkflowHasReadOnlyContentsPermission(workflow);
  assertWorkflowDoesNotUseDangerousTriggersOrWriteScopes(workflow);
}

assertNoUnapprovedPattern(/\brm\s+-rf\s+["'][^"']+["']/g, allowedRmRf, 'recursive shell delete');
assertNoUnapprovedPattern(/\bRemove-Item\b[^\r\n]*/g, allowedRemoveItem, 'PowerShell delete');
assertNoUnapprovedPattern(/\bDELETE\s+FROM\s+[A-Za-z0-9_".]+/gi, allowedDeleteFrom, 'SQL delete');

const gitignore = read('.gitignore');
assert(
  gitignore.includes('.agents/') && gitignore.includes('skills-lock.json'),
  '.gitignore must keep local agent skill caches out of GitHub candidates',
);
assert(
  gitignore.includes('!.env.*.example') && gitignore.includes('!**/.env.*.example'),
  '.gitignore must keep environment example files visible to Git',
);

const gitattributes = read('.gitattributes');
for (const binaryPattern of ['*.png binary', '*.jpg binary', '*.ttf binary', '*.jar binary', '*.keystore binary']) {
  assert(
    gitattributes.includes(binaryPattern),
    `.gitattributes must keep ${binaryPattern} so binary assets are not normalized as text`,
  );
}

const dockerignore = read('.dockerignore');
assert(
  dockerignore.includes('.agents') && dockerignore.includes('skills-lock.json'),
  '.dockerignore must keep local agent skill caches out of Docker build contexts',
);

const adminDockerignore = read('apps/admin-web/.dockerignore');
assert(
  adminDockerignore.includes('.npmrc') && adminDockerignore.includes('.env.*'),
  'admin-web Docker context must ignore local npm config and env files',
);

const repositorySensitiveFilesCheck = read('scripts/qa/check-repository-sensitive-files.mjs');
assert(
  repositorySensitiveFilesCheck.includes('git')
    && repositorySensitiveFilesCheck.includes('ls-files')
    && repositorySensitiveFilesCheck.includes('--exclude-standard'),
  'repository sensitive-file check must scan tracked and untracked non-ignored Git candidates',
);
assert(
  repositorySensitiveFilesCheck.includes('key')
    && repositorySensitiveFilesCheck.includes('properties')
    && repositorySensitiveFilesCheck.includes('keystore')
    && repositorySensitiveFilesCheck.includes('.npmrc'),
  'repository sensitive-file check must guard signing material and npm credentials',
);
assert(
  repositorySensitiveFilesCheck.includes('google-services.json')
    && repositorySensitiveFilesCheck.includes('GoogleService-Info.plist'),
  'repository sensitive-file check must guard Firebase config files',
);

const localGeneratedArtifactsCleanup = read('scripts/qa/clean-local-generated-artifacts.mjs');
assert(
  localGeneratedArtifactsCleanup.includes('Dry run only. Pass --apply')
    && localGeneratedArtifactsCleanup.includes('--include-node-modules'),
  'local generated artifacts cleanup must stay dry-run by default and explicit for node_modules',
);
assert(
  localGeneratedArtifactsCleanup.includes('Refusing to remove protected path')
    && localGeneratedArtifactsCleanup.includes('Refusing to remove path outside repository')
    && localGeneratedArtifactsCleanup.includes('tracked files exist under it'),
  'local generated artifacts cleanup must keep path safety guards',
);
assert(
  localGeneratedArtifactsCleanup.includes('.env.staging.local')
    && localGeneratedArtifactsCleanup.includes('.projects/vault'),
  'local generated artifacts cleanup must not remove local secrets or project vault state',
);

for (const forbidden of [
  /\bdocker(?:-compose|\s+compose)\s+down\s+(-v|--volumes)\b/i,
  /\bdropdb\b/i,
  /\bDROP\s+DATABASE\b/i,
  /\bInvoke-Expression\b/i,
  /\biex\b/i,
  /\bSet-ExecutionPolicy\b/i,
  /\bchmod\s+777\b/i,
  /\bcurl\b[^\r\n|]*\|[^\r\n]*(?:sh|bash|pwsh|powershell)\b/i,
  /\bwget\b[^\r\n|]*\|[^\r\n]*(?:sh|bash|pwsh|powershell)\b/i,
]) {
  assertNoUnapprovedPattern(forbidden, new Map(), `forbidden pattern ${forbidden}`);
}

const watermarkSeed = read('scripts/qa/seed-watermark-manual-qa.sql');
assert(
  watermarkSeed.includes('Local-only seed helper for watermark monetization manual QA.'),
  'watermark seed SQL must remain explicitly local-only',
);

const stagingSmoke = read('scripts/qa/run-staging-generation-scheduler-smoke.mjs');
assert(
  stagingSmoke.includes("throw new Error('docker-compose-psql is only allowed for local smoke mode.');"),
  'staging scheduler smoke must reject docker-compose-psql outside local mode',
);
assert(
  stagingSmoke.includes("smokeMode === 'local' ? 'local mode allows localhost/local compose' : 'staging mode rejects localhost/local compose'"),
  'staging scheduler smoke must keep explicit local-vs-staging target policy evidence',
);
assert(
  stagingSmoke.includes('function extractDatabaseHost(value)'),
  'staging scheduler smoke must determine local database targets from the host, not the database name',
);
assert(
  !stagingSmoke.includes("normalized.includes('/petmagic_db')"),
  'staging scheduler smoke must not reject Render staging solely because the database name is petmagic_db',
);

const stagingEnvReadiness = read('scripts/qa/check-staging-env-readiness.mjs');
assert(
  stagingEnvReadiness.includes('Staging env readiness checker.'),
  'staging env readiness checker must keep help text for operator use',
);
assert(
  stagingEnvReadiness.includes('The default mode validates that a local operator .env.staging.local file'),
  'staging env readiness checker must document that it validates local operator inputs',
);

const renderDockerBuildSmoke = read('scripts/qa/run-render-docker-build-smoke.mjs');
assert(
  renderDockerBuildSmoke.includes('Render Docker build smoke.'),
  'Render Docker build smoke must keep help text for operator use',
);
assert(
  renderDockerBuildSmoke.includes('It does not pass secrets as Docker build args.'),
  'Render Docker build smoke must document that secrets are not passed as build args',
);

const renderPostdeploySmoke = read('scripts/qa/run-render-postdeploy-smoke.mjs');
assert(
  renderPostdeploySmoke.includes('Render post-deploy smoke.'),
  'Render post-deploy smoke must keep help text for operator use',
);
assert(
  renderPostdeploySmoke.includes('The smoke is read-only: it checks API /health and admin /ru'),
  'Render post-deploy smoke must document its read-only scope',
);

const renderPredeployGate = read('scripts/qa/run-render-predeploy-gate.mjs');
assert(
  renderPredeployGate.includes('Render predeploy gate.'),
  'Render predeploy gate must keep help text for operator use',
);
assert(
  renderPredeployGate.includes('check-render-blueprint.mjs'),
  'Render predeploy gate must run Blueprint validation',
);
assert(
  renderPredeployGate.includes('check-staging-env-readiness.mjs'),
  'Render predeploy gate must run staging env example validation',
);
assert(
  renderPredeployGate.includes('compose_staging_example_config')
    && renderPredeployGate.includes("'compose', '--env-file', '.env.staging.local.example', 'config', '--quiet'"),
  'Render predeploy gate must preserve Compose config validation evidence',
);
assert(
  renderPredeployGate.includes('--with-docker-build'),
  'Render predeploy gate must keep Docker build smoke opt-in documented',
);

const economyStagingGate = read('scripts/qa/run-economy-staging-infra-gate.mjs');
assert(
  economyStagingGate.includes('validateStagingTargets();'),
  'economy staging infra gate must validate staging targets before running checks',
);
assert(
  economyStagingGate.includes(
    'must not target localhost/local infrastructure for the economy staging infra gate.',
  ),
  'economy staging infra gate must reject local targets without printing secrets',
);
assert(
  economyStagingGate.includes("assertNotLocalStagingTarget('STAGING_API_BASE_URL', apiBaseUrl);"),
  'economy staging infra gate must validate optional API targets',
);
assert(
  economyStagingGate.includes('validateStagingPsqlCommand();'),
  'economy staging infra gate must validate staging psql command before running checks',
);
assert(
  economyStagingGate.includes('STAGING_PSQL_COMMAND must not use repo-local Docker compose psql wrappers'),
  'economy staging infra gate must reject repo-local Docker compose psql wrappers',
);
assert(
  !economyStagingGate.includes('requiredEnv('),
  'economy staging infra gate must use the defined requireEnv helper',
);

const templateFeedEvidenceValidator = read('scripts/qa/validate-template-feed-tz1-8-evidence.mjs');
assert(
  templateFeedEvidenceValidator.includes('!isLocalHttpUrl(evidence.prometheusBaseUrl)'),
  'template feed evidence validator must reject local Prometheus snapshot targets',
);
assert(
  templateFeedEvidenceValidator.includes('!isLocalHttpUrl(evidence.apiBase)'),
  'template feed evidence validator must reject local feed-load API targets',
);
assert(
  templateFeedEvidenceValidator.includes('hasAcceptedMobileReleaseSignoff(text)'),
  'template feed evidence validator must require concrete mobile release signoff evidence',
);
assert(
  templateFeedEvidenceValidator.includes('^(?:-\\\\s*)?${escaped}:'),
  'template feed evidence validator must parse promoter-style metadata with or without list markers',
);

const longScrollPromoter = read('scripts/qa/promote-template-feed-long-scroll-artifact.mjs');
assert(
  longScrollPromoter.includes('validateDeviceLabelForSignoff(signoff, deviceLabel);'),
  'template feed long-scroll promoter must validate device labels before PASS signoff',
);
assert(
  longScrollPromoter.includes('Release signoff requires a concrete weak-device or low-memory device label.'),
  'template feed long-scroll promoter must reject placeholder release-signoff device labels',
);

console.log('script safety inventory ok');
