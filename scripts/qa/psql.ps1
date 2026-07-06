$ErrorActionPreference = "Stop"
$Arguments = $args

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\..")
$service = if ($env:WATERMARK_QA_POSTGRES_SERVICE) { $env:WATERMARK_QA_POSTGRES_SERVICE } else { "postgres" }
$container = $env:WATERMARK_QA_POSTGRES_CONTAINER
$dbUser = if ($env:WATERMARK_QA_POSTGRES_USER) { $env:WATERMARK_QA_POSTGRES_USER } else { "petmagic_user" }
$dbName = if ($env:WATERMARK_QA_POSTGRES_DB) { $env:WATERMARK_QA_POSTGRES_DB } else { "petmagic_db" }

$remaining = [System.Collections.Generic.List[string]]::new()
foreach ($argument in $Arguments) {
    $remaining.Add($argument)
}

if ($remaining.Count -gt 0 -and ($remaining[0] -match '^postgres(ql)?://')) {
    $remaining.RemoveAt(0)
}

$file = $null
$forwarded = [System.Collections.Generic.List[string]]::new()
$index = 0
while ($index -lt $remaining.Count) {
    $argument = $remaining[$index]
    if ($argument -eq "-f" -and ($index + 1) -lt $remaining.Count) {
        $file = $remaining[$index + 1]
        $index += 2
        continue
    }

    $forwarded.Add($argument)
    $index += 1
}

$psqlArgs = @("psql", "-U", $dbUser, "-d", $dbName) + $forwarded.ToArray()
if ($container) {
    $dockerArgs = @("exec", "-i", $container) + $psqlArgs
} else {
    $dockerArgs = @("compose", "-f", (Join-Path $repoRoot "docker-compose.yml"), "exec", "-T", $service) + $psqlArgs
}

if ($file) {
    Get-Content -Raw -LiteralPath $file | & docker @dockerArgs
} else {
    & docker @dockerArgs
}

exit $LASTEXITCODE
