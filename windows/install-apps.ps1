<#
.SYNOPSIS
    Installs (or lists/checks) every emulator in apps.json.

.DESCRIPTION
    Counterpart of the Linux bootstrap_packages/install_* roles and
    macos/install-apps.sh. Three sources, per apps.json entry:

      winget  -- winget install; portable (zip) packages are placed in
                 <EmulatorsRoot>\<installDir> (default %USERPROFILE%\Emulators)
      github  -- latest release asset matching assetPattern, extracted with
                 Windows' built-in tar.exe into <EmulatorsRoot>\<installDir>
      manual  -- the site blocks scripted downloads; prints where to put it

    Already-installed apps are skipped (use -Update to refresh GitHub-sourced
    ones). Nothing is ever uninstalled.

.PARAMETER Only
    Limit to these app ids, e.g. -Only rpcs3,flycast

.EXAMPLE
    ./install-apps.ps1
    ./install-apps.ps1 -Check
    ./install-apps.ps1 -Only rpcs3 -Update
#>
[CmdletBinding()]
param(
    [switch]$List,
    [switch]$Check,
    [switch]$Update,
    [string[]]$Only,
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptRoot 'lib\common.ps1')

$config = Get-DgConfig -ConfigPath $ConfigPath -ScriptRoot $scriptRoot
$emulatorsRoot = $config.EmulatorsRoot
$apps = @(Get-DgApps -ScriptRoot $scriptRoot)
if ($Only) {
    $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $unknown = $Only | Where-Object { $_ -notin $apps.id }
    if ($unknown) { throw "Unknown app id(s): $($unknown -join ', '). Valid: $($apps.id -join ', ')" }
    $apps = @($apps | Where-Object { $_.id -in $Only })
}

if ($List) {
    $apps | ForEach-Object {
        [PSCustomObject]@{
            Id      = $_.id
            Name    = $_.name
            Source  = $_.source
            From    = if ($_.wingetId) { $_.wingetId } elseif ($_.repo) { "github:$($_.repo)" } else { $_.manualUrl }
            Systems = ($_.systems -join ' ')
        }
    } | Format-Table -AutoSize -Wrap
    return
}

if ($Check) {
    $rows = foreach ($app in $apps) {
        $exe = Resolve-AppRealExePath -App $app -EmulatorsRoot $emulatorsRoot
        [PSCustomObject]@{ Id = $app.id; Name = $app.name; Source = $app.source; Installed = [bool]$exe; Path = $exe }
    }
    $rows | Format-Table -AutoSize
    $missing = @($rows | Where-Object { -not $_.Installed })
    if ($missing) { Write-Host "Missing: $($missing.Name -join ', ')" -ForegroundColor Yellow }
    else { Write-Host 'All apps are installed.' -ForegroundColor Green }
    return
}

# ---------------------------------------------------------------------------
# Installers
# ---------------------------------------------------------------------------

$knownFailures = @(
    @{ Match = 'canceled by the user|You cancelled the installation|ERROR_INSTALL_USERCANCEL'
       Hint  = 'needs Administrator approval (UAC). Rerun from an interactive PowerShell window and accept the prompt.' }
    @{ Match = 'Forbidden \(403\)|Download request status is not success'
       Hint  = 'the download server refused the request (HTTP 403). Retry later or download it manually.' }
    @{ Match = 'No applicable installer found'
       Hint  = 'winget has no installer for this machine/scope.' }
)

function Install-FromWinget {
    param($App)
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget was not found. Install 'App Installer' from the Microsoft Store."
    }
    $wingetArgs = @('install', '--id', $App.wingetId, '--exact', '--silent', '--source', 'winget',
        '--accept-package-agreements', '--accept-source-agreements')
    if ($App.installDir) {
        $wingetArgs += @('--location', (Join-Path $emulatorsRoot $App.installDir))
    }
    $output = & winget @wingetArgs 2>&1
    $output | ForEach-Object { Write-Host "    $_" }

    # A portable install that failed midway can leave winget believing the
    # package is installed with no files on disk. The caller only gets here
    # when the exe is missing, so drop the orphaned registration and retry.
    if ($LASTEXITCODE -ne 0 -and ($output -join "`n") -match 'existing package already installed') {
        Write-Host '    winget has a stale registration with no files; removing it and retrying' -ForegroundColor Yellow
        & winget uninstall --id $App.wingetId --exact --silent --source winget 2>&1 | ForEach-Object { Write-Host "    $_" }
        $output = & winget @wingetArgs 2>&1
        $output | ForEach-Object { Write-Host "    $_" }
    }

    if ($LASTEXITCODE -ne 0) {
        $text = $output -join "`n"
        $hint = ($knownFailures | Where-Object { $text -match $_.Match } | Select-Object -First 1).Hint
        if (-not $hint) { $hint = "winget exited with code $LASTEXITCODE." }
        throw $hint
    }
}

