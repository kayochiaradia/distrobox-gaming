@{
    # Copy this file to windows/config/localhost.psd1 and edit -- that copy is
    # git-ignored (see .gitignore). Mirrors ansible/host_vars/localhost.yml.example
    # and macos/ansible/host_vars/localhost.yml.example, but as native PowerShell
    # data instead of YAML, since there is no Ansible control node on Windows.

    # ES-DE's home directory. Default matches the installer release
    # (C:\Users\<you>\ES-DE). Only change this if you used the portable release.
    EsdeHome = '%USERPROFILE%\ES-DE'

    # Default ROM library root, used for every system unless overridden below.
    # ES-DE's own first-run wizard also lets you pick this location -- keep the
    # two in sync, or just point RomRoot at whatever you picked there.
    RomRoot = '%USERPROFILE%\ES-DE\ROMs'

    # Per-system overrides, e.g. for an existing split library elsewhere on
    # C: or on a NAS share. Keys are ES-DE system names (gc, wii, ps2, psx,
    # psp, ...). Omit a key to fall back to "RomRoot\<system>". Everything in
    # this project defaults to the C: drive -- only add a path here if you
    # deliberately keep ROMs somewhere else.
    RomPaths = @{
        # gc  = 'C:\Games\roms\gc'
        # wii = 'C:\Games\roms\wii'
        # ps2 = '\\NAS\Games\roms\ps2'
    }

    # bootstrap.ps1 -Action Configure only *reports* missing ROM directories by
    # default -- it never creates them, so a disconnected network/USB drive
    # can't silently become an empty local folder. Set this to $true to opt in
    # to creating missing local directories.
    CreateRomDirs = $false

    # Your own BIOS files (PS1/PS2/etc.). Not supplied by this project or by
    # any of the installers -- see the "BIOS" note in windows/INSTALL.md.
    BiosRoot = '%USERPROFILE%\ES-DE\BIOS'

    # Per-emulator config file location overrides, read by
    # configure-emulators.ps1. Only set the ones that differ from the
    # defaults in config/emulators.psd1 (e.g. you installed PCSX2 or
    # RetroArch in portable mode, or somewhere other than the default path).
    EmulatorConfigPaths = @{
        # pcsx2      = '%USERPROFILE%\Documents\PCSX2-portable\inis\PCSX2.ini'
        # duckstation = '%LOCALAPPDATA%\DuckStation\settings.ini'
        # retroarch  = 'C:\RetroArch-Win64\retroarch.cfg'
        # dolphin    = '%USERPROFILE%\Documents\Dolphin Emulator\Config'
    }
}
