<#
.SYNOPSIS
    Check or configure the native Windows distrobox-gaming baseline.

.DESCRIPTION
    Windows equivalent of macos/bootstrap.sh {check|configure}. Does NOT call
    winget and does NOT install anything -- run install-apps.ps1 first. This
    script only:

      1. Reports whether ES-DE's own find-rules can already locate each
         installed emulator (PATH, registry, or the Emulators\<dir>\ static
         path ES-DE already ships on Windows).
      2. In -Action Configure, creates a directory junction under
         "<EsdeHome>\Emulators\<dir>\" pointing at the real winget install
         location for any emulator ES-DE can't already see -- no PATH
         mutation, no registry writes, fully reversible (delete the junction).
      3. Reports (Check) or optionally creates (Configure, opt-in) the
         per-system ROM directories under RomRoot/RomPaths.

    ES-DE ships a complete Windows es_systems.xml out of the box, so unlike
    macos/ and the Linux distrobox tree, there is no XML to render here.

.PARAMETER Action
    'Check' (default) previews without writing anything. 'Configure' applies
    junctions and, if CreateRomDirs is set, creates missing ROM directories.

.PARAMETER ConfigPath
    Path to a localhost.psd1 override (see config/localhost.example.psd1).
    Defaults to config/localhost.psd1 next to this script if present.

.PARAMETER CreateRomDirs
    Overrides the CreateRomDirs value from the config file for this run.

.EXAMPLE
    ./bootstrap.ps1 -Action Check
    ./bootstrap.ps1 -Action Configure
#>
[CmdletBinding()]
param(
    [ValidateSet('Check', 'Configure')]
    [string]$Action = 'Check',

    [string]$ConfigPath,

    [Nullable[bool]]$CreateRomDirs = $null,

    [string]$EsdeHomeOverride,
    [string]$RomRootOverride
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# ---------------------------------------------------------------------------
# Load config
# ---------------------------------------------------------------------------

$defaultConfigPath = Join-Path $scriptRoot 'config\localhost.psd1'
if (-not $ConfigPath) { $ConfigPath = $defaultConfigPath }

$config = @{
    EsdeHome      = "$env:USERPROFILE\ES-DE"
    RomRoot       = "$env:USERPROFILE\ES-DE\ROMs"
    RomPaths      = @{}
    CreateRomDirs = $false
}

if (Test-Path $ConfigPath) {
    $userConfig = Import-PowerShellDataFile -Path $ConfigPath
    foreach ($key in $userConfig.Keys) { $config[$key] = $userConfig[$key] }
    Write-Verbose "Loaded overrides from $ConfigPath"
}

if ($EsdeHomeOverride) { $config.EsdeHome = $EsdeHomeOverride }
if ($RomRootOverride) { $config.RomRoot = $RomRootOverride }
if ($null -ne $CreateRomDirs) { $config.CreateRomDirs = $CreateRomDirs }

$esdeHome = $config.EsdeHome
$romRoot = $config.RomRoot

# ---------------------------------------------------------------------------
# Load apps.json
# ---------------------------------------------------------------------------

$appsJsonPath = Join-Path $scriptRoot 'apps.json'
$manifest = Get-Content -Raw -Path $appsJsonPath | ConvertFrom-Json
$apps = $manifest.apps

# ---------------------------------------------------------------------------
# Detection helpers
# ---------------------------------------------------------------------------

function Test-OnPath {
    param([string[]]$ExeNames)
    foreach ($exe in $ExeNames) {
        if (Get-Command $exe -ErrorAction SilentlyContinue) { return $true }
    }
    return $false
}

function Test-AppPathsRegistry {
    param([string[]]$ExeNames)
    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths'
    )
    foreach ($root in $roots) {
        foreach ($exe in $ExeNames) {
            $keyPath = Join-Path $root $exe
            if (Test-Path $keyPath) { return $true }
        }
    }
    return $false
}

function Test-UninstallKey {
    param($UninstallKey)
    if (-not $UninstallKey) { return $false }
    foreach ($hive in @('HKLM:', 'HKCU:')) {
        $keyPath = Join-Path $hive $UninstallKey.path
        if (-not (Test-Path $keyPath)) { continue }
        $installLoc = (Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue).($UninstallKey.valueName)
        if ($installLoc -and (Test-Path (Join-Path $installLoc $UninstallKey.exeName))) { return $true }
    }
    return $false
}

function Get-EsdeJunctionPath {
    param($App, [string]$EsdeHome)
    if (-not $App.esdeEmulatorDir) { return $null }
    return Join-Path (Join-Path $EsdeHome 'Emulators') $App.esdeEmulatorDir
}

