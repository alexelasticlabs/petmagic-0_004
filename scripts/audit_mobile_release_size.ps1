param(
  [string]$ProjectRoot = "apps/petmagic-mobile"
)

$ErrorActionPreference = 'Stop'

$root = Resolve-Path $ProjectRoot
Set-Location $root

function To-MB([long]$bytes) {
  return [math]::Round($bytes / 1MB, 2)
}

Write-Host "== PetMagic Mobile Release Size Audit =="
Write-Host "Project: $root"

$assetsDir = Join-Path $root 'assets'
if (Test-Path $assetsDir) {
  Write-Host "`n[1] Assets by extension"
  Get-ChildItem -Recurse -File $assetsDir |
    Group-Object Extension |
    ForEach-Object {
      [PSCustomObject]@{
        Extension = if ([string]::IsNullOrWhiteSpace($_.Name)) { '(none)' } else { $_.Name }
        Files = $_.Count
        TotalMB = To-MB (($_.Group | Measure-Object Length -Sum).Sum)
      }
    } |
    Sort-Object TotalMB -Descending |
    Format-Table -AutoSize

  Write-Host "`n[2] Top 20 largest asset files"
  Get-ChildItem -Recurse -File $assetsDir |
    Sort-Object Length -Descending |
    Select-Object -First 20 FullName, @{n='MB';e={To-MB $_.Length}} |
    Format-Table -AutoSize
}

Write-Host "`n[3] pubspec assets/fonts declarations"
$pubspec = Join-Path $root 'pubspec.yaml'
if (Test-Path $pubspec) {
  Select-String -Path $pubspec -Pattern '^[ ]{2}(assets|fonts):|^[ ]{4}- ' | ForEach-Object { $_.Line }
}

Write-Host "`n[4] Android release/ABI/AppBundle config"
$gradle = Join-Path $root 'android/app/build.gradle.kts'
if (Test-Path $gradle) {
  Select-String -Path $gradle -Pattern 'minifyEnabled|shrinkResources|abiFilters|splits|bundle|ndkVersion|signingConfig' |
    ForEach-Object { "{0}:{1}" -f $_.LineNumber, $_.Line.Trim() }
}

Write-Host "`n[5] Possible debug/test/mock/smoke files"
Get-ChildItem -Recurse -File $root |
  Where-Object {
    $_.FullName -match '(?i)(debug|mock|smoke|fixture|sample|test)' -and
    $_.FullName -notmatch '\\.dart_tool|\\build|\\.git|\\.idea|\\test\\'
  } |
  Select-Object FullName |
  Format-Table -AutoSize

Write-Host "`n[6] Direct dependencies vs imports (quick signal)"
$declared = @()
$inDependencies = $false
Get-Content $pubspec | ForEach-Object {
  if ($_ -match '^dependencies:') { $inDependencies = $true; return }
  if ($_ -match '^[^ ]') { $inDependencies = $false }
  if ($inDependencies -and $_ -match '^  ([a-zA-Z0-9_]+):') {
    $name = $matches[1]
    if ($name -ne 'flutter' -and $name -ne 'flutter_localizations') {
      $declared += $name
    }
  }
}

$declared = $declared | Sort-Object -Unique
$unused = @()
foreach ($dep in $declared) {
  $count = (rg -n "package:$dep/" lib test 2>$null | Measure-Object).Count
  if ($count -eq 0) {
    $unused += $dep
  }
}

if ($unused.Count -eq 0) {
  Write-Host 'No obvious unused direct dependencies by import scan.'
} else {
  Write-Host 'Potentially unused direct dependencies (validate before removal):'
  $unused | ForEach-Object { "- $_" }
}

Write-Host "`n[7] Release build blockers (R8 missing classes)"
$missingRules = Join-Path $root 'build/app/outputs/mapping/release/missing_rules.txt'
if (Test-Path $missingRules) {
  Get-Content $missingRules
} else {
  Write-Host 'No missing_rules.txt found.'
}

Write-Host "`n[8] Existing release artifacts"
$artifactDirs = @(
  'build/app/outputs/flutter-apk',
  'build/app/outputs/bundle/release'
)
foreach ($dir in $artifactDirs) {
  $full = Join-Path $root $dir
  if (Test-Path $full) {
    Write-Host "Artifacts in $dir"
    Get-ChildItem -File $full |
      Select-Object Name, @{n='MB';e={To-MB $_.Length}} |
      Format-Table -AutoSize
  }
}

Write-Host "`n[9] Native libs (release intermediates, if present)"
$nativeDir = Join-Path $root 'build/app/intermediates/stripped_native_libs/release/stripReleaseDebugSymbols/out/lib'
if (Test-Path $nativeDir) {
  Get-ChildItem -Directory $nativeDir | ForEach-Object {
    $abi = $_.Name
    $sum = (Get-ChildItem -File $_.FullName | Measure-Object Length -Sum).Sum
    "${abi}: $(To-MB $sum) MB"
    Get-ChildItem -File $_.FullName |
      Sort-Object Length -Descending |
      Select-Object Name, @{n='MB';e={To-MB $_.Length}} |
      Format-Table -AutoSize
  }
} else {
  Write-Host 'No stripped release native libs found. Build release first.'
}

Write-Host "`nDone."
