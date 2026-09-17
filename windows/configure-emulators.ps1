<#
.SYNOPSIS
    Apply the project's emulator tuning to an already-installed Windows setup.

.DESCRIPTION
    Windows equivalent of the Linux tree's seed_configs role plus gpu.yml.
    Reads config/emulators.psd1 and applies it to each emulator's own config:

      - PCSX2       INI keys (upscale, filtering, hotkeys, Pad1)
      - DuckStation INI keys (resolution, PGXP, widescreen, BIOS dir) plus
                    optional per-game gamesettings\<SERIAL>.ini overrides
      - RetroArch   retroarch.cfg keys and per-core option files
      - Dolphin     optional controller profile files
      - GPU         per-exe "Graphics performance preference", only on PCs
                    with more than one GPU

    A config file the emulator hasn't created yet is skipped, never written
    half-baked -- launch each emulator once first. Every file is backed up as
    <file>.bak.<timestamp> before its first change in a run.

.PARAMETER Action
    'Check' (default) reports what would change and writes nothing.
    'Configure' applies the changes.

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

$apply = $Action -eq 'Configure'

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

if (-not $EmulatorsConfigPath) { $EmulatorsConfigPath = Join-Path $scriptRoot 'config\emulators.psd1' }

$config = Get-DgConfig -ConfigPath $ConfigPath -ScriptRoot $scriptRoot

$emu = Import-ConfigDataFile -Path $EmulatorsConfigPath
if ($config.ContainsKey('PreferDiscreteGpu')) { $emu.PreferDiscreteGpu = $config.PreferDiscreteGpu }

function Get-ConfiguredPath {
    param([string]$Key, [string]$Default)
    if ($config.EmulatorConfigPaths -and $config.EmulatorConfigPaths.ContainsKey($Key)) {
        return $config.EmulatorConfigPaths[$Key]
    }
    return $Default
}

# ---------------------------------------------------------------------------
# File writers (mirror community.general.ini_file / ansible.builtin.lineinfile)
# ---------------------------------------------------------------------------

$script:BackedUp = @{}

function Backup-ConfigFile {
    param([string]$Path)
    if ($script:BackedUp.ContainsKey($Path)) { return }
    if (Test-Path $Path) {
        $stamp = Get-Date -Format 'yyyyMMddHHmmss'
        Copy-Item -Path $Path -Destination "$Path.bak.$stamp" -Force
    }
    $script:BackedUp[$Path] = $true
}

function Save-Lines {
    param([string]$Path, $Lines)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    Backup-ConfigFile -Path $Path
    [IO.File]::WriteAllLines($Path, [string[]]$Lines, (New-Object Text.UTF8Encoding $false))
}

function Read-Lines {
    param([string]$Path)
    $list = New-Object 'System.Collections.Generic.List[string]'
    if (Test-Path $Path) { foreach ($l in [IO.File]::ReadAllLines($Path)) { $list.Add($l) } }
    return ,$list
}

# Returns $true when the value differs from what's on disk (and, with -Apply,
# after writing it).
function Set-IniValue {
    param([string]$Path, [string]$Section, [string]$Option, [string]$Value, [bool]$Apply)

    $lines = Read-Lines -Path $Path
    $desired = "$Option = $Value"

    $sectionIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq "[$Section]") { $sectionIndex = $i; break }
    }

    if ($sectionIndex -lt 0) {
        if ($Apply) {
            if ($lines.Count -gt 0 -and $lines[$lines.Count - 1].Trim() -ne '') { $lines.Add('') }
            $lines.Add("[$Section]")
            $lines.Add($desired)
            Save-Lines -Path $Path -Lines $lines
        }
        return $true
    }

    $sectionEnd = $lines.Count
    for ($i = $sectionIndex + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -match '^\[.+\]$') { $sectionEnd = $i; break }
    }

    for ($i = $sectionIndex + 1; $i -lt $sectionEnd; $i++) {
        if ($lines[$i] -match "^\s*$([regex]::Escape($Option))\s*=\s*(.*)$") {
            if ($Matches[1].Trim() -eq $Value) { return $false }
            if ($Apply) {
                $lines[$i] = $desired
                Save-Lines -Path $Path -Lines $lines
            }
            return $true
        }
    }

    if ($Apply) {
        $lines.Insert($sectionIndex + 1, $desired)
        Save-Lines -Path $Path -Lines $lines
    }
    return $true
}

