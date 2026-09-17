@{
    # Windows counterparts of ansible/backup.yml, restore.yml and the verify
    # role. There is no container image to snapshot: emulators are reinstalled
    # by install-apps.ps1, so a backup holds configuration only -- the same
    # scope as the Linux home archive (emulator configs + ES-DE), with the same
    # exclusions (caches, shaders, screenshots, captures, logs, saves, states).
    # ROMs, BIOS and saves are never touched.
    #
    # Paths use the same tokens as emulators.psd1: %VAR% and {dir:<app id>}.
    # {esdehome} is the detected ES-DE home. Missing paths are skipped.

    BackupDir = '%USERPROFILE%\distrobox-gaming-backups'

    BackupItems = @(
        @{ Name = 'esde'; Path = '{esdehome}'; Exclude = @('downloaded_media', 'themes', 'logs', 'screensavers') }
        @{ Name = 'windows-localhost'; Path = '{scriptroot}\config\localhost.psd1' }
        @{ Name = 'pcsx2'; Path = '%USERPROFILE%\Documents\PCSX2'; Exclude = @('cache', 'covers', 'logs', 'snaps', 'sstates', 'videos', 'textures', 'memcards', 'bios') }
        @{ Name = 'duckstation'; Path = '%LOCALAPPDATA%\DuckStation'; Exclude = @('cache', 'covers', 'gameicons', 'screenshots', 'videos', 'savestates', 'shaders', 'textures', 'memcards', 'bios', 'resources') }
        @{ Name = 'dolphin'; Path = '%USERPROFILE%\Documents\Dolphin Emulator\Config' }
        @{ Name = 'retroarch-cfg'; Path = '{dir:retroarch}\retroarch.cfg' }
        @{ Name = 'retroarch-config'; Path = '{dir:retroarch}\config' }
        @{ Name = 'ppsspp-portable'; Path = '{dir:ppsspp}\memstick\PSP\SYSTEM' }
        @{ Name = 'ppsspp-documents'; Path = '%USERPROFILE%\Documents\PPSSPP\PSP\SYSTEM' }
        @{ Name = 'rpcs3'; Path = '{dir:rpcs3}\config' }
        @{ Name = 'shadps4'; Path = '%APPDATA%\shadPS4'; Exclude = @('cache', 'captures', 'download', 'fonts', 'game_data', 'log', 'screenshots', 'shader', 'temp', 'sys_modules') }
        @{ Name = 'eden'; Path = '%APPDATA%\eden\config' }
        @{ Name = 'cemu'; Path = '%APPDATA%\Cemu'; Exclude = @('shaderCache', 'log.txt') }
        @{ Name = 'azahar'; Path = '%APPDATA%\Azahar\config' }
        @{ Name = 'melonds'; Path = '{dir:melonds}\melonDS.toml' }
        @{ Name = 'xemu'; Path = '%APPDATA%\xemu\xemu\xemu.toml' }
        @{ Name = 'xenia'; Path = '{dir:xenia}\xenia-canary.config.toml' }
        @{ Name = 'vita3k'; Path = '{dir:vita3k}\config.yml' }
        @{ Name = 'flycast'; Path = '{dir:flycast}\emu.cfg' }
        @{ Name = 'supermodel'; Path = '{dir:supermodel}\Config' }
        @{ Name = 'm2emulator'; Path = '{dir:m2emulator}\EMULATOR.INI' }
    )
}
