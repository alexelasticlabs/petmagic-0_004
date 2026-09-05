# Pass all arguments unchanged to the cross-platform runner.
$ErrorActionPreference = 'Stop'
$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
$pythonPath = if ($env:PETMAGIC_QA_PYTHON) { $env:PETMAGIC_QA_PYTHON } elseif ($pythonCommand) { $pythonCommand.Source } else {
    Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
}
if (-not (Test-Path -LiteralPath $pythonPath)) {
    throw 'Python 3.10+ is required. Install Python or set PETMAGIC_QA_PYTHON to its executable.'
}
& $pythonPath (Join-Path $PSScriptRoot 'payments_push_qa.py') @args
exit $LASTEXITCODE
