param(
    [string]$EnvFile = ".env.staging.local",
    [string]$RunId = "",
    [string]$AdminQaReportPath = "",
    [int]$SseWaitSeconds = 180,
    [string]$MobileLongScrollRunDir = "",
    [ValidateSet("pending", "weak-device", "low-memory-emulator")]
    [string]$MobileLongScrollSignoff = "pending",
    [string]$MobileLongScrollDeviceLabel = "",
    [switch]$PreflightOnly,
    [switch]$ValidateStagingInputsOnly,
    [switch]$SkipLatency,
    [switch]$SkipSse,
    [switch]$SkipValidator,
    [switch]$SkipBackendGuardTests,
    [switch]$SkipAdminGuardTests,
    [string]$FeedLoadApiBase = "",
    [int]$FeedLoadProbeConcurrency = 4,
    [switch]$CreateAdminQaDraftIfMissing,
    [string]$AdminQaDraftAdminUrl = "",
    [string]$AdminQaDraftApiHealth = "",
    [string]$AdminQaDraftOperator = "",
    [string]$ReleaseGateArtifactDir = ""
)

$ErrorActionPreference = "Stop"
$script:ReleaseGateSteps = @()
$script:ReleaseGateStartedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
$script:ReleaseGateArtifactDir = $null

function Add-ReleaseGateStep {
    param(
        [string]$Name,
        [string]$Status,
        [int]$ExitCode,
        [datetime]$StartedAtUtc,
        [datetime]$FinishedAtUtc,
        [string]$ErrorMessage = ""
    )

    $script:ReleaseGateSteps += [pscustomobject]@{
        name = $Name
        status = $Status
        exitCode = $ExitCode
        startedAtUtc = $StartedAtUtc.ToString("o")
        finishedAtUtc = $FinishedAtUtc.ToString("o")
        durationSeconds = [Math]::Round(($FinishedAtUtc - $StartedAtUtc).TotalSeconds, 3)
        error = $ErrorMessage
    }
}

function Write-ReleaseGateSummary {
    param([string]$Status)

    if ([string]::IsNullOrWhiteSpace($script:ReleaseGateArtifactDir)) {
        return
    }

    New-Item -ItemType Directory -Force -Path $script:ReleaseGateArtifactDir | Out-Null
    $summary = [pscustomobject]@{
        runId = $effectiveRunId
        status = $Status
        startedAtUtc = $script:ReleaseGateStartedAtUtc
        finishedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
        preflightOnly = [bool]$PreflightOnly
        skipLatency = [bool]$SkipLatency
        skipSse = [bool]$SkipSse
        skipValidator = [bool]$SkipValidator
        skipBackendGuardTests = [bool]$SkipBackendGuardTests
        skipAdminGuardTests = [bool]$SkipAdminGuardTests
        steps = $script:ReleaseGateSteps
    }
    $summary | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 -Path (Join-Path $script:ReleaseGateArtifactDir "summary.json")
}

function Invoke-Step {
    param(
        [string]$Name,
        [scriptblock]$Command
    )

    Write-Host ""
    Write-Host "==> $Name"
    $startedAtUtc = (Get-Date).ToUniversalTime()
    $exitCode = 0

    try {
        & $Command
        if ($null -ne $LASTEXITCODE) {
            $exitCode = $LASTEXITCODE
        }
        if ($exitCode -ne 0) {
            throw "$Name failed with exit code $exitCode"
        }
        Add-ReleaseGateStep -Name $Name -Status "passed" -ExitCode $exitCode -StartedAtUtc $startedAtUtc -FinishedAtUtc (Get-Date).ToUniversalTime()
    } catch {
        if ($exitCode -eq 0) {
            $exitCode = 1
        }
        Add-ReleaseGateStep -Name $Name -Status "failed" -ExitCode $exitCode -StartedAtUtc $startedAtUtc -FinishedAtUtc (Get-Date).ToUniversalTime() -ErrorMessage ($_.Exception.Message)
        Write-ReleaseGateSummary -Status "failed"
        throw
    }
}

