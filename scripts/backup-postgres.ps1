param(
    [string]$OutputDir = "backups"
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupPath = Join-Path $root $OutputDir
$filePath = Join-Path $backupPath "petmagic_db_$timestamp.sql"

New-Item -ItemType Directory -Force -Path $backupPath | Out-Null

docker-compose exec -T postgres pg_dump -U petmagic_user -d petmagic_db --no-owner --no-privileges |
Out-File -FilePath $filePath -Encoding utf8

Write-Host "Backup saved to $filePath"
