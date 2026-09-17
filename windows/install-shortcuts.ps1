<#
.SYNOPSIS
    Create Start Menu shortcuts for ES-DE and every installed emulator.

.DESCRIPTION
    Windows counterpart of the Linux desktop_apps role and
    scripts/install-host-launchers.sh. Portable and GitHub-release emulators
    have no installer, so nothing else puts them in the Start Menu.

    Shortcuts go into their own Start Menu folder ("distrobox-gaming" by
    default), start in the emulator's folder (portable builds keep their data
    there) and use the emulator's own icon. Like install-host-launchers.sh,
    shortcuts in that folder for apps that are no longer installed are
    removed. Nothing outside the folder is touched.

.PARAMETER Action
    'Check' (default) previews. 'Configure' writes.

.EXAMPLE
    ./install-shortcuts.ps1 -Action Configure
#>
[CmdletBinding()]
param(
    [ValidateSet('Check', 'Configure')]
    [string]$Action = 'Check',

    [string]$ConfigPath,
    [string]$ShortcutsDir
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'lib\common.ps1')

$apply = $Action -eq 'Configure'
$config = Get-DgConfig -ConfigPath $ConfigPath -ScriptRoot $scriptRoot
if (-not $ShortcutsDir) {
    $folder = if ($config.ContainsKey('StartMenuFolder')) { $config.StartMenuFolder } else { 'distrobox-gaming' }
    $ShortcutsDir = Join-Path ([Environment]::GetFolderPath('Programs')) $folder
}

$shell = New-Object -ComObject WScript.Shell
$systemNames = @{}
foreach ($s in (Import-PowerShellDataFile -Path (Join-Path $scriptRoot 'config\esde-systems.psd1')).Systems) {
    $systemNames[$s.Name] = $s.FullName
}

Write-Host "`n== Start Menu shortcuts ($ShortcutsDir) ==" -ForegroundColor Cyan

$wanted = @{}
foreach ($app in Get-DgApps -ScriptRoot $scriptRoot) {
    $exe = Resolve-AppRealExePath -App $app -EmulatorsRoot $config.EmulatorsRoot
    if (-not $exe) { continue }

    $lnk = Join-Path $ShortcutsDir "$($app.name).lnk"
    $wanted[$lnk] = $true
    $description = if ($app.role -eq 'frontend') { 'Emulator frontend' } else {
        $names = @($app.systems | ForEach-Object { if ($systemNames.ContainsKey($_)) { $systemNames[$_] } else { $_ } })
        if ($names.Count -gt 4) { "$($names[0..3] -join ', ') and $($names.Count - 4) more" } else { $names -join ', ' }
    }
    $workDir = Split-Path -Parent $exe

    $state = 'up to date'
    if ([IO.File]::Exists($lnk)) {
        $current = $shell.CreateShortcut($lnk)
        if ($current.TargetPath -ne $exe -or $current.WorkingDirectory -ne $workDir -or $current.Description -ne $description) {
            $state = 'updated'
        }
    } else {
        $state = 'created'
    }

    if ($state -ne 'up to date' -and $apply) {
        [void][IO.Directory]::CreateDirectory($ShortcutsDir)
        $s = $shell.CreateShortcut($lnk)
        $s.TargetPath = $exe
        $s.WorkingDirectory = $workDir
        $s.IconLocation = "$exe,0"
        $s.Description = $description
        $s.Save()
    }
    $verb = if ($state -eq 'up to date' -or $apply) { $state } else { "would be $state" }
    Write-Host "[$($app.name)] $verb" -ForegroundColor $(if ($state -eq 'up to date') { 'Green' } else { 'Yellow' })
}

if ([IO.Directory]::Exists($ShortcutsDir)) {
    foreach ($stale in [IO.Directory]::GetFiles($ShortcutsDir, '*.lnk')) {
        if ($wanted.ContainsKey($stale)) { continue }
        if ($apply) { [IO.File]::Delete($stale) }
        Write-Host "[$([IO.Path]::GetFileNameWithoutExtension($stale))] $(if ($apply) { 'removed' } else { 'would be removed' }) (no longer installed)" -ForegroundColor Yellow
    }
}

if ($apply) { Write-Host "`nShortcuts are in the Start Menu under '$(Split-Path -Leaf $ShortcutsDir)'." -ForegroundColor Green }
else { Write-Host "`nCheck complete. Nothing was written. Run with -Action Configure to apply." -ForegroundColor Green }
