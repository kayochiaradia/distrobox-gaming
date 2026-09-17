<#
    Config-file editing helpers (dot-sourced). Windows counterparts of
    community.general.ini_file, ansible.builtin.lineinfile and backup: true.
    Each Set-* returns $true when the file differs from the desired value, and
    only writes when -Apply is $true. A file is backed up as
    <file>.bak.<timestamp> before its first change in a run.
#>

$script:DgBackedUp = @{}
$script:DgUtf8 = New-Object Text.UTF8Encoding $false

function Backup-DgFile {
    param([string]$Path)
    if ($script:DgBackedUp.ContainsKey($Path)) { return }
    if ([IO.File]::Exists($Path)) {
        [IO.File]::Copy($Path, "$Path.bak.$(Get-Date -Format 'yyyyMMddHHmmss')", $true)
    }
    $script:DgBackedUp[$Path] = $true
}

function Save-DgLines {
    param([string]$Path, $Lines)
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    Backup-DgFile -Path $Path
    [IO.File]::WriteAllLines($Path, [string[]]$Lines, $script:DgUtf8)
}

function Read-DgLines {
    param([string]$Path)
    $list = New-Object 'System.Collections.Generic.List[string]'
    if ([IO.File]::Exists($Path)) { foreach ($l in [IO.File]::ReadAllLines($Path)) { $list.Add($l) } }
    return ,$list
}

# "[ Global ]" and "[Global]" are the same section (Supermodel uses spaces).
function Test-DgSectionHeader {
    param([string]$Line, [string]$Section)
    $t = $Line.Trim()
    return $t.StartsWith('[') -and $t.EndsWith(']') -and (($t.Substring(1, $t.Length - 2).Trim()) -eq $Section)
}

function Set-DgIniValue {
    param([string]$Path, [string]$Section, [string]$Option, [string]$Value, [bool]$Apply)
    $lines = Read-DgLines -Path $Path
    $desired = "$Option = $Value"

    $sectionIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if (Test-DgSectionHeader -Line $lines[$i] -Section $Section) { $sectionIndex = $i; break }
    }
    if ($sectionIndex -lt 0) {
        if ($Apply) {
            if ($lines.Count -gt 0 -and $lines[$lines.Count - 1].Trim() -ne '') { $lines.Add('') }
            $lines.Add("[$Section]")
            $lines.Add($desired)
            Save-DgLines -Path $Path -Lines $lines
        }
        return $true
    }

    $sectionEnd = $lines.Count
    for ($i = $sectionIndex + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -match '^\[.+\]$') { $sectionEnd = $i; break }
    }
    for ($i = $sectionIndex + 1; $i -lt $sectionEnd; $i++) {
        if ($lines[$i] -match "^\s*$([regex]::Escape($Option))\s*=\s*(.*)$") {
            if ($Matches[1].Trim() -eq $Value) { return $false }
            if ($Apply) { $lines[$i] = $desired; Save-DgLines -Path $Path -Lines $lines }
            return $true
        }
    }
    if ($Apply) { $lines.Insert($sectionIndex + 1, $desired); Save-DgLines -Path $Path -Lines $lines }
    return $true
}

function Set-DgFlatValue {
    param([string]$Path, [string]$Key, [string]$Value, [bool]$Apply)
    $lines = Read-DgLines -Path $Path
    $desired = "$Key = $Value"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^\s*$([regex]::Escape($Key))\s*=\s*(.*)$") {
            if ($Matches[1].Trim() -eq $Value) { return $false }
            if ($Apply) { $lines[$i] = $desired; Save-DgLines -Path $Path -Lines $lines }
            return $true
        }
    }
    if ($Apply) { $lines.Add($desired); Save-DgLines -Path $Path -Lines $lines }
    return $true
}

# Sets the text of <root>/<XPath>, creating missing child elements.
function Set-DgXmlValue {
    param([string]$Path, [string]$XPath, [string]$Value, [bool]$Apply)
    $doc = New-Object Xml.XmlDocument
    $doc.PreserveWhitespace = $true
    $doc.Load($Path)
    $node = $doc.DocumentElement
    foreach ($part in $XPath.Split('/')) {
        $child = $node.SelectSingleNode($part)
        if (-not $child) { $child = $node.AppendChild($doc.CreateElement($part)) }
        $node = $child
    }
    $onlyText = @($node.ChildNodes | Where-Object { $_.NodeType -ne 'Text' }).Count -eq 0
    if ($onlyText -and $node.InnerText -eq $Value) { return $false }
    if ($Apply) {
        $node.InnerText = $Value
        Backup-DgFile -Path $Path
        $settings = New-Object Xml.XmlWriterSettings
        $settings.Encoding = $script:DgUtf8
        $writer = [Xml.XmlWriter]::Create($Path, $settings)
        try { $doc.Save($writer) } finally { $writer.Close() }
    }
    return $true
}

# Directory link without Administrator rights: an NTFS junction for local
# targets. Junctions can't point at network shares, so a UNC target is copied
# instead (a later run refreshes the copy). An existing link to a different
# target is replaced; a real non-empty directory is never removed.
# Returns 'linked', 'copied', 'current' or 'blocked'.
function Set-DgDirLink {
    param([string]$Link, [string]$Target, [bool]$Apply)
    $item = Get-Item -LiteralPath $Link -Force -ErrorAction SilentlyContinue
    if ($item -and $item.LinkType -eq 'Junction') {
        if (@($item.Target)[0] -eq $Target) { return 'current' }
        if ($Apply) { [IO.Directory]::Delete($Link) }
    } elseif ($item -and $item.PSIsContainer -and $Target.StartsWith('\\')) {
        # previously copied UNC target: refresh below
    } elseif ($item -and $item.PSIsContainer) {
        if (@([IO.Directory]::GetFileSystemEntries($Link)).Count -gt 0) { return 'blocked' }
        if ($Apply) { [IO.Directory]::Delete($Link) }
    } elseif ($item) {
        return 'blocked'
    }
    if (-not $Apply) { return $(if ($Target.StartsWith('\\')) { 'copied' } else { 'linked' }) }

    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Link))
    if ($Target.StartsWith('\\')) {
        & robocopy $Target $Link /E /NJH /NJS /NFL /NDL /NP | Out-Null
        return 'copied'
    }
    New-Item -ItemType Junction -Path $Link -Target $Target | Out-Null
    return 'linked'
}

# File placement without Administrator rights: hard link on the same volume,
# copy otherwise. Existing identical files are left alone.
function Set-DgFileLink {
    param([string]$Dest, [string]$Source, [bool]$Apply)
    if ([IO.File]::Exists($Dest)) {
        if ((Get-FileHash -LiteralPath $Dest).Hash -eq (Get-FileHash -LiteralPath $Source).Hash) { return $false }
    }
    if ($Apply) {
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Dest))
        if ([IO.File]::Exists($Dest)) { Backup-DgFile -Path $Dest; [IO.File]::Delete($Dest) }
        $sameVolume = [IO.Path]::GetPathRoot($Dest) -ieq [IO.Path]::GetPathRoot($Source) -and -not $Source.StartsWith('\\')
        if ($sameVolume) {
            New-Item -ItemType HardLink -Path $Dest -Target $Source -ErrorAction SilentlyContinue | Out-Null
        }
        if (-not [IO.File]::Exists($Dest)) { [IO.File]::Copy($Source, $Dest) }
    }
    return $true
}
