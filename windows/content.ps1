<#
.SYNOPSIS
    Opt-in content: DLC/updates, cheats, per-game configs, patches, textures.

.DESCRIPTION
    Windows port of the Linux roles that only run when their tag is passed to
    site.yml. Driven by config/content.psd1; nothing runs without -Tags.

      dlcs           install_dlcs: PS3 PKGs -> RPCS3 dev_hdd0\game, Switch
                     update/DLC NSPs -> Eden NAND (same Python extractors)
      cheats         switch_cheats: Atmosphere cheats -> Eden load dir (junctions)
      rpcs3_configs  rpcs3_per_game_configs: tuned custom_configs from the RPCS3
                     compatibility API (same Python generator)
      pcsx2          pcsx2_textures: texture pack junctions, public .pnach
                     patches, cheats, per-game gamesettings INIs
      rom_patches    install_rom_patches: SHA-1-verified IPS/BPS patched copies
                     beside the originals (-Revert removes those copies)
      hd_textures    install_hd_textures: Dolphin 4K packs extracted and
                     junctioned into Load\Textures

    Python helpers run on the portable Python from install-apps.ps1. Links
    use junctions/hard links (no Administrator rights); network-share
    sources are copied instead. ROMs, BIOS and saves are never deleted.

.PARAMETER Action
    'Check' (default) previews (Python helpers run with --dry-run).
    'Configure' applies.

.EXAMPLE
    ./content.ps1 -Tags dlcs,cheats
    ./content.ps1 -Tags pcsx2,rom_patches -Action Configure
#>
[CmdletBinding()]
param(
    [string[]]$Tags,

    [ValidateSet('Check', 'Configure')]
    [string]$Action = 'Check',

    [switch]$Revert,
    [switch]$Force,
    [string]$ConfigPath,
    [string]$ContentConfigPath
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'lib\common.ps1')
. (Join-Path $scriptRoot 'lib\configfiles.ps1')
Add-Type -AssemblyName System.IO.Compression.FileSystem

$Tags = Resolve-DgTags -Values $Tags -Allowed @('dlcs', 'cheats', 'rpcs3_configs', 'pcsx2', 'rom_patches', 'hd_textures')
if (-not $Tags) {
    Write-Host 'Nothing runs without -Tags (like the never-tagged Linux roles). Available:' -ForegroundColor Yellow
    Write-Host '  dlcs, cheats, rpcs3_configs, pcsx2, rom_patches, hd_textures'
    Write-Host 'Example: ./content.ps1 -Tags dlcs,cheats   (add -Action Configure to apply)'
    return
}

$apply = $Action -eq 'Configure'
$config = Get-DgConfig -ConfigPath $ConfigPath -ScriptRoot $scriptRoot
$apps = @(Get-DgApps -ScriptRoot $scriptRoot)
if (-not $ContentConfigPath) { $ContentConfigPath = Join-Path $scriptRoot 'config\content.psd1' }
$content = Import-ConfigDataFile -Path $ContentConfigPath
$script:problems = 0

# content.psd1 roots may reference each other ({{Pcsx2PacksRoot}} inside
# Pcsx2CheatsSource), so expand them first, then the shared tokens.
function X {
    param([string]$Text)
    if (-not $Text) { return $null }
    $t = $Text
    foreach ($i in 1..3) {
        foreach ($root in 'HdTexturesRoot', 'Pcsx2PacksRoot') {
            if ($content.ContainsKey($root)) { $t = $t.Replace("{{$root}}", $content[$root]) }
        }
    }
    return Expand-DgTokens -Text $t -Config $config -Apps $apps -ScriptRoot $scriptRoot
}

function Get-Python {
    $py = Resolve-AppRealExePath -App ($apps | Where-Object id -eq 'python') -EmulatorsRoot $config.EmulatorsRoot
    if (-not $py) { throw 'Python is not installed. Run ./install-apps.ps1 -Only python' }
    return $py
}

function Invoke-Python {
    param([string]$Label, [string]$Script, [string[]]$Arguments)
    # Python writes warnings to stderr; under 'Stop', PowerShell 5.1 would turn
    # redirected native stderr into a terminating error.
    $ErrorActionPreference = 'Continue'
    $out = & (Get-Python) $Script @Arguments 2>&1
    $code = $LASTEXITCODE
    $out | Select-Object -Last 12 | ForEach-Object { Write-Host "    $_" }
    if ($code -ne 0) { Write-Host "[FAILED] ${Label}: exit code $code" -ForegroundColor Red; $script:problems++ }
}