function Import-EnvFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Env file not found: $Path"
    }

    Get-Content -LiteralPath $Path | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith("#")) {
            return
        }

        $match = [regex]::Match($line, "^([A-Za-z_][A-Za-z0-9_]*)=(.*)$")
        if (-not $match.Success) {
            return
        }

        $name = $match.Groups[1].Value
        $value = $match.Groups[2].Value.Trim()
        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        if (-not [Environment]::GetEnvironmentVariable($name, "Process")) {
            [Environment]::SetEnvironmentVariable($name, $value, "Process")
        }
    }
}

function Require-Env {
    param([string[]]$Names)

    $missing = @()
    foreach ($name in $Names) {
        if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name, "Process"))) {
            $missing += $name
        }
    }

    if ($missing.Count -gt 0) {
        throw "Missing required environment variable(s): $($missing -join ', ')"
    }
}

function Assert-HttpUrl {
    param(
        [string]$Name,
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$Name must not be empty."
    }

    $uri = $null
    if (-not [Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$uri)) {
        throw "$Name must be an absolute http/https URL, got: $Value"
    }

    if ($uri.Scheme -ne "http" -and $uri.Scheme -ne "https") {
        throw "$Name must use http or https, got: $Value"
    }
}

function Get-RequiredUtcInstant {
    param([string]$Name)

    $value = [Environment]::GetEnvironmentVariable($Name, "Process")
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Missing required environment variable(s): $Name"
    }

    try {
        $instant = [DateTimeOffset]::Parse(
            $value,
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::AssumeUniversal)
    } catch {
        throw "$Name must be an ISO-8601 UTC timestamp, got: $value"
    }

    if ($instant.Offset.TotalSeconds -ne 0) {
        throw "$Name must be a UTC timestamp ending with Z or +00:00, got: $value"
    }

    return $instant
}

function Assert-LatencyComparisonTimes {
    $beforeAt = Get-RequiredUtcInstant -Name "TEMPLATE_FEED_BEFORE_AT_UTC"
    $afterAt = Get-RequiredUtcInstant -Name "TEMPLATE_FEED_AFTER_AT_UTC"

    if ($afterAt -le $beforeAt) {
        throw "TEMPLATE_FEED_AFTER_AT_UTC must be later than TEMPLATE_FEED_BEFORE_AT_UTC for Task 4 before/after latency evidence."
    }
}

function Get-RepoRelativePath {
    param([string]$Path)

    $repoRoot = [IO.Path]::GetFullPath((Get-Location).Path)
    $fullPath = if ([IO.Path]::IsPathRooted($Path)) {
        [IO.Path]::GetFullPath($Path)
    } else {
        [IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
    }

    $repoRootWithSeparator = $repoRoot.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
    $repoUri = [Uri]$repoRootWithSeparator
    $pathUri = [Uri]$fullPath
    return [Uri]::UnescapeDataString($repoUri.MakeRelativeUri($pathUri).ToString()).Replace("\", "/")
}

function Assert-AdminQaReportPathAllowed {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    $relativePath = Get-RepoRelativePath -Path $Path
    if ($relativePath.StartsWith("../", [StringComparison]::Ordinal) -or $relativePath -eq ".." -or $relativePath -match "^[A-Za-z]:/") {
        throw "Admin QA report path must be inside artifacts/templates-feed-tz1-8-admin-qa-report*.md, got: $Path"
    }

    if ($relativePath -notmatch "^artifacts/templates-feed-tz1-8-admin-qa-report(?!\.template).*\.md$") {
        throw "Admin QA report path must match artifacts/templates-feed-tz1-8-admin-qa-report*.md and must not be the template file, got: $relativePath"
    }
}

function Ensure-AdminQaReport {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "Admin QA report path is required. Pass -AdminQaReportPath artifacts/templates-feed-tz1-8-admin-qa-report-<date>.md or set TEMPLATE_FEED_ADMIN_QA_REPORT_PATH after completing manual Admin QA."
    }

    Assert-AdminQaReportPathAllowed -Path $Path

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Admin QA report not found: $Path"
    }
}

