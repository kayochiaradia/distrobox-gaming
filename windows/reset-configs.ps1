<#
.SYNOPSIS
    Re-apply the managed configuration without reinstalling anything.

.DESCRIPTION
    Windows counterpart of ansible/reset-configs.yml: when emulator settings
    got messed up, this puts the project's managed values back (existing
    files are backed up first) and leaves everything else alone.

      configs   configure-emulators.ps1  (BIOS placement + emulator settings)
      desktop   install-shortcuts.ps1    (Start Menu shortcuts)
      esde      bootstrap.ps1            (ES-DE systems, find rules, gamelists)
      verify    verify-setup.ps1

.PARAMETER Tags
    Subset to run, e.g. -Tags configs,esde. Default: all.

.EXAMPLE
    ./reset-configs.ps1
    ./reset-configs.ps1 -Tags esde
#>
[CmdletBinding()]
param(
    [string[]]$Tags = @('configs', 'desktop', 'esde', 'verify'),
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'lib\common.ps1')
$Tags = Resolve-DgTags -Values $Tags -Allowed @('configs', 'desktop', 'esde', 'verify')
$common = @{}
if ($ConfigPath) { $common.ConfigPath = $ConfigPath }

if ('configs' -in $Tags) { & (Join-Path $scriptRoot 'configure-emulators.ps1') -Action Configure @common }
if ('desktop' -in $Tags) { & (Join-Path $scriptRoot 'install-shortcuts.ps1') -Action Configure @common }
if ('esde' -in $Tags) { & (Join-Path $scriptRoot 'bootstrap.ps1') -Action Configure @common }
if ('verify' -in $Tags) {
    & (Join-Path $scriptRoot 'verify-setup.ps1') @common
    exit $LASTEXITCODE
}
