<#
.SYNOPSIS
    Apply BIOS placement and emulator tuning to an installed Windows setup.

.DESCRIPTION
    Windows counterpart of the Linux link_storage and seed_configs roles plus
    gpu.yml. Reads config/emulators.psd1 and:

      1. copies BIOS/firmware from BiosRoot into each installed emulator
      2. applies settings to each emulator's own INI/TOML, flat cfg or XML
         config (PCSX2, DuckStation, RetroArch + core options, Flycast,
         Supermodel, xemu, melonDS, Cemu, Dolphin profiles)
      3. sets a "High performance" GPU preference per emulator, only on PCs
         with more than one GPU

    Config files the emulator hasn't written yet are skipped (launch it once).
    Every changed file is backed up as <file>.bak.<timestamp> first.

.PARAMETER Action
    'Check' (default) reports what would change and writes nothing.
    'Configure' applies it.

.EXAMPLE
    ./configure-emulators.ps1 -Action Check
    ./configure-emulators.ps1 -Action Configure
#>
[CmdletBinding()]
param(
    [ValidateSet('Check', 'Configure')]
    [string]$Action = 'Check',

    [string]$ConfigPath,
    [string]$EmulatorsConfigPath
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'lib\common.ps1')
. (Join-Path $scriptRoot 'lib\configfiles.ps1')

$apply = $Action -eq 'Configure'
if (-not $EmulatorsConfigPath) { $EmulatorsConfigPath = Join-Path $scriptRoot 'config\emulators.psd1' }

$config = Get-DgConfig -ConfigPath $ConfigPath -ScriptRoot $scriptRoot
$emu = Import-ConfigDataFile -Path $EmulatorsConfigPath
if ($config.ContainsKey('PreferDiscreteGpu')) { $emu.PreferDiscreteGpu = $config.PreferDiscreteGpu }
$apps = @(Get-DgApps -ScriptRoot $scriptRoot)

# ---------------------------------------------------------------------------
# Tokens
# ---------------------------------------------------------------------------

function Get-AppDir { param([string]$Id) Get-DgAppDir -Id $Id -Config $config -Apps $apps }
function Expand-Tokens { param([string]$Text) Expand-DgTokens -Text $Text -Config $config -Apps $apps -ScriptRoot $scriptRoot }

function Backup-ConfigFile { param([string]$Path) Backup-DgFile -Path $Path }

function Invoke-ConfigFile {
    param([string]$Label, [string]$Path, [string]$Format, [array]$Settings, [switch]$CreateIfMissing)

    if (-not [IO.File]::Exists($Path) -and -not $CreateIfMissing) {
        Write-Host "[skip] ${Label}: $Path does not exist yet -- launch the emulator once first" -ForegroundColor DarkGray
        return
    }
    $changed = 0; $considered = 0
    foreach ($s in $Settings) {
        if ($s.Requires -and -not [IO.File]::Exists((Join-Path $config.BiosRoot $s.Requires))) { continue }
        if ($s.UnlessBios -and [IO.File]::Exists((Join-Path $config.BiosRoot $s.UnlessBios))) { continue }
        if ($s.Value -like '*{{BiosRoot}}*' -and -not [IO.Directory]::Exists($config.BiosRoot)) { continue }
        $value = Expand-Tokens -Text $s.Value
        if ($null -eq $value) { continue }
        $considered++
        $did = switch ($Format) {
            'ini' { Set-DgIniValue -Path $Path -Section $s.Section -Option $s.Option -Value $value -Apply $apply }
            'flat' { Set-DgFlatValue -Path $Path -Key $s.Key -Value $value -Apply $apply }
            'xml' { Set-DgXmlValue -Path $Path -XPath $s.XPath -Value $value -Apply $apply }
            default { throw "unknown format '$Format' for $Label" }
        }
        if ($did) { $changed++ }
    }
    $verb = if ($apply) { 'changed' } else { 'would change' }
    Write-Host ("[{0}] {1}: {2} of {3} setting(s) {4}" -f $Label, $Path, $changed, $considered, $verb) -ForegroundColor $(if ($changed) { 'Yellow' } else { 'Green' })
}

# ---------------------------------------------------------------------------
# 1. BIOS / firmware
# ---------------------------------------------------------------------------

Write-Host "`n== BIOS and firmware ($($config.BiosRoot)) ==" -ForegroundColor Cyan

if (-not [IO.Directory]::Exists($config.BiosRoot)) {
    Write-Host "[skip] BiosRoot does not exist -- create it and add your own BIOS files to use this step" -ForegroundColor DarkGray
} else {
    $copied = 0; $current = 0; $missing = @()
    foreach ($b in $emu.BiosFiles) {
        if (-not (Get-AppDir -Id $b.App)) { continue }
        $dest = Expand-Tokens -Text $b.Dest
        $srcPattern = Join-Path $config.BiosRoot $b.Source
        $isDir = $b.Source.EndsWith('\*')
        $sources = if ($isDir) {
            $srcDir = Split-Path -Parent $srcPattern
            if ([IO.Directory]::Exists($srcDir)) { @([IO.Directory]::GetFiles($srcDir)) } else { @() }
        } elseif ([IO.File]::Exists($srcPattern)) { @($srcPattern) } else { @() }
        if (-not $sources) { $missing += "$($b.App):$($b.Source)"; continue }

        foreach ($src in $sources) {
            $target = if ($isDir) { Join-Path $dest ([IO.Path]::GetFileName($src)) } else { $dest }
            $exists = [IO.File]::Exists($target)
            $needs = -not $exists -or ($b.Mode -ne 'seed' -and (Get-FileHash -LiteralPath $src).Hash -ne (Get-FileHash -LiteralPath $target).Hash)
            if (-not $needs) { $current++; continue }
            if ($apply) {
                [void][IO.Directory]::CreateDirectory((Split-Path -Parent $target))
                if ($exists) { Backup-ConfigFile -Path $target }
                [IO.File]::Copy($src, $target, $true)
            }
            $copied++
            Write-Host "[bios] $([IO.Path]::GetFileName($src)) -> $target $(if (-not $apply) { '(would copy)' })" -ForegroundColor Yellow
        }
    }
    Write-Host "$copied file(s) $(if ($apply) { 'copied' } else { 'to copy' }), $current already in place."
    if ($missing) {
        Write-Host "Not in BiosRoot (optional unless you play those systems): $($missing -join ', ')" -ForegroundColor DarkGray
    }
}

