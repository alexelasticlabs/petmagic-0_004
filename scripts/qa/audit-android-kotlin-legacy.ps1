param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
    [string]$MobileAppRelativePath = "apps/petmagic-mobile"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$mobileAppPath = Join-Path $RepoRoot $MobileAppRelativePath
$lockPath = Join-Path $mobileAppPath "pubspec.lock"
$pubCacheRoot = Join-Path $env:LOCALAPPDATA "Pub\Cache\hosted\pub.dev"

if (-not (Test-Path $lockPath)) {
    throw "pubspec.lock not found: $lockPath"
}

function Add-PackageRecord {
    param(
        [System.Collections.Generic.List[object]]$Records,
        [hashtable]$Current
    )

    if ($null -ne $Current -and $Current.Count -gt 0) {
        $Records.Add([pscustomobject]$Current)
    }
}

$packages = [System.Collections.Generic.List[object]]::new()
$current = $null
$inPackages = $false

foreach ($line in Get-Content $lockPath) {
    if (-not $inPackages) {
        if ($line -eq "packages:") {
            $inPackages = $true
        }
        continue
    }

    if ($line -match '^  ([^:\s]+):$') {
        Add-PackageRecord -Records $packages -Current $current
        $current = [ordered]@{
            Name = $matches[1]
            Dependency = $null
            Source = $null
            Version = $null
            Path = $null
        }
        continue
    }

    if ($null -eq $current) {
        continue
    }

    if ($line -match '^    dependency: "?([^"]+)"?$') {
        $current.Dependency = $matches[1]
        continue
    }

    if ($line -match '^    source: ([^\s]+)$') {
        $current.Source = $matches[1]
        continue
    }

    if ($line -match '^    version: "?([^"]+)"?$') {
        $current.Version = $matches[1]
        continue
    }

    if ($line -match '^      path: "?([^"]+)"?$') {
        $current.Path = $matches[1]
        continue
    }
}

Add-PackageRecord -Records $packages -Current $current

$kgpPluginRegex = [regex]'(?m)^[ \t]*(apply[ \t]+plugin[ \t]*:[ \t]*["''](?:kotlin-android|org\.jetbrains\.kotlin\.android)["'']|(?:id|alias)(?:[ \t]*\(\s*|[ \t]+)["''](?:kotlin-android|org\.jetbrains\.kotlin\.android)["''])'
$kgpClasspathRegex = [regex]'kotlin-gradle-plugin'
$agpPluginRegex = [regex]'(?m)^[ \t]*(apply[ \t]+plugin[ \t]*:[ \t]*["'']com\.android\.(?:application|library)["'']|(?:id|alias)(?:[ \t]*\(\s*|[ \t]+)["'']com\.android\.(?:application|library)["''])'

$results = foreach ($package in $packages) {
    if ([string]::IsNullOrWhiteSpace($package.Dependency) -or $package.Dependency -match 'dev') {
        continue
    }

    $packageRoot = switch ($package.Source) {
        "hosted" {
            Join-Path $pubCacheRoot "$($package.Name)-$($package.Version)"
        }
        "path" {
            $relativePath = $package.Path -replace '/', '\'
            [System.IO.Path]::GetFullPath((Join-Path $mobileAppPath $relativePath))
        }
        default {
            $null
        }
    }

    if ([string]::IsNullOrWhiteSpace($packageRoot) -or -not (Test-Path $packageRoot)) {
        continue
    }

    $androidDir = Join-Path $packageRoot "android"
    if (-not (Test-Path $androidDir)) {
        continue
    }

    $gradleScript = @(
        Join-Path $androidDir "build.gradle.kts"
        Join-Path $androidDir "build.gradle"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($null -eq $gradleScript) {
        continue
    }

    $scriptText = Get-Content $gradleScript -Raw
    $hasAgpPlugin = $agpPluginRegex.IsMatch($scriptText)
    if (-not $hasAgpPlugin) {
        continue
    }

    $hasExplicitKgpPlugin = $kgpPluginRegex.IsMatch($scriptText)
    $hasKgpClasspath = $kgpClasspathRegex.IsMatch($scriptText)

    $status = if ($hasExplicitKgpPlugin) {
        "ExplicitKgpPlugin"
    }
    elseif ($hasKgpClasspath) {
        "LegacyKgpClasspath"
    }
    else {
        "ImplicitFlutterAutoApplyRisk"
    }

    $evidence = @()
    if ($hasExplicitKgpPlugin) {
        $evidence += "declares kotlin-android plugin"
    }
    if ($hasKgpClasspath) {
        $evidence += "declares kotlin-gradle-plugin classpath"
    }
    if (-not $hasExplicitKgpPlugin -and -not $hasKgpClasspath) {
        $evidence += "Android plugin without KGP declaration"
    }

    [pscustomobject]@{
        Package = $package.Name
        Dependency = $package.Dependency
        Source = $package.Source
        Version = $package.Version
        Status = $status
        Script = $gradleScript.Replace($RepoRoot, ".")
        Evidence = ($evidence -join "; ")
    }
}

$orderedResults =
    $results |
    Sort-Object @{ Expression = {
        switch ($_.Dependency) {
            "direct main" { 0 }
            default { 1 }
        }
    } }, @{ Expression = {
        switch ($_.Status) {
            "ExplicitKgpPlugin" { 0 }
            "LegacyKgpClasspath" { 1 }
            default { 2 }
        }
    } }, Package

if (-not $orderedResults) {
    Write-Host "No Android plugin Kotlin legacy blockers found in $lockPath"
    exit 0
}

$summary = $orderedResults | Group-Object Status | Sort-Object Name
Write-Host "Android Kotlin legacy audit for $lockPath"
Write-Host ""
foreach ($group in $summary) {
    Write-Host ("{0}: {1}" -f $group.Name, $group.Count)
}
Write-Host ""

$orderedResults | Format-Table -AutoSize
