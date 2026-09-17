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
    $ok = $app.id -and $app.name -and $app.exeNames -and ($app.source -in 'winget', 'github', 'gitlab', 'url', 'manual')
    if ($app.source -eq 'winget') { $ok = $ok -and $app.wingetId }
    if ($app.source -eq 'github') { $ok = $ok -and $app.repo -and $app.assetPattern -and $app.installDir }
    if ($app.source -eq 'gitlab') { $ok = $ok -and $app.project -and $app.assetPattern -and $app.installDir }
    if ($app.source -eq 'url') { $ok = $ok -and $app.versionIndexUrl -and $app.versionRegex -and $app.urlTemplate -and $app.installDir }
    Assert (-not $app.uac) "apps.json entry '$($app.id)' installs without Administrator rights"
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
$duckEntry = $emuData.ConfigFiles | Where-Object { $_.Id -eq 'duckstation' }
Assert ($duckEntry.Path -eq "$env:LOCALAPPDATA\DuckStation\settings.ini") 'emulators.psd1 loads and expands %LOCALAPPDATA%'
Assert (@($emuData.ConfigFiles | Where-Object { $_.App -notin $apps.id }).Count -eq 0) 'every emulators.psd1 config file belongs to an app in apps.json'
Assert (@($emuData.BiosFiles | Where-Object { $_.App -notin $apps.id }).Count -eq 0) 'every BIOS entry belongs to an app in apps.json'

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

    # PS4 game with a real-format PARAM.SFO (TITLE + TITLE_ID, utf8 strings).
    $cusa = Join-Path $romRoot 'ps4\CUSA99999'
    New-Item -ItemType Directory -Path (Join-Path $cusa 'sce_sys') -Force | Out-Null
    Set-Content -Path (Join-Path $cusa 'eboot.bin') -Value 'fake'
    $keys = [Text.Encoding]::ASCII.GetBytes("TITLE`0TITLE_ID`0")
    $v1 = [Text.Encoding]::UTF8.GetBytes("Test Game & Co`0"); $v2 = [Text.Encoding]::ASCII.GetBytes("CUSA99999`0")
    $keyTable = 20 + 2 * 16; $dataTable = $keyTable + $keys.Length
    $sfo = New-Object IO.MemoryStream; $w = New-Object IO.BinaryWriter($sfo)
    $w.Write([byte[]](0, 0x50, 0x53, 0x46)); $w.Write([uint32]0x101); $w.Write([uint32]$keyTable); $w.Write([uint32]$dataTable); $w.Write([uint32]2)
    $w.Write([uint16]0); $w.Write([uint16]0x0204); $w.Write([uint32]$v1.Length); $w.Write([uint32]$v1.Length); $w.Write([uint32]0)
    $w.Write([uint16]6); $w.Write([uint16]0x0204); $w.Write([uint32]$v2.Length); $w.Write([uint32]$v2.Length); $w.Write([uint32]$v1.Length)
    $w.Write($keys); $w.Write($v1); $w.Write($v2); $w.Flush()
    [IO.File]::WriteAllBytes((Join-Path $cusa 'sce_sys\param.sfo'), $sfo.ToArray())

    # Skraper arcade gamelist with a parent and a clone scraped to one name.
    New-Item -ItemType Directory -Path (Join-Path $romRoot 'model2') -Force | Out-Null
    Set-Content -Path (Join-Path $romRoot 'model2\gamelist.xml') -Encoding UTF8 -Value @(
        '<gameList>',
        '<game><path>./daytonam.zip</path><name>Daytona USA</name></game>',
        '<game><path>./daytona.zip</path><name>Daytona USA</name><desc>Race</desc></game>',
        '<game><path>./srallyc.zip</path><name>Sega Rally</name></game>',
        '</gameList>')

    # Skraper-flat scraped cover.
    New-Item -ItemType Directory -Path (Join-Path $romRoot 'nes\images') -Force | Out-Null
    Set-Content -Path (Join-Path $romRoot 'nes\images\Mario-image.png') -Value 'png'

    New-Item -ItemType Directory -Path (Join-Path $esdeHome 'settings') -Force | Out-Null
    Set-Content -Path (Join-Path $esdeHome 'settings\es_settings.xml') -Encoding UTF8 -Value @(
        '<?xml version="1.0"?>', '<bool name="ParseGamelistOnly" value="true" />', '<string name="ROMDirectory" value="C:\old" />')
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

    [xml]$ps4List = Get-Content -Raw (Join-Path $esdeHome 'gamelists\ps4\gamelist.xml')
    Assert ($ps4List.gameList.game.name -eq 'Test Game & Co' -and $ps4List.gameList.game.path -eq './CUSA99999/eboot.bin') 'PS4 gamelist takes the title from PARAM.SFO'
    [xml]$arcade = Get-Content -Raw (Join-Path $esdeHome 'gamelists\model2\gamelist.xml')
    $hidden = @($arcade.gameList.game | Where-Object { $_.hidden -eq 'true' } | ForEach-Object { $_.path })
    Assert (($hidden -join ',') -eq './daytonam.zip') 'arcade gamelist hides the clone and keeps the parent visible'
    $cover = Join-Path $esdeHome 'downloaded_media\nes\covers\Mario.png'
    Assert ((Test-Path $cover) -and (Get-Content $cover) -eq 'png') 'Skraper-flat art is linked into downloaded_media'
    $settingsText = Get-Content -Raw (Join-Path $esdeHome 'settings\es_settings.xml')
    Assert ($settingsText -match [regex]::Escape("<string name=""ROMDirectory"" value=""$romRoot"" />") -and $settingsText -match 'ParseGamelistOnly" value="false"') 'ES-DE ROMDirectory and ParseGamelistOnly are set'
    $gamelistBaks = @(Get-ChildItem (Join-Path $esdeHome 'gamelists') -Recurse -Filter '*.bak.*')
    Assert ($gamelistBaks.Count -eq 0) 're-running bootstrap does not rewrite unchanged gamelists'

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
    New-Item -ItemType Directory -Path (Join-Path $cd 'cores'), (Join-Path $cd 'overlays') -Force | Out-Null
    Set-Content -Path (Join-Path $cd 'cores\mesen_libretro.dll') -Value 'fake'
    Set-Content -Path (Join-Path $cd 'overlays\.dg-installed') -Value 'fake'
    $before = @(Get-ChildItem $cd -Recurse -Force).Count
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $windowsRoot 'install-cores.ps1') -Check -RetroArchDir $cd 2>&1 | Out-String
    Assert ($LASTEXITCODE -eq 0 -and $out -match 'Missing cores:' -and $out -notmatch 'Missing cores:.*\bmesen\b') 'install-cores -Check reports missing cores and counts present ones'
    Assert ($out -match 'Missing asset packs:' -and $out -notmatch 'Missing asset packs:.*overlays\.zip') 'install-cores -Check honours asset pack stamps'
    Assert (@(Get-ChildItem $cd -Recurse -Force).Count -eq $before) 'install-cores -Check writes nothing'
}
finally {
    Remove-Item -Path $cd -Recurse -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# install-shortcuts.ps1
# ---------------------------------------------------------------------------

$sc = New-TempDir
try {
    $scEmu = Join-Path $sc 'Emulators'
    $scDir = Join-Path $sc 'StartMenu'
    New-Item -ItemType Directory -Path (Join-Path $scEmu 'flycast'), $scDir -Force | Out-Null
    Set-Content -Path (Join-Path $scEmu 'flycast\flycast.exe') -Value 'fake'
    $scCfg = Join-Path $sc 'localhost.psd1'
    Set-Content -Path $scCfg -Encoding UTF8 -Value "@{ EmulatorsRoot = '$scEmu' }"
    $shortcuts = Join-Path $windowsRoot 'install-shortcuts.ps1'
    Set-Content -Path (Join-Path $scDir 'Gone Emulator.lnk') -Value 'stale'

    & $shortcuts -Action Check -ConfigPath $scCfg -ShortcutsDir $scDir | Out-Null
    Assert ((@(Get-ChildItem $scDir).Count -eq 1) -and (Test-Path (Join-Path $scDir 'Gone Emulator.lnk'))) 'install-shortcuts -Action Check writes nothing'

    & $shortcuts -Action Configure -ConfigPath $scCfg -ShortcutsDir $scDir | Out-Null
    $lnkPath = Join-Path $scDir 'Flycast.lnk'
    $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut($lnkPath)
    Assert ((Test-Path $lnkPath) -and $lnk.TargetPath -eq (Join-Path $scEmu 'flycast\flycast.exe') -and $lnk.WorkingDirectory -eq (Join-Path $scEmu 'flycast')) 'shortcut targets the emulator and starts in its folder'
    Assert (-not (Test-Path (Join-Path $scDir 'Gone Emulator.lnk'))) 'shortcuts for apps no longer installed are removed'

    $h = (Get-FileHash $lnkPath).Hash
    & $shortcuts -Action Configure -ConfigPath $scCfg -ShortcutsDir $scDir | Out-Null
    Assert ((Get-FileHash $lnkPath).Hash -eq $h) 're-running install-shortcuts leaves shortcuts unchanged'
}
finally {
    Remove-Item -Path $sc -Recurse -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# configure-emulators.ps1 against fixture files
# ---------------------------------------------------------------------------

$configureScript = Join-Path $windowsRoot 'configure-emulators.ps1'

# Real config files the script would touch outside the fixture -- they must
# not change during the test.
$realConfigs = @(
    "$env:APPDATA\xemu\xemu\xemu.toml", "$env:APPDATA\Cemu\settings.xml",
    "$env:LOCALAPPDATA\DuckStation\settings.ini", "$env:USERPROFILE\Documents\PCSX2\inis\PCSX2.ini"
) | Where-Object { Test-Path $_ }
$realHashes = @{}
foreach ($r in $realConfigs) { $realHashes[$r] = (Get-FileHash $r).Hash }

$fx = New-TempDir
$fxEmu = Join-Path $fx 'Emulators'
$fxBios = Join-Path $fx 'BIOS'
$fxRoms = Join-Path $fx 'ROMs'
$fxDuck = Join-Path $fx 'DuckStation\settings.ini'
$fxRetro = Join-Path $fx 'RetroArch-Win64\retroarch.cfg'
$fxPcsx2 = Join-Path $fx 'PCSX2\inis\PCSX2.ini'
$fxCemu = Join-Path $fx 'Cemu\settings.xml'
$fxXemu = Join-Path $fx 'xemu\xemu.toml'
$fxFlycastExe = Join-Path $fxEmu 'flycast\flycast.exe'
$fxSuperExe = Join-Path $fxEmu 'Supermodel\supermodel-test\supermodel.exe'
$fxSuperIni = Join-Path $fxEmu 'Supermodel\supermodel-test\Config\Supermodel.ini'
$fxMelonExe = Join-Path $fxEmu 'melonDS\melonDS.exe'

foreach ($f in $fxDuck, $fxRetro, $fxCemu, $fxXemu, $fxFlycastExe, $fxSuperIni, $fxMelonExe, (Join-Path $fxBios 'dc\naomi.zip')) {
    New-Item -ItemType Directory -Path (Split-Path $f) -Force | Out-Null
}
Set-Content -Path $fxDuck -Value @('[Main]', 'ConfirmPowerOff = true', '', '[GPU]', 'ResolutionScale = 1', 'Keep = me') -Encoding UTF8
Set-Content -Path $fxRetro -Value @('menu_swap_ok_cancel_buttons = "false"', 'video_driver = "d3d11"') -Encoding UTF8
Set-Content -Path $fxCemu -Encoding UTF8 -Value @('<?xml version="1.0" encoding="UTF-8"?>', '<content>', '    <fullscreen>false</fullscreen>', '    <Graphic>', '        <VSync>0</VSync>', '    </Graphic>', '    <GamePaths>', '        <Entry>C:/Games</Entry>', '    </GamePaths>', '</content>')
Set-Content -Path $fxXemu -Value @('[sys.files]', "eeprom_path = 'C:\x\eeprom.bin'") -Encoding UTF8
foreach ($exe in $fxFlycastExe, $fxSuperExe, $fxMelonExe) { Set-Content -Path $exe -Value 'fake' }
Set-Content -Path (Join-Path $fxEmu 'flycast\emu.cfg') -Value @('[window]', 'width = 640') -Encoding UTF8
Set-Content -Path $fxSuperIni -Value @('[ Global ]', 'New3DEngine = true', 'WideScreen = false') -Encoding UTF8
Set-Content -Path (Join-Path $fxEmu 'melonDS\melonDS.toml') -Value @('[3D]', 'Renderer = 0') -Encoding UTF8
Set-Content -Path (Join-Path $fxBios 'dc\naomi.zip') -Value 'naomi-v1'
Set-Content -Path (Join-Path $fxBios 'bios7.bin') -Value 'bios7-v1'
Set-Content -Path (Join-Path $fxBios 'mcpx_1.0.bin') -Value 'mcpx'

$fxConfig = Join-Path $fx 'localhost.psd1'
Set-Content -Path $fxConfig -Encoding UTF8 -Value @"
@{
    BiosRoot = '$fxBios'
    RomRoot = '$fxRoms'
    EmulatorsRoot = '$fxEmu'
    PreferDiscreteGpu = `$false
    EmulatorConfigPaths = @{
        pcsx2 = '$fxPcsx2'
        duckstation = '$fxDuck'
        retroarch = '$fxRetro'
        cemu = '$fxCemu'
        xemu = '$fxXemu'
        dolphin = '$(Join-Path $fx 'Dolphin')'
    }
}
"@

try {
    $duckHash = (Get-FileHash $fxDuck).Hash
    & $configureScript -Action Check -ConfigPath $fxConfig | Out-Null
    Assert ((Get-FileHash $fxDuck).Hash -eq $duckHash) 'configure-emulators -Action Check writes nothing'
    Assert (-not (Test-Path (Join-Path $fx 'RetroArch-Win64\config'))) 'Check does not create RetroArch core option files'
    Assert (-not (Test-Path (Join-Path $fxEmu 'flycast\data\naomi.zip'))) 'Check does not copy BIOS files'

    & $configureScript -Action Configure -ConfigPath $fxConfig | Out-Null

    $duck = Get-Content $fxDuck
    Assert ($duck -contains 'ConfirmPowerOff = false') 'Configure updates an existing INI key in place'
    Assert ($duck -contains 'ResolutionScale = 8') 'Configure updates a key in a later section'
    Assert ($duck -contains 'Keep = me') 'Configure preserves unmanaged keys'
    Assert ($duck -contains "SearchDirectory = $fxBios") 'BIOS.SearchDirectory points at an existing BiosRoot'
    Assert (@($duck | Where-Object { $_ -eq '[Main]' }).Count -eq 1) 'Configure does not duplicate existing sections'
    Assert ((Get-Content $fxRetro) -contains 'video_driver = "d3d11"') 'Configure leaves unmanaged retroarch.cfg keys alone'
    Assert (Test-Path (Join-Path $fx 'RetroArch-Win64\config\melonDS\melonDS.cfg')) 'Configure creates RetroArch core option files next to retroarch.cfg'
    Assert ((Get-Content (Join-Path $fx 'RetroArch-Win64\config\ParaLLEl N64\ParaLLEl N64.cfg')) -contains 'video_driver = "vulkan"') 'ParaLLEl-N64 gets a per-core Vulkan driver override'
    Assert (-not (Test-Path $fxPcsx2)) 'Configure never creates a config file the emulator has not written yet (PCSX2)'
    Assert (@(Get-ChildItem (Split-Path $fxDuck) -Filter 'settings.ini.bak.*').Count -eq 1) 'Configure backs up a changed file once'

    $super = Get-Content $fxSuperIni
    Assert (($super -contains 'WideScreen = true') -and @($super | Where-Object { $_ -match '^\s*\[\s*Global\s*\]' }).Count -eq 1) 'Supermodel "[ Global ]" is matched without adding a duplicate section'
    Assert ((Get-Content (Join-Path $fxEmu 'flycast\emu.cfg')) -contains 'rend.WideScreen = yes') 'Flycast settings land in a new [config] section of emu.cfg'

    [xml]$cemu = Get-Content -Raw $fxCemu
    Assert ($cemu.content.fullscreen -eq 'true' -and $cemu.content.Graphic.VSync -eq '1') 'Cemu XML values are updated'
    Assert ($cemu.content.GamePaths.Entry -eq (Join-Path $fxRoms 'wiiu')) 'Cemu game path uses {{RomPath:wiiu}}'

    $xemu = Get-Content $fxXemu
    Assert ($xemu -contains "bootrom_path = '$fxBios\mcpx_1.0.bin'") 'xemu BIOS path is set when the file exists in BiosRoot'
    Assert (-not ($xemu -match 'flashrom_path')) 'xemu settings whose BIOS file is missing are skipped'

    $melon = Get-Content (Join-Path $fxEmu 'melonDS\melonDS.toml')
    Assert ($melon -contains "BIOS7Path = '$fxEmu\melonDS\bios\bios7.bin'") 'melonDS BIOS path resolves {dir:melonds} with a TOML literal string'
    Assert (-not ($melon -match 'BIOS9Path')) 'melonDS BIOS9 path skipped when bios9.bin is missing'

    $naomi = Join-Path $fxEmu 'flycast\data\naomi.zip'
    $bios7 = Join-Path $fxEmu 'melonDS\bios\bios7.bin'
    Assert ((Test-Path $naomi) -and (Test-Path $bios7)) 'BIOS files are copied into installed emulators'

    $duckHash = (Get-FileHash $fxDuck).Hash
    $retroHash = (Get-FileHash $fxRetro).Hash
    $cemuHash = (Get-FileHash $fxCemu).Hash
    Start-Sleep -Seconds 1
    & $configureScript -Action Configure -ConfigPath $fxConfig | Out-Null
    Assert (((Get-FileHash $fxDuck).Hash -eq $duckHash) -and ((Get-FileHash $fxRetro).Hash -eq $retroHash) -and ((Get-FileHash $fxCemu).Hash -eq $cemuHash)) 'Re-running configure-emulators is idempotent (INI, cfg, XML)'
    Assert (@(Get-ChildItem (Split-Path $fxDuck) -Filter 'settings.ini.bak.*').Count -eq 1) 'Idempotent re-run creates no new backup'

    Set-Content -Path (Join-Path $fxBios 'dc\naomi.zip') -Value 'naomi-v2'
    Set-Content -Path (Join-Path $fxBios 'bios7.bin') -Value 'bios7-v2'
    & $configureScript -Action Configure -ConfigPath $fxConfig | Out-Null
    Assert ((Get-Content $naomi) -eq 'naomi-v2') 'sync-mode BIOS files are recopied when the source changes'
    Assert ((Get-Content $bios7) -eq 'bios7-v1') 'seed-mode BIOS files are never overwritten'
}
finally {
    Remove-Item -Path $fx -Recurse -Force -ErrorAction SilentlyContinue
}

$touched = @($realConfigs | Where-Object { (Get-FileHash $_).Hash -ne $realHashes[$_] })
Assert ($touched.Count -eq 0) "the test left real emulator configs untouched$(if ($touched) { " -- CHANGED: $($touched -join ', ')" })"

# ---------------------------------------------------------------------------

if ($failures.Count -gt 0) {
    Write-Host "`n$($failures.Count) check(s) failed." -ForegroundColor Red
    exit 1
}
Write-Host "`nAll checks passed." -ForegroundColor Green
