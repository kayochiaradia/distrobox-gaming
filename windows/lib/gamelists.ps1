<#
    ES-DE gamelist and media helpers (dot-sourced by bootstrap.ps1).
    PowerShell ports of ansible/roles/configure_esde/files/*.py and
    tasks/media-symlinks.yml -- Windows has no Python by default.
    Each function returns $true when its output differs from what's on disk
    (and writes it only when -Apply).
#>

if (-not ('DgNative' -as [type])) {
    Add-Type -Namespace '' -Name 'DgNative' -MemberDefinition @'
[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern bool CreateHardLink(string lpFileName, string lpExistingFileName, IntPtr lpSecurityAttributes);
'@
}

function Write-XmlIfChanged {
    param([string]$Path, [Xml.XmlDocument]$Document, [bool]$Apply)
    $settings = New-Object Xml.XmlWriterSettings
    $settings.Indent = $true
    $settings.IndentChars = '  '
    $settings.Encoding = New-Object Text.UTF8Encoding $false
    $stream = New-Object IO.MemoryStream
    $writer = [Xml.XmlWriter]::Create($stream, $settings)
    $Document.Save($writer)
    $writer.Close()
    $bytes = $stream.ToArray()

    if ([IO.File]::Exists($Path)) {
        $old = [IO.File]::ReadAllBytes($Path)
        if ([Convert]::ToBase64String($old) -eq [Convert]::ToBase64String($bytes)) { return $false }
    }
    if ($Apply) {
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
        if ([IO.File]::Exists($Path)) {
            [IO.File]::Copy($Path, "$Path.bak.$(Get-Date -Format 'yyyyMMddHHmmss')", $true)
        }
        [IO.File]::WriteAllBytes($Path, $bytes)
    }
    return $true
}

function Add-XmlChild {
    param($Parent, [string]$Name, [string]$Text)
    $e = $Parent.OwnerDocument.CreateElement($Name)
    $e.InnerText = $Text
    [void]$Parent.AppendChild($e)
}

# Sony PARAM.SFO -> hashtable (string and int32 fields).
function ConvertFrom-ParamSfo {
    param([byte[]]$Data)
    if ($Data.Length -lt 20 -or $Data[0] -ne 0 -or [Text.Encoding]::ASCII.GetString($Data, 1, 3) -ne 'PSF') {
        throw 'not a PARAM.SFO file'
    }
    $keyTable = [BitConverter]::ToUInt32($Data, 8)
    $dataTable = [BitConverter]::ToUInt32($Data, 12)
    $count = [BitConverter]::ToUInt32($Data, 16)
    $out = @{}
    for ($i = 0; $i -lt $count; $i++) {
        $entry = 0x14 + $i * 16
        $keyOffset = [BitConverter]::ToUInt16($Data, $entry)
        $format = [BitConverter]::ToUInt16($Data, $entry + 2)
        $used = [BitConverter]::ToUInt32($Data, $entry + 4)
        $valueOffset = [BitConverter]::ToUInt32($Data, $entry + 12)
        $keyStart = $keyTable + $keyOffset
        $keyEnd = [Array]::IndexOf($Data, [byte]0, [int]$keyStart)
        $key = [Text.Encoding]::UTF8.GetString($Data, $keyStart, $keyEnd - $keyStart)
        $start = $dataTable + $valueOffset
        if ($format -eq 0x0404 -or $format -eq 0x0204) {
            $out[$key] = [Text.Encoding]::UTF8.GetString($Data, $start, $used).TrimEnd([char]0)
        } elseif ($format -eq 0x0004) {
            $out[$key] = [BitConverter]::ToUInt32($Data, $start)
        }
    }
    return $out
}

# ES-DE gamelist for PS4 from each <root>\<CUSA>\sce_sys\param.sfo, so games
# show their title instead of "eboot". Port of ps4-sfo-to-gamelist.py.
function Update-Ps4Gamelist {
    param([string]$RomDir, [string]$OutFile, [bool]$Apply)
    if (-not [IO.Directory]::Exists($RomDir)) { return $null }

    $doc = New-Object Xml.XmlDocument
    [void]$doc.AppendChild($doc.CreateXmlDeclaration('1.0', 'UTF-8', $null))
    $list = $doc.AppendChild($doc.CreateElement('gameList'))
    $count = 0
    foreach ($dir in [IO.Directory]::GetDirectories($RomDir) | Sort-Object) {
        if (-not [IO.File]::Exists((Join-Path $dir 'eboot.bin'))) { continue }
        $folder = [IO.Path]::GetFileName($dir)
        $name = $folder; $titleId = $folder; $version = $null
        $sfo = Join-Path $dir 'sce_sys\param.sfo'
        if ([IO.File]::Exists($sfo)) {
            try {
                $meta = ConvertFrom-ParamSfo -Data ([IO.File]::ReadAllBytes($sfo))
                if ($meta.TITLE) { $name = "$($meta.TITLE)".Trim() }
                if ($meta.TITLE_ID) { $titleId = "$($meta.TITLE_ID)".Trim() }
                if ($meta.VERSION) { $version = "$($meta.VERSION)".Trim() }
            } catch {
                Write-Host "    WARN: could not parse ${sfo}: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        $game = $list.AppendChild($doc.CreateElement('game'))
        Add-XmlChild $game 'path' "./$folder/eboot.bin"
        Add-XmlChild $game 'name' $name
        $desc = "Title ID: $titleId"
        if ($version) { $desc += "`nApp Version: $version" }
        Add-XmlChild $game 'desc' $desc
        $count++
    }
    if ($count -eq 0) { return $null }
    return [PSCustomObject]@{ Changed = (Write-XmlIfChanged -Path $OutFile -Document $doc -Apply $Apply); Games = $count }
}

# ES-DE gamelist from a Skraper gamelist.xml in a MAME-style ROM dir, hiding
# clone sets (shortest filename per display name stays visible). Port of
# arcade-clone-gamelist.py.
function Update-ArcadeCloneGamelist {
    param([string]$SourceFile, [string]$OutFile, [bool]$Apply)
    if (-not [IO.File]::Exists($SourceFile)) { return $null }

    $src = New-Object Xml.XmlDocument
    $src.Load($SourceFile)
    $games = foreach ($g in $src.SelectNodes('//game')) {
        $path = "$($g.path)".Trim(); $name = "$($g.name)".Trim()
        if (-not $path -or -not $name) { continue }
        [PSCustomObject]@{ Path = $path; Name = $name; Desc = "$($g.desc)".Trim(); Release = "$($g.releasedate)".Trim(); Hidden = $false }
    }
    $games = @($games)
    foreach ($group in $games | Group-Object Name) {
        $ordered = @($group.Group | Sort-Object @{ e = { [IO.Path]::GetFileName($_.Path).Length } }, Path)
        for ($i = 1; $i -lt $ordered.Count; $i++) { $ordered[$i].Hidden = $true }
    }

    $doc = New-Object Xml.XmlDocument
    [void]$doc.AppendChild($doc.CreateXmlDeclaration('1.0', 'UTF-8', $null))
    $list = $doc.AppendChild($doc.CreateElement('gameList'))
    foreach ($g in $games | Sort-Object Path) {
        $e = $list.AppendChild($doc.CreateElement('game'))
        Add-XmlChild $e 'path' $g.Path
        Add-XmlChild $e 'name' $g.Name
        if ($g.Desc) { Add-XmlChild $e 'desc' $g.Desc }
        if ($g.Release) { Add-XmlChild $e 'releasedate' $g.Release }
        if ($g.Hidden) { Add-XmlChild $e 'hidden' 'true' }
    }
    return [PSCustomObject]@{
        Changed = (Write-XmlIfChanged -Path $OutFile -Document $doc -Apply $Apply)
        Games   = $games.Count
        Hidden  = @($games | Where-Object Hidden).Count
    }
}

# Bridges Skraper/EmuDeck scraped art into ES-DE's downloaded_media layout.
# Port of media-symlinks.yml: hierarchical <rom>\media\<type>\ first, then
# Skraper-flat <rom>\images\<rom>-image|-marquee.*; first writer wins.
# Windows can't symlink without Developer Mode, so files are hard-linked
# (same volume, no extra space) or copied across volumes.
function Sync-EsdeMedia {
    param([hashtable]$SystemRomDirs, [string]$MediaDir, [bool]$Apply)
    $created = 0
    foreach ($system in $SystemRomDirs.Keys) {
        $romDir = $SystemRomDirs[$system]
        $pairs = New-Object System.Collections.Generic.List[object]

        $mediaRoot = Join-Path $romDir 'media'
        if ([IO.Directory]::Exists($mediaRoot)) {
            foreach ($sub in [IO.Directory]::GetDirectories($mediaRoot)) {
                $type = [IO.Path]::GetFileName($sub)
                foreach ($f in [IO.Directory]::GetFiles($sub)) {
                    $pairs.Add(@($f, (Join-Path $MediaDir "$system\$type\$([IO.Path]::GetFileName($f))")))
                }
            }
        }
        $images = Join-Path $romDir 'images'
        if ([IO.Directory]::Exists($images)) {
            foreach ($f in [IO.Directory]::GetFiles($images)) {
                $file = [IO.Path]::GetFileName($f)
                $m = [regex]::Match($file, '^(.+)-(image|marquee)\.(png|jpg|jpeg)$', 'IgnoreCase')
                if (-not $m.Success) { continue }
                $type = if ($m.Groups[2].Value -ieq 'image') { 'covers' } else { 'marquees' }
                $pairs.Add(@($f, (Join-Path $MediaDir "$system\$type\$($m.Groups[1].Value).$($m.Groups[3].Value)")))
            }
        }

        foreach ($p in $pairs) {
            $src, $dest = $p
            if ([IO.File]::Exists($dest)) { continue }
            if ($Apply) {
                [void][IO.Directory]::CreateDirectory((Split-Path -Parent $dest))
                $linked = ([IO.Path]::GetPathRoot($src) -ieq [IO.Path]::GetPathRoot($dest)) -and
                    [DgNative]::CreateHardLink($dest, $src, [IntPtr]::Zero)
                if (-not $linked) { [IO.File]::Copy($src, $dest) }
            }
            $created++
        }
    }
    return $created
}

# Sets <type name="Name" value="..." /> entries in ES-DE's es_settings.xml,
# only once ES-DE has written that file on its first run. One backup per call.
function Set-EsdeSettings {
    param([string]$SettingsFile, [array]$Settings, [bool]$Apply)
    if (-not [IO.File]::Exists($SettingsFile)) { return $null }
    $text = [IO.File]::ReadAllText($SettingsFile)
    $new = $text
    foreach ($s in $Settings) {
        $value = [Security.SecurityElement]::Escape($s.Value)
        $line = "<$($s.Type) name=""$($s.Name)"" value=""$value"" />"
        $pattern = "<$($s.Type) name=""$([regex]::Escape($s.Name))"" value=""[^""]*"" />"
        if ($new -match $pattern) {
            $new = [regex]::Replace($new, $pattern, { param($m) $line })
        } else {
            $new = $new.TrimEnd() + "`r`n" + $line + "`r`n"
        }
    }
    if ($new -eq $text) { return $false }
    if ($Apply) {
        [IO.File]::Copy($SettingsFile, "$SettingsFile.bak.$(Get-Date -Format 'yyyyMMddHHmmss')", $true)
        [IO.File]::WriteAllText($SettingsFile, $new, (New-Object Text.UTF8Encoding $false))
    }
    return $true
}