function Install-FromGitHub {
    param($App)
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$($App.repo)/releases/latest" `
        -Headers @{ 'User-Agent' = 'distrobox-gaming-windows' }
    $asset = $release.assets | Where-Object { $_.name -match $App.assetPattern } | Select-Object -First 1
    if (-not $asset) { throw "no asset matching '$($App.assetPattern)' in $($App.repo) release $($release.tag_name)" }

    $dest = Join-Path $emulatorsRoot $App.installDir
    $marker = Join-Path $dest '.dg-release'
    if ((Test-Path $marker) -and ((Get-Content $marker -Raw).Trim() -eq $release.tag_name)) {
        Write-Host "    already at $($release.tag_name)" -ForegroundColor DarkGray
        return
    }

    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("dg-" + [Guid]::NewGuid().ToString('N') + '-' + $asset.name)
    try {
        Write-Host "    downloading $($asset.name) ($([math]::Round($asset.size / 1MB, 1)) MB, $($release.tag_name))"
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmp -UseBasicParsing `
            -Headers @{ 'User-Agent' = 'distrobox-gaming-windows' }
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        & "$env:SystemRoot\System32\tar.exe" -xf $tmp -C $dest
        if ($LASTEXITCODE -ne 0) { throw "tar.exe could not extract $($asset.name) (exit $LASTEXITCODE)" }
        Set-Content -Path $marker -Value $release.tag_name -Encoding ASCII
    }
    finally {
        Remove-Item -Path $tmp -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "Emulators root: $emulatorsRoot" -ForegroundColor Cyan
if ($apps | Where-Object { $_.uac }) {
    Write-Host 'Some installers ask for Administrator approval (UAC) -- run this from an interactive window.' -ForegroundColor DarkGray
}

$failures = @()
$manual = @()
foreach ($app in $apps) {
    $existing = Resolve-AppRealExePath -App $app -EmulatorsRoot $emulatorsRoot
    $refresh = $Update -and $app.source -eq 'github'
    if ($existing -and -not $refresh) {
        Write-Host "[skip] $($app.name): $existing" -ForegroundColor DarkGray
        continue
    }

    Write-Host "[$($app.source)] $($app.name)" -ForegroundColor Cyan
    if ($app.source -eq 'manual') {
        $target = Join-Path (Join-Path $emulatorsRoot $app.installDir) $app.exeNames[0]
        Write-Host "    manual install required -> $target" -ForegroundColor Yellow
        if ($app.manualUrl) { Write-Host "    download: $($app.manualUrl)" -ForegroundColor Yellow }
        Write-Host "    $($app.notes)" -ForegroundColor Yellow
        $manual += $app.name
        continue
    }
    try {
        if ($app.source -eq 'winget') { Install-FromWinget -App $app }
        elseif ($app.source -eq 'github') { Install-FromGitHub -App $app }
        else { throw "unknown source '$($app.source)'" }
        $installed = Resolve-AppRealExePath -App $app -EmulatorsRoot $emulatorsRoot
        if (-not $installed) { throw "installer finished but none of $($app.exeNames -join ', ') was found" }
        Write-Host "    ok: $installed" -ForegroundColor Green
    }
    catch {
        Write-Host "[FAILED] $($app.name): $($_.Exception.Message)" -ForegroundColor Red
        $failures += $app.name
    }
}

if ($manual) { Write-Host "`nManual downloads still needed: $($manual -join ', ')" -ForegroundColor Yellow }
if ($failures) {
    Write-Host "Failed: $($failures -join ', '). Rerun after fixing -- installed apps are skipped." -ForegroundColor Red
    exit 1
}
Write-Host "`nDone. Next: ./install-cores.ps1, then ./bootstrap.ps1 -Action Configure." -ForegroundColor Green
