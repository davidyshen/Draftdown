<#
.SYNOPSIS
    Builds Draftdown for Windows and packages it into an Inno Setup installer.
#>
[CmdletBinding()]
param(
    [ValidateSet("x64", "arm64")]
    [string]$Arch = "x64",
    [switch]$SkipPandocFetch,
    [switch]$SkipFlutterBuild
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Push-Location $repoRoot
try {
    # Extract version (without +build suffix) from pubspec.yaml
    $pubspec = Get-Content "pubspec.yaml" -Raw
    if ($pubspec -match '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
        $appVersion = $Matches[1]
    } else {
        $appVersion = "1.0.0"
    }

    # Fetch pandoc.exe if missing and not skipped
    $pandocDest = Join-Path $repoRoot "assets\bin\pandoc.exe"
    if (-not $SkipPandocFetch -and -not (Test-Path $pandocDest)) {
        Write-Host "Fetching latest Pandoc binary for bundling..."
        New-Item -ItemType Directory -Force -Path (Split-Path $pandocDest) | Out-Null
        $headers = @{ "Accept" = "application/vnd.github+json" }
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/jgm/pandoc/releases/latest" -Headers $headers
        $asset = $release.assets | Where-Object { $_.name -match "windows-x86_64\.zip$" } | Select-Object -First 1
        if (-not $asset) {
            throw "Could not find Windows Pandoc archive in latest release."
        }
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "draftdown_pandoc_$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
        try {
            $zipPath = Join-Path $tempDir "pandoc.zip"
            $extractDir = Join-Path $tempDir "extract"
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath
            Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
            $pandocExe = Get-ChildItem -Path $extractDir -Recurse -Filter "pandoc.exe" | Select-Object -First 1
            if (-not $pandocExe) {
                throw "pandoc.exe not found inside downloaded archive."
            }
            Copy-Item -Path $pandocExe.FullName -Destination $pandocDest -Force
        } finally {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not $SkipFlutterBuild) {
        Write-Host "Running flutter pub get..."
        flutter pub get
        if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed." }

        Write-Host "Building Windows release ($Arch, v$appVersion)..."
        flutter build windows --release --dart-define="APP_VERSION=$appVersion"
        if ($LASTEXITCODE -ne 0) { throw "flutter build windows --release failed." }
    }

    $releaseDir = Join-Path $repoRoot "build\windows\$Arch\runner\Release"
    if (-not (Test-Path (Join-Path $releaseDir "draftdown.exe"))) {
        throw "Release build not found at $releaseDir"
    }

    # Locate Inno Setup Compiler (ISCC.exe)
    $iscc = Get-Command iscc -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
    if (-not $iscc) {
        $candidates = @(
            "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
            "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
            "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
        )
        $iscc = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    }
    if (-not $iscc) {
        throw "Inno Setup 6 (ISCC.exe) not found. Install it via: winget install JRSoftware.InnoSetup"
    }

    Write-Host "Compiling Inno Setup installer (v$appVersion, $Arch)..."
    & $iscc "/DMyAppVersion=$appVersion" "/DMyAppArch=$Arch" (Join-Path $PSScriptRoot "draftdown.iss")
    if ($LASTEXITCODE -ne 0) { throw "ISCC failed with exit code $LASTEXITCODE." }

    $installerPath = Join-Path $repoRoot "build\installer\Draftdown-Setup-$Arch-$appVersion.exe"
    Write-Host "Installer created: $installerPath"
} finally {
    Pop-Location
}