function Test-EsdeJunctionResolves {
    param($App, [string]$EsdeHome)
    $junctionPath = Get-EsdeJunctionPath -App $App -EsdeHome $EsdeHome
    if (-not $junctionPath -or -not (Test-Path $junctionPath)) { return $false }
    foreach ($exe in $App.exeNames) {
        if (Get-ChildItem -Path $junctionPath -Filter $exe -ErrorAction SilentlyContinue) { return $true }
    }
    return $false
}

function Test-AppDetected {
    param($App, [string]$EsdeHome)
    if (Test-OnPath -ExeNames $App.exeNames) { return $true }
    if ($App.registryAppPaths -and (Test-AppPathsRegistry -ExeNames $App.registryAppPaths)) { return $true }
    if (Test-UninstallKey -UninstallKey $App.registryUninstallKey) { return $true }
    if (Test-EsdeJunctionResolves -App $App -EsdeHome $EsdeHome) { return $true }
    return $false
}

function Find-InstalledExe {
    param($App)
    $roots = @(
        $env:ProgramFiles,
        ${env:ProgramFiles(x86)},
        (Join-Path $env:LOCALAPPDATA 'Programs'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages')
    ) | Where-Object { $_ -and (Test-Path $_) }

    foreach ($root in $roots) {
        foreach ($exe in $App.exeNames) {
            $hit = Get-ChildItem -Path $root -Recurse -Depth 4 -Filter $exe -File -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($hit) { return $hit.Directory.FullName }
        }
    }
    return $null
}

# ---------------------------------------------------------------------------
# Emulator detection / junction wiring
# ---------------------------------------------------------------------------

Write-Host "`n== Emulator detection (ESDE home: $esdeHome) ==" -ForegroundColor Cyan

$emulatorRows = @()
foreach ($app in $apps) {
    $detected = Test-AppDetected -App $app -EsdeHome $esdeHome
    $row = [PSCustomObject]@{
        Name      = $app.name
        Detected  = $detected
        Action    = ''
    }

    if (-not $detected -and $app.esdeEmulatorDir) {
        if ($Action -eq 'Configure') {
            $foundDir = Find-InstalledExe -App $app
            if ($foundDir) {
                $junctionPath = Get-EsdeJunctionPath -App $app -EsdeHome $esdeHome
                $emulatorsDir = Split-Path -Parent $junctionPath
                if (-not (Test-Path $emulatorsDir)) {
                    New-Item -ItemType Directory -Path $emulatorsDir -Force | Out-Null
                }
                if (-not (Test-Path $junctionPath)) {
                    New-Item -ItemType Junction -Path $junctionPath -Target $foundDir | Out-Null
                    $row.Action = "linked -> $foundDir"
                } else {
                    $row.Action = 'junction already present'
                }
                $row.Detected = $true
            } else {
                $row.Action = 'not found under Program Files / WinGet packages -- install it or set the path manually'
            }
        } else {
            $row.Action = 'run -Action Configure to auto-link, or install it if missing'
        }
    }

    $emulatorRows += $row
}

$emulatorRows | Format-Table -AutoSize

# ---------------------------------------------------------------------------
# ROM directory layout
# ---------------------------------------------------------------------------

Write-Host "`n== ROM directories (root: $romRoot) ==" -ForegroundColor Cyan

$systemIds = $apps |
    ForEach-Object { $_.systems } |
    Where-Object { $_ -and ($_ -match '^[a-z0-9_-]+$') } |
    Select-Object -Unique

$romRows = @()
foreach ($sys in $systemIds) {
    $path = if ($config.RomPaths.ContainsKey($sys)) { $config.RomPaths[$sys] } else { Join-Path $romRoot $sys }
    $exists = Test-Path $path
    $created = $false

    if (-not $exists -and $Action -eq 'Configure' -and $config.CreateRomDirs) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        $exists = $true
        $created = $true
    }

    $romRows += [PSCustomObject]@{
        System  = $sys
        Path    = $path
        Exists  = $exists
        Created = $created
    }
}

$romRows | Sort-Object System | Format-Table -AutoSize

$missingRoms = $romRows | Where-Object { -not $_.Exists }
if ($missingRoms -and -not $config.CreateRomDirs) {
    Write-Host "Missing ROM directories are only reported, never created -- set CreateRomDirs: `$true in $ConfigPath to opt in." -ForegroundColor Yellow
}

if ($Action -eq 'Check') {
    Write-Host "`nCheck complete. Nothing was written. Run with -Action Configure to apply." -ForegroundColor Green
} else {
    Write-Host "`nConfigure complete." -ForegroundColor Green
}
