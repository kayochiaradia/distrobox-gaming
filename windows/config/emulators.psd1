@{
    # Windows port of ansible/group_vars/all/emulators.yml, gpu.yml and the
    # link_storage role, trimmed to settings that change something on Windows.
    # Dropped on purpose (see windows/README.md#what-was-not-ported): values
    # already equal to the Windows default, keys missing from current builds,
    # Linux-only workarounds (Vulkan/ICD forcing, PulseAudio, container locale,
    # NAS read-ahead) and maintainer-specific data (monitor resolution, 8BitDo
    # mappings, specific games).
    #
    # Path tokens: %VAR% (expanded on load), {dir:<app id>} = folder of that
    # app's installed exe. Value tokens: {{BiosRoot}}, {{RomPath:<system>}}.
    # A setting whose value uses {{BiosRoot}} is skipped when BiosRoot doesn't
    # exist; a setting with Requires is skipped when BiosRoot\<Requires> is
    # missing. A config file is only edited once the emulator has written it
    # (launch it once first), except files marked CreateIfMissing.

    # --- BIOS / firmware (link_storage) --------------------------------------
    # Same relative layout under BiosRoot as the Linux dg_bios_root (EmuDeck
    # layout), so an existing EmuDeck BIOS folder works as BiosRoot. Windows
    # can't symlink without Developer Mode, so files are copied: Mode 'sync'
    # recopies when the source changes, 'seed' only copies when missing (for
    # files the emulator writes to). Missing sources are reported and skipped.
    BiosFiles = @(
        # RetroArch system dir -- all optional; see docs/atari.md.
        @{ App = 'retroarch'; Source = '5200.ROM'; Dest = '{dir:retroarch}\system\5200.ROM' }
        @{ App = 'retroarch'; Source = 'ATARIXL.ROM'; Dest = '{dir:retroarch}\system\ATARIXL.ROM' }
        @{ App = 'retroarch'; Source = 'ATARIBAS.ROM'; Dest = '{dir:retroarch}\system\ATARIBAS.ROM' }
        @{ App = 'retroarch'; Source = 'ATARIOSA.ROM'; Dest = '{dir:retroarch}\system\ATARIOSA.ROM' }
        @{ App = 'retroarch'; Source = 'ATARIOSB.ROM'; Dest = '{dir:retroarch}\system\ATARIOSB.ROM' }
        @{ App = 'retroarch'; Source = 'lynxboot.img'; Dest = '{dir:retroarch}\system\lynxboot.img' }
        # Flycast arcade BIOS sets; NAOMI/Atomiswave games don't boot without them.
        @{ App = 'flycast'; Source = 'dc\naomi.zip'; Dest = '{dir:flycast}\data\naomi.zip' }
        @{ App = 'flycast'; Source = 'dc\naomi2.zip'; Dest = '{dir:flycast}\data\naomi2.zip' }
        @{ App = 'flycast'; Source = 'dc\awbios.zip'; Dest = '{dir:flycast}\data\awbios.zip' }
        # melonDS writes user settings into the firmware file: seed only.
        @{ App = 'melonds'; Source = 'bios7.bin'; Dest = '{dir:melonds}\bios\bios7.bin'; Mode = 'seed' }
        @{ App = 'melonds'; Source = 'bios9.bin'; Dest = '{dir:melonds}\bios\bios9.bin'; Mode = 'seed' }
        @{ App = 'melonds'; Source = 'dsfirmware.bin'; Dest = '{dir:melonds}\bios\dsfirmware.bin'; Mode = 'seed' }
        # PS4 firmware modules for shadPS4 (every file in the folder).
        @{ App = 'shadps4'; Source = 'ps4\sys_modules\*'; Dest = '%APPDATA%\shadPS4\sys_modules' }
    )

    # --- Emulator config files -----------------------------------------------
    ConfigFiles = @(
        # PCSX2 -- verified live 2026-09-17 (2.8.2) against the PCSX2.ini it
        # writes. Dropped as already-default: InputSources SDL and
        # SDLControllerEnhancedMode, Pad1 Type. TextureReplacementsAsync was
        # renamed LoadTextureReplacementsAsync and defaults to true. The D-pad
        # keys are Up/Down/Left/Right -- the Linux DPadUp/... names don't exist
        # in PCSX2 and leave the D-pad unmapped there.
        @{ Id = 'pcsx2'; App = 'pcsx2'; Format = 'ini'
           Path = '%USERPROFILE%\Documents\PCSX2\inis\PCSX2.ini'
           Settings = @(
               @{ Section = 'UI'; Option = 'ConfirmShutdown'; Value = 'false' }
               @{ Section = 'Folders'; Option = 'Bios'; Value = '{{BiosRoot}}' }
               @{ Section = 'Hotkeys'; Option = 'ShutdownVM'; Value = 'SDL-0/Start & SDL-0/Back' }
               @{ Section = 'Hotkeys'; Option = 'SaveStateToSlot1'; Value = 'SDL-0/Back & SDL-0/RightShoulder' }
               @{ Section = 'Hotkeys'; Option = 'LoadStateFromSlot1'; Value = 'SDL-0/Back & SDL-0/LeftShoulder' }
               # 6x targets a high-end discrete GPU (4K output).
               @{ Section = 'EmuCore/GS'; Option = 'upscale_multiplier'; Value = '6.000000' }
               @{ Section = 'EmuCore/GS'; Option = 'MaxAnisotropy'; Value = '16' }
               @{ Section = 'EmuCore/GS'; Option = 'fxaa'; Value = 'true' }
               @{ Section = 'EmuCore/GS'; Option = 'LoadTextureReplacements'; Value = 'true' }
               @{ Section = 'EmuCore'; Option = 'EnableWideScreenPatches'; Value = 'true' }
               @{ Section = 'EmuCore/Speedhacks'; Option = 'fastCDVD'; Value = 'true' }
               @{ Section = 'EmuCore'; Option = 'SaveStateOnShutdown'; Value = 'true' }
               @{ Section = 'Pad1'; Option = 'Cross'; Value = 'SDL-0/A' }
               @{ Section = 'Pad1'; Option = 'Circle'; Value = 'SDL-0/B' }
               @{ Section = 'Pad1'; Option = 'Square'; Value = 'SDL-0/X' }
               @{ Section = 'Pad1'; Option = 'Triangle'; Value = 'SDL-0/Y' }
               @{ Section = 'Pad1'; Option = 'Up'; Value = 'SDL-0/DPadUp' }
               @{ Section = 'Pad1'; Option = 'Down'; Value = 'SDL-0/DPadDown' }
               @{ Section = 'Pad1'; Option = 'Left'; Value = 'SDL-0/DPadLeft' }
               @{ Section = 'Pad1'; Option = 'Right'; Value = 'SDL-0/DPadRight' }
               @{ Section = 'Pad1'; Option = 'L1'; Value = 'SDL-0/LeftShoulder' }
               @{ Section = 'Pad1'; Option = 'R1'; Value = 'SDL-0/RightShoulder' }
               @{ Section = 'Pad1'; Option = 'L2'; Value = 'SDL-0/+LeftTrigger' }
               @{ Section = 'Pad1'; Option = 'R2'; Value = 'SDL-0/+RightTrigger' }
               @{ Section = 'Pad1'; Option = 'L3'; Value = 'SDL-0/LeftStick' }
               @{ Section = 'Pad1'; Option = 'R3'; Value = 'SDL-0/RightStick' }
               @{ Section = 'Pad1'; Option = 'Select'; Value = 'SDL-0/Back' }
               @{ Section = 'Pad1'; Option = 'Start'; Value = 'SDL-0/Start' }
               @{ Section = 'Pad1'; Option = 'LUp'; Value = 'SDL-0/-LeftY' }
               @{ Section = 'Pad1'; Option = 'LDown'; Value = 'SDL-0/+LeftY' }
               @{ Section = 'Pad1'; Option = 'LLeft'; Value = 'SDL-0/-LeftX' }
               @{ Section = 'Pad1'; Option = 'LRight'; Value = 'SDL-0/+LeftX' }
               @{ Section = 'Pad1'; Option = 'RUp'; Value = 'SDL-0/-RightY' }
               @{ Section = 'Pad1'; Option = 'RDown'; Value = 'SDL-0/+RightY' }
               @{ Section = 'Pad1'; Option = 'RLeft'; Value = 'SDL-0/-RightX' }
               @{ Section = 'Pad1'; Option = 'RRight'; Value = 'SDL-0/+RightX' }
           ) }

        # DuckStation -- verified live 2026-09-17 (0.1-11752): every key exists
        # in the settings.ini DuckStation writes and differs from its default.
        @{ Id = 'duckstation'; App = 'duckstation'; Format = 'ini'
           Path = '%LOCALAPPDATA%\DuckStation\settings.ini'
           Settings = @(
               @{ Section = 'Main'; Option = 'ConfirmPowerOff'; Value = 'false' }
               @{ Section = 'Main'; Option = 'StartFullscreen'; Value = 'true' }
               @{ Section = 'Main'; Option = 'CreateSaveStateBackups'; Value = 'false' }
               @{ Section = 'BIOS'; Option = 'SearchDirectory'; Value = '{{BiosRoot}}' }
               @{ Section = 'BIOS'; Option = 'PatchFastBoot'; Value = 'true' }
               @{ Section = 'GPU'; Option = 'ResolutionScale'; Value = '8' }
               @{ Section = 'GPU'; Option = 'TextureFilter'; Value = 'JINC2' }
               @{ Section = 'GPU'; Option = 'SpriteTextureFilter'; Value = 'JINC2' }
               @{ Section = 'GPU'; Option = 'Multisamples'; Value = '2' }
               @{ Section = 'GPU'; Option = 'PGXPEnable'; Value = 'true' }
               @{ Section = 'GPU'; Option = 'PGXPDepthBuffer'; Value = 'true' }
               @{ Section = 'GPU'; Option = 'PGXPPreserveProjFP'; Value = 'true' }
               @{ Section = 'GPU'; Option = 'WidescreenHack'; Value = 'true' }
               @{ Section = 'CDROM'; Option = 'ReadSpeedup'; Value = '4' }
               @{ Section = 'CDROM'; Option = 'SeekSpeedup'; Value = '4' }
               @{ Section = 'Display'; Option = 'VSync'; Value = 'true' }
               @{ Section = 'TextureReplacements'; Option = 'EnableTextureReplacements'; Value = 'true' }
               @{ Section = 'TextureReplacements'; Option = 'PreloadTextures'; Value = 'true' }
               @{ Section = 'TextureReplacements'; Option = 'MaxVRAMWriteSplits'; Value = '1024' }
           ) }

        # RetroArch -- config lives beside the exe on Windows.
        @{ Id = 'retroarch'; App = 'retroarch'; Format = 'flat'
           Path = '{dir:retroarch}\retroarch.cfg'
           # Verified live 2026-09-17 (1.22.2): menu_swap_ok_cancel_buttons already
           # defaults to "true" on Windows, and there is no audio_driver override
           # to port (Windows defaults to wasapi). Nothing global left to set.
           Settings = @() }

        # Flycast -- emu.cfg only stores non-default values. Linux pvr.rend
        # (forced Vulkan) is not ported; vsync, EmulateFramebuffer and
        # AutoSkipFrame are left at their defaults.
        @{ Id = 'flycast'; App = 'flycast'; Format = 'ini'
           Path = '{dir:flycast}\emu.cfg'
           Settings = @(
               # 4320 = 9x internal resolution; targets a high-end GPU.
               @{ Section = 'config'; Option = 'rend.Resolution'; Value = '4320' }
               @{ Section = 'config'; Option = 'rend.WideScreen'; Value = 'yes' }
               @{ Section = 'config'; Option = 'rend.DupeFrames'; Value = 'yes' }
               @{ Section = 'config'; Option = 'rend.DelayFrameSwapping'; Value = 'no' }
           ) }

        # Supermodel -- ships Config\Supermodel.ini with "[ Global ]". The
        # Linux X/YResolution (maintainer's monitor) and xpad button mapping
        # (Linux joystick ordering) are not ported. FullScreen is required on
        # Windows per ES-DE's guide.
        @{ Id = 'supermodel'; App = 'supermodel'; Format = 'ini'
           Path = '{dir:supermodel}\Config\Supermodel.ini'
           Settings = @(
               @{ Section = 'Global'; Option = 'FullScreen'; Value = 'true' }
               @{ Section = 'Global'; Option = 'WideScreen'; Value = 'true' }
               @{ Section = 'Global'; Option = 'WideBackground'; Value = 'true' }
           ) }

        # Model 2 Emulator -- ES-DE passes only the romset name, so the ROM
        # folder must be set in EMULATOR.INI (ES-DE user guide). Same as the
        # Linux m2emulator wrapper's [RomDirs].
        @{ Id = 'm2emulator'; App = 'm2emulator'; Format = 'ini'
           Path = '{dir:m2emulator}\EMULATOR.INI'
           Settings = @(
               @{ Section = 'RomDirs'; Option = 'Dir1'; Value = '{{RomPath:model2}}' }
           ) }

        # xemu -- BIOS/flash/HDD come straight from BiosRoot (Linux symlinks
        # them; the HDD image is written in place in both cases). Linux
        # backend='vulkan' is not ported.
        @{ Id = 'xemu'; App = 'xemu'; Format = 'ini'
           Path = '%APPDATA%\xemu\xemu\xemu.toml'
           Settings = @(
               @{ Section = 'general'; Option = 'show_welcome'; Value = 'false' }
               @{ Section = 'general.updates'; Option = 'check'; Value = 'false' }
               @{ Section = 'display.window'; Option = 'fullscreen_on_startup'; Value = 'true' }
               @{ Section = 'display.quality'; Option = 'surface_scale'; Value = '3' }
               @{ Section = 'sys.files'; Option = 'bootrom_path'; Value = "'{{BiosRoot}}\mcpx_1.0.bin'"; Requires = 'mcpx_1.0.bin' }
               @{ Section = 'sys.files'; Option = 'flashrom_path'; Value = "'{{BiosRoot}}\Complex_4627.bin'"; Requires = 'Complex_4627.bin' }
               @{ Section = 'sys.files'; Option = 'hdd_path'; Value = "'{{BiosRoot}}\xbox_hdd.qcow2'"; Requires = 'xbox_hdd.qcow2' }
           ) }

        # melonDS -- the Windows melonDS.toml omits these sections entirely
        # (defaults). Linux joystick mapping (8BitDo) is not ported.
        @{ Id = 'melonds'; App = 'melonds'; Format = 'ini'
           Path = '{dir:melonds}\melonDS.toml'
           Settings = @(
               @{ Section = '3D'; Option = 'Renderer'; Value = '2' }
               @{ Section = '3D.GL'; Option = 'ScaleFactor'; Value = '8' }
               @{ Section = '3D.GL'; Option = 'BetterPolygons'; Value = 'true' }
               @{ Section = '3D.GL'; Option = 'HiresCoordinates'; Value = 'true' }
               @{ Section = '3D.Soft'; Option = 'Threaded'; Value = 'true' }
               @{ Section = 'Emu'; Option = 'DirectBoot'; Value = 'true' }
               @{ Section = 'Emu'; Option = 'ExternalBIOSEnable'; Value = 'true'; Requires = 'bios7.bin' }
               @{ Section = 'DS'; Option = 'BIOS7Path'; Value = "'{dir:melonds}\bios\bios7.bin'"; Requires = 'bios7.bin' }
               @{ Section = 'DS'; Option = 'BIOS9Path'; Value = "'{dir:melonds}\bios\bios9.bin'"; Requires = 'bios9.bin' }
               @{ Section = 'DS'; Option = 'FirmwarePath'; Value = "'{dir:melonds}\bios\dsfirmware.bin'"; Requires = 'dsfirmware.bin' }
           ) }

        # Cemu -- verified live 2026-09-17 (2.6): values survive a Cemu restart.
        # Vulkan is already its Windows default, so api is not forced. Linux
        # window size, console region/language, PulseAudio api and
        # did_show_graphic_pack_download (dropped by Cemu 2.6) are not ported.
        @{ Id = 'cemu'; App = 'cemu'; Format = 'xml'
           Path = '%APPDATA%\Cemu\settings.xml'
           Settings = @(
               @{ XPath = 'fullscreen'; Value = 'true' }
               @{ XPath = 'check_update'; Value = 'false' }
               @{ XPath = 'use_discord_presence'; Value = 'false' }
               @{ XPath = 'Graphic/VSync'; Value = '1' }
               @{ XPath = 'Graphic/UpscaleFilter'; Value = '2' }
               @{ XPath = 'GamePaths/Entry'; Value = '{{RomPath:wiiu}}' }
           ) }
    )

    # RetroArch per-core option files, under <folder of retroarch.cfg>\config.
    # Created when missing (RetroArch only writes them after a core runs).
    RetroarchCoreOptions = @(
        @{ RelativePath = 'bsnes-hd beta\bsnes-hd beta.opt'
           Settings = @(
               @{ Key = 'bsnes_mode7_wsMode'; Value = '"all"' }
               @{ Key = 'bsnes_mode7_widescreen'; Value = '"16:9"' }
               @{ Key = 'bsnes_mode7_wsobj'; Value = '"unsafe"' }
               @{ Key = 'bsnes_video_aspectcorrection'; Value = '"ON"' }
           ) }
        # melonDS's hardware renderer is OpenGL-only; guards against a black
        # screen if the global video driver is vulkan or d3d11/d3d12.
        @{ RelativePath = 'melonDS\melonDS.cfg'
           Settings = @( @{ Key = 'video_driver'; Value = '"glcore"' } ) }
        @{ RelativePath = 'melonDS\melonDS.opt'
           Settings = @( @{ Key = 'melonds_opengl_renderer'; Value = '"enabled"' } ) }
        # RetroArch's Windows default video driver is d3d11; the ParaLLEl-RDP
        # renderer below needs Vulkan (Linux used vulkan globally).
        @{ RelativePath = 'ParaLLEl N64\ParaLLEl N64.cfg'
           Settings = @( @{ Key = 'video_driver'; Value = '"vulkan"' } ) }
        # Atari 5200 vs 8-bit on the one atari800 core. Linux rewrites
        # atari800_system before every launch (bin/retroarch-atari800) because
        # the core only ever forces 5200 mode ON. RetroArch natively loads
        # config\<core>\<ROM folder name>.opt for every game in that folder
        # (runloop.c validate_folder_options), so one file per ROM folder does
        # the same with no wrapper. ROMs in subfolders of these folders use the
        # subfolder's name instead. 5200 uses the real BIOS when present, else
        # the core's built-in AltirraOS, as the Linux wrapper does. With the
        # default folder name, atari800.opt is also the core-wide Atari800.opt
        # (case-insensitive paths), so 800XL becomes the fallback everywhere,
        # which matches the wrapper's default. .a52 carts still self-switch.
        @{ RelativePath = 'Atari800\{{RomDirName:atari5200}}.opt'
           Settings = @(
               @{ Key = 'atari800_system'; Value = '"5200"' }
               @{ Key = 'atari800_os_5200'; Value = '"Original"'; Requires = '5200.ROM' }
               @{ Key = 'atari800_os_5200'; Value = '"AltirraOS"'; UnlessBios = '5200.ROM' }
           ) }
        @{ RelativePath = 'Atari800\{{RomDirName:atari800}}.opt'
           Settings = @( @{ Key = 'atari800_system'; Value = '"800XL (64K)"' } ) }
        @{ RelativePath = 'ParaLLEl N64\ParaLLEl N64.opt'
           Settings = @(
               @{ Key = 'parallel-n64-gfxplugin'; Value = '"parallel"' }
               @{ Key = 'parallel-n64-rspplugin'; Value = '"parallel"' }
           ) }
    )

    # Per-game DuckStation overrides -> <DuckStation dir>\gamesettings\<SERIAL>.ini.
    # Empty: the Linux entries are for the maintainer's own PS1 library.
    # @{ Serial = 'SCUS-94455'; Settings = @(@{ Section='GPU'; Option='WidescreenHack'; Value='false' }) }
    DuckstationPerGameSettings = @()

    # Dolphin controller profiles copied into its Config dir. Empty: the Linux
    # profiles are for the maintainer's 8BitDo pads. Source is relative to config\.
    # @{ Source = 'dolphin-profiles\GCPadNew.ini'; Dest = 'GCPadNew.ini' }
    DolphinConfigDir = '%USERPROFILE%\Documents\Dolphin Emulator\Config'
    DolphinControllerProfiles = @()

    # Windows analogue of dg_nvidia_enabled: per-exe "High performance" GPU
    # preference, applied only when Windows reports more than one GPU.
    PreferDiscreteGpu = $true
}
