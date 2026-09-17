<#
.SYNOPSIS
    Install the RetroArch cores and asset packs.

.DESCRIPTION
    Windows counterpart of the Linux retroarch_extras role and
    macos/scripts/install-cores.py, using the official libretro buildbot:

      cores   every core named in config/esde-systems.psd1 plus ExtraCores in
              config/retroarch-cores.psd1, into <RetroArch>\cores. Existing
              cores are never overwritten unless -Update. Each download records
              its URL and SHA-256 as <core>_libretro.dll.dg-source -- an
              integrity record, not a signature; "latest" is a rolling build.
      assets  the same 8 packs as Linux (info, assets, autoconfig, cheats,
              databases, slang shaders, overlays), extracted next to
              retroarch.exe with a .dg-installed stamp. Skip with -NoAssets.

.EXAMPLE
    ./install-cores.ps1 -Check
    ./install-cores.ps1
    ./install-cores.ps1 -NoAssets
#>
[CmdletBinding()]
param(
    [switch]$Check,
    [switch]$Update,
    [switch]$NoAssets,
    [string]$RetroArchDir,
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'lib\common.ps1')

$raConfig = Import-PowerShellDataFile -Path (Join-Path $scriptRoot 'config\retroarch-cores.psd1')
$systems = (Import-PowerShellDataFile -Path (Join-Path $scriptRoot 'config\esde-systems.psd1')).Systems

$fromSystems = foreach ($s in $systems) {
    foreach ($c in $s.Commands) {
        foreach ($m in [regex]::Matches($c.Cmd, '([A-Za-z0-9_]+)_libretro\.dll')) { $m.Groups[1].Value }
    }
}
$cores = @(@($fromSystems) + @($raConfig.ExtraCores) | Sort-Object -Unique)

if (-not $RetroArchDir) {
    $config = Get-DgConfig -ConfigPath $ConfigPath -ScriptRoot $scriptRoot
    $retroarch = Get-DgApps -ScriptRoot $scriptRoot | Where-Object { $_.id -eq 'retroarch' }
    $exe = Resolve-AppRealExePath -App $retroarch -EmulatorsRoot $config.EmulatorsRoot
    if (-not $exe) {
        throw 'RetroArch is not installed. Run ./install-apps.ps1 -Only retroarch first (or pass -RetroArchDir).'
    }
    $RetroArchDir = Split-Path -Parent $exe
}
$coresDir = Join-Path $RetroArchDir 'cores'

$missingCores = @($cores | Where-Object { -not [IO.File]::Exists((Join-Path $coresDir "$($_)_libretro.dll")) })
$packs = if ($NoAssets) { @() } else { @($raConfig.AssetPacks) }
$missingPacks = @($packs | Where-Object { -not [IO.File]::Exists((Join-Path (Join-Path $RetroArchDir $_.Dir) '.dg-installed')) })

Write-Host "RetroArch: $RetroArchDir" -ForegroundColor Cyan
Write-Host "Cores: $($cores.Count - $missingCores.Count) of $($cores.Count) present."
if (-not $NoAssets) { Write-Host "Asset packs: $($packs.Count - $missingPacks.Count) of $($packs.Count) present." }

if ($Check) {
    if ($missingCores) { Write-Host "Missing cores: $($missingCores -join ', ')" -ForegroundColor Yellow }
    if ($missingPacks) { Write-Host "Missing asset packs: $($missingPacks.Zip -join ', ')" -ForegroundColor Yellow }
    if (-not $missingCores -and -not $missingPacks) { Write-Host 'Everything is installed.' -ForegroundColor Green }
    return
}

function Get-Download {
    param([string]$Url)
    $file = Join-Path ([IO.Path]::GetTempPath()) ("dg-ra-" + [Guid]::NewGuid().ToString('N') + '.zip')
    Invoke-WebRequest -Uri $Url -OutFile $file -UseBasicParsing
    return $file
}

$failures = @()

$coreTargets = if ($Update) { $cores } else { $missingCores }
foreach ($core in $coreTargets) {
    $url = "$($raConfig.BuildbotUrl)/$($core)_libretro.dll.zip"
    $zip = $null; $stage = $null
    try {
        $zip = Get-Download -Url $url
        $stage = "$zip.d"
        Expand-Archive -Path $zip -DestinationPath $stage -Force
        $dll = Get-ChildItem -Path $stage -Filter "$($core)_libretro.dll" -Recurse | Select-Object -First 1
        if (-not $dll) { throw "archive did not contain $($core)_libretro.dll" }
        [void][IO.Directory]::CreateDirectory($coresDir)
        $dest = Join-Path $coresDir $dll.Name
        Copy-Item -Path $dll.FullName -Destination $dest -Force
        $hash = (Get-FileHash -Path $dest -Algorithm SHA256).Hash.ToLower()
        Set-Content -Path "$dest.dg-source" -Encoding ASCII -Value @("url=$url", "sha256=$hash")
        Write-Host "[core] $core" -ForegroundColor Green
    }
    catch {
        Write-Host "[FAILED] core ${core}: $($_.Exception.Message)" -ForegroundColor Red
        $failures += $core
    }
    finally {
        if ($zip) { Remove-Item -Path $zip, $stage -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

$packTargets = if ($Update) { $packs } else { $missingPacks }
foreach ($pack in $packTargets) {
    $url = "$($raConfig.AssetsUrl)/$($pack.Zip)"
    $dest = Join-Path $RetroArchDir $pack.Dir
    $zip = $null
    try {
        Write-Host "[assets] downloading $($pack.Zip)"
        $zip = Get-Download -Url $url
        [void][IO.Directory]::CreateDirectory($dest)
        & "$env:SystemRoot\System32\tar.exe" -xf $zip -C $dest
        if ($LASTEXITCODE -ne 0) { throw "tar.exe could not extract $($pack.Zip) (exit $LASTEXITCODE)" }
        Set-Content -Path (Join-Path $dest '.dg-installed') -Encoding ASCII -Value "url=$url"
        Write-Host "[assets] $($pack.Zip) -> $dest" -ForegroundColor Green
    }
    catch {
        Write-Host "[FAILED] assets $($pack.Zip): $($_.Exception.Message)" -ForegroundColor Red
        $failures += $pack.Zip
    }
    finally {
        if ($zip) { Remove-Item -Path $zip -Force -ErrorAction SilentlyContinue }
    }
}

if ($failures) {
    Write-Host "`nFailed: $($failures -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host "`nDone: $(@($coreTargets).Count) core(s), $(@($packTargets).Count) asset pack(s) installed." -ForegroundColor Green
