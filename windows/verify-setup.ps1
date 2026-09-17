<#
.SYNOPSIS
    Post-setup assertions for an installed Windows setup.

.DESCRIPTION
    Windows counterpart of the Linux verify role (not the test suite in
    tests\verify.ps1). Checks the real machine and exits 1 on any failure:

      FAIL  an automated app from apps.json is not installed
      FAIL  ES-DE custom_systems files are missing, invalid, or the find rules
            don't point at every installed emulator
      FAIL  RetroArch is installed but cores referenced by ES-DE are missing
      FAIL  an installed app has no Start Menu shortcut
      WARN  a manual-download app (Dolphin, Model 2 Emulator) is missing
      WARN  BiosRoot doesn't exist, or shadPS4 has no firmware modules

.EXAMPLE
    ./verify-setup.ps1
#>
[CmdletBinding()]
param([string]$ConfigPath, [string]$ShortcutsDir)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'lib\common.ps1')

$config = Get-DgConfig -ConfigPath $ConfigPath -ScriptRoot $scriptRoot
$apps = @(Get-DgApps -ScriptRoot $scriptRoot)
$esdeData = Import-PowerShellDataFile -Path (Join-Path $scriptRoot 'config\esde-systems.psd1')
if (-not $ShortcutsDir) {
    $folder = if ($config.ContainsKey('StartMenuFolder')) { $config.StartMenuFolder } else { 'distrobox-gaming' }
    $ShortcutsDir = Join-Path ([Environment]::GetFolderPath('Programs')) $folder
}

$script:fails = 0; $script:warns = 0
function Pass { param($Msg) Write-Host "[ok]   $Msg" -ForegroundColor Green }
function Warn { param($Msg) Write-Host "[warn] $Msg" -ForegroundColor Yellow; $script:warns++ }
function Fail { param($Msg) Write-Host "[FAIL] $Msg" -ForegroundColor Red; $script:fails++ }

Write-Host "`n== Apps ==" -ForegroundColor Cyan
$installed = @{}
foreach ($app in $apps) {
    $exe = Resolve-AppRealExePath -App $app -EmulatorsRoot $config.EmulatorsRoot
    if ($exe) { $installed[$app.id] = $exe; Pass "$($app.name): $exe" }
    elseif ($app.group) { continue }
    elseif ($app.source -eq 'manual') { Warn "$($app.name) not installed (manual download, see INSTALL.md)" }
    else { Fail "$($app.name) not installed -- run ./install-apps.ps1 -Only $($app.id)" }
}

Write-Host "`n== ES-DE ($($config.EsdeHome)) ==" -ForegroundColor Cyan
$rulesPath = Join-Path $config.EsdeHome 'custom_systems\es_find_rules.xml'
$systemsPath = Join-Path $config.EsdeHome 'custom_systems\es_systems.xml'
$rules = $null
foreach ($p in $rulesPath, $systemsPath) {
    if (-not [IO.File]::Exists($p)) { Fail "$p missing -- run ./bootstrap.ps1 -Action Configure"; continue }
    try {
        $xml = [xml][IO.File]::ReadAllText($p)
        if ($p -eq $rulesPath) { $rules = $xml }
        Pass "$([IO.Path]::GetFileName($p)) is valid XML"
    } catch { Fail "$p is not valid XML: $($_.Exception.Message)" }
}
if ($rules) {
    foreach ($app in $apps | Where-Object { $installed.ContainsKey($_.id) }) {
        foreach ($name in $app.emulatorNames) {
            $entry = @($rules.ruleList.emulator | Where-Object { $_.name -eq $name })[0]
            if (-not $entry) { Fail "find rule for $name ($($app.name)) missing -- rerun ./bootstrap.ps1 -Action Configure" }
            elseif ($entry.rule.entry -ne $installed[$app.id]) { Fail "find rule for $name points at $($entry.rule.entry), but $($app.name) is at $($installed[$app.id]) -- rerun ./bootstrap.ps1" }
        }
    }
    Pass 'find rules checked against every installed emulator'
}

if ($installed.ContainsKey('retroarch')) {
    Write-Host "`n== RetroArch cores ==" -ForegroundColor Cyan
    $coresDir = Join-Path (Split-Path -Parent $installed.retroarch) 'cores'
    $needed = foreach ($s in $esdeData.Systems) { foreach ($c in $s.Commands) { foreach ($m in [regex]::Matches($c.Cmd, '([A-Za-z0-9_]+)_libretro\.dll')) { $m.Groups[1].Value } } }
    $missing = @($needed | Sort-Object -Unique | Where-Object { -not [IO.File]::Exists((Join-Path $coresDir "$($_)_libretro.dll")) })
    if ($missing) { Fail "missing cores: $($missing -join ', ') -- run ./install-cores.ps1" }
    else { Pass "all cores used by ES-DE systems are in $coresDir" }
}

Write-Host "`n== Start Menu ($ShortcutsDir) ==" -ForegroundColor Cyan
$noShortcut = @($apps | Where-Object { $_.shortcut -ne $false -and $installed.ContainsKey($_.id) -and -not [IO.File]::Exists((Join-Path $ShortcutsDir "$($_.name).lnk")) })
if ($noShortcut) { Fail "no shortcut for: $($noShortcut.name -join ', ') -- run ./install-shortcuts.ps1 -Action Configure" }
else { Pass 'every installed app has a shortcut' }

Write-Host "`n== BIOS ==" -ForegroundColor Cyan
if (-not [IO.Directory]::Exists($config.BiosRoot)) { Warn "BiosRoot $($config.BiosRoot) does not exist -- systems that need BIOS won't boot" }
else { Pass "BiosRoot exists: $($config.BiosRoot)" }
if ($installed.ContainsKey('shadps4')) {
    $modules = Join-Path $env:APPDATA 'shadPS4\sys_modules'
    $count = if ([IO.Directory]::Exists($modules)) { @([IO.Directory]::GetFiles($modules)).Count } else { 0 }
    if ($count -eq 0) { Warn "shadPS4 has no firmware modules in $modules -- put them in BiosRoot\ps4\sys_modules and run ./configure-emulators.ps1" }
    else { Pass "shadPS4 firmware modules: $count" }
}

Write-Host ''
if ($script:fails) {
    Write-Host "$($script:fails) failure(s), $($script:warns) warning(s)." -ForegroundColor Red
    exit 1
}
Write-Host "Setup verified with $($script:warns) warning(s)." -ForegroundColor Green