# ---------------------------------------------------------------------------
# 2. Emulator settings
# ---------------------------------------------------------------------------

Write-Host "`n== Emulator settings ($Action) ==" -ForegroundColor Cyan

$resolvedPaths = @{}
foreach ($f in $emu.ConfigFiles) {
    $path = if ($config.EmulatorConfigPaths -and $config.EmulatorConfigPaths.ContainsKey($f.Id)) {
        $config.EmulatorConfigPaths[$f.Id]
    } else { Expand-Tokens -Text $f.Path }
    if (-not $path) {
        Write-Host "[skip] $($f.Id): not installed" -ForegroundColor DarkGray
        continue
    }
    $resolvedPaths[$f.Id] = $path
    Invoke-ConfigFile -Label $f.Id -Path $path -Format $f.Format -Settings $f.Settings
}

if ($resolvedPaths.ContainsKey('duckstation') -and [IO.File]::Exists($resolvedPaths.duckstation)) {
    foreach ($game in $emu.DuckstationPerGameSettings) {
        $gamePath = Join-Path (Join-Path (Split-Path -Parent $resolvedPaths.duckstation) 'gamesettings') "$($game.Serial).ini"
        Invoke-ConfigFile -Label "duckstation $($game.Serial)" -Path $gamePath -Format 'ini' -Settings $game.Settings -CreateIfMissing
    }
}

if ($resolvedPaths.ContainsKey('retroarch') -and [IO.File]::Exists($resolvedPaths.retroarch)) {
    $retroConfigDir = Join-Path (Split-Path -Parent $resolvedPaths.retroarch) 'config'
    foreach ($core in $emu.RetroarchCoreOptions) {
        Invoke-ConfigFile -Label 'retroarch core' -Format 'flat' -CreateIfMissing `
            -Path (Join-Path $retroConfigDir (Expand-Tokens -Text $core.RelativePath)) -Settings $core.Settings
    }
}

$dolphinConfigDir = if ($config.EmulatorConfigPaths -and $config.EmulatorConfigPaths.ContainsKey('dolphin')) {
    $config.EmulatorConfigPaths.dolphin } else { $emu.DolphinConfigDir }
foreach ($profile in $emu.DolphinControllerProfiles) {
    $src = Join-Path (Join-Path $scriptRoot 'config') $profile.Source
    $dest = Join-Path $dolphinConfigDir $profile.Dest
    if (-not [IO.File]::Exists($src)) { Write-Host "[skip] Dolphin profile source missing: $src" -ForegroundColor Yellow; continue }
    if ([IO.File]::Exists($dest) -and (Get-FileHash -LiteralPath $src).Hash -eq (Get-FileHash -LiteralPath $dest).Hash) { continue }
    if ($apply) {
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $dest))
        Backup-ConfigFile -Path $dest
        [IO.File]::Copy($src, $dest, $true)
    }
    Write-Host "[dolphin] $dest $(if ($apply) { 'copied' } else { 'would be copied' })" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 3. GPU preference
# ---------------------------------------------------------------------------

if ($emu.PreferDiscreteGpu) {
    Write-Host "`n== GPU preference ==" -ForegroundColor Cyan
    $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch 'Basic Display|Remote Display|Virtual' })
    if ($gpus.Count -lt 2) {
        Write-Host "[skip] only one GPU found ($($gpus.Name -join ', ')) -- nothing to prefer" -ForegroundColor DarkGray
    } else {
        $key = 'HKCU:\SOFTWARE\Microsoft\DirectX\UserGpuPreferences'
        foreach ($app in $apps | Where-Object { $_.role -eq 'emulator' }) {
            $exe = Resolve-AppRealExePath -App $app -EmulatorsRoot $config.EmulatorsRoot
            if (-not $exe) { continue }
            $current = if (Test-Path $key) { (Get-ItemProperty -Path $key -Name $exe -ErrorAction SilentlyContinue).$exe }
            if ($current -eq 'GpuPreference=2;') { continue }
            if ($apply) {
                if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
                Set-ItemProperty -Path $key -Name $exe -Value 'GpuPreference=2;'
            }
            Write-Host "[gpu] $($app.name): $(if ($apply) { 'set' } else { 'would set' }) high performance" -ForegroundColor Yellow
        }
    }
}

if ($apply) {
    Write-Host "`nConfigure complete. Changed files were backed up as <file>.bak.<timestamp>." -ForegroundColor Green
} else {
    Write-Host "`nCheck complete. Nothing was written. Run with -Action Configure to apply." -ForegroundColor Green
}