function Skip { param($Msg) Write-Host "[skip] $Msg" -ForegroundColor DarkGray }
function Note { param($Msg) Write-Host "  $Msg" -ForegroundColor $(if ($apply) { 'Green' } else { 'Yellow' }) }
$dryRun = if ($apply) { @() } else { @('--dry-run') }

# ---------------------------------------------------------------------------
if ('dlcs' -in $Tags) {
    Write-Host "`n== dlcs ==" -ForegroundColor Cyan
    $src = X $content.Ps3DlcSource; $dest = X $content.Rpcs3GameDir
    if (-not $dest) { Skip 'PS3: RPCS3 not installed' }
    elseif (-not [IO.Directory]::Exists($src)) { Skip "PS3: no DLC/patch folder at $src" }
    elseif (-not [IO.Directory]::EnumerateFiles($src, '*.pkg', 'AllDirectories').GetEnumerator().MoveNext()) { Skip "PS3: no .pkg files in $src" }
    else {
        Write-Host "[ps3] $src -> $dest"
        Invoke-Python -Label 'PS3 DLC' -Script (X $content.Scripts.ExtractPs3Dlc) -Arguments (@($src, '--dest', $dest) + $dryRun)
    }
    $src = X $content.SwitchUpdatesSource; $dest = X $content.EdenNandRegistered
    if (-not (Get-DgAppDir -Id 'eden' -Config $config -Apps $apps)) { Skip 'Switch: Eden not installed' }
    elseif (-not [IO.Directory]::Exists($src)) { Skip "Switch: no updates folder at $src" }
    elseif (-not [IO.Directory]::EnumerateFiles($src, '*.nsp', 'AllDirectories').GetEnumerator().MoveNext()) { Skip "Switch: no .nsp files in $src" }
    else {
        Write-Host "[switch] $src -> $dest"
        Invoke-Python -Label 'Switch updates' -Script (X $content.Scripts.InstallSwitchUpdates) -Arguments (@($src, '--dest', $dest) + $dryRun)
    }
}

# ---------------------------------------------------------------------------
if ('cheats' -in $Tags) {
    Write-Host "`n== cheats ==" -ForegroundColor Cyan
    $src = X $content.SwitchCheatsSource; $dest = X $content.EdenLoadDir
    if (-not (Get-DgAppDir -Id 'eden' -Config $config -Apps $apps)) { Skip 'Eden not installed' }
    elseif (-not [IO.Directory]::Exists($src)) { Skip "no Switch cheats folder at $src" }
    else {
        $counts = @{ linked = 0; copied = 0; current = 0; blocked = 0 }
        foreach ($dir in [IO.Directory]::GetDirectories($src)) {
            $m = [regex]::Match([IO.Path]::GetFileName($dir), '^([0-9A-Fa-f]{16})')
            $cheats = Join-Path $dir 'cheats'
            if (-not $m.Success -or -not [IO.Directory]::Exists($cheats)) { continue }
            $r = Set-DgDirLink -Link (Join-Path $dest "$($m.Groups[1].Value.ToUpper())\cheats") -Target $cheats -Apply $apply
            $counts[$r]++
            if ($r -eq 'blocked') { Write-Host "  kept existing non-empty folder for $($m.Groups[1].Value)" -ForegroundColor Yellow }
        }
        Note "$($counts.linked + $counts.copied) $(if ($apply) { 'linked' } else { 'to link' }), $($counts.current) already linked, $($counts.blocked) kept"
    }
}

# ---------------------------------------------------------------------------
if ('rpcs3_configs' -in $Tags) {
    Write-Host "`n== rpcs3_configs ==" -ForegroundColor Cyan
    $ps3 = Get-DgRomPath -System 'ps3' -Config $config; $dest = X $content.Rpcs3CustomConfigs
    if (-not $dest) { Skip 'RPCS3 not installed' }
    elseif (-not [IO.Directory]::Exists($ps3)) { Skip "no PS3 ROM folder at $ps3" }
    else {
        $genArgs = @($ps3, '--dest', $dest) + $dryRun
        if ($Force) { $genArgs += '--force' }
        Invoke-Python -Label 'RPCS3 per-game configs' -Script (X $content.Scripts.GenerateRpcs3Configs) -Arguments $genArgs
    }
}

