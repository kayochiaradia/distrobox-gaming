<#
    Shared functions for the windows/ scripts (dot-sourced by bootstrap.ps1
    and configure-emulators.ps1). Detection logic mirrors ES-DE's own Windows
    es_find_rules.xml: PATH, App Paths / uninstall registry, then the
    Emulators\<name>\ static path ES-DE already checks.
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

function Test-OnPath {
    param([string[]]$ExeNames)
    foreach ($exe in $ExeNames) {
        if (Get-Command $exe -ErrorAction SilentlyContinue) { return $true }
    }
    return $false
}

function Get-PathExe {
    param([string[]]$ExeNames)
    foreach ($exe in $ExeNames) {
        $cmd = Get-Command $exe -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    return $null
}

function Test-AppPathsRegistry {
    param([string[]]$ExeNames)
    foreach ($exe in $ExeNames) {
        if (Get-AppPathsRegistryExe -ExeNames @($exe)) { return $true }
    }
    return $false
}

function Get-AppPathsRegistryExe {
    param([string[]]$ExeNames)
    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths'
    )
    foreach ($root in $roots) {
        foreach ($exe in $ExeNames) {
            $keyPath = Join-Path $root $exe
            if (Test-Path $keyPath) {
                $default = (Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue).'(default)'
                if ($default -and (Test-Path $default)) { return $default }
                return $keyPath
            }
        }
    }
    return $null
}

function Test-UninstallKey {
    param($UninstallKey)
    return [bool](Get-UninstallKeyExe -UninstallKey $UninstallKey)
}

function Get-UninstallKeyExe {
    param($UninstallKey)
    if (-not $UninstallKey) { return $null }
    foreach ($hive in @('HKLM:', 'HKCU:')) {
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

function Get-EsdeJunctionPath {
    param($App, [string]$EsdeHome)
    if (-not $App.esdeEmulatorDir) { return $null }
    return Join-Path (Join-Path $EsdeHome 'Emulators') $App.esdeEmulatorDir
}

function Get-EsdeJunctionExe {
    param($App, [string]$EsdeHome)
    $junctionPath = Get-EsdeJunctionPath -App $App -EsdeHome $EsdeHome
    if (-not $junctionPath -or -not (Test-Path $junctionPath)) { return $null }
    foreach ($exe in $App.exeNames) {
        $hit = Get-ChildItem -Path $junctionPath -Filter $exe -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

function Test-EsdeJunctionResolves {
    param($App, [string]$EsdeHome)
    return [bool](Get-EsdeJunctionExe -App $App -EsdeHome $EsdeHome)
}

function Test-AppDetected {
    param($App, [string]$EsdeHome)
    if (Test-OnPath -ExeNames $App.exeNames) { return $true }
    if ($App.registryAppPaths -and (Test-AppPathsRegistry -ExeNames $App.registryAppPaths)) { return $true }
    if (Test-UninstallKey -UninstallKey $App.registryUninstallKey) { return $true }
    if (Test-EsdeJunctionResolves -App $App -EsdeHome $EsdeHome) { return $true }
    return $false
}

function Find-InstalledExe {
    param($App)
    $roots = @(
        $env:ProgramFiles,
        ${env:ProgramFiles(x86)},
        (Join-Path $env:LOCALAPPDATA 'Programs'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'),
        $env:LOCALAPPDATA
    ) | Where-Object { $_ -and (Test-Path $_) }

    foreach ($root in $roots) {
        foreach ($exe in $App.exeNames) {
            $hit = Get-ChildItem -Path $root -Recurse -Depth 4 -Filter $exe -File -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($hit) { return $hit.FullName }
        }
    }
    return $null
}

# Resolves the real (non-junction) installed exe path for an app, trying
# every detection method in the same priority order as Test-AppDetected, so
# callers (e.g. the GPU preference registry key) key off the actual binary
# Windows will run rather than a junction path.
function Resolve-AppRealExePath {
    param($App, [string]$EsdeHome)

    $onPath = Get-PathExe -ExeNames $App.exeNames
    if ($onPath) { return $onPath }

    if ($App.registryAppPaths) {
        $viaAppPaths = Get-AppPathsRegistryExe -ExeNames $App.registryAppPaths
        if ($viaAppPaths -and $viaAppPaths -like '*.exe') { return $viaAppPaths }
    }

    $viaUninstall = Get-UninstallKeyExe -UninstallKey $App.registryUninstallKey
    if ($viaUninstall) { return $viaUninstall }

    $viaJunction = Get-EsdeJunctionExe -App $App -EsdeHome $EsdeHome
    if ($viaJunction) {
        # Resolve through the junction so registry keys match the real binary.
        $junctionDir = Get-Item -Path (Get-EsdeJunctionPath -App $App -EsdeHome $EsdeHome)
        $target = $junctionDir.Target | Select-Object -First 1
        if ($target) { return Join-Path $target (Split-Path -Leaf $viaJunction) }
        return $viaJunction
    }

    return Find-InstalledExe -App $App
}
