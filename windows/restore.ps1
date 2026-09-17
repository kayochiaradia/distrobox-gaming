<#
.SYNOPSIS
    Restore emulator and ES-DE configuration from a backup.ps1 zip.

.DESCRIPTION
    Windows counterpart of ansible/restore.yml. Copies every archived file
    back to the path recorded in the backup's manifest, overwriting the
    current file. Files that exist now but weren't in the backup are left
    alone. Before writing, the current configuration is backed up first
    (skip with -NoSafetyBackup), so a restore can itself be undone.

.PARAMETER Timestamp
    Backup to restore (see ./backup.ps1 -List). -Latest picks the newest.

.PARAMETER Action
    'Check' (default) lists what would be restored. 'Configure' restores.

.EXAMPLE
    ./restore.ps1 -Latest
    ./restore.ps1 -Timestamp 20260917T120000 -Action Configure
#>
[CmdletBinding()]
param(
    [string]$Timestamp,
    [switch]$Latest,
    [ValidateSet('Check', 'Configure')]
    [string]$Action = 'Check',
    [switch]$NoSafetyBackup,
    [string]$ConfigPath,
    [string]$BackupDir,
    [string]$MaintenanceConfigPath
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'lib\common.ps1')
Add-Type -AssemblyName System.IO.Compression.FileSystem

$config = Get-DgConfig -ConfigPath $ConfigPath -ScriptRoot $scriptRoot
if (-not $MaintenanceConfigPath) { $MaintenanceConfigPath = Join-Path $scriptRoot 'config\maintenance.psd1' }
$maint = Import-ConfigDataFile -Path $MaintenanceConfigPath
if (-not $BackupDir) { $BackupDir = if ($config.ContainsKey('BackupDir')) { $config.BackupDir } else { $maint.BackupDir } }

$backups = if ([IO.Directory]::Exists($BackupDir)) {
    @(Get-ChildItem -LiteralPath $BackupDir -Filter 'distrobox-gaming-config-*.zip' | Sort-Object Name)
} else { @() }
if (-not $backups) { throw "No backups found in $BackupDir. Create one with ./backup.ps1" }

$zipFile = if ($Latest) { $backups[-1] }
           elseif ($Timestamp) { $backups | Where-Object { $_.BaseName -eq "distrobox-gaming-config-$Timestamp" } }
           else { $null }
if (-not $zipFile) {
    throw "Pass -Latest or -Timestamp. Available: $(($backups | ForEach-Object { $_.BaseName -replace '^distrobox-gaming-config-', '' }) -join ', ')"
}

$apply = $Action -eq 'Configure'
Write-Host "Backup: $($zipFile.FullName)" -ForegroundColor Cyan

if ($apply -and -not $NoSafetyBackup) {
    Write-Host 'Backing up the current configuration first...' -ForegroundColor DarkGray
    $safety = @{ BackupDir = $BackupDir; MaintenanceConfigPath = $MaintenanceConfigPath }
    if ($ConfigPath) { $safety.ConfigPath = $ConfigPath }
    & (Join-Path $scriptRoot 'backup.ps1') @safety | Out-Null
    Start-Sleep -Seconds 1
}

$zip = [IO.Compression.ZipFile]::OpenRead($zipFile.FullName)
try {
    $manifestEntry = $zip.GetEntry('manifest.json')
    if (-not $manifestEntry) { throw 'manifest.json missing -- not a backup.ps1 archive' }
    $reader = New-Object IO.StreamReader($manifestEntry.Open())
    # PowerShell 5.1 emits a JSON array as one object; unroll it.
    $manifest = @(ConvertFrom-Json $reader.ReadToEnd() | ForEach-Object { $_ })
    $reader.Close()

    foreach ($m in $manifest) {
        $prefix = "$($m.Name)/"
        $entries = @($zip.Entries | Where-Object { $_.FullName.Replace('\', '/').StartsWith($prefix) -and $_.Name })
        foreach ($e in $entries) {
            $relative = $e.FullName.Replace('\', '/').Substring($prefix.Length).Replace('/', '\')
            $target = if ($m.Type -eq 'file') { $m.Source } else { Join-Path $m.Source $relative }
            if ($apply) {
                [void][IO.Directory]::CreateDirectory((Split-Path -Parent $target))
                [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $target, $true)
            }
        }
        Write-Host "[$($m.Name)] $(if ($apply) { 'restored' } else { 'would restore' }) $($entries.Count) file(s) -> $($m.Source)" -ForegroundColor $(if ($apply) { 'Green' } else { 'Yellow' })
    }
}
finally { $zip.Dispose() }

if ($apply) { Write-Host "`nRestore complete. Restart ES-DE and any open emulator." -ForegroundColor Green }
else { Write-Host "`nCheck complete. Nothing was written. Run with -Action Configure to restore." -ForegroundColor Green }
