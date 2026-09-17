<#
.SYNOPSIS
    Back up emulator and ES-DE configuration to a zip.

.DESCRIPTION
    Windows counterpart of ansible/backup.yml. Emulators themselves are
    reinstalled by install-apps.ps1, so -- unlike the Linux container image --
    only configuration is archived: the BackupItems in config/maintenance.psd1
    (emulator configs, ES-DE settings/gamelists/custom_systems, your
    localhost.psd1), without caches, shaders, screenshots, logs, saves, states,
    BIOS or ROMs. Restore with restore.ps1.

.PARAMETER List
    List existing backups and exit.

.EXAMPLE
    ./backup.ps1
    ./backup.ps1 -List
#>
[CmdletBinding()]
param(
    [switch]$List,
    [string]$ConfigPath,
    [string]$BackupDir,
    [string]$MaintenanceConfigPath
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'lib\common.ps1')
Add-Type -AssemblyName System.IO.Compression.FileSystem

$config = Get-DgConfig -ConfigPath $ConfigPath -ScriptRoot $scriptRoot
$apps = @(Get-DgApps -ScriptRoot $scriptRoot)
if (-not $MaintenanceConfigPath) { $MaintenanceConfigPath = Join-Path $scriptRoot 'config\maintenance.psd1' }
$maint = Import-ConfigDataFile -Path $MaintenanceConfigPath
if (-not $BackupDir) { $BackupDir = if ($config.ContainsKey('BackupDir')) { $config.BackupDir } else { $maint.BackupDir } }

if ($List) {
    if (-not [IO.Directory]::Exists($BackupDir)) { Write-Host "No backups in $BackupDir"; return }
    Get-ChildItem -LiteralPath $BackupDir -Filter 'distrobox-gaming-config-*.zip' | Sort-Object Name |
        Select-Object @{ n = 'Timestamp'; e = { $_.BaseName -replace '^distrobox-gaming-config-', '' } },
                      @{ n = 'SizeMB'; e = { [math]::Round($_.Length / 1MB, 1) } }, FullName |
        Format-Table -AutoSize
    return
}

function Copy-Tree {
    param([string]$Source, [string]$Dest, [string[]]$Exclude)
    [void][IO.Directory]::CreateDirectory($Dest)
    foreach ($entry in [IO.Directory]::GetFileSystemEntries($Source)) {
        $name = [IO.Path]::GetFileName($entry)
        if ($Exclude -contains $name -or $name -like '*.bak.*') { continue }
        $target = Join-Path $Dest $name
        if ([IO.Directory]::Exists($entry)) { Copy-Tree -Source $entry -Dest $target -Exclude $Exclude }
        else { [IO.File]::Copy($entry, $target, $true) }
    }
}

$timestamp = Get-Date -Format 'yyyyMMddTHHmmss'
$stage = Join-Path ([IO.Path]::GetTempPath()) "dg-backup-$timestamp-$([Guid]::NewGuid().ToString('N'))"
[void][IO.Directory]::CreateDirectory($stage)
$manifest = @()

try {
    foreach ($item in $maint.BackupItems) {
        $source = Expand-DgTokens -Text $item.Path -Config $config -Apps $apps -ScriptRoot $scriptRoot
        if (-not $source) { continue }
        $excludes = @($item.Exclude)
        if ([IO.Directory]::Exists($source)) {
            Copy-Tree -Source $source -Dest (Join-Path $stage $item.Name) -Exclude $excludes
            $manifest += [PSCustomObject]@{ Name = $item.Name; Source = $source; Type = 'dir' }
        } elseif ([IO.File]::Exists($source)) {
            [void][IO.Directory]::CreateDirectory((Join-Path $stage $item.Name))
            [IO.File]::Copy($source, (Join-Path (Join-Path $stage $item.Name) ([IO.Path]::GetFileName($source))), $true)
            $manifest += [PSCustomObject]@{ Name = $item.Name; Source = $source; Type = 'file' }
        } else { continue }
        Write-Host "[backup] $($item.Name): $source" -ForegroundColor Green
    }

    if (-not $manifest) { Write-Host 'Nothing to back up yet.' -ForegroundColor Yellow; return }
    [IO.File]::WriteAllText((Join-Path $stage 'manifest.json'), (ConvertTo-Json -InputObject @($manifest) -Depth 3))

    [void][IO.Directory]::CreateDirectory($BackupDir)
    $zip = Join-Path $BackupDir "distrobox-gaming-config-$timestamp.zip"
    [IO.Compression.ZipFile]::CreateFromDirectory($stage, $zip)
    Write-Host "`nBackup written: $zip ($([math]::Round((Get-Item -LiteralPath $zip).Length / 1MB, 1)) MB). Restore with: ./restore.ps1 -Timestamp $timestamp -Action Configure" -ForegroundColor Green
}
finally {
    [IO.Directory]::Delete($stage, $true)
}