function Get-EffectiveAdminQaReportPath {
    if (-not [string]::IsNullOrWhiteSpace($AdminQaReportPath)) {
        return $AdminQaReportPath
    }

    $pathFromEnv = [Environment]::GetEnvironmentVariable("TEMPLATE_FEED_ADMIN_QA_REPORT_PATH", "Process")
    if (-not [string]::IsNullOrWhiteSpace($pathFromEnv)) {
        return $pathFromEnv
    }

    return ""
}

function Get-EffectiveFeedLoadApiBase {
    if (-not [string]::IsNullOrWhiteSpace($FeedLoadApiBase)) {
        return $FeedLoadApiBase
    }

    $apiBaseFromEnv = [Environment]::GetEnvironmentVariable("TEMPLATE_FEED_LOAD_PROBE_API_BASE", "Process")
    if (-not [string]::IsNullOrWhiteSpace($apiBaseFromEnv)) {
        return $apiBaseFromEnv
    }

    return ""
}

function Assert-AdminQaDraftParameters {
    $missing = @()
    if ([string]::IsNullOrWhiteSpace($AdminQaDraftAdminUrl)) {
        $missing += "AdminQaDraftAdminUrl"
    }
    if ([string]::IsNullOrWhiteSpace($AdminQaDraftApiHealth)) {
        $missing += "AdminQaDraftApiHealth"
    }
    if ([string]::IsNullOrWhiteSpace($AdminQaDraftOperator)) {
        $missing += "AdminQaDraftOperator"
    }
    if ($missing.Count -gt 0) {
        throw "Cannot create Admin QA draft; missing parameter(s): -$($missing -join ', -')"
    }

    Assert-HttpUrl -Name "AdminQaDraftAdminUrl" -Value $AdminQaDraftAdminUrl
}

