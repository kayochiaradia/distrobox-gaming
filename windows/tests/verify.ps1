<#
.SYNOPSIS
    Integration test for windows/, in the spirit of macos/tests/verify.py.

.DESCRIPTION
    Runs the real scripts against temporary directories and fixture files --
    never against your actual ES-DE, emulator configs or install folders.
    Never calls winget and downloads nothing.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File windows/tests/verify.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$windowsRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$repoRoot = Split-Path -Parent $windowsRoot
. (Join-Path $windowsRoot 'lib\common.ps1')

$failures = @()
function Assert {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { Write-Host "[pass] $Message" -ForegroundColor Green }
    else { Write-Host "[FAIL] $Message" -ForegroundColor Red; $script:failures += $Message }
}

function New-TempDir {
    $p = Join-Path ([IO.Path]::GetTempPath()) ("dg-windows-test-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $p -Force | Out-Null
    return $p
}

# ---------------------------------------------------------------------------
# Data files
# ---------------------------------------------------------------------------

$apps = @(Get-DgApps -ScriptRoot $windowsRoot)
Assert ((@($apps.id | Sort-Object -Unique)).Count -eq $apps.Count) 'apps.json ids are unique'
foreach ($app in $apps) {
    $ok = $app.id -and $app.name -and $app.exeNames -and ($app.source -in 'winget', 'github', 'manual')
    if ($app.source -eq 'winget') { $ok = $ok -and $app.wingetId }
    if ($app.source -eq 'github') { $ok = $ok -and $app.repo -and $app.assetPattern -and $app.installDir }
    if ($app.source -eq 'manual') { $ok = $ok -and $app.installDir }
    Assert ([bool]$ok) "apps.json entry '$($app.id)' has the fields its source needs"
}

$systems = (Import-PowerShellDataFile -Path (Join-Path $windowsRoot 'config\esde-systems.psd1')).Systems
Assert ((@($systems.Name | Sort-Object -Unique)).Count -eq $systems.Count) 'esde-systems.psd1 system names are unique'
Assert (@($systems | Where-Object { -not $_.Commands }).Count -eq 0) 'every system has at least one command'

# Every console/arcade system the Linux tree defines must exist on Windows.
$linuxEsde = Get-Content (Join-Path $repoRoot 'ansible\group_vars\all\esde.yml')
$linuxSystems = @($linuxEsde | Select-String -Pattern '^\s{2}- name:\s*(\S+)' | ForEach-Object { $_.Matches[0].Groups[1].Value })
$missingFromWindows = @($linuxSystems | Where-Object { $_ -notin $systems.Name })
Assert ($linuxSystems.Count -gt 30) "parsed the Linux system list ($($linuxSystems.Count) systems)"
Assert ($missingFromWindows.Count -eq 0) "every Linux ES-DE system is defined on Windows$(if ($missingFromWindows) { " -- missing: $($missingFromWindows -join ', ')" })"

# Every %EMULATOR_X% used as a default (first) command maps to an app.
$knownEmulators = @($apps | ForEach-Object { $_.emulatorNames }) + @('OS-SHELL')
$unmapped = foreach ($s in $systems) {
    $m = [regex]::Match($s.Commands[0].Cmd, '%EMULATOR_([A-Z0-9-]+)%')
    if ($m.Success -and $m.Groups[1].Value -notin $knownEmulators) { "$($s.Name):$($m.Groups[1].Value)" }
}
Assert (@($unmapped).Count -eq 0) "every default emulator is provided by apps.json$(if ($unmapped) { " -- unmapped: $($unmapped -join ', ')" })"

$example = Import-ConfigDataFile -Path (Join-Path $windowsRoot 'config\localhost.example.psd1')
Assert ($example.EsdeHome -eq "$env:USERPROFILE\ES-DE") 'localhost.example.psd1 loads and expands %USERPROFILE%'
Assert ($example.EmulatorsRoot -like 'C:\*') 'default EmulatorsRoot is on C:'
$emuData = Import-ConfigDataFile -Path (Join-Path $windowsRoot 'config\emulators.psd1')
Assert ($emuData.DuckstationIniPath -eq "$env:LOCALAPPDATA\DuckStation\settings.ini") 'emulators.psd1 loads and expands %LOCALAPPDATA%'

$listOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $windowsRoot 'install-apps.ps1') -List 2>&1
Assert ($LASTEXITCODE -eq 0 -and ($listOutput -match 'rpcs3')) 'install-apps.ps1 -List runs and lists every source'

# ---------------------------------------------------------------------------
# bootstrap.ps1
# ---------------------------------------------------------------------------

