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
    [switch]$SkipLatency,
    [switch]$SkipSse,
    [switch]$SkipValidator
)

$ErrorActionPreference = "Stop"

function Invoke-Step {
    param(
        [string]$Name,
        [scriptblock]$Command
    )

    Write-Host ""
    Write-Host "==> $Name"
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE"
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

function Ensure-AdminQaReport {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "Admin QA report path is required. Pass -AdminQaReportPath artifacts/templates-feed-tz1-8-admin-qa-report-<date>.md after completing manual Admin QA."
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Admin QA report not found: $Path"
    }
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$effectiveRunId = if ([string]::IsNullOrWhiteSpace($RunId)) { "template-feed-tz1-8-release-$timestamp" } else { $RunId }

Invoke-Step "snapshot runner self-test" {
    node scripts\qa\test-template-feed-staging-snapshot.mjs
}

Invoke-Step "evidence validator self-test" {
    node scripts\qa\test-template-feed-tz1-8-evidence-validator.mjs
}

Invoke-Step "mobile long-scroll promoter self-test" {
    node scripts\qa\test-template-feed-long-scroll-promoter.mjs
}

if ([Environment]::GetEnvironmentVariable("TEMPLATE_FEED_SKIP_RELEASE_GATE_SELF_TEST", "Process") -ne "true") {
    Invoke-Step "release gate self-test" {
        node scripts\qa\test-template-feed-release-gate.mjs
    }
}

if ($PreflightOnly) {
    Write-Host ""
    Write-Host "Preflight complete. Real staging collection was skipped because -PreflightOnly was set."
    exit 0
}

Import-EnvFile -Path $EnvFile
Require-Env -Names @("STAGING_PROMETHEUS_BASE_URL")

if (-not $SkipLatency) {
    Require-Env -Names @("TEMPLATE_FEED_BEFORE_AT_UTC", "TEMPLATE_FEED_AFTER_AT_UTC")
    [Environment]::SetEnvironmentVariable("TEMPLATE_FEED_SNAPSHOT_RUN_ID", "$effectiveRunId-latency", "Process")
    [Environment]::SetEnvironmentVariable("TEMPLATE_FEED_REQUIRED_LATENCY_RUN_ID", "$effectiveRunId-latency", "Process")
    Invoke-Step "staging feed latency snapshot" {
        node scripts\qa\run-template-feed-staging-snapshot.mjs --mode=latency
    }
} elseif (-not $SkipValidator) {
    Require-Env -Names @("TEMPLATE_FEED_REQUIRED_LATENCY_RUN_ID")
}

if (-not $SkipSse) {
    if ($SseWaitSeconds -le 0) {
        throw "SseWaitSeconds must be positive for Task 6 acceptance."
    }

    [Environment]::SetEnvironmentVariable("TEMPLATE_FEED_SNAPSHOT_RUN_ID", "$effectiveRunId-sse", "Process")
    [Environment]::SetEnvironmentVariable("TEMPLATE_FEED_REQUIRED_SSE_RUN_ID", "$effectiveRunId-sse", "Process")
    [Environment]::SetEnvironmentVariable("TEMPLATE_FEED_SNAPSHOT_WAIT_SECONDS", [string]$SseWaitSeconds, "Process")
    Invoke-Step "staging SSE full-invalidation snapshot" {
        node scripts\qa\run-template-feed-staging-snapshot.mjs --mode=sse
    }
} elseif (-not $SkipValidator) {
    Require-Env -Names @("TEMPLATE_FEED_REQUIRED_SSE_RUN_ID")
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

Ensure-AdminQaReport -Path $AdminQaReportPath
[Environment]::SetEnvironmentVariable("TEMPLATE_FEED_ADMIN_QA_REPORT_PATH", $AdminQaReportPath, "Process")

if (-not $SkipValidator) {
    Invoke-Step "final TZ1-8 evidence gate" {
        node scripts\qa\validate-template-feed-tz1-8-evidence.mjs
    }
}

Write-Host ""
Write-Host "Templates feed TZ1-8 release gate completed."
