<#
.SYNOPSIS
    Installs (or lists/checks) the emulators, tools and ports in apps.json.

.DESCRIPTION
    Counterpart of the Linux bootstrap_packages/install_* roles and
    macos/install-apps.sh. Sources, per apps.json entry (all portable, into
    <EmulatorsRoot>\<installDir>, default %USERPROFILE%\Emulators):

      winget  -- winget portable package
      github  -- newest release asset matching assetPattern (includePrerelease
                 for projects that only publish pre-releases)
      gitlab  -- newest GitLab release link matching assetPattern
      url     -- newest version found on an index page (e.g. RetroArch buildbot)
      manual  -- the site blocks scripted downloads; prints where to put it

    Entries with a "group" (ports, pctools) are optional, like the Linux
    never-tagged roles: they install only with -Group or -Only.
    Already-installed apps are skipped (-Update refreshes release-based ones).
    Nothing is ever uninstalled.

.PARAMETER Only
    Limit to these app ids, e.g. -Only rpcs3,flycast

.PARAMETER Group
    Also include optional groups, e.g. -Group ports,pctools

.EXAMPLE
    ./install-apps.ps1
    ./install-apps.ps1 -Group ports -List
    ./install-apps.ps1 -Only rpcs3 -Update
#>
[CmdletBinding()]
param(
    [switch]$List,
    [switch]$Check,
    [switch]$Update,
    [string[]]$Only,
    [string[]]$Group,
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
    $Only = Resolve-DgTags -Values $Only -Allowed $apps.id
    $apps = @($apps | Where-Object { $_.id -in $Only })
} else {
    $groups = @($apps | Where-Object { $_.group } | ForEach-Object { $_.group } | Sort-Object -Unique)
    $Group = if ($Group) { Resolve-DgTags -Values $Group -Allowed $groups } else { @() }
    $apps = @($apps | Where-Object { -not $_.group -or $_.group -in $Group })
}