function Set-FlatKeyValue {
    param([string]$Path, [string]$Key, [string]$Value, [bool]$Apply)

    $lines = Read-Lines -Path $Path
    $desired = "$Key = $Value"

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^\s*$([regex]::Escape($Key))\s*=\s*(.*)$") {
            if ($Matches[1].Trim() -eq $Value) { return $false }
            if ($Apply) {
                $lines[$i] = $desired
                Save-Lines -Path $Path -Lines $lines
            }
            return $true
        }
    }

    if ($Apply) {
        $lines.Add($desired)
        Save-Lines -Path $Path -Lines $lines
    }
    return $true
}

function Invoke-SettingsBlock {
    param(
        [string]$Label,
        [string]$Path,
        [array]$Settings,
        [switch]$Flat,
        [switch]$CreateIfMissing
    )

    if (-not (Test-Path $Path) -and -not $CreateIfMissing) {
        Write-Host ("[skip] {0}: {1} does not exist yet -- install and launch it once first" -f $Label, $Path) -ForegroundColor DarkGray
        return
    }

    $changed = 0
    $applied = 0
    foreach ($s in $Settings) {
        if ($Flat) {
            if (Set-FlatKeyValue -Path $Path -Key $s.Key -Value $s.Value -Apply $apply) { $changed++ }
            $applied++
            continue
        }

        $value = $s.Value
        if ($value -like '*{{BiosRoot}}*') {
            if (-not (Test-Path $config.BiosRoot)) {
                Write-Host ("[skip] {0}: {1}.{2} -- BiosRoot {3} does not exist, keeping the emulator's own BIOS folder" -f $Label, $s.Section, $s.Option, $config.BiosRoot) -ForegroundColor DarkGray
                continue
            }
            $value = $value.Replace('{{BiosRoot}}', $config.BiosRoot)
        }
        if (Set-IniValue -Path $Path -Section $s.Section -Option $s.Option -Value $value -Apply $apply) { $changed++ }
        $applied++
    }

    $verb = if ($apply) { 'changed' } else { 'would change' }
    $color = if ($changed -gt 0) { 'Yellow' } else { 'Green' }
    Write-Host ("[{0}] {1}: {2} of {3} setting(s) {4}" -f $Label, $Path, $changed, $applied, $verb) -ForegroundColor $color
}

# ---------------------------------------------------------------------------
# Emulator settings
# ---------------------------------------------------------------------------

Write-Host "`n== Emulator settings ($Action) ==" -ForegroundColor Cyan

Invoke-SettingsBlock -Label 'PCSX2' `
    -Path (Get-ConfiguredPath -Key 'pcsx2' -Default $emu.Pcsx2IniPath) `
    -Settings $emu.Pcsx2Settings

$duckIni = Get-ConfiguredPath -Key 'duckstation' -Default $emu.DuckstationIniPath
Invoke-SettingsBlock -Label 'DuckStation' -Path $duckIni -Settings $emu.DuckstationSettings

if (Test-Path $duckIni) {
    foreach ($game in $emu.DuckstationPerGameSettings) {
        $gamePath = Join-Path (Join-Path (Split-Path -Parent $duckIni) 'gamesettings') "$($game.Serial).ini"
        Invoke-SettingsBlock -Label "DuckStation $($game.Serial)" -Path $gamePath -Settings $game.Settings -CreateIfMissing
    }
}

