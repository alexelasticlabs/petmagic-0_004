[CmdletBinding()]
param(
    [string]$OutputDir = "backups/render",
    [string]$FilePrefix = "petmagic-render",
    [string]$PgDumpCommand = "pg_dump",
    [string]$PgRestoreCommand = "pg_restore"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($FilePrefix -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$') {
    throw 'FilePrefix must contain only letters, digits, dots, underscores, or hyphens.'
}

$databaseUrl = $env:RENDER_POSTGRES_DATABASE_URL
if ([string]::IsNullOrWhiteSpace($databaseUrl)) {
    throw 'RENDER_POSTGRES_DATABASE_URL must be supplied through the process environment.'
}
if ($databaseUrl.Contains("`r") -or $databaseUrl.Contains("`n")) {
    throw 'RENDER_POSTGRES_DATABASE_URL contains an invalid newline.'
}

[Uri]$databaseUri = $null
if (-not [Uri]::TryCreate($databaseUrl, [UriKind]::Absolute, [ref]$databaseUri) -or
    $databaseUri.Scheme -notin @('postgres', 'postgresql')) {
    throw 'RENDER_POSTGRES_DATABASE_URL must be an absolute postgres/postgresql URL.'
}
if ($databaseUri.IsLoopback -or $databaseUri.Host -notlike '*.render.com') {
    throw 'RENDER_POSTGRES_DATABASE_URL must target a non-loopback Render PostgreSQL hostname.'
}

$pgDump = Get-Command -Name $PgDumpCommand -ErrorAction Stop
$pgRestore = Get-Command -Name $PgRestoreCommand -ErrorAction Stop
$repoRoot = Split-Path -Parent $PSScriptRoot
$resolvedOutputDir = if ([IO.Path]::IsPathRooted($OutputDir)) {
    [IO.Path]::GetFullPath($OutputDir)
} else {
    [IO.Path]::GetFullPath((Join-Path $repoRoot $OutputDir))
}
New-Item -ItemType Directory -Force -Path $resolvedOutputDir | Out-Null

$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ')
$nonce = [Guid]::NewGuid().ToString('N').Substring(0, 8)
$baseName = "$FilePrefix-$timestamp-$nonce"
$finalBackupPath = Join-Path $resolvedOutputDir "$baseName.custom.dump"
$partialBackupPath = "$finalBackupPath.partial"
$finalListPath = Join-Path $resolvedOutputDir "$baseName.restore-list.txt"
$partialListPath = "$finalListPath.partial"
$finalManifestPath = Join-Path $resolvedOutputDir "$baseName.manifest.json"
$partialManifestPath = "$finalManifestPath.partial"

foreach ($path in @(
    $finalBackupPath,
    $partialBackupPath,
    $finalListPath,
    $partialListPath,
    $finalManifestPath,
    $partialManifestPath
)) {
    if (Test-Path -LiteralPath $path) {
        throw "Refusing to overwrite an existing backup artifact: $([IO.Path]::GetFileName($path))"
    }
}

$previousPgDatabaseExists = Test-Path Env:PGDATABASE
$previousPgDatabase = if ($previousPgDatabaseExists) { $env:PGDATABASE } else { $null }
$promotedSidecars = $false

try {
    # libpq accepts a connection URL via PGDATABASE. The URL never appears in command arguments,
    # filenames, stdout, the restore list, or the manifest.
    $env:PGDATABASE = $databaseUrl

    $dumpVersionOutput = @(& $pgDump.Source --version)
    $dumpVersionExitCode = $LASTEXITCODE
    if ($dumpVersionExitCode -ne 0) {
        throw 'pg_dump --version failed.'
    }
    $dumpVersion = $dumpVersionOutput | Select-Object -First 1
    $restoreVersionOutput = @(& $pgRestore.Source --version)
    $restoreVersionExitCode = $LASTEXITCODE
    if ($restoreVersionExitCode -ne 0) {
        throw 'pg_restore --version failed.'
    }
    $restoreVersion = $restoreVersionOutput | Select-Object -First 1

    & $pgDump.Source --format=custom --no-owner --no-privileges --file $partialBackupPath
    if ($LASTEXITCODE -ne 0) {
        throw "pg_dump failed with exit code $LASTEXITCODE."
    }
    if (-not (Test-Path -LiteralPath $partialBackupPath) -or
        (Get-Item -LiteralPath $partialBackupPath).Length -le 0) {
        throw 'pg_dump did not create a non-empty custom-format backup.'
    }

    & $pgRestore.Source --list --file $partialListPath $partialBackupPath
    if ($LASTEXITCODE -ne 0) {
        throw "pg_restore --list failed with exit code $LASTEXITCODE."
    }
    if (-not (Test-Path -LiteralPath $partialListPath)) {
        throw 'pg_restore --list did not create its verification artifact.'
    }
    $restoreListEntries = @(
        Get-Content -LiteralPath $partialListPath |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and -not $_.TrimStart().StartsWith(';') }
    )
    if ($restoreListEntries.Count -le 0) {
        throw 'pg_restore --list returned no restorable entries.'
    }

    $backupFile = Get-Item -LiteralPath $partialBackupPath
    $backupHash = Get-FileHash -LiteralPath $partialBackupPath -Algorithm SHA256
    $manifest = [ordered]@{
        schemaVersion = 1
        createdAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        backupFile = [IO.Path]::GetFileName($finalBackupPath)
        restoreListFile = [IO.Path]::GetFileName($finalListPath)
        format = 'PostgreSQL custom'
        sizeBytes = $backupFile.Length
        sha256 = $backupHash.Hash.ToLowerInvariant()
        pgRestoreListVerified = $true
        restoreListEntryCount = $restoreListEntries.Count
        tools = [ordered]@{
            pgDump = [string]$dumpVersion
            pgRestore = [string]$restoreVersion
        }
    }
    $manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $partialManifestPath -Encoding utf8

    # Sidecars are promoted first. The verified dump becomes visible under its final name last.
    Move-Item -LiteralPath $partialListPath -Destination $finalListPath
    Move-Item -LiteralPath $partialManifestPath -Destination $finalManifestPath
    $promotedSidecars = $true
    Move-Item -LiteralPath $partialBackupPath -Destination $finalBackupPath

    Write-Host "Verified custom-format backup: $finalBackupPath"
    Write-Host "SHA256 manifest: $finalManifestPath"
} catch {
    foreach ($path in @($partialBackupPath, $partialListPath, $partialManifestPath)) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        }
    }
    if ($promotedSidecars -and -not (Test-Path -LiteralPath $finalBackupPath)) {
        Remove-Item -LiteralPath $finalListPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $finalManifestPath -Force -ErrorAction SilentlyContinue
    }
    throw
} finally {
    if ($previousPgDatabaseExists) {
        $env:PGDATABASE = $previousPgDatabase
    } else {
        Remove-Item Env:PGDATABASE -ErrorAction SilentlyContinue
    }
    $databaseUrl = $null
    $databaseUri = $null
}
