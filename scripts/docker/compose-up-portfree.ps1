param(
    [int]$PostgresHostPort = 5433,
    [int]$BackendHostPort = 5601,
    [int]$MailpitSmtpHostPort = 2525,
    [int]$MailpitWebHostPort = 9025,
    [int]$AdminWebHostPort = 4000,
    [string]$ProjectName = "petmagic-0_004",
    [string]$WaitTimeout = "240",
    [switch]$Build
)

$ErrorActionPreference = "Stop"

if (-not $env:POSTGRES_HOST_PORT) { $env:POSTGRES_HOST_PORT = $PostgresHostPort.ToString() }
if (-not $env:BACKEND_HOST_PORT) { $env:BACKEND_HOST_PORT = $BackendHostPort.ToString() }
if (-not $env:MAILPIT_SMTP_HOST_PORT) { $env:MAILPIT_SMTP_HOST_PORT = $MailpitSmtpHostPort.ToString() }
if (-not $env:MAILPIT_WEB_HOST_PORT) { $env:MAILPIT_WEB_HOST_PORT = $MailpitWebHostPort.ToString() }
if (-not $env:ADMIN_WEB_HOST_PORT) { $env:ADMIN_WEB_HOST_PORT = $AdminWebHostPort.ToString() }

$composeArgs = @("-p", $ProjectName, "up", "-d")
if ($Build) { $composeArgs += "--build" }
$composeArgs += @("--wait", "--wait-timeout", $WaitTimeout)

Write-Host "Starting docker compose with mapped ports:"
Write-Host "  COMPOSE_PROJECT_NAME=$ProjectName"
Write-Host "  POSTGRES_HOST_PORT=$($env:POSTGRES_HOST_PORT)"
Write-Host "  BACKEND_HOST_PORT=$($env:BACKEND_HOST_PORT)"
Write-Host "  MAILPIT_SMTP_HOST_PORT=$($env:MAILPIT_SMTP_HOST_PORT)"
Write-Host "  MAILPIT_WEB_HOST_PORT=$($env:MAILPIT_WEB_HOST_PORT)"
Write-Host "  ADMIN_WEB_HOST_PORT=$($env:ADMIN_WEB_HOST_PORT)"

& docker compose @composeArgs