function New-AdminQaDraftIfMissing {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or (Test-Path -LiteralPath $Path) -or -not $CreateAdminQaDraftIfMissing) {
        return
    }

    Assert-AdminQaReportPathAllowed -Path $Path
    Assert-AdminQaDraftParameters

    Invoke-Step "Admin QA report draft creation" {
        node scripts\qa\create-template-feed-admin-qa-report-draft.mjs `
            "--sse-run-id=$effectiveRunId-sse" `
            "--admin-url=$AdminQaDraftAdminUrl" `
            "--api-health=$AdminQaDraftApiHealth" `
            "--operator=$AdminQaDraftOperator" `
            "--output=$Path"
    }

    Write-ReleaseGateSummary -Status "failed"
    throw "Admin QA draft created at $Path. Complete every TODO row with PASS/FAIL/N/A and concrete UI evidence, then rerun the release gate."
}

function Assert-AdminQaInputReadiness {
    param([string]$Path)

    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        Assert-AdminQaReportPathAllowed -Path $Path
        if (Test-Path -LiteralPath $Path) {
            return
        }
    }

    if (-not $CreateAdminQaDraftIfMissing) {
        Ensure-AdminQaReport -Path $Path
        return
    }

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "Admin QA report path is required when -CreateAdminQaDraftIfMissing is set."
    }

    Assert-AdminQaReportPathAllowed -Path $Path
    Assert-AdminQaDraftParameters
}

function Assert-ReleaseGateInputReadiness {
    Import-EnvFile -Path $EnvFile
    Require-Env -Names @("STAGING_PROMETHEUS_BASE_URL")
    Assert-HttpUrl -Name "STAGING_PROMETHEUS_BASE_URL" -Value ([Environment]::GetEnvironmentVariable("STAGING_PROMETHEUS_BASE_URL", "Process"))

    if (-not $SkipLatency) {
        Require-Env -Names @("TEMPLATE_FEED_BEFORE_AT_UTC", "TEMPLATE_FEED_AFTER_AT_UTC")
        Assert-LatencyComparisonTimes
    } elseif (-not $SkipValidator) {
        Require-Env -Names @("TEMPLATE_FEED_REQUIRED_LATENCY_RUN_ID")
    }

    if (-not $SkipSse) {
        if ($SseWaitSeconds -le 0) {
            throw "SseWaitSeconds must be positive for Task 6 acceptance."
        }
    } elseif (-not $SkipValidator) {
        Require-Env -Names @("TEMPLATE_FEED_REQUIRED_SSE_RUN_ID")
    }

    $effectiveFeedLoadApiBase = Get-EffectiveFeedLoadApiBase
    if (-not $SkipSse -and -not [string]::IsNullOrWhiteSpace($effectiveFeedLoadApiBase)) {
        Assert-HttpUrl -Name "TEMPLATE_FEED_LOAD_PROBE_API_BASE" -Value $effectiveFeedLoadApiBase
        if ($FeedLoadProbeConcurrency -le 0) {
            throw "FeedLoadProbeConcurrency must be greater than 0 when feed-load probing is enabled."
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($MobileLongScrollRunDir) -and -not (Test-Path -LiteralPath $MobileLongScrollRunDir)) {
        throw "Mobile long-scroll run directory not found: $MobileLongScrollRunDir"
    }

    Assert-AdminQaInputReadiness -Path (Get-EffectiveAdminQaReportPath)
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$effectiveRunId = if ([string]::IsNullOrWhiteSpace($RunId)) { "template-feed-tz1-8-release-$timestamp" } else { $RunId }
$artifactDirFromEnv = [Environment]::GetEnvironmentVariable("TEMPLATE_FEED_RELEASE_GATE_ARTIFACT_DIR", "Process")
$script:ReleaseGateArtifactDir = if ($PSBoundParameters.ContainsKey("ReleaseGateArtifactDir") -and -not [string]::IsNullOrWhiteSpace([string]$PSBoundParameters["ReleaseGateArtifactDir"])) {
    [string]$PSBoundParameters["ReleaseGateArtifactDir"]
} elseif (-not [string]::IsNullOrWhiteSpace($artifactDirFromEnv)) {
    $artifactDirFromEnv
} else {
    $null
}

if ($ValidateStagingInputsOnly) {
    Invoke-Step "staging input readiness" {
        Assert-ReleaseGateInputReadiness
    }
    Write-ReleaseGateSummary -Status "input_validation_passed"
    Write-Host ""
    Write-Host "Staging/Admin release-gate inputs are present. No tests or staging snapshots were run."
    exit 0
}

Invoke-Step "snapshot runner self-test" {
    node scripts\qa\test-template-feed-staging-snapshot.mjs
}

Invoke-Step "evidence validator self-test" {
    node scripts\qa\test-template-feed-tz1-8-evidence-validator.mjs
}

Invoke-Step "mobile long-scroll promoter self-test" {
    node scripts\qa\test-template-feed-long-scroll-promoter.mjs
}

Invoke-Step "feed load probe self-test" {
    node scripts\qa\test-template-feed-load-probe.mjs
}

Invoke-Step "Admin QA report draft self-test" {
    node scripts\qa\test-template-feed-admin-qa-report-draft.mjs
}

if ([Environment]::GetEnvironmentVariable("TEMPLATE_FEED_SKIP_RELEASE_GATE_SELF_TEST", "Process") -ne "true") {
    Invoke-Step "release gate self-test" {
        node scripts\qa\test-template-feed-release-gate.mjs
    }
}

if (-not $SkipBackendGuardTests) {
    Invoke-Step "backend template guard tests" {
        dotnet test tests\PetMagic.Modules.Identity.Tests\PetMagic.Modules.Identity.Tests.csproj --no-restore -m:1 --filter "FullyQualifiedName~TemplatesServiceTests|FullyQualifiedName~AdminTemplateEndpointHardeningTests|FullyQualifiedName~TemplateGenerationMetricsTests|FullyQualifiedName~TemplateFeedRealtimeServiceTests"
    }
}

if (-not $SkipAdminGuardTests) {
    Invoke-Step "admin template guard tests" {
        Push-Location apps\admin-web
        try {
            npm test -- --run src/components/templates/template-form-mappers.test.ts src/components/templates/templates-catalog-actions.test.ts
        } finally {
            Pop-Location
        }
    }
}

if ($PreflightOnly) {
    Write-ReleaseGateSummary -Status "preflight_passed"
    Write-Host ""
    Write-Host "Preflight complete. Real staging collection was skipped because -PreflightOnly was set."
    exit 0
}

Assert-ReleaseGateInputReadiness

if (-not $SkipLatency) {
    [Environment]::SetEnvironmentVariable("TEMPLATE_FEED_SNAPSHOT_RUN_ID", "$effectiveRunId-latency", "Process")
    [Environment]::SetEnvironmentVariable("TEMPLATE_FEED_REQUIRED_LATENCY_RUN_ID", "$effectiveRunId-latency", "Process")
    Invoke-Step "staging feed latency snapshot" {
        node scripts\qa\run-template-feed-staging-snapshot.mjs --mode=latency
    }
}

if (-not $SkipSse) {
    [Environment]::SetEnvironmentVariable("TEMPLATE_FEED_SNAPSHOT_RUN_ID", "$effectiveRunId-sse", "Process")
    [Environment]::SetEnvironmentVariable("TEMPLATE_FEED_REQUIRED_SSE_RUN_ID", "$effectiveRunId-sse", "Process")
    [Environment]::SetEnvironmentVariable("TEMPLATE_FEED_SNAPSHOT_WAIT_SECONDS", [string]$SseWaitSeconds, "Process")
    $effectiveFeedLoadApiBase = Get-EffectiveFeedLoadApiBase
    if (-not [string]::IsNullOrWhiteSpace($effectiveFeedLoadApiBase)) {
        [Environment]::SetEnvironmentVariable("TEMPLATE_FEED_LOAD_PROBE_API_BASE", $effectiveFeedLoadApiBase, "Process")
    }
    if (-not [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable("TEMPLATE_FEED_LOAD_PROBE_API_BASE", "Process"))) {
        [Environment]::SetEnvironmentVariable("TEMPLATE_FEED_LOAD_PROBE_RUN_ID", "$effectiveRunId-rename-load", "Process")
        [Environment]::SetEnvironmentVariable("TEMPLATE_FEED_LOAD_PROBE_ARTIFACT_DIR", "artifacts/template-feed-load-probes/$effectiveRunId-rename-load", "Process")
        [Environment]::SetEnvironmentVariable("TEMPLATE_FEED_LOAD_PROBE_DURATION_SECONDS", [string]$SseWaitSeconds, "Process")
        [Environment]::SetEnvironmentVariable("TEMPLATE_FEED_LOAD_PROBE_CONCURRENCY", [string]$FeedLoadProbeConcurrency, "Process")
    }
    Invoke-Step "staging SSE full-invalidation snapshot" {
        node scripts\qa\run-template-feed-staging-snapshot.mjs --mode=sse
    }
}

if (-not [string]::IsNullOrWhiteSpace($MobileLongScrollRunDir)) {
    $promoteArgs = @(
        "scripts\qa\promote-template-feed-long-scroll-artifact.mjs",
        "--run-dir=$MobileLongScrollRunDir",
        "--signoff=$MobileLongScrollSignoff"
    )
    if (-not [string]::IsNullOrWhiteSpace($MobileLongScrollDeviceLabel)) {
        $promoteArgs += "--device-label=$MobileLongScrollDeviceLabel"
    }

    Invoke-Step "mobile long-scroll curated artifact promotion" {
        node @promoteArgs
    }
}

$effectiveAdminQaReportPath = Get-EffectiveAdminQaReportPath
New-AdminQaDraftIfMissing -Path $effectiveAdminQaReportPath
Ensure-AdminQaReport -Path $effectiveAdminQaReportPath
[Environment]::SetEnvironmentVariable("TEMPLATE_FEED_ADMIN_QA_REPORT_PATH", $effectiveAdminQaReportPath, "Process")

if (-not $SkipValidator) {
    Invoke-Step "final TZ1-8 evidence gate" {
        node scripts\qa\validate-template-feed-tz1-8-evidence.mjs
    }
}

Write-Host ""
Write-Host "Templates feed TZ1-8 release gate completed."
Write-ReleaseGateSummary -Status "passed"
