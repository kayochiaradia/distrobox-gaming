@{
    # Windows port of ansible/group_vars/all/emulators.yml + gpu.yml, trimmed
    # to settings that actually change something on Windows. Dropped on
    # purpose (see windows/README.md#what-was-not-ported):
    #   - values that already are the Windows default
    #   - keys that no longer exist in current emulator builds
    #   - Linux-only workarounds: VK_ICD_FILENAMES/Vulkan forcing, PulseAudio,
    #     container locale (PCSX2 Language), NAS read-ahead (CdvdPrecache,
    #     LoadImageToRAM -- ROMs live on the local C: drive here)
    #
    # Paths use %VAR% placeholders (Import-PowerShellDataFile can't evaluate
    # $env:), expanded when loaded.
    #
    # configure-emulators.ps1 only edits a config file the emulator already
    # created on first launch -- run each emulator once before -Action Configure.

    # --- PCSX2 (PS2) --------------------------------------------------------
    # Not yet verified against a live Windows install (installer needs UAC).
    Pcsx2IniPath = '%USERPROFILE%\Documents\PCSX2\inis\PCSX2.ini'
    Pcsx2Settings = @(
        @{ Section = 'UI'; Option = 'ConfirmShutdown'; Value = 'false' }
        @{ Section = 'Hotkeys'; Option = 'ShutdownVM'; Value = 'SDL-0/Start & SDL-0/Back' }
        @{ Section = 'Hotkeys'; Option = 'SaveStateToSlot1'; Value = 'SDL-0/Back & SDL-0/RightShoulder' }
        @{ Section = 'Hotkeys'; Option = 'LoadStateFromSlot1'; Value = 'SDL-0/Back & SDL-0/LeftShoulder' }
        # 6x internal resolution targets a high-end discrete GPU (4K output).
        # Lower it on weaker hardware.
        @{ Section = 'EmuCore/GS'; Option = 'upscale_multiplier'; Value = '6.000000' }
        @{ Section = 'EmuCore/GS'; Option = 'MaxAnisotropy'; Value = '16' }
        @{ Section = 'EmuCore/GS'; Option = 'fxaa'; Value = 'true' }
        @{ Section = 'EmuCore/GS'; Option = 'LoadTextureReplacements'; Value = 'true' }
        @{ Section = 'EmuCore/GS'; Option = 'TextureReplacementsAsync'; Value = 'true' }
        @{ Section = 'EmuCore'; Option = 'EnableWideScreenPatches'; Value = 'true' }
        @{ Section = 'EmuCore/Speedhacks'; Option = 'fastCDVD'; Value = 'true' }
        @{ Section = 'EmuCore'; Option = 'SaveStateOnShutdown'; Value = 'true' }
        # SDL must be on for the SDL-0/* bindings below to resolve.
        @{ Section = 'InputSources'; Option = 'SDL'; Value = 'true' }
        @{ Section = 'InputSources'; Option = 'SDLControllerEnhancedMode'; Value = 'true' }
        @{ Section = 'Pad1'; Option = 'Type'; Value = 'DualShock2' }
        @{ Section = 'Pad1'; Option = 'Cross'; Value = 'SDL-0/A' }
        @{ Section = 'Pad1'; Option = 'Circle'; Value = 'SDL-0/B' }
        @{ Section = 'Pad1'; Option = 'Square'; Value = 'SDL-0/X' }
        @{ Section = 'Pad1'; Option = 'Triangle'; Value = 'SDL-0/Y' }
        @{ Section = 'Pad1'; Option = 'DPadUp'; Value = 'SDL-0/DPadUp' }
        @{ Section = 'Pad1'; Option = 'DPadDown'; Value = 'SDL-0/DPadDown' }
        @{ Section = 'Pad1'; Option = 'DPadLeft'; Value = 'SDL-0/DPadLeft' }
        @{ Section = 'Pad1'; Option = 'DPadRight'; Value = 'SDL-0/DPadRight' }
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
    )

    # --- DuckStation (PS1) --------------------------------------------------
    # Verified 2026-09-17 against a live install (0.1-11752): every key below
    # exists in its settings.ini and differs from the Windows default.
    DuckstationIniPath = '%LOCALAPPDATA%\DuckStation\settings.ini'
    DuckstationSettings = @(
        @{ Section = 'Main'; Option = 'ConfirmPowerOff'; Value = 'false' }
        @{ Section = 'Main'; Option = 'StartFullscreen'; Value = 'true' }
        @{ Section = 'Main'; Option = 'CreateSaveStateBackups'; Value = 'false' }
        # Only applied when BiosRoot exists; otherwise DuckStation keeps its
        # own %LOCALAPPDATA%\DuckStation\bios folder.
        @{ Section = 'BIOS'; Option = 'SearchDirectory'; Value = '{{BiosRoot}}' }
        @{ Section = 'BIOS'; Option = 'PatchFastBoot'; Value = 'true' }
        # 8x (4K+) targets a high-end discrete GPU. Lower it on weaker hardware.
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
        # Lives under [Hacks] in older builds; current builds moved it here.
        @{ Section = 'TextureReplacements'; Option = 'MaxVRAMWriteSplits'; Value = '1024' }
    )
    # Per-game overrides -> <DuckStation dir>\gamesettings\<SERIAL>.ini. Same
    # capability as ansible's dg_duckstation_per_game_settings; empty because
    # the Linux entries are for the maintainer's own PS1 library.
    # @{ Serial = 'SCUS-94455'; Settings = @(@{ Section='GPU'; Option='WidescreenHack'; Value='false' }) }
    DuckstationPerGameSettings = @()

    # --- RetroArch -----------------------------------------------------------
    # Installer default; config lives beside the exe. Core option files are
    # resolved under <folder of retroarch.cfg>\config\.
    RetroarchCfgPath = 'C:\RetroArch-Win64\retroarch.cfg'
    RetroarchSettings = @(
        # Xbox-style menu confirm/cancel. The Linux audio_driver=pulse override
        # is not ported: RetroArch already defaults to a native Windows driver.
        @{ Key = 'menu_swap_ok_cancel_buttons'; Value = '"true"' }
    )
    RetroarchCoreOptions = @(
        @{
            RelativePath = 'bsnes-hd beta\bsnes-hd beta.opt'
            Settings = @(
                @{ Key = 'bsnes_mode7_wsMode'; Value = '"all"' }
                @{ Key = 'bsnes_mode7_widescreen'; Value = '"16:9"' }
                @{ Key = 'bsnes_mode7_wsobj'; Value = '"unsafe"' }
                @{ Key = 'bsnes_video_aspectcorrection'; Value = '"ON"' }
            )
        }
        # melonDS's hardware renderer is OpenGL-only; guards against a black
        # screen if the global video driver is vulkan or d3d11/d3d12.
        @{
            RelativePath = 'melonDS\melonDS.cfg'
            Settings = @( @{ Key = 'video_driver'; Value = '"glcore"' } )
        }
        @{
            RelativePath = 'melonDS\melonDS.opt'
            Settings = @( @{ Key = 'melonds_opengl_renderer'; Value = '"enabled"' } )
        }
        @{
            RelativePath = 'ParaLLEl N64\ParaLLEl N64.opt'
            Settings = @(
                @{ Key = 'parallel-n64-gfxplugin'; Value = '"parallel"' }
                @{ Key = 'parallel-n64-rspplugin'; Value = '"parallel"' }
            )
        }
    )

    # --- Dolphin -------------------------------------------------------------
    DolphinConfigDir = '%USERPROFILE%\Documents\Dolphin Emulator\Config'
    # Same capability as ansible's dg_dolphin_configs; empty because the Linux
    # profiles are for the maintainer's 8BitDo Ultimate 2 pads. Source is
    # relative to this config/ directory:
    # @{ Source = 'dolphin-profiles\GCPadNew.ini'; Dest = 'GCPadNew.ini' }
    DolphinControllerProfiles = @()

    # --- GPU preference ------------------------------------------------------
    # Windows analogue of ansible's dg_nvidia_enabled. Only acts when Windows
    # reports more than one display adapter (iGPU + dGPU); on a single-GPU PC
    # there is nothing to choose, so it is skipped automatically.
    PreferDiscreteGpu = $true
}
