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
# Result
# ---------------------------------------------------------------------------

if ($failures.Count -gt 0) {
    Write-Host "`n$($failures.Count) check(s) failed." -ForegroundColor Red
    exit 1
}
Write-Host "`nAll checks passed." -ForegroundColor Green
