<#
.SYNOPSIS
    Installs (or lists/checks) the Windows-native distrobox-gaming app set via winget.

.DESCRIPTION
    Reads windows/apps.json and, for each entry under "apps", installs the winget
    package. Equivalent to macos/install-apps.sh driving the Brewfile, but for
    winget. Never touches the "future" list -- those are documented, not installed.

.PARAMETER List
    Print the app list (id, name, winget id) and exit. Installs nothing.

.PARAMETER Check
    Report which apps are already installed per `winget list --id`, without
    installing or changing anything.

.EXAMPLE
    ./install-apps.ps1
    ./install-apps.ps1 -List
    ./install-apps.ps1 -Check
#>
[CmdletBinding()]
param(
    [switch]$List,
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$appsJsonPath = Join-Path $scriptRoot 'apps.json'

if (-not (Test-Path $appsJsonPath)) {
    throw "apps.json not found at $appsJsonPath"
}

$manifest = Get-Content -Raw -Path $appsJsonPath | ConvertFrom-Json
$apps = $manifest.apps

if ($List) {
    $apps | ForEach-Object {
        [PSCustomObject]@{
            Id       = $_.id
            Name     = $_.name
            WingetId = $_.wingetId
            Role     = $_.role
        }
    } | Format-Table -AutoSize
    return
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget was not found on PATH. Install 'App Installer' from the Microsoft Store first."
}

function Test-WingetInstalled {
    param([string]$WingetId)
    $result = winget list --id $WingetId --exact --source winget 2>$null
    return ($LASTEXITCODE -eq 0) -and ($result -match [regex]::Escape($WingetId))
}

if ($Check) {
    $rows = $apps | ForEach-Object {
        [PSCustomObject]@{
            Id        = $_.id
            Name      = $_.name
            WingetId  = $_.wingetId
            Installed = Test-WingetInstalled -WingetId $_.wingetId
        }
    }
    $rows | Format-Table -AutoSize
    $missing = $rows | Where-Object { -not $_.Installed }
    if ($missing) {
        Write-Host "`nMissing: $($missing.Name -join ', ')" -ForegroundColor Yellow
    } else {
        Write-Host "`nAll apps in apps.json are installed." -ForegroundColor Green
    }
    return
}

Write-Host "Installing $($apps.Count) app(s) via winget..." -ForegroundColor Cyan
Write-Host "Several of these installers require Administrator elevation (a UAC prompt)." -ForegroundColor DarkGray
Write-Host "Run this script from a normal interactive PowerShell window so you can approve it.`n" -ForegroundColor DarkGray

# Known winget/installer failure signatures, and the actionable hint to print
# for each. winget's own error text varies by installer technology
# (Inno Setup vs NSIS vs MSI) but these substrings are stable across runs --
# confirmed against real failures on 2026-09-17 (ES-DE, PCSX2, PPSSPP,
# RetroArch all hit the elevation case; Dolphin hit the mirror case).
$knownFailures = @(
    @{
        Match = 'canceled by the user|You cancelled the installation|ERROR_INSTALL_USERCANCEL'
        Hint  = "requires Administrator elevation (UAC) that couldn't be approved in this session -- rerun this script from an interactive PowerShell window and accept the UAC prompt."
    },
    @{
        Match = 'Forbidden \(403\)|Download request status is not success'
        Hint  = "the upstream download mirror refused the request (HTTP 403). This is not a winget/script bug -- retry later, or download it manually from the project's own site."
    }
)

$failures = @()
foreach ($app in $apps) {
    if (Test-WingetInstalled -WingetId $app.wingetId) {
        Write-Host "[skip] $($app.name) ($($app.wingetId)) already installed" -ForegroundColor DarkGray
        continue
    }
    Write-Host "[install] $($app.name) ($($app.wingetId))" -ForegroundColor Cyan
    $output = & winget install --id $app.wingetId --exact --silent `
        --accept-package-agreements --accept-source-agreements --source winget 2>&1
    $output | ForEach-Object { Write-Host $_ }

    if ($LASTEXITCODE -ne 0) {
        $outputText = $output -join "`n"
        $hint = ($knownFailures | Where-Object { $outputText -match $_.Match } | Select-Object -First 1).Hint
        if ($hint) {
            Write-Host "[FAILED] $($app.name): $hint" -ForegroundColor Red
        } else {
            Write-Host "[FAILED] $($app.name) exited with code $LASTEXITCODE" -ForegroundColor Red
        }
        $failures += $app.name
    }
}

if ($failures) {
    Write-Host "`nFailed to install: $($failures -join ', ')" -ForegroundColor Red
    Write-Host "Rerun ./install-apps.ps1 after addressing the above -- already-installed apps are skipped." -ForegroundColor Yellow
    exit 1
}

Write-Host "`nDone. Next: run ./bootstrap.ps1 -Action Check, then -Action Configure." -ForegroundColor Green
