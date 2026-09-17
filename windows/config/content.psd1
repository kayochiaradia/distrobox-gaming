@{
    # Opt-in content for content.ps1 -- the Windows port of the Linux roles
    # that are never-tagged in site.yml: install_dlcs, switch_cheats,
    # rpcs3_per_game_configs, pcsx2_textures, install_rom_patches and
    # install_hd_textures. Nothing here runs unless its tag is passed.
    #
    # Tokens: %VAR%, {dir:<app id>}, {reporoot}, {{RomRoot}}, {{RomPath:<sys>}},
    # {{HdTexturesRoot}}, {{Pcsx2PacksRoot}}. Anything missing is reported and
    # skipped. ROMs, BIOS and saves are never deleted (rom_patches -Revert only
    # removes the patched outputs it created).

    # --- Sources: same sibling layout as the Linux ROM tree -----------------
    Ps3DlcSource        = '{{RomRoot}}\ps3-DLC'
    SwitchUpdatesSource = '{{RomRoot}}\switch_updates'
    SwitchCheatsSource  = '{{RomRoot}}\switch_cheats'
    Pcsx2PacksRoot      = '{{RomRoot}}\ps2-packs'
    Pcsx2CheatsSource   = '{{Pcsx2PacksRoot}}\cheats'
    HdTexturesRoot      = '{{RomRoot}}\HD-textures'

    # --- Destinations --------------------------------------------------------
    Rpcs3GameDir        = '{dir:rpcs3}\dev_hdd0\game'
    Rpcs3CustomConfigs  = '{dir:rpcs3}\config\custom_configs'
    EdenNandRegistered  = '%APPDATA%\eden\nand\user\Contents\registered'
    EdenLoadDir         = '%APPDATA%\eden\load'
    Pcsx2Dir            = '%USERPROFILE%\Documents\PCSX2'
    DolphinTexturesDir  = '%USERPROFILE%\Documents\Dolphin Emulator\Load\Textures'

    # --- Helper scripts reused unchanged from the Linux roles ---------------
    Scripts = @{
        ExtractPs3Dlc        = '{reporoot}\ansible\roles\scripts_in_box\files\extract_ps3_dlc.py'
        InstallSwitchUpdates = '{reporoot}\ansible\roles\scripts_in_box\files\install_switch_updates.py'
        GenerateRpcs3Configs = '{reporoot}\ansible\roles\rpcs3_per_game_configs\files\generate_rpcs3_configs.py'
        ApplyIps             = '{reporoot}\ansible\roles\install_rom_patches\files\apply_ips.py'
        ApplyBps             = '{reporoot}\ansible\roles\install_rom_patches\files\apply_bps.py'
        RomPatchFiles        = '{reporoot}\ansible\roles\install_rom_patches\files'
        Pcsx2LocalPnach      = '{reporoot}\ansible\roles\pcsx2_textures\files'
    }

    # --- PCSX2 (dg_pcsx2_*) --------------------------------------------------
    # Texture packs: each source folder is junctioned to
    # textures\<Serial>\replacements\<LinkAs>. Sources are the Linux layout
    # under Pcsx2PacksRoot; missing ones are skipped.
    Pcsx2TexturePacks = @(
        @{ Serial = 'SCUS-97328'; Name = 'Gran Turismo 4'; Sources = @(
            @{ Path = '{{Pcsx2PacksRoot}}\Gran Turismo 4 Remaster\Gran Turismo 4 HD HUD & UI Texture pack by Silentwarior112\replacements'; LinkAs = 'hd-hud-ui' }
            @{ Path = '{{Pcsx2PacksRoot}}\Gran Turismo 4 Remaster\update 2.1\replacements'; LinkAs = 'hd-hud-ui-update-2.1' }
            @{ Path = '{{Pcsx2PacksRoot}}\Gran Turismo 4 Remaster\HD HUD & U.I. blocky haze fix v2\text files jap kor usa pal shared'; LinkAs = 'blocky-haze-fix' }
        ) }
        @{ Serial = 'SCUS-97436'; Name = 'Gran Turismo 4 Spec II'; Sources = @(
            @{ Path = '{{Pcsx2PacksRoot}}\Gran Turismo 4 Remaster\Gran Turismo 4 HD HUD & UI Texture pack by Silentwarior112\replacements'; LinkAs = 'hd-hud-ui' }
            @{ Path = '{{Pcsx2PacksRoot}}\Gran Turismo 4 Remaster\update 2.1\replacements'; LinkAs = 'hd-hud-ui-update-2.1' }
            @{ Path = '{{Pcsx2PacksRoot}}\Gran Turismo 4 Remaster\HD HUD & U.I. blocky haze fix v2\text files jap kor usa pal shared'; LinkAs = 'blocky-haze-fix' }
        ) }
        @{ Serial = 'SCUS-97102'; Name = 'Gran Turismo 3 A-spec'; Sources = @(
            @{ Path = '{{Pcsx2PacksRoot}}\GT3 Retexture 1.0\replacements'; LinkAs = 'retexture-1.0' }
        ) }
        @{ Serial = 'PBPX-95503'; Name = 'Gran Turismo 3 A-spec (PS2 Bundle)'; Sources = @(
            @{ Path = '{{Pcsx2PacksRoot}}\GT3 Retexture 1.0\replacements'; LinkAs = 'retexture-1.0' }
        ) }
        @{ Serial = 'SLUS-20967'; Name = 'Enthusia Professional Racing'; Sources = @(
            @{ Path = '{{Pcsx2PacksRoot}}\Enthusia\SLUS-20967\replacements'; LinkAs = 'hd-textures' }
        ) }
    )

    # Public .pnach patches downloaded into patches\. PCSX2 only loads a pnach
    # whose CRC matches the running game, so patches for games you don't own
    # are harmless.
    Pcsx2PatchUrls = @(
        'https://raw.githubusercontent.com/CookiePLMonster/Console-Cheat-Codes/master/PS2/Gran%20Turismo%204/Adjusted%20triggers%20sensitivity/SCUS-97328_77E61C8A_triggers.pnach'
        'https://raw.githubusercontent.com/CookiePLMonster/Console-Cheat-Codes/master/PS2/Gran%20Turismo%204/GT3%20style%20camera/SCUS-97328_77E61C8A_gt3cam.pnach'
        'https://raw.githubusercontent.com/CookiePLMonster/Console-Cheat-Codes/master/PS2/Gran%20Turismo%204/Far%20chase%20camera/SCUS-97328_77E61C8A_farchasecam.pnach'
        'https://raw.githubusercontent.com/PCSX2/pcsx2_patches/main/patches/SLUS-20967_81D233DC.pnach'
        'https://raw.githubusercontent.com/PCSX2/pcsx2_patches/main/patches/SLUS-20002_06AD9CA0.pnach'
    )
    # Upstream pnach saved under a different CRC (same base game, other build).
    Pcsx2PatchUrlRenames = @(
        @{ Url = 'https://raw.githubusercontent.com/PCSX2/pcsx2_patches/main/patches/SCUS-97436_32A1C752.pnach'; DestName = 'SCUS-97436_4CE521F2.pnach' }
        @{ Url = 'https://raw.githubusercontent.com/PCSX2/pcsx2_patches/main/patches/SCUS-97102_85AE91B3.pnach'; DestName = 'SCUS-97102_85AE91B3.pnach' }
        @{ Url = 'https://raw.githubusercontent.com/AeroWidescreen/PCSX2-Cheats/main/Gran%20Turismo%203/PBPX-95503/Widescreen%20Text/PBPX-95503_8AA991B0_widescreen.pnach'; DestName = 'PBPX-95503_8AA991B0.pnach' }
    )
    # Repo-local pnach block appended once onto a deployed pnach.
    Pcsx2PatchAppends = @(
        @{ Target = 'SCUS-97436_4CE521F2.pnach'; LocalFile = 'SCUS-97436_4CE521F2-gt4specii-cheats.pnach' }
    )

    # gamesettings\<SERIAL>_<CRC>.ini (PCSX2 2.7+ reads only the CRC-suffixed
    # name). Ported from dg_pcsx2_per_game_settings with one fix:
    # TextureReplacementsAsync is LoadTextureReplacementsAsync in current PCSX2.
    Pcsx2PerGameSettings = @(
        @{ Serial = 'SCUS-97328'; Crc = '77E61C8A'; Name = 'Gran Turismo 4'; Settings = @(
            @{ Section = 'EmuCore/GS'; Option = 'AspectRatio'; Value = '16:9' }
            @{ Section = 'EmuCore/GS'; Option = 'AccurateBlendingUnit'; Value = 'Basic' }
            @{ Section = 'EmuCore/GS'; Option = 'MaxAnisotropy'; Value = '16' }
            @{ Section = 'EmuCore/GS'; Option = 'TextureFiltering'; Value = '2' }
            @{ Section = 'EmuCore/GS'; Option = 'LoadTextureReplacements'; Value = 'true' }
            @{ Section = 'EmuCore/GS'; Option = 'PrecacheTextureReplacements'; Value = 'false' }
            @{ Section = 'EmuCore/GS'; Option = 'LoadTextureReplacementsAsync'; Value = 'true' }
            @{ Section = 'EmuCore'; Option = 'EnableWideScreenPatches'; Value = 'true' }
        ) }
        @{ Serial = 'SCUS-97436'; Crc = '4CE521F2'; Name = 'Gran Turismo 4 Spec II'; Settings = @(
            @{ Section = 'EmuCore/GS'; Option = 'AspectRatio'; Value = '16:9' }
            @{ Section = 'EmuCore/GS'; Option = 'AccurateBlendingUnit'; Value = 'Basic' }
            @{ Section = 'EmuCore/GS'; Option = 'MaxAnisotropy'; Value = '16' }
            @{ Section = 'EmuCore/GS'; Option = 'TextureFiltering'; Value = '2' }
            @{ Section = 'EmuCore/GS'; Option = 'LoadTextureReplacements'; Value = 'true' }
            @{ Section = 'EmuCore/GS'; Option = 'PrecacheTextureReplacements'; Value = 'false' }
            @{ Section = 'EmuCore/GS'; Option = 'LoadTextureReplacementsAsync'; Value = 'true' }
            @{ Section = 'EmuCore/GS'; Option = 'deinterlace_mode'; Value = '8' }
            @{ Section = 'EmuCore/GS'; Option = 'ShadeBoost'; Value = 'true' }
            @{ Section = 'EmuCore/GS'; Option = 'ShadeBoost_Saturation'; Value = '60' }
            @{ Section = 'EmuCore/GS'; Option = 'ShadeBoost_Brightness'; Value = '53' }
            @{ Section = 'EmuCore/GS'; Option = 'ShadeBoost_Contrast'; Value = '52' }
            @{ Section = 'EmuCore'; Option = 'EnableWideScreenPatches'; Value = 'true' }
        ) }
        @{ Serial = 'SCUS-97102'; Crc = '85AE91B3'; Name = 'Gran Turismo 3 A-spec'; Settings = @(
            @{ Section = 'EmuCore/GS'; Option = 'AspectRatio'; Value = '16:9' }
            @{ Section = 'EmuCore/GS'; Option = 'AccurateBlendingUnit'; Value = 'Basic' }
            @{ Section = 'EmuCore/GS'; Option = 'MaxAnisotropy'; Value = '16' }
            @{ Section = 'EmuCore/GS'; Option = 'TextureFiltering'; Value = '2' }
            @{ Section = 'EmuCore/GS'; Option = 'LoadTextureReplacements'; Value = 'true' }
            @{ Section = 'EmuCore/GS'; Option = 'PrecacheTextureReplacements'; Value = 'false' }
            @{ Section = 'EmuCore/GS'; Option = 'LoadTextureReplacementsAsync'; Value = 'false' }
            @{ Section = 'EmuCore'; Option = 'EnableWideScreenPatches'; Value = 'true' }
        ) }
        @{ Serial = 'PBPX-95503'; Crc = '8AA991B0'; Name = 'Gran Turismo 3 A-spec (PS2 Bundle)'; Settings = @(
            @{ Section = 'EmuCore/GS'; Option = 'AspectRatio'; Value = '16:9' }
            @{ Section = 'EmuCore/GS'; Option = 'AccurateBlendingUnit'; Value = 'Basic' }
            @{ Section = 'EmuCore/GS'; Option = 'MaxAnisotropy'; Value = '16' }
            @{ Section = 'EmuCore/GS'; Option = 'TextureFiltering'; Value = '2' }
            @{ Section = 'EmuCore/GS'; Option = 'LoadTextureReplacements'; Value = 'true' }
            @{ Section = 'EmuCore/GS'; Option = 'PrecacheTextureReplacements'; Value = 'false' }
            @{ Section = 'EmuCore/GS'; Option = 'LoadTextureReplacementsAsync'; Value = 'false' }
            @{ Section = 'EmuCore'; Option = 'EnableWideScreenPatches'; Value = 'true' }
        ) }
        @{ Serial = 'SLUS-20967'; Crc = '81D233DC'; Name = 'Enthusia Professional Racing'; Settings = @(
            @{ Section = 'EmuCore/GS'; Option = 'AspectRatio'; Value = '16:9' }
            @{ Section = 'EmuCore/GS'; Option = 'MaxAnisotropy'; Value = '16' }
            @{ Section = 'EmuCore/GS'; Option = 'TextureFiltering'; Value = '2' }
            @{ Section = 'EmuCore/GS'; Option = 'LoadTextureReplacements'; Value = 'true' }
            @{ Section = 'EmuCore/GS'; Option = 'PrecacheTextureReplacements'; Value = 'false' }
            @{ Section = 'EmuCore/GS'; Option = 'LoadTextureReplacementsAsync'; Value = 'true' }
            @{ Section = 'EmuCore'; Option = 'EnableWideScreenPatches'; Value = 'true' }
        ) }
        @{ Serial = 'SLES-51824'; Crc = 'DCC25DBE'; Name = 'Colin McRae Rally 04'; Settings = @(
            @{ Section = 'EmuCore/GS'; Option = 'AspectRatio'; Value = '16:9' }
            @{ Section = 'EmuCore/GS'; Option = 'MaxAnisotropy'; Value = '16' }
            @{ Section = 'EmuCore/GS'; Option = 'TextureFiltering'; Value = '2' }
            @{ Section = 'EmuCore/GS'; Option = 'AccurateBlendingUnit'; Value = 'High' }
            @{ Section = 'EmuCore/GS'; Option = 'UserHacks'; Value = 'true' }
            @{ Section = 'EmuCore/GS'; Option = 'UserHacks_SkipDraw_Start'; Value = '1' }
            @{ Section = 'EmuCore/GS'; Option = 'UserHacks_SkipDraw_End'; Value = '3' }
            @{ Section = 'EmuCore/GS'; Option = 'UserHacks_HalfPixelOffset'; Value = '4' }
            @{ Section = 'EmuCore/GS'; Option = 'UserHacks_AutoFlush'; Value = '2' }
            @{ Section = 'EmuCore/GS'; Option = 'UserHacks_RoundSprite'; Value = '0' }
            @{ Section = 'EmuCore/GS'; Option = 'UserHacks_AlignSpriteX'; Value = 'false' }
            @{ Section = 'EmuCore/GS'; Option = 'UserHacks_MergePPSprite'; Value = 'false' }
        ) }
        @{ Serial = 'SLES-52636'; Crc = '05C3F8E1'; Name = 'Colin McRae Rally 2005'; Settings = @(
            @{ Section = 'EmuCore/GS'; Option = 'AspectRatio'; Value = '16:9' }
            @{ Section = 'EmuCore/GS'; Option = 'MaxAnisotropy'; Value = '16' }
            @{ Section = 'EmuCore/GS'; Option = 'TextureFiltering'; Value = '2' }
            @{ Section = 'EmuCore/GS'; Option = 'AccurateBlendingUnit'; Value = 'High' }
            @{ Section = 'EmuCore/GS'; Option = 'UserHacks'; Value = 'true' }
            @{ Section = 'EmuCore/GS'; Option = 'UserHacks_CPUCLUTRender'; Value = '1' }
            @{ Section = 'EmuCore/GS'; Option = 'UserHacks_SkipDraw_Start'; Value = '1' }
            @{ Section = 'EmuCore/GS'; Option = 'UserHacks_SkipDraw_End'; Value = '3' }
            @{ Section = 'EmuCore/GS'; Option = 'UserHacks_HalfPixelOffset'; Value = '4' }
            @{ Section = 'EmuCore/GS'; Option = 'UserHacks_RoundSprite'; Value = '0' }
            @{ Section = 'EmuCore/GS'; Option = 'UserHacks_AlignSpriteX'; Value = 'false' }
            @{ Section = 'EmuCore/GS'; Option = 'UserHacks_MergePPSprite'; Value = 'false' }
            @{ Section = 'EmuCore/GS'; Option = 'UserHacks_AutoFlush'; Value = '0' }
        ) }
        @{ Serial = 'SLUS-20002'; Crc = '06AD9CA0'; Name = 'Ridge Racer V'; Settings = @(
            @{ Section = 'EmuCore/GS'; Option = 'AspectRatio'; Value = '16:9' }
            @{ Section = 'EmuCore/GS'; Option = 'MaxAnisotropy'; Value = '16' }
            @{ Section = 'EmuCore/GS'; Option = 'TextureFiltering'; Value = '2' }
            @{ Section = 'EmuCore'; Option = 'EnableWideScreenPatches'; Value = 'true' }
            @{ Section = 'EmuCore'; Option = 'EnableNoInterlacingPatches'; Value = 'true' }
        ) }
    )

    # --- ROM patches (dg_rom_patches) ----------------------------------------
    # Patched copies written beside the untouched originals; base and output
    # SHA-1 are verified by the Linux apply_ips.py / apply_bps.py.
    RomPatches = @(
        @{ Name = 'Donkey Kong Country (GBA) SNES colour restoration'
           Base = '{{RomPath:gba}}\Donkey Kong Country (Europe) (En,Fr,De,Es,It).gba'; BaseSha1 = '8995f0be99a9cff66474a8975b8499bd69fb4c45'
           Patch = 'dkc_gba_restoration_v1_1.ips'
           Out = '{{RomPath:gba}}\Donkey Kong Country (Europe) (SNES Restoration).gba'; OutSha1 = '005b5571e169c45a0649fdb2cc52729f9d6b4116' }
        @{ Name = 'Final Fight ONE Arcade Edition v3.0 (USA)'
           Base = '{{RomPath:gba}}\Final Fight One (USA).gba'; BaseSha1 = '17918e125bcafd44fcf3b21813575c2ccb19bd45'
           Patch = 'ffoae_arcade_edition_u_v3.0.ips'
           Out = '{{RomPath:gba}}\Final Fight One - Arcade Edition (USA) [v3.0].gba'; OutSha1 = 'e189ae8abe70497cad342dd5e1e80fcfa53e0783' }
        @{ Name = 'F-Zero Vintage Velocity I (EN v2.1)'
           Base = '{{RomPath:gba}}\F-Zero - Maximum Velocity (USA, Europe).gba'; BaseSha1 = '8a08e29ec987f9cbdde21c34d5f7657aa7ba0be6'
           Patch = 'vintage_velocity_i_en_v2.1.ips'
           Out = '{{RomPath:gba}}\F-Zero - Vintage Velocity I (v2.1).gba'; OutSha1 = '40aab9df0c1209464f6a79e53e7b0352d5e77cc2' }
        @{ Name = 'F-Zero Vintage Velocity Ace (EN v3.0)'
           Base = '{{RomPath:gba}}\F-Zero - Maximum Velocity (USA, Europe).gba'; BaseSha1 = '8a08e29ec987f9cbdde21c34d5f7657aa7ba0be6'
           Patch = 'vintage_velocity_ace_en_v3.0.ips'
           Out = '{{RomPath:gba}}\F-Zero - Vintage Velocity Ace (v3.0).gba'; OutSha1 = '962f357de0237c54aba3acdd0bda70fe274314d6' }
        @{ Name = 'Super Metroid Redux v1.5'
           Base = '{{RomPath:snes}}\Super Metroid (Japan, USA) (En,Ja).sfc'; BaseSha1 = 'da957f0d63d14cb441d215462904c4fa8519c613'
           Patch = 'super_metroid_redux.ips'
           Out = '{{RomPath:snes}}\Super Metroid Redux.sfc'; OutSha1 = '0f4133f2e6bdd275b0ceec3e348e2d6bf1c8189e' }
        # ~19 MB BPS kept out of the repo, as on Linux: stage it yourself. Needs
        # the ParaLLEl N64 core (pick it per game in ES-DE).
        @{ Name = "Return to Yoshi's Island Demo 2 (Kaze, N64)"
           Base = '{{RomPath:n64}}\Super Mario 64 (USA).z64'; BaseSha1 = '9bef1128717f958171a4afac3ed78ee2bb4e86ce'
           PatchSource = '{{RomPath:n64}}\romhack-patches\RTYI Demo TWO 1.06.bps'
           Out = "{{RomPath:n64}}\Return to Yoshi's Island (Demo 2 v1.06).z64"; OutSha1 = '4e91e2375d4094ec5e04beeaa87b883de51dfcec' }
    )

    # --- HD texture packs (dg_hd_texture_packs) ------------------------------
    # Only the Load/Textures subtree of each zip is extracted (the packs bundle
    # a whole portable Dolphin), then each game ID is junctioned into Dolphin's
    # Load\Textures. The Linux Azahar packs stay disabled: they use the legacy
    # Citra texture hash, which current Azahar can't load.
    HdTexturePacks = @(
        @{ Slug = 'luigis-mansion'; Archive = "{{HdTexturesRoot}}\dolphin-textures\Luigi's Mansion 4K Texture Pack 1.1.0b (4K).zip"; GameIds = @('GLM') }
        @{ Slug = 'super-mario-sunshine'; Archive = '{{HdTexturesRoot}}\dolphin-textures\SMS 4K 2.0c (4K).zip'; GameIds = @('GMS') }
        @{ Slug = 'skyward-sword'; Archive = '{{HdTexturesRoot}}\dolphin-textures\Zelda Skyward Sword 4K (4K) 1.0.5.zip'; GameIds = @('SOU') }
        @{ Slug = 'wind-waker'; Archive = '{{HdTexturesRoot}}\dolphin-textures\ZWW4K 1.0.0d (4K).zip'; GameIds = @('GZL') }
    )
}