$sb = New-TempDir
try {
    $esdeHome = Join-Path $sb 'ES-DE'
    $romRoot = Join-Path $sb 'ROMs'
    $emuRoot = Join-Path $sb 'Emulators'
    $oddPs2 = Join-Path $sb 'PS2 & Friends [USA]'
    # Fake a GitHub-style install with a nested top-level folder.
    $fakeFlycast = Join-Path $emuRoot 'flycast\flycast-win64-9.9\flycast.exe'
    New-Item -ItemType Directory -Path (Split-Path $fakeFlycast) -Force | Out-Null
    Set-Content -Path $fakeFlycast -Value 'fake'
    $cfg = Join-Path $sb 'localhost.psd1'
    Set-Content -Path $cfg -Encoding UTF8 -Value @"
@{
    EsdeHome = '$esdeHome'
    RomRoot = '$romRoot'
    EmulatorsRoot = '$emuRoot'
    RomPaths = @{ ps2 = '$oddPs2' }
}
"@
    $bootstrap = Join-Path $windowsRoot 'bootstrap.ps1'
    $findRules = Join-Path $esdeHome 'custom_systems\es_find_rules.xml'
    $esSystems = Join-Path $esdeHome 'custom_systems\es_systems.xml'

    & $bootstrap -Action Check -ConfigPath $cfg | Out-Null
    Assert (-not (Test-Path (Join-Path $esdeHome 'custom_systems'))) 'bootstrap -Action Check writes nothing'

    & $bootstrap -Action Configure -ConfigPath $cfg | Out-Null
    $rulesXml = [xml](Get-Content -Raw $findRules)
    $systemsXml = [xml](Get-Content -Raw $esSystems)
    Assert ($true) 'bootstrap writes well-formed es_find_rules.xml and es_systems.xml'
    $flyEntry = $rulesXml.ruleList.emulator | Where-Object { $_.name -eq 'FLYCAST' }
    Assert ($flyEntry.rule.entry -eq $fakeFlycast) 'find rules point FLYCAST at the exe found in a nested install folder'
    Assert (@($systemsXml.systemList.system).Count -eq $systems.Count) 'es_systems.xml contains every configured system'
    $ps2 = $systemsXml.systemList.system | Where-Object { $_.name -eq 'ps2' }
    Assert ($ps2.path -eq $oddPs2) 'RomPaths override is used and XML special characters round-trip'
    $snes = $systemsXml.systemList.system | Where-Object { $_.name -eq 'snes' }
    Assert ($snes.path -eq (Join-Path $romRoot 'snes')) 'systems default to RomRoot\<system>'
    Assert (@($snes.command)[0].label -eq 'bsnes (RetroArch)') 'default emulator order follows the data file'

    $before = @((Get-FileHash $findRules).Hash, (Get-FileHash $esSystems).Hash)
    & $bootstrap -Action Configure -ConfigPath $cfg | Out-Null
    $after = @((Get-FileHash $findRules).Hash, (Get-FileHash $esSystems).Hash)
    $baks = @(Get-ChildItem (Join-Path $esdeHome 'custom_systems') -Filter '*.bak.*')
    Assert (($before -join '') -eq ($after -join '') -and $baks.Count -eq 0) 're-running bootstrap is idempotent and creates no backups'

    Add-Content -Path $esSystems -Value '<!-- hand edit -->'
    & $bootstrap -Action Configure -ConfigPath $cfg | Out-Null
    Assert (@(Get-ChildItem (Join-Path $esdeHome 'custom_systems') -Filter 'es_systems.xml.bak.*').Count -eq 1) 'a changed generated file is backed up before being replaced'

    Assert (-not (Test-Path (Join-Path $romRoot 'snes'))) 'ROM folders are not created by default'
    & $bootstrap -Action Configure -ConfigPath $cfg -CreateRomDirs $true | Out-Null
    Assert ((Test-Path (Join-Path $romRoot 'snes')) -and [IO.Directory]::Exists($oddPs2)) 'CreateRomDirs creates default and overridden ROM folders, including names with [brackets]'
}
finally {
    Remove-Item -Path $sb -Recurse -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# install-cores.ps1 -Check (no network)
# ---------------------------------------------------------------------------

$cd = New-TempDir
try {
    Set-Content -Path (Join-Path $cd 'mesen_libretro.dll') -Value 'fake'
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $windowsRoot 'install-cores.ps1') -Check -CoresDir $cd 2>&1 | Out-String
    Assert ($LASTEXITCODE -eq 0 -and $out -match 'Missing:' -and $out -notmatch 'Missing:.*\bmesen\b') 'install-cores -Check reports missing cores and counts present ones'
    Assert (@(Get-ChildItem $cd).Count -eq 1) 'install-cores -Check writes nothing'
}
finally {
    Remove-Item -Path $cd -Recurse -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# configure-emulators.ps1 against fixture files
# ---------------------------------------------------------------------------

$configureScript = Join-Path $windowsRoot 'configure-emulators.ps1'
$fx = New-TempDir
$fxDuck = Join-Path $fx 'DuckStation\settings.ini'
$fxRetro = Join-Path $fx 'RetroArch-Win64\retroarch.cfg'
$fxPcsx2 = Join-Path $fx 'PCSX2\inis\PCSX2.ini'
$fxBios = Join-Path $fx 'BIOS'
New-Item -ItemType Directory -Path (Split-Path $fxDuck), (Split-Path $fxRetro), $fxBios -Force | Out-Null
Set-Content -Path $fxDuck -Value @('[Main]', 'ConfirmPowerOff = true', '', '[GPU]', 'ResolutionScale = 1', 'Keep = me') -Encoding UTF8
Set-Content -Path $fxRetro -Value @('menu_swap_ok_cancel_buttons = "false"', 'video_driver = "d3d11"') -Encoding UTF8
$fxConfig = Join-Path $fx 'localhost.psd1'
Set-Content -Path $fxConfig -Encoding UTF8 -Value @"
@{
    BiosRoot = '$fxBios'
    EmulatorsRoot = '$(Join-Path $fx 'Emulators')'
    PreferDiscreteGpu = `$false
    EmulatorConfigPaths = @{
        pcsx2 = '$fxPcsx2'
        duckstation = '$fxDuck'
        retroarch = '$fxRetro'
    }
}
"@

try {
    $duckHash = (Get-FileHash $fxDuck).Hash
    & $configureScript -Action Check -ConfigPath $fxConfig | Out-Null
    Assert ((Get-FileHash $fxDuck).Hash -eq $duckHash) 'configure-emulators -Action Check writes nothing'
    Assert (-not (Test-Path (Join-Path $fx 'RetroArch-Win64\config'))) 'Check does not create RetroArch core option files'

    & $configureScript -Action Configure -ConfigPath $fxConfig | Out-Null
    $duck = Get-Content $fxDuck
    Assert ($duck -contains 'ConfirmPowerOff = false') 'Configure updates an existing INI key in place'
    Assert ($duck -contains 'ResolutionScale = 8') 'Configure updates a key in a later section'
    Assert ($duck -contains 'Keep = me') 'Configure preserves unmanaged keys'
    Assert ($duck -contains "SearchDirectory = $fxBios") 'BIOS.SearchDirectory points at an existing BiosRoot'
    Assert (@($duck | Where-Object { $_ -eq '[Main]' }).Count -eq 1) 'Configure does not duplicate existing sections'
    Assert ((Get-Content $fxRetro) -contains 'menu_swap_ok_cancel_buttons = "true"') 'Configure updates retroarch.cfg'
    Assert ((Get-Content $fxRetro) -contains 'video_driver = "d3d11"') 'Configure leaves unmanaged retroarch.cfg keys alone'
    Assert (Test-Path (Join-Path $fx 'RetroArch-Win64\config\melonDS\melonDS.cfg')) 'Configure creates RetroArch core option files next to retroarch.cfg'
    Assert (-not (Test-Path $fxPcsx2)) 'Configure never creates a config file the emulator has not written yet (PCSX2)'
    Assert (@(Get-ChildItem (Split-Path $fxDuck) -Filter 'settings.ini.bak.*').Count -eq 1) 'Configure backs up a changed file once'

    $duckHash = (Get-FileHash $fxDuck).Hash
    $retroHash = (Get-FileHash $fxRetro).Hash
    Start-Sleep -Seconds 1
    & $configureScript -Action Configure -ConfigPath $fxConfig | Out-Null
    Assert (((Get-FileHash $fxDuck).Hash -eq $duckHash) -and ((Get-FileHash $fxRetro).Hash -eq $retroHash)) 'Re-running configure-emulators is idempotent'
    Assert (@(Get-ChildItem (Split-Path $fxDuck) -Filter 'settings.ini.bak.*').Count -eq 1) 'Idempotent re-run creates no new backup'
}
finally {
    Remove-Item -Path $fx -Recurse -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------

if ($failures.Count -gt 0) {
    Write-Host "`n$($failures.Count) check(s) failed." -ForegroundColor Red
    exit 1
}
Write-Host "`nAll checks passed." -ForegroundColor Green
