<#
.SYNOPSIS
    Full Windows setup in one run.

.DESCRIPTION
    Windows counterpart of ansible/site.yml. Runs, in order:

      install   install-apps.ps1          every emulator + ES-DE
      cores     install-cores.ps1         RetroArch cores and asset packs
      esde      bootstrap.ps1             ES-DE systems, find rules, gamelists
      desktop   install-shortcuts.ps1     Start Menu shortcuts
      configs   configure-emulators.ps1   BIOS placement + emulator settings
      verify    verify-setup.ps1          post-setup assertions

    Every step is idempotent, so rerunning is safe. Emulators only get their
    settings once they have written their own config (first launch), so run
    this again after opening each emulator once.

.PARAMETER Tags
    Subset to run, e.g. -Tags install,cores. Default: all.

.EXAMPLE
    ./site.ps1
    ./site.ps1 -Tags esde,configs,verify
#>
[CmdletBinding()]
param(
    [string[]]$Tags = @('install', 'cores', 'esde', 'desktop', 'configs', 'verify'),
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'lib\common.ps1')
$Tags = Resolve-DgTags -Values $Tags -Allowed @('install', 'cores', 'esde', 'desktop', 'configs', 'verify')
$common = @{}
if ($ConfigPath) { $common.ConfigPath = $ConfigPath }

function Invoke-Step {
    param([string]$Title, [scriptblock]$Body)
    Write-Host "`n########## $Title ##########" -ForegroundColor Magenta
    & $Body
}

$failed = @()
if ('install' -in $Tags) {
    Invoke-Step 'install-apps' { & (Join-Path $scriptRoot 'install-apps.ps1') @common }
    if ($LASTEXITCODE) { $failed += 'install-apps' }
}
if ('cores' -in $Tags) {
    Invoke-Step 'install-cores' { & (Join-Path $scriptRoot 'install-cores.ps1') @common }
    if ($LASTEXITCODE) { $failed += 'install-cores' }
}
if ('esde' -in $Tags) { Invoke-Step 'bootstrap' { & (Join-Path $scriptRoot 'bootstrap.ps1') -Action Configure @common } }
if ('desktop' -in $Tags) { Invoke-Step 'install-shortcuts' { & (Join-Path $scriptRoot 'install-shortcuts.ps1') -Action Configure @common } }
if ('configs' -in $Tags) { Invoke-Step 'configure-emulators' { & (Join-Path $scriptRoot 'configure-emulators.ps1') -Action Configure @common } }
if ('verify' -in $Tags) {
    Invoke-Step 'verify-setup' { & (Join-Path $scriptRoot 'verify-setup.ps1') @common }
    if ($LASTEXITCODE) { $failed += 'verify-setup' }
}

if ($failed) {
    Write-Host "`nFinished with problems in: $($failed -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host "`nSetup complete." -ForegroundColor Green