if ($List) {
    $apps | ForEach-Object {
        [PSCustomObject]@{
            Id      = $_.id
            Name    = $_.name
            Source  = $_.source
            From    = switch ($_.source) {
                'winget' { $_.wingetId }
                'github' { "github:$($_.repo)" }
                'gitlab' { "gitlab:$($_.project)" }
                'url'    { $_.urlTemplate }
                default  { $_.manualUrl }
            }
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

$userAgent = @{ 'User-Agent' = 'distrobox-gaming-windows' }

# Resolves an app's newest release to @{ Version; Url; FileName }.
function Get-ReleaseArchive {
    param($App)
    switch ($App.source) {
        'github' {
            # includePrerelease: some projects only publish pre-releases, which
            # /releases/latest never returns; take the newest release (of any
            # kind) that has a matching asset.
            $releases = if ($App.includePrerelease) {
                @(Invoke-RestMethod -Uri "https://api.github.com/repos/$($App.repo)/releases?per_page=15" -Headers $userAgent)
            } else {
                @(Invoke-RestMethod -Uri "https://api.github.com/repos/$($App.repo)/releases/latest" -Headers $userAgent)
            }
            foreach ($release in $releases | ForEach-Object { $_ }) {
                $asset = $release.assets | Where-Object { $_.name -match $App.assetPattern } | Select-Object -First 1
                if ($asset) { return @{ Version = $release.tag_name; Url = $asset.browser_download_url; FileName = $asset.name } }
            }
            throw "no asset matching '$($App.assetPattern)' in $($App.repo) releases"
        }
        'gitlab' {
            $project = [Uri]::EscapeDataString($App.project)
            $release = Invoke-RestMethod -Uri "https://gitlab.com/api/v4/projects/$project/releases/permalink/latest" -Headers $userAgent
            $link = $release.assets.links | Where-Object { $_.name -match $App.assetPattern } | Select-Object -First 1
            if (-not $link) { throw "no asset matching '$($App.assetPattern)' in $($App.project) release $($release.tag_name)" }
            return @{ Version = $release.tag_name; Url = $link.url; FileName = $link.name }
        }
        'url' {
            if ($App.url) {
                return @{ Version = $App.version; Url = $App.url; FileName = [IO.Path]::GetFileName(([Uri]$App.url).AbsolutePath) }
            }
            $index =(Invoke-WebRequest -Uri $App.versionIndexUrl -UseBasicParsing -Headers $userAgent).Content
            $versions = @([regex]::Matches($index, $App.versionRegex) | ForEach-Object { [version]$_.Groups[1].Value } | Sort-Object -Descending)
            if (-not $versions) { throw "no version matching '$($App.versionRegex)' at $($App.versionIndexUrl)" }
            # probeUrl: index folders can exist before their files (pre-releases),
            # so take the newest version whose download actually exists.
            $candidates = if ($App.probeUrl) { @($versions | Select-Object -First 15) } else { @($versions[0]) }
            foreach ($v in $candidates) {
                $url = $App.urlTemplate.Replace('{version}', $v.ToString())
                if ($App.probeUrl) {
                    try { [void](Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -Headers $userAgent) }
                    catch { continue }
                }
                return @{ Version = $v.ToString(); Url = $url; FileName = [IO.Path]::GetFileName(([Uri]$url).AbsolutePath) }
            }
            throw "none of the newest versions at $($App.versionIndexUrl) has $($App.urlTemplate)"
        }
    }
    throw "source '$($App.source)' has no release archive"
}

function Install-FromArchive {
    param($App)
    $archive = Get-ReleaseArchive -App $App
    $dest = Join-Path $emulatorsRoot $App.installDir
    $marker = Join-Path $dest '.dg-release'
    if ([IO.File]::Exists($marker) -and ([IO.File]::ReadAllText($marker).Trim() -eq $archive.Version)) {
        Write-Host "    already at $($archive.Version)" -ForegroundColor DarkGray
        return
    }

    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("dg-" + [Guid]::NewGuid().ToString('N') + '-' + $archive.FileName)
    try {
        Write-Host "    downloading $($archive.FileName) ($($archive.Version))"
        Invoke-WebRequest -Uri $archive.Url -OutFile $tmp -UseBasicParsing -Headers $userAgent
        if ($App.installerArgs) {
            # Per-user installer run silently into the install dir (no UAC).
            $argList = $App.installerArgs.Replace('{dest}', $dest)
            $proc = Start-Process -FilePath $tmp -ArgumentList $argList -Wait -PassThru
            if ($proc.ExitCode -ne 0) { throw "installer exited with code $($proc.ExitCode)" }
        } elseif ($archive.FileName -like '*.exe') {
            # A single portable executable.
            [void][IO.Directory]::CreateDirectory($dest)
            [IO.File]::Copy($tmp, (Join-Path $dest $archive.FileName), $true)
        } else {
            Expand-DgArchive -Path $tmp -Destination $dest
        }
        [void][IO.Directory]::CreateDirectory($dest)
        [IO.File]::WriteAllText($marker, $archive.Version)
    }
    finally {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
}

# The embeddable Python ships without pip and ignores site-packages until
# "import site" is enabled in its pythonXY._pth. Idempotent: only acts when
# a listed package can't be imported.
function Install-PipPackages {
    param($App, [string]$PythonExe)
    $ErrorActionPreference = 'Continue'
    $missing = @($App.pipPackages | Where-Object {
        & $PythonExe -c "import $_" 2>$null | Out-Null
        $LASTEXITCODE -ne 0
    })
    if (-not $missing) { return }

    $pyDir = Split-Path -Parent $PythonExe
    foreach ($pth in [IO.Directory]::GetFiles($pyDir, 'python*._pth')) {
        $text = [IO.File]::ReadAllText($pth)
        if ($text -match '(?m)^#\s*import site') {
            [IO.File]::WriteAllText($pth, ($text -replace '(?m)^#\s*import site', 'import site'))
        }
    }
    & $PythonExe -m pip --version 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        $getPip = Join-Path ([IO.Path]::GetTempPath()) "dg-get-pip-$([Guid]::NewGuid().ToString('N')).py"
        try {
            Invoke-WebRequest -Uri 'https://bootstrap.pypa.io/get-pip.py' -OutFile $getPip -UseBasicParsing -Headers $userAgent
            & $PythonExe $getPip --no-warn-script-location 2>&1 | Select-Object -Last 2 | ForEach-Object { Write-Host "    $_" }
            if ($LASTEXITCODE -ne 0) { throw "get-pip.py failed (exit $LASTEXITCODE)" }
        } finally { Remove-Item -LiteralPath $getPip -Force -ErrorAction SilentlyContinue }
    }
    Write-Host "    pip install $($missing -join ' ')"
    & $PythonExe -m pip install --only-binary=:all: --no-warn-script-location @missing 2>&1 | Select-Object -Last 2 | ForEach-Object { Write-Host "    $_" }
    if ($LASTEXITCODE -ne 0) { throw "pip install $($missing -join ' ') failed (exit $LASTEXITCODE)" }
}

# Pinned add-ons installed next to an app's exe (e.g. HD .o2r packs into a
# port's mods folder), same URL + SHA-256 pinning as the Linux roles. A
# <dest>.dg-ref file records the installed hash, so reruns skip them.
function Install-AppExtras {
    param($App, [string]$ExePath)
    foreach ($x in $App.extras) {
        $dest = Join-Path (Split-Path -Parent $ExePath) $x.dest
        $ref = "$dest.dg-ref"
        if ([IO.File]::Exists($dest) -and [IO.File]::Exists($ref) -and [IO.File]::ReadAllText($ref).Trim() -eq $x.sha256) { continue }

        $name = [IO.Path]::GetFileName(([Uri]$x.url).AbsolutePath)
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ("dg-extra-" + [Guid]::NewGuid().ToString('N') + '-' + $name)
        $stage = "$tmp.d"
        try {
            Write-Host "    extra: downloading $name"
            Invoke-WebRequest -Uri $x.url -OutFile $tmp -UseBasicParsing -Headers $userAgent
            $hash = (Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash.ToLower()
            if ($hash -ne $x.sha256) { throw "$name SHA-256 mismatch (got $hash)" }
            $source = $tmp
            if ($x.member) {
                Expand-DgArchive -Path $tmp -Destination $stage
                $source = (Get-ChildItem -LiteralPath $stage -Recurse -File -Filter $x.member | Select-Object -First 1).FullName
                if (-not $source) { throw "$($x.member) not found inside $name" }
            }
            [void][IO.Directory]::CreateDirectory((Split-Path -Parent $dest))
            [IO.File]::Copy($source, $dest, $true)
            [IO.File]::WriteAllText($ref, $x.sha256)
            Write-Host "    extra: $($x.dest)" -ForegroundColor Green
        }
        finally {
            Remove-Item -LiteralPath $tmp, $stage -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host "Emulators root: $emulatorsRoot" -ForegroundColor Cyan

$failures = @()
$manual = @()
foreach ($app in $apps) {
    $existing = Resolve-AppRealExePath -App $app -EmulatorsRoot $emulatorsRoot
    $refresh = $Update -and $app.source -in 'github', 'gitlab', 'url'
    if ($existing -and -not $refresh) {
        Write-Host "[skip] $($app.name): $existing" -ForegroundColor DarkGray
        try {
            if ($app.pipPackages) { Install-PipPackages -App $app -PythonExe $existing }
            if ($app.extras) { Install-AppExtras -App $app -ExePath $existing }
        }
        catch { Write-Host "[FAILED] $($app.name): $($_.Exception.Message)" -ForegroundColor Red; $failures += $app.name }
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
        elseif ($app.source -in 'github', 'gitlab', 'url') { Install-FromArchive -App $app }
        else { throw "unknown source '$($app.source)'" }
        $installed = Resolve-AppRealExePath -App $app -EmulatorsRoot $emulatorsRoot
        if (-not $installed) { throw "installer finished but none of $($app.exeNames -join ', ') was found" }
        if ($app.pipPackages) { Install-PipPackages -App $app -PythonExe $installed }
        if ($app.extras) { Install-AppExtras -App $app -ExePath $installed }
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
