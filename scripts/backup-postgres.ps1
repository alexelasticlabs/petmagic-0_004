param(
    [string]$OutputDir = "backups"
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupPath = Join-Path $root $OutputDir
$filePath = Join-Path $backupPath "petmagic_db_$timestamp.sql"

$hasDocker = $null -ne (Get-Command docker -ErrorAction SilentlyContinue)
$hasLegacyDockerCompose = $null -ne (Get-Command docker-compose -ErrorAction SilentlyContinue)
if (-not $hasDocker -and -not $hasLegacyDockerCompose) {
    throw "Docker Compose is not available. Install Docker Desktop or ensure docker compose is on PATH."
}

function Invoke-Compose {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$ComposeArgs
    )

    if ($hasDocker) {
        & docker compose @ComposeArgs
        return
    }

    & docker-compose @ComposeArgs
}

New-Item -ItemType Directory -Force -Path $backupPath | Out-Null

Invoke-Compose exec -T postgres pg_dump -U petmagic_user -d petmagic_db --no-owner --no-privileges |
Out-File -FilePath $filePath -Encoding utf8

Write-Host "Backup saved to $filePath"