$retroCfg = Get-ConfiguredPath -Key 'retroarch' -Default $emu.RetroarchCfgPath
Invoke-SettingsBlock -Label 'RetroArch' -Flat -Path $retroCfg -Settings $emu.RetroarchSettings

# Core option files only exist after a core has run, so they are created --
# but only once RetroArch itself is installed and has written retroarch.cfg.
if (Test-Path $retroCfg) {
    $retroConfigDir = Join-Path (Split-Path -Parent $retroCfg) 'config'
    foreach ($core in $emu.RetroarchCoreOptions) {
        Invoke-SettingsBlock -Label 'RetroArch core' -Flat -CreateIfMissing `
            -Path (Join-Path $retroConfigDir $core.RelativePath) -Settings $core.Settings
    }
}

$dolphinConfigDir = Get-ConfiguredPath -Key 'dolphin' -Default $emu.DolphinConfigDir
foreach ($profile in $emu.DolphinControllerProfiles) {
    $src = Join-Path (Join-Path $scriptRoot 'config') $profile.Source
    $dest = Join-Path $dolphinConfigDir $profile.Dest
    if (-not (Test-Path $src)) {
        Write-Host "[skip] Dolphin profile source missing: $src" -ForegroundColor Yellow
        continue
    }
    $same = (Test-Path $dest) -and ((Get-FileHash $src).Hash -eq (Get-FileHash $dest).Hash)
    if ($same) {
        Write-Host "[Dolphin] $dest already up to date" -ForegroundColor Green
        continue
    }
    if ($apply) {
        $destParent = Split-Path -Parent $dest
        if (-not (Test-Path $destParent)) { New-Item -ItemType Directory -Path $destParent -Force | Out-Null }
        Backup-ConfigFile -Path $dest
        Copy-Item -Path $src -Destination $dest -Force
    }
    Write-Host "[Dolphin] $dest $(if ($apply) { 'copied' } else { 'would be copied' })" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# GPU preference (Windows analogue of dg_nvidia_enabled)
# ---------------------------------------------------------------------------

function Set-GpuPreference {
    param([string]$ExePath, [bool]$Apply)

    $key = 'HKCU:\SOFTWARE\Microsoft\DirectX\UserGpuPreferences'
    $desired = 'GpuPreference=2;'

    $current = $null
    if (Test-Path $key) {
        $current = (Get-ItemProperty -Path $key -Name $ExePath -ErrorAction SilentlyContinue).$ExePath
    }
    if ($current -eq $desired) { return $false }
    if ($Apply) {
        if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
        Set-ItemProperty -Path $key -Name $ExePath -Value $desired
    }
    return $true
}

if ($emu.PreferDiscreteGpu) {
    Write-Host "`n== GPU preference ==" -ForegroundColor Cyan
    $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch 'Basic Display|Remote Display|Virtual' })

    if ($gpus.Count -lt 2) {
        Write-Host "[skip] only one GPU found ($($gpus.Name -join ', ')) -- nothing to prefer" -ForegroundColor DarkGray
    } else {
        $apps = Get-DgApps -ScriptRoot $scriptRoot | Where-Object { $_.role -eq 'emulator' }
        foreach ($app in $apps) {
            $exe = Resolve-AppRealExePath -App $app -EmulatorsRoot $config.EmulatorsRoot
            if (-not $exe) {
                Write-Host "[skip] $($app.name): not installed" -ForegroundColor DarkGray
                continue
            }
            $changed = Set-GpuPreference -ExePath $exe -Apply $apply
            $state = if (-not $changed) { 'already set' } elseif ($apply) { 'set' } else { 'would set' }
            Write-Host "[gpu] $($app.name): $state ($exe)" -ForegroundColor $(if ($changed) { 'Yellow' } else { 'Green' })
        }
    }
}

if ($apply) {
    Write-Host "`nConfigure complete. Changed files were backed up as <file>.bak.<timestamp>." -ForegroundColor Green
} else {
    Write-Host "`nCheck complete. Nothing was written. Run with -Action Configure to apply." -ForegroundColor Green
}
