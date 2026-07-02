param(
    [string]$RunId = $([DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ")),
    [string]$DeviceId = $env:DEVICE_ID,
    [ValidateSet("debug", "profile", "release")]
    [string]$Mode = $(if ($env:MODE) { $env:MODE } else { "profile" }),
    [string]$Target = $(if ($env:TARGET) { $env:TARGET } else { "integration_test/templates_feed_backend_stress_test.dart" }),
    [string]$Driver = $(if ($env:DRIVER) { $env:DRIVER } else { "test_driver/integration_test.dart" }),
    [string]$AppId = $(if ($env:APP_ID) { $env:APP_ID } else { "com.petmagic.app" }),
    [int]$SampleIntervalSeconds = $(if ($env:ANDROID_SAMPLE_INTERVAL_SECONDS) { [int]$env:ANDROID_SAMPLE_INTERVAL_SECONDS } else { 5 }),
    [string]$FlutterDriveExtraArgs = $env:FLUTTER_DRIVE_EXTRA_ARGS,
    [string]$ArtifactRoot = $(if ($env:ARTIFACT_ROOT) { $env:ARTIFACT_ROOT } else { "artifacts/mobile-template-feed" })
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$mobileDir = Join-Path $root "apps\petmagic-mobile"
$runDir = Join-Path $root (Join-Path $ArtifactRoot $RunId)
New-Item -ItemType Directory -Force -Path $runDir | Out-Null

if ([string]::IsNullOrWhiteSpace($DeviceId)) {
    Push-Location $mobileDir
    try {
        flutter devices | Tee-Object -FilePath (Join-Path $runDir "flutter-devices.txt")
    }
    finally {
        Pop-Location
    }

    throw "DeviceId is required. Pass -DeviceId or set DEVICE_ID."
}

$metadata = [ordered]@{
    RUN_ID = $RunId
    DEVICE_ID = $DeviceId
    MODE = $Mode
    TARGET = $Target
    DRIVER = $Driver
    APP_ID = $AppId
    ANDROID_SAMPLE_INTERVAL_SECONDS = $SampleIntervalSeconds
    FLUTTER_DRIVE_EXTRA_ARGS = $FlutterDriveExtraArgs
    UTC_STARTED_AT = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
}
$metadata.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" } |
    Set-Content -LiteralPath (Join-Path $runDir "template-feed-device-qa.env")

Push-Location $mobileDir
try {
    flutter devices > (Join-Path $runDir "flutter-devices.txt") 2>&1
    flutter doctor -v > (Join-Path $runDir "flutter-doctor.txt") 2>&1
}
finally {
    Pop-Location
}

function Invoke-Adb {
    param([string[]]$Arguments, [string]$OutputPath)

    try {
        & adb -s $DeviceId @Arguments > $OutputPath 2>&1
    }
    catch {
        $_ | Out-String | Set-Content -LiteralPath $OutputPath
    }
}

function Capture-AndroidSnapshot {
    param([string]$Phase)

    Invoke-Adb -Arguments @("shell", "dumpsys", "meminfo", $AppId) `
        -OutputPath (Join-Path $runDir "android-meminfo-$Phase.txt")
    Invoke-Adb -Arguments @("shell", "dumpsys", "gfxinfo", $AppId, "framestats") `
        -OutputPath (Join-Path $runDir "android-gfxinfo-$Phase.txt")
    Invoke-Adb -Arguments @("shell", "run-as", $AppId, "sh", "-c", "du -ak cache 2>/dev/null | sort -nr | head -80") `
        -OutputPath (Join-Path $runDir "android-private-cache-$Phase.txt")
    Invoke-Adb -Arguments @("shell", "du", "-ak", "/sdcard/Android/data/$AppId/cache") `
        -OutputPath (Join-Path $runDir "android-external-cache-$Phase.txt")
}

Capture-AndroidSnapshot -Phase "before"
Invoke-Adb -Arguments @("shell", "am", "force-stop", $AppId) `
    -OutputPath (Join-Path $runDir "android-force-stop-before.txt")
Capture-AndroidSnapshot -Phase "after-force-stop"

$driveArgs = @(
    "drive",
    "--driver=$Driver",
    "--target=$Target",
    "-d",
    $DeviceId,
    "--no-dds"
)
if ($Mode -eq "profile") {
    $driveArgs += "--profile"
}
elseif ($Mode -eq "release") {
    $driveArgs += "--release"
}
if ($FlutterDriveExtraArgs) {
    $driveArgs += ($FlutterDriveExtraArgs -split "\s+" | Where-Object { $_ })
}

$driveLog = Join-Path $runDir "flutter-drive.log"
$job = Start-Job -ArgumentList $mobileDir, $runDir, $driveArgs, $driveLog -ScriptBlock {
    param($MobileDir, $RunDir, $DriveArgs, $DriveLog)
    $env:FLUTTER_TEST_OUTPUTS_DIR = $RunDir
    Set-Location $MobileDir
    & flutter @DriveArgs > $DriveLog 2>&1
    exit $LASTEXITCODE
}

$sampleIndex = 0
while ($job.State -eq "Running") {
    $sampleIndex++
    Capture-AndroidSnapshot -Phase ("during-{0:D2}" -f $sampleIndex)
    Start-Sleep -Seconds $SampleIntervalSeconds
}

Receive-Job -Job $job -Wait | Out-Null
$driveExit = if ($job.ChildJobs.Count -gt 0) { $job.ChildJobs[0].JobStateInfo.Reason } else { $null }
$exitCode = 0
if ($job.State -ne "Completed") {
    $exitCode = 1
}
elseif (Select-String -LiteralPath $driveLog -Pattern "All tests passed" -Quiet) {
    $exitCode = 0
}
else {
    $exitCode = 1
}
Remove-Job -Job $job -Force

Capture-AndroidSnapshot -Phase "after"

$responseData = Join-Path $mobileDir "build\integration_response_data.json"
if (Test-Path -LiteralPath $responseData) {
    Copy-Item -LiteralPath $responseData -Destination (Join-Path $runDir "integration_response_data.json") -Force
}

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    $python = Get-Command python3 -ErrorAction SilentlyContinue
}
if ($python) {
    & $python.Source (Join-Path $root "scripts\qa\template-feed-metrics-summary.py") $runDir
    & $python.Source (Join-Path $root "scripts\qa\template-feed-memory-plateau-summary.py") $runDir
    if (Test-Path -LiteralPath $driveLog) {
        & $python.Source `
            (Join-Path $root "scripts\qa\template-feed-video-log-summary.py") `
            $driveLog `
            (Join-Path $runDir "video-playback-log-summary.json") `
            (Join-Path $runDir "video-playback-log-summary.md")
    }
}

$completion = [ordered]@{
    exit_code = $exitCode
    completion_marker = $(if (Select-String -LiteralPath $driveLog -Pattern "All tests passed" -Quiet) { "all_tests_passed_log" } else { "not_found" })
    integration_response_data = (Test-Path -LiteralPath (Join-Path $runDir "integration_response_data.json"))
}
$completion | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runDir "completion-summary.json")

Write-Host "Template feed QA artifacts written to $runDir"
exit $exitCode
