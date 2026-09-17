<#
.SYNOPSIS
    Install the RetroArch cores every ES-DE system needs.

.DESCRIPTION
    Windows counterpart of the Linux retroarch_extras role and
    macos/scripts/install-cores.py. Downloads <core>_libretro.dll from the
    official libretro buildbot into RetroArch's cores folder: every core named
    in config/esde-systems.psd1 plus the extras in config/retroarch-cores.psd1.

    Cores already present are never overwritten (use -Update to refresh them).
    Each download records its URL and SHA-256 next to the core as
    <core>_libretro.dll.dg-source -- an integrity record of what was fetched,
    not a signature; the buildbot "latest" folder is a rolling build.

.EXAMPLE
    ./install-cores.ps1 -Check
    ./install-cores.ps1
#>
[CmdletBinding()]
param(
    [switch]$Check,
    [switch]$Update,
    [string]$CoresDir,
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'lib\common.ps1')

$coreConfig = Import-PowerShellDataFile -Path (Join-Path $scriptRoot 'config\retroarch-cores.psd1')
$systems = (Import-PowerShellDataFile -Path (Join-Path $scriptRoot 'config\esde-systems.psd1')).Systems

$fromSystems = foreach ($s in $systems) {
    foreach ($c in $s.Commands) {
        foreach ($m in [regex]::Matches($c.Cmd, '([A-Za-z0-9_]+)_libretro\.dll')) { $m.Groups[1].Value }
    }
}
$cores = @(@($fromSystems) + @($coreConfig.ExtraCores) | Sort-Object -Unique)

if (-not $CoresDir) {
    $config = Get-DgConfig -ConfigPath $ConfigPath -ScriptRoot $scriptRoot
    $retroarch = Get-DgApps -ScriptRoot $scriptRoot | Where-Object { $_.id -eq 'retroarch' }
    $exe = Resolve-AppRealExePath -App $retroarch -EmulatorsRoot $config.EmulatorsRoot
    if (-not $exe) {
        throw 'RetroArch is not installed. Run ./install-apps.ps1 -Only retroarch first (or pass -CoresDir).'
    }
    $CoresDir = Join-Path (Split-Path -Parent $exe) 'cores'
}

$missing = @($cores | Where-Object { -not (Test-Path (Join-Path $CoresDir "$($_)_libretro.dll")) })
Write-Host "RetroArch cores in ${CoresDir}: $($cores.Count - $missing.Count) of $($cores.Count) present." -ForegroundColor Cyan

if ($Check) {
    if ($missing) { Write-Host "Missing: $($missing -join ', ')" -ForegroundColor Yellow }
    else { Write-Host 'All cores are installed.' -ForegroundColor Green }
    return
}

$targets = if ($Update) { $cores } else { $missing }
if (-not $targets) {
    Write-Host 'Nothing to do.' -ForegroundColor Green
    return
}

New-Item -ItemType Directory -Path $CoresDir -Force | Out-Null
$failures = @()
foreach ($core in $targets) {
    $url = "$($coreConfig.BuildbotUrl)/$($core)_libretro.dll.zip"
    $zip = Join-Path ([IO.Path]::GetTempPath()) ("dg-core-" + [Guid]::NewGuid().ToString('N') + '.zip')
    $stage = "$zip.d"
    try {
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
        Expand-Archive -Path $zip -DestinationPath $stage -Force
        $dll = Get-ChildItem -Path $stage -Filter "$($core)_libretro.dll" -Recurse | Select-Object -First 1
        if (-not $dll) { throw "archive did not contain $($core)_libretro.dll" }
        $dest = Join-Path $CoresDir $dll.Name
        Copy-Item -Path $dll.FullName -Destination $dest -Force
        $hash = (Get-FileHash -Path $dest -Algorithm SHA256).Hash.ToLower()
        Set-Content -Path "$dest.dg-source" -Encoding ASCII -Value @("url=$url", "sha256=$hash")
        Write-Host "[ok] $core" -ForegroundColor Green
    }
    catch {
        Write-Host "[FAILED] ${core}: $($_.Exception.Message)" -ForegroundColor Red
        $failures += $core
    }
    finally {
        Remove-Item -Path $zip, $stage -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($failures) {
    Write-Host "`nFailed: $($failures -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host "`nInstalled $($targets.Count) core(s)." -ForegroundColor Green
