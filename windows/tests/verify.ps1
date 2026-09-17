<#
.SYNOPSIS
    Integration test for the windows/ baseline, in the spirit of macos/tests/verify.py.

.DESCRIPTION
    Runs bootstrap.ps1 for real against a temporary EsdeHome/RomRoot -- never
    against the user's actual $env:USERPROFILE\ES-DE. Installs nothing (does
    not call winget). Checks:
      - apps.json parses and every entry has the required fields
      - -Action Check makes no filesystem changes
      - -Action Configure creating a junction is idempotent (second run is a no-op)
      - missing ROM directories are reported, never created, unless CreateRomDirs is set
      - CreateRomDirs opt-in actually creates the directories

.EXAMPLE
    pwsh windows/tests/verify.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$windowsRoot = Split-Path -Parent $scriptRoot
$bootstrap = Join-Path $windowsRoot 'bootstrap.ps1'
$appsJsonPath = Join-Path $windowsRoot 'apps.json'

$failures = @()
function Assert {
    param([bool]$Condition, [string]$Message)
    if ($Condition) {
        Write-Host "[pass] $Message" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $Message" -ForegroundColor Red
        $script:failures += $Message
    }
}

# ---------------------------------------------------------------------------
# apps.json shape
# ---------------------------------------------------------------------------

$manifest = Get-Content -Raw -Path $appsJsonPath | ConvertFrom-Json
Assert ($manifest.apps.Count -gt 0) 'apps.json has at least one app'
foreach ($app in $manifest.apps) {
    Assert ([bool]$app.id) "app has id ($($app.name))"
    Assert ([bool]$app.wingetId) "$($app.name) has wingetId"
    Assert ($app.exeNames -and $app.exeNames.Count -gt 0) "$($app.name) has exeNames"
}

# ---------------------------------------------------------------------------
# Temp sandbox -- never touch the real ES-DE home
# ---------------------------------------------------------------------------

$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("dg-windows-test-" + [System.Guid]::NewGuid().ToString('N'))
$esdeHome = Join-Path $sandbox 'ES-DE'
$romRoot = Join-Path $sandbox 'ROMs'
New-Item -ItemType Directory -Path $esdeHome, $romRoot -Force | Out-Null

# Fake one installed emulator under Program Files-equivalent so a junction has
# something real to link to, without needing an actual winget install.
$fakeProgramFiles = Join-Path $sandbox 'ProgramFiles'
$fakeDolphinDir = Join-Path $fakeProgramFiles 'Dolphin-x64-5.0'
New-Item -ItemType Directory -Path $fakeDolphinDir -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $fakeDolphinDir 'Dolphin.exe') -Force | Out-Null
$env:ProgramFiles_Backup = $env:ProgramFiles
$env:ProgramFiles = $fakeProgramFiles

try {
    # --- Check makes no changes ---
    & $bootstrap -Action Check -EsdeHomeOverride $esdeHome -RomRootOverride $romRoot | Out-Null
    $junctionPath = Join-Path $esdeHome 'Emulators\Dolphin-x64'
    Assert (-not (Test-Path $junctionPath)) '-Action Check does not create the Dolphin junction'
    Assert ((Get-ChildItem -Path $romRoot -ErrorAction SilentlyContinue).Count -eq 0) '-Action Check does not create ROM directories'

    # --- Configure creates the junction and links to the fake install ---
    & $bootstrap -Action Configure -EsdeHomeOverride $esdeHome -RomRootOverride $romRoot | Out-Null
    Assert (Test-Path $junctionPath) '-Action Configure creates the Dolphin junction'
    $linkedExe = Join-Path $junctionPath 'Dolphin.exe'
    Assert (Test-Path $linkedExe) 'Junction resolves to the fake Dolphin.exe'

    # --- Configure again is idempotent ---
    $before = [string]((Get-Item $junctionPath).Target | Select-Object -First 1)
    & $bootstrap -Action Configure -EsdeHomeOverride $esdeHome -RomRootOverride $romRoot | Out-Null
    $after = [string]((Get-Item $junctionPath).Target | Select-Object -First 1)
    Assert ($before -eq $after) 'Re-running -Action Configure is idempotent (junction unchanged)'

    # --- ROM dirs still not created by default ---
    Assert ((Get-ChildItem -Path $romRoot -ErrorAction SilentlyContinue).Count -eq 0) 'ROM directories still not auto-created (CreateRomDirs defaults to false)'

    # --- CreateRomDirs opt-in actually creates them ---
    & $bootstrap -Action Configure -EsdeHomeOverride $esdeHome -RomRootOverride $romRoot -CreateRomDirs:$true | Out-Null
    $gcDir = Join-Path $romRoot 'gc'
    Assert (Test-Path $gcDir) 'CreateRomDirs:$true creates missing system ROM directories (gc)'
}
finally {
    $env:ProgramFiles = $env:ProgramFiles_Backup
    Remove-Item -Path $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# Config data files load (Import-PowerShellDataFile rejects $env: expressions)
# ---------------------------------------------------------------------------

. (Join-Path $windowsRoot 'lib\common.ps1')

$example = Import-ConfigDataFile -Path (Join-Path $windowsRoot 'config\localhost.example.psd1')
Assert ($example.EsdeHome -eq "$env:USERPROFILE\ES-DE") 'localhost.example.psd1 loads and expands %USERPROFILE%'
$emuData = Import-ConfigDataFile -Path (Join-Path $windowsRoot 'config\emulators.psd1')
Assert ($emuData.DuckstationIniPath -eq "$env:LOCALAPPDATA\DuckStation\settings.ini") 'emulators.psd1 loads and expands %LOCALAPPDATA%'

# ---------------------------------------------------------------------------
# configure-emulators.ps1 against fixture files
# ---------------------------------------------------------------------------

$configureScript = Join-Path $windowsRoot 'configure-emulators.ps1'
$fx = Join-Path ([System.IO.Path]::GetTempPath()) ("dg-windows-emu-" + [System.Guid]::NewGuid().ToString('N'))
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
# Result
# ---------------------------------------------------------------------------

if ($failures.Count -gt 0) {
    Write-Host "`n$($failures.Count) check(s) failed." -ForegroundColor Red
    exit 1
}
Write-Host "`nAll checks passed." -ForegroundColor Green