# ---------------------------------------------------------------------------
if ('pcsx2' -in $Tags) {
    Write-Host "`n== pcsx2 ==" -ForegroundColor Cyan
    $pcsx2 = X $content.Pcsx2Dir
    if (-not (Get-DgAppDir -Id 'pcsx2' -Config $config -Apps $apps)) { Skip 'PCSX2 not installed' }
    else {
        $packCount = 0
        foreach ($pack in $content.Pcsx2TexturePacks) {
            foreach ($s in $pack.Sources) {
                $path = X $s.Path
                if (-not [IO.Directory]::Exists($path)) { continue }
                $r = Set-DgDirLink -Link (Join-Path $pcsx2 "textures\$($pack.Serial)\replacements\$($s.LinkAs)") -Target $path -Apply $apply
                if ($r -ne 'current') { Note "texture pack $($pack.Serial)\$($s.LinkAs): $r" }
                $packCount++
            }
        }
        if (-not $packCount) { Skip "no texture pack sources under $(X $content.Pcsx2PacksRoot)" }

        $cheatSrc = X $content.Pcsx2CheatsSource
        if ([IO.Directory]::Exists($cheatSrc)) {
            $n = 0
            foreach ($f in [IO.Directory]::GetFiles($cheatSrc, '*.pnach')) {
                if (Set-DgFileLink -Dest (Join-Path $pcsx2 "cheats\$([IO.Path]::GetFileName($f))") -Source $f -Apply $apply) { $n++ }
            }
            Note "$n cheat file(s) $(if ($apply) { 'placed' } else { 'to place' }) from $cheatSrc"
        }

        $patches = Join-Path $pcsx2 'patches'
        $downloads = @($content.Pcsx2PatchUrls | ForEach-Object { @{ Url = $_; Name = [Uri]::UnescapeDataString([IO.Path]::GetFileName(([Uri]$_).AbsolutePath)) } }) +
                     @($content.Pcsx2PatchUrlRenames | ForEach-Object { @{ Url = $_.Url; Name = $_.DestName } })
        foreach ($d in $downloads) {
            $target = Join-Path $patches $d.Name
            if ([IO.File]::Exists($target)) { continue }
            if ($apply) {
                try {
                    [void][IO.Directory]::CreateDirectory($patches)
                    Invoke-WebRequest -Uri $d.Url -OutFile $target -UseBasicParsing
                } catch { Write-Host "[FAILED] $($d.Name): $($_.Exception.Message)" -ForegroundColor Red; $script:problems++; continue }
            }
            Note "patch $($d.Name) $(if ($apply) { 'downloaded' } else { 'to download' })"
        }

        foreach ($a in $content.Pcsx2PatchAppends) {
            $target = Join-Path $patches $a.Target
            $local = Join-Path (X $content.Scripts.Pcsx2LocalPnach) $a.LocalFile
            if (-not [IO.File]::Exists($target) -or -not [IO.File]::Exists($local)) { continue }
            $block = [IO.File]::ReadAllText($local).Trim()
            if ([IO.File]::ReadAllText($target).Contains($block)) { continue }
            if ($apply) { Backup-DgFile -Path $target; [IO.File]::AppendAllText($target, "`r`n$block`r`n") }
            Note "appended $($a.LocalFile) to $($a.Target)"
        }

        $changedGames = 0
        foreach ($g in $content.Pcsx2PerGameSettings) {
            $ini = Join-Path $pcsx2 "gamesettings\$($g.Serial)_$($g.Crc).ini"
            $changed = 0
            foreach ($s in $g.Settings) {
                if (Set-DgIniValue -Path $ini -Section $s.Section -Option $s.Option -Value $s.Value -Apply $apply) { $changed++ }
            }
            if ($changed) { $changedGames++; Note "gamesettings $($g.Serial)_$($g.Crc) ($($g.Name)): $changed setting(s)" }
        }
        if (-not $changedGames) { Write-Host '  per-game settings up to date' -ForegroundColor Green }
    }
}

