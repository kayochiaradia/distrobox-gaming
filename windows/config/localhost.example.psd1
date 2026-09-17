@{
    # Copy this file to windows/config/localhost.psd1 and edit -- that copy is
    # git-ignored (see .gitignore). Mirrors ansible/host_vars/localhost.yml.example
    # and macos/ansible/host_vars/localhost.yml.example, but as native PowerShell
    # data instead of YAML, since there is no Ansible control node on Windows.

    # ES-DE's home directory. Default matches the installer release
    # (C:\Users\<you>\ES-DE). Only change this if you used the portable release.
    EsdeHome = "$env:USERPROFILE\ES-DE"

    # Default ROM library root, used for every system unless overridden below.
    # ES-DE's own first-run wizard also lets you pick this location -- keep the
    # two in sync, or just point RomRoot at whatever you picked there.
    RomRoot = "$env:USERPROFILE\ES-DE\ROMs"

    # Per-system overrides, e.g. for an existing split library on another
    # drive or a NAS share. Keys are ES-DE system names (gc, wii, ps2, psx,
    # psp, ...). Omit a key to fall back to "RomRoot\<system>".
    RomPaths = @{
        # gc  = 'D:\Games\roms\gc'
        # wii = 'D:\Games\roms\wii'
        # ps2 = '\\NAS\Games\roms\ps2'
    }

    # bootstrap.ps1 -Action Configure only *reports* missing ROM directories by
    # default -- it never creates them, so a disconnected network/USB drive
    # can't silently become an empty local folder. Set this to $true to opt in
    # to creating missing local directories.
    CreateRomDirs = $false
}
