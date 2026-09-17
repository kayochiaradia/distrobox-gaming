<#
    Shared helpers for the windows/ scripts (dot-sourced).
#>

# Import-PowerShellDataFile rejects $env: expressions, so config files use
# %VAR% placeholders that are expanded here after loading.
function Expand-ConfigValue {
    param($Value)
    if ($Value -is [string]) { return [Environment]::ExpandEnvironmentVariables($Value) }
    if ($Value -is [hashtable]) {
        $out = @{}
        foreach ($k in $Value.Keys) { $out[$k] = Expand-ConfigValue -Value $Value[$k] }
        return $out
    }
    if ($Value -is [array]) { return ,@($Value | ForEach-Object { Expand-ConfigValue -Value $_ }) }
    return $Value
}

function Import-ConfigDataFile {
    param([string]$Path)
    return Expand-ConfigValue -Value (Import-PowerShellDataFile -Path $Path)
}

# Defaults merged with config/localhost.psd1 (or -ConfigPath). Everything
# lives on C: unless the user overrides it.
function Get-DgConfig {
    param([string]$ConfigPath, [string]$ScriptRoot)
    if (-not $ConfigPath) { $ConfigPath = Join-Path $ScriptRoot 'config\localhost.psd1' }
    $config = @{
        EsdeHome            = "$env:USERPROFILE\ES-DE"
        RomRoot             = "$env:USERPROFILE\ES-DE\ROMs"
        RomPaths            = @{}
        CreateRomDirs       = $false
        BiosRoot            = "$env:USERPROFILE\ES-DE\BIOS"
        EmulatorsRoot       = "$env:USERPROFILE\Emulators"
        EmulatorConfigPaths = @{}
        ParseGamelistOnly   = $false
        ConfigPath          = $ConfigPath
    }
    if (Test-Path $ConfigPath) {
        $user = Import-ConfigDataFile -Path $ConfigPath
        foreach ($k in $user.Keys) { $config[$k] = $user[$k] }
    }

    # The portable ES-DE release keeps its home inside its own folder
    # (<ES-DE dir>\ES-DE, flagged by portable.txt) instead of %USERPROFILE%\ES-DE.
    if (-not ($user -and $user.ContainsKey('EsdeHome')) -and $ScriptRoot) {
        $esde = Get-DgApps -ScriptRoot $ScriptRoot | Where-Object { $_.id -eq 'esde' }
        $esdeExe = if ($esde) { Resolve-AppRealExePath -App $esde -EmulatorsRoot $config.EmulatorsRoot } else { $null }
        if ($esdeExe -and [IO.File]::Exists((Join-Path (Split-Path -Parent $esdeExe) 'portable.txt'))) {
            $config.EsdeHome = Join-Path (Split-Path -Parent $esdeExe) 'ES-DE'
            $config.EsdeHomeSource = 'portable ES-DE'
        }
    }
    return $config
}