# ---------------------------------------------------------------------------
if ('rom_patches' -in $Tags) {
    Write-Host "`n== rom_patches$(if ($Revert) { ' (revert)' }) ==" -ForegroundColor Cyan
    foreach ($p in $content.RomPatches) {
        $out = X $p.Out
        if ($Revert) {
            if ([IO.File]::Exists($out)) {
                if ($apply) { [IO.File]::Delete($out) }
                Note "$($p.Name): $(if ($apply) { 'removed' } else { 'would remove' }) $out"
            }
            continue
        }
        if ([IO.File]::Exists($out)) { Write-Host "  $($p.Name): already patched" -ForegroundColor Green; continue }
        $base = X $p.Base
        if (-not [IO.File]::Exists($base)) { Skip "$($p.Name): base ROM not found ($base)"; continue }
        $patch = if ($p.PatchSource) { X $p.PatchSource } else { Join-Path (X $content.Scripts.RomPatchFiles) $p.Patch }
        if (-not [IO.File]::Exists($patch)) { Skip "$($p.Name): patch not found ($patch)"; continue }
        $sha1 = (Get-FileHash -LiteralPath $base -Algorithm SHA1).Hash.ToLower()
        if ($sha1 -ne $p.BaseSha1) {
            Write-Host "[FAILED] $($p.Name): base ROM is the wrong revision (sha1 $sha1, need $($p.BaseSha1))" -ForegroundColor Red
            $script:problems++; continue
        }
        if (-not $apply) { Note "$($p.Name): would patch -> $out"; continue }
        $tool = if ($patch -like '*.bps') { X $content.Scripts.ApplyBps } else { X $content.Scripts.ApplyIps }
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $out))
        Invoke-Python -Label $p.Name -Script $tool -Arguments @($base, $patch, $out, $p.BaseSha1, $p.OutSha1)
    }
}

# ---------------------------------------------------------------------------
if ('hd_textures' -in $Tags) {
    Write-Host "`n== hd_textures ==" -ForegroundColor Cyan
    $dolphinTex = X $content.DolphinTexturesDir
    if (-not (Get-DgAppDir -Id 'dolphin' -Config $config -Apps $apps)) { Skip 'Dolphin not installed' }
    else {
        foreach ($pack in $content.HdTexturePacks) {
            $archive = X $pack.Archive
            if (-not [IO.File]::Exists($archive)) { Skip "$($pack.Slug): archive not found ($archive)"; continue }
            $extractDir = Join-Path (Join-Path (Split-Path -Parent $archive) 'extracted') $pack.Slug
            $marker = Join-Path $extractDir '.dg-extracted'
            if (-not [IO.File]::Exists($marker)) {
                if (-not $apply) { Note "$($pack.Slug): would extract Load/Textures and link $($pack.GameIds -join ', ')"; continue }
                $zip = [IO.Compression.ZipFile]::OpenRead($archive)
                try {
                    $root = [IO.Path]::GetFullPath($extractDir).TrimEnd('\') + '\'
                    foreach ($e in $zip.Entries) {
                        $name = $e.FullName.Replace('\', '/')
                        if ($name -notmatch '(?i)/Load/Textures/' -or $name.EndsWith('/')) { continue }
                        $target = [IO.Path]::GetFullPath((Join-Path $root $name))
                        if (-not $target.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { continue }
                        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $target))
                        [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $target, $true)
                    }
                } finally { $zip.Dispose() }
                [IO.File]::WriteAllText($marker, $archive)
            }
            $candidates = foreach ($gid in $pack.GameIds) {
                Get-ChildItem -LiteralPath $extractDir -Recurse -Directory -Filter $gid -ErrorAction SilentlyContinue |
                    ForEach-Object { [PSCustomObject]@{ Path = $_.FullName; Files = @(Get-ChildItem -LiteralPath $_.FullName -Recurse -File).Count } }
            }
            $best = @($candidates | Where-Object Files -gt 0 | Sort-Object Files -Descending)[0]
            if (-not $best) { Write-Host "  $($pack.Slug): no populated game ID folder in $extractDir" -ForegroundColor Yellow; continue }
            foreach ($gid in $pack.GameIds) {
                $r = Set-DgDirLink -Link (Join-Path $dolphinTex $gid) -Target $best.Path -Apply $apply
                Note "$($pack.Slug) $gid -> $r ($($best.Files) files)"
            }
        }
    }
}

if ($script:problems) {
    Write-Host "`nFinished with $($script:problems) problem(s)." -ForegroundColor Red
    exit 1
}
Write-Host "`n$(if ($apply) { 'Done.' } else { 'Check complete. Nothing was written. Run with -Action Configure to apply.' })" -ForegroundColor Green
