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
        ConfigPath          = $ConfigPath
    }
    if (Test-Path $ConfigPath) {
        $user = Import-ConfigDataFile -Path $ConfigPath
        foreach ($k in $user.Keys) { $config[$k] = $user[$k] }
    }
    return $config
}

function Get-DgApps {
    param([string]$ScriptRoot)
    return (Get-Content -Raw -Path (Join-Path $ScriptRoot 'apps.json') | ConvertFrom-Json).apps
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

    if ($App.wingetId) {
        $pkgRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
        if (Test-Path $pkgRoot) {
            foreach ($dir in Get-ChildItem -Path $pkgRoot -Directory -Filter "$($App.wingetId)_*" -ErrorAction SilentlyContinue) {
                $hit = Find-ExeUnder -Root $dir.FullName -ExeNames $App.exeNames
                if ($hit) { return $hit }
            }
        }
    }

    $onPath = Get-PathExe -ExeNames $App.exeNames
    if ($onPath -and $onPath -notlike '*\WinGet\Links\*') { return $onPath }

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