# Extracts an archive into $Destination, overwriting existing files. .zip goes
# through .NET, which decodes UTF-8 entry names (Windows tar.exe skips
# non-ASCII names, e.g. dozens of entries in RetroArch's cheats.zip); .7z and
# .rar go through the built-in tar.exe (libarchive).
function Expand-DgArchive {
    param([string]$Path, [string]$Destination)
    [void][IO.Directory]::CreateDirectory($Destination)
    if ([IO.Path]::GetExtension($Path) -ieq '.zip') {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $root = [IO.Path]::GetFullPath($Destination).TrimEnd('\') + '\'
        $zip = [IO.Compression.ZipFile]::OpenRead($Path)
        try {
            foreach ($entry in $zip.Entries) {
                $target = [IO.Path]::GetFullPath((Join-Path $root $entry.FullName))
                if (-not $target.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
                    throw "archive entry escapes the destination: $($entry.FullName)"
                }
                if ($entry.FullName.EndsWith('/') -or $entry.FullName.EndsWith('\')) {
                    [void][IO.Directory]::CreateDirectory($target)
                    continue
                }
                [void][IO.Directory]::CreateDirectory((Split-Path -Parent $target))
                [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
            }
        }
        finally { $zip.Dispose() }
        return
    }
    & "$env:SystemRoot\System32\tar.exe" -xf $Path -C $Destination
    if ($LASTEXITCODE -ne 0) { throw "tar.exe could not extract $([IO.Path]::GetFileName($Path)) (exit $LASTEXITCODE)" }
}

function Get-DgApps {
    param([string]$ScriptRoot)
    return (Get-Content -Raw -Path (Join-Path $ScriptRoot 'apps.json') | ConvertFrom-Json).apps
}

# -Tags/-Only values: "a,b" arrives as one string through powershell -File,
# so split on commas and validate against the allowed set.
function Resolve-DgTags {
    param([string[]]$Values, [string[]]$Allowed)
    $tags = @($Values | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $bad = @($tags | Where-Object { $_ -notin $Allowed })
    if ($bad) { throw "Unknown tag(s): $($bad -join ', '). Valid: $($Allowed -join ', ')" }
    return $tags
}

# Token expansion shared by the config-driven scripts. Returns $null when a
# {dir:<app>} token names an app that isn't installed.
#   {dir:<app id>}      folder of that app's installed exe
#   {esdehome}          detected ES-DE home
#   {scriptroot}        the windows/ folder
#   {reporoot}          the repository root
#   {{BiosRoot}}        BiosRoot
#   {{RomRoot}}         RomRoot
#   {{RomPath:<sys>}}   RomPaths override or RomRoot\<sys>
#   {{RomDirName:<sys>}} leaf folder name of that ROM path
$script:DgAppDirCache = @{}
function Get-DgAppDir {
    param([string]$Id, $Config, $Apps)
    if (-not $script:DgAppDirCache.ContainsKey($Id)) {
        $app = $Apps | Where-Object { $_.id -eq $Id }
        $exe = if ($app) { Resolve-AppRealExePath -App $app -EmulatorsRoot $Config.EmulatorsRoot } else { $null }
        $script:DgAppDirCache[$Id] = if ($exe) { Split-Path -Parent $exe } else { $null }
    }
    return $script:DgAppDirCache[$Id]
}

function Get-DgRomPath {
    param([string]$System, $Config)
    if ($Config.RomPaths -and $Config.RomPaths.ContainsKey($System)) { return $Config.RomPaths[$System] }
    return Join-Path $Config.RomRoot $System
}

function Expand-DgTokens {
    param([string]$Text, $Config, $Apps, [string]$ScriptRoot)
    $out = $Text
    foreach ($m in [regex]::Matches($Text, '\{dir:([a-z0-9]+)\}')) {
        $dir = Get-DgAppDir -Id $m.Groups[1].Value -Config $Config -Apps $Apps
        if (-not $dir) { return $null }
        $out = $out.Replace($m.Value, $dir)
    }
    foreach ($m in [regex]::Matches($out, '\{\{RomPath:([a-z0-9]+)\}\}')) {
        $out = $out.Replace($m.Value, (Get-DgRomPath -System $m.Groups[1].Value -Config $Config))
    }
    foreach ($m in [regex]::Matches($out, '\{\{RomDirName:([a-z0-9]+)\}\}')) {
        $out = $out.Replace($m.Value, [IO.Path]::GetFileName((Get-DgRomPath -System $m.Groups[1].Value -Config $Config).TrimEnd('\')))
    }
    $out = $out.Replace('{{BiosRoot}}', $Config.BiosRoot).Replace('{{RomRoot}}', $Config.RomRoot).Replace('{esdehome}', $Config.EsdeHome)
    if ($ScriptRoot) { $out = $out.Replace('{scriptroot}', $ScriptRoot).Replace('{reporoot}', (Split-Path -Parent $ScriptRoot)) }
    return $out
}

function Get-PathExe {
    param([string[]]$ExeNames)
    foreach ($exe in $ExeNames) {
        $cmd = Get-Command $exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd) { return $cmd.Source }
    }
    return $null
}

function Get-AppPathsRegistryExe {
    param([string[]]$ExeNames)
    foreach ($root in @('HKCU:', 'HKLM:')) {
        foreach ($exe in $ExeNames) {
            $keyPath = Join-Path $root "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$exe"
            if (-not (Test-Path $keyPath)) { continue }
            $default = (Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue).'(default)'
            if ($default) {
                $default = $default.Trim('"')
                if (Test-Path $default) { return $default }
            }
        }
    }
    return $null
}

function Get-UninstallKeyExe {
    param($UninstallKey)
    if (-not $UninstallKey) { return $null }
    foreach ($hive in @('HKCU:', 'HKLM:')) {
        $keyPath = Join-Path $hive $UninstallKey.path
        if (-not (Test-Path $keyPath)) { continue }
        $installLoc = (Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue).($UninstallKey.valueName)
        if ($installLoc) {
            $candidate = Join-Path $installLoc $UninstallKey.exeName
            if (Test-Path $candidate) { return $candidate }
        }
    }
    return $null
}

function Find-ExeUnder {
    param([string]$Root, [string[]]$ExeNames, [int]$Depth = 3)
    if (-not $Root -or -not (Test-Path $Root)) { return $null }
    foreach ($exe in $ExeNames) {
        $hit = Get-ChildItem -Path $Root -Recurse -Depth $Depth -Filter $exe -File -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

# Real installed exe for an app, or $null. Order: the project's own install
# dir, winget's portable package dir, PATH, registry, then standard install
# roots.
function Resolve-AppRealExePath {
    param($App, [string]$EmulatorsRoot)

    if ($App.installDir) {
        $hit = Find-ExeUnder -Root (Join-Path $EmulatorsRoot $App.installDir) -ExeNames $App.exeNames
        if ($hit) { return $hit }
    }
    # ownInstallOnly: never adopt a copy found elsewhere (e.g. a system Python
    # on PATH, which pip would then modify).
    if ($App.ownInstallOnly) { return $null }

    if ($App.wingetId) {
        $pkgRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
        if (Test-Path $pkgRoot) {
            foreach ($dir in Get-ChildItem -Path $pkgRoot -Directory -Filter "$($App.wingetId)_*" -ErrorAction SilentlyContinue) {
                $hit = Find-ExeUnder -Root $dir.FullName -ExeNames $App.exeNames
                if ($hit) { return $hit }
            }
        }
    }

    # WinGet\Links holds alias shims; WindowsApps holds Microsoft Store App
    # Execution Aliases (e.g. a python.exe stub that only opens the Store).
    $onPath = Get-PathExe -ExeNames $App.exeNames
    if ($onPath -and $onPath -notlike '*\WinGet\Links\*' -and $onPath -notlike '*\WindowsApps\*') { return $onPath }

    if ($App.registryAppPaths) {
        $viaAppPaths = Get-AppPathsRegistryExe -ExeNames $App.registryAppPaths
        if ($viaAppPaths) { return $viaAppPaths }
    }

    $viaUninstall = Get-UninstallKeyExe -UninstallKey $App.registryUninstallKey
    if ($viaUninstall) { return $viaUninstall }

    foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, (Join-Path $env:LOCALAPPDATA 'Programs'), 'C:\RetroArch-Win64')) {
        $hit = Find-ExeUnder -Root $root -ExeNames $App.exeNames -Depth 2
        if ($hit) { return $hit }
    }
    return $null
}
