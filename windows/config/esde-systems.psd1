@{
    # Windows port of ansible/group_vars/all/esde.yml. bootstrap.ps1 renders
    # these into <EsdeHome>\custom_systems\es_systems.xml, which overrides
    # ES-DE's bundled definition for each system listed (the others keep
    # ES-DE's defaults). Paths are filled in from RomRoot / RomPaths.
    #
    # Launch syntax follows ES-DE's bundled Windows es_systems.xml; the first
    # command is the default, matching the Linux choice. Linux-only wrapper
    # scripts (flycast-hires/gamescope, Wine launchers, xenia .xbla stubs)
    # are replaced by the plain emulator command; retroarch-snes becomes
    # AltEmulators below and retroarch-atari800 RetroArch folder options.
    #
    # Not expanded as %VAR% on load -- %ROM%, %EMULATOR_X% etc. are ES-DE
    # variables.

    # MAME-style arcade systems whose ROM folder has a Skraper gamelist.xml:
    # bootstrap.ps1 generates the ES-DE gamelist with clone sets hidden
    # (Linux dg_esde_arcade_clone_systems).
    ArcadeCloneSystems = @('model1', 'model2', 'model3')

    # Per-game emulator, written as <altemulator> into the ES-DE gamelist for
    # ROMs under <system ROM dir>\<Folder> whose file name matches Pattern
    # (regex). Label must be one of that system's command labels. Port of
    # bin/retroarch-snes: Vitor Vilela's SMW widescreen hack needs bsnes-hd.
    AltEmulators = @(
        @{ System = 'snes'; Folder = 'no_match'; Pattern = '(?i)smw.*widescreen|super.*mario.*world.*widescreen'
           Label = 'bsnes-hd beta (RetroArch)' }
    )

    Systems = @(
        @{ Name = 'switch'; FullName = 'Nintendo Switch'; Platform = 'switch'; Theme = 'switch'
           Extension = '.nca .NCA .nro .NRO .nso .NSO .nsp .NSP .xci .XCI'
           Commands = @(
               @{ Label = 'Eden (Standalone)'; Cmd = '%EMULATOR_EDEN% -f -g %ROM%' }
               @{ Label = 'Ryujinx (Standalone)'; Cmd = '%EMULATOR_RYUJINX% %ROM%' }
           ) }

        @{ Name = 'psx'; FullName = 'Sony PlayStation'; Platform = 'psx'; Theme = 'psx'
           Extension = '.bin .BIN .cbn .CBN .ccd .CCD .chd .CHD .cue .CUE .ecm .ECM .exe .EXE .img .IMG .iso .ISO .m3u .M3U .mdf .MDF .mds .MDS .minipsf .MINIPSF .pbp .PBP .psexe .PSEXE .psf .PSF .toc .TOC .z .Z .znx .ZNX .7z .7Z .zip .ZIP'
           Commands = @(
               @{ Label = 'DuckStation (Standalone)'; Cmd = '%EMULATOR_DUCKSTATION% -batch %ROM%' }
               @{ Label = 'Beetle PSX HW (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\mednafen_psx_hw_libretro.dll %ROM%' }
               @{ Label = 'Beetle PSX (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\mednafen_psx_libretro.dll %ROM%' }
           ) }

        @{ Name = 'ps2'; FullName = 'Sony PlayStation 2'; Platform = 'ps2'; Theme = 'ps2'
           Extension = '.bin .BIN .chd .CHD .ciso .CISO .cso .CSO .dump .DUMP .elf .ELF .gz .GZ .m3u .M3U .mdf .MDF .img .IMG .iso .ISO .isz .ISZ .ngr .NRG .zso .ZSO'
           Commands = @(
               @{ Label = 'PCSX2 (Standalone)'; Cmd = '%EMULATOR_PCSX2% -batch %ROM%' }
               @{ Label = 'PCSX2 (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\pcsx2_libretro.dll %ROM%' }
           ) }

        @{ Name = 'dreamcast'; FullName = 'Sega Dreamcast'; Platform = 'dreamcast'; Theme = 'dreamcast'
           Extension = '.cdi .CDI .chd .CHD .cue .CUE .dat .DAT .elf .ELF .gdi .GDI .iso .ISO .lst .LST .m3u .M3U .7z .7Z .zip .ZIP'
           Commands = @(
               @{ Label = 'Flycast (Standalone)'; Cmd = '%EMULATOR_FLYCAST% %ROM%' }
               @{ Label = 'Flycast (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\flycast_libretro.dll %ROM%' }
           ) }

        @{ Name = 'gc'; FullName = 'Nintendo GameCube'; Platform = 'gc'; Theme = 'gc'
           Extension = '.ciso .CISO .dff .DFF .dol .DOL .elf .ELF .gcm .GCM .gcz .GCZ .iso .ISO .json .JSON .m3u .M3U .rvz .RVZ .tgc .TGC .wad .WAD .wbfs .WBFS .wia .WIA .7z .7Z .zip .ZIP'
           Commands = @(
               @{ Label = 'Dolphin (Standalone)'; Cmd = '%EMULATOR_DOLPHIN% -b -e %ROM%' }
               @{ Label = 'Dolphin (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\dolphin_libretro.dll %ROM%' }
           ) }

        @{ Name = 'wii'; FullName = 'Nintendo Wii'; Platform = 'wii'; Theme = 'wii'
           Extension = '.ciso .CISO .dff .DFF .dol .DOL .elf .ELF .gcm .GCM .gcz .GCZ .iso .ISO .json .JSON .m3u .M3U .rvz .RVZ .tgc .TGC .wad .WAD .wbfs .WBFS .wia .WIA .7z .7Z .zip .ZIP'
           Commands = @(
               @{ Label = 'Dolphin (Standalone)'; Cmd = '%EMULATOR_DOLPHIN% -b -e %ROM%' }
               @{ Label = 'Dolphin (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\dolphin_libretro.dll %ROM%' }
           ) }

        @{ Name = 'wiiu'; FullName = 'Nintendo Wii U'; Platform = 'wiiu'; Theme = 'wiiu'
           Extension = '.elf .ELF .rpx .RPX .tmd .TMD .wua .WUA .wud .WUD .wuhb .WUHB .wux .WUX'
           Commands = @(
               @{ Label = 'Cemu (Standalone)'; Cmd = '%EMULATOR_CEMU% -f -g %ROM%' }
           ) }

        @{ Name = 'psp'; FullName = 'Sony PlayStation Portable'; Platform = 'psp'; Theme = 'psp'
           Extension = '.chd .CHD .cso .CSO .elf .ELF .iso .ISO .pbp .PBP .prx .PRX .7z .7Z .zip .ZIP'
           Commands = @(
               @{ Label = 'PPSSPP (Standalone)'; Cmd = '%EMULATOR_PPSSPP% %ROM%' }
               @{ Label = 'PPSSPP (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\ppsspp_libretro.dll %ROM%' }
           ) }

        @{ Name = 'psvita'; FullName = 'Sony PlayStation Vita'; Platform = 'psvita'; Theme = 'psvita'
           Extension = '.psvita'
           Commands = @(
               @{ Label = 'Vita3K (Standalone)'; Cmd = '%STARTDIR%=%EMUDIR% %EMULATOR_VITA3K% -r %INJECT%=%BASENAME%.psvita' }
           ) }

        # Extracted-folder dumps named "<Title>.ps3" (PS3_GAME/USRDIR/EBOOT.BIN
        # inside), same layout as Linux.
        @{ Name = 'ps3'; FullName = 'Sony PlayStation 3'; Platform = 'ps3'; Theme = 'ps3'
           Extension = '.ps3 .PS3'
           Commands = @(
               @{ Label = 'RPCS3 (Standalone)'; Cmd = '%EMULATOR_RPCS3% --no-gui %ROM%' }
           ) }

        # <ps4 dir>\CUSAxxxxx\eboot.bin, same layout as Linux.
        @{ Name = 'ps4'; FullName = 'Sony PlayStation 4'; Platform = 'ps4'; Theme = 'ps4'
           Extension = '.bin .BIN'
           Commands = @(
               @{ Label = 'shadPS4 (Standalone)'; Cmd = '%STARTDIR%=%EMUDIR% %EMULATOR_SHADPS4% %ROM%' }
           ) }

        @{ Name = 'xbox'; FullName = 'Microsoft Xbox'; Platform = 'xbox'; Theme = 'xbox'
           Extension = '.iso .ISO .xiso .XISO'
           Commands = @(
               @{ Label = 'xemu (Standalone)'; Cmd = '%STARTDIR%=%EMUDIR% %EMULATOR_XEMU% -dvd_path %ROM%' }
           ) }

        @{ Name = 'n3ds'; FullName = 'Nintendo 3DS'; Platform = 'n3ds'; Theme = 'n3ds'
           Extension = '.3ds .3DS .cci .CCI .cxi .CXI .app .APP .elf .ELF .cia .CIA .3dsx .3DSX'
           Commands = @(
               @{ Label = 'Azahar (Standalone)'; Cmd = '%EMULATOR_AZAHAR% %ROM%' }
           ) }

        @{ Name = 'xbox360'; FullName = 'Microsoft Xbox 360'; Platform = 'xbox360'; Theme = 'xbox360'
           Extension = '.iso .ISO .xex .XEX'
           Commands = @(
               @{ Label = 'Xenia Canary (Standalone)'; Cmd = '%STARTDIR%=%EMUDIR% %EMULATOR_XENIA% %ROM%' }
           ) }

        @{ Name = 'model1'; FullName = 'Sega Model 1'; Platform = 'arcade'; Theme = 'model1'
           Extension = '.zip .ZIP'
           Commands = @(
               @{ Label = 'MAME (Standalone)'; Cmd = '%HIDEWINDOW% %STARTDIR%=%EMUDIR% %EMULATOR_MAME% -rompath %GAMEDIR% %BASENAME%' }
               @{ Label = 'MAME (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\mame_libretro.dll %ROM%' }
           ) }

        @{ Name = 'model2'; FullName = 'Sega Model 2'; Platform = 'arcade'; Theme = 'model2'
           Extension = '.zip .ZIP'
           Commands = @(
               @{ Label = 'Model 2 Emulator (Standalone)'; Cmd = '%RUNINBACKGROUND% %STARTDIR%=%EMUDIR% %EMULATOR_M2EMULATOR% %BASENAME%' }
               @{ Label = 'Model 2 Emulator [Suspend ES-DE] (Standalone)'; Cmd = '%STARTDIR%=%EMUDIR% %EMULATOR_M2EMULATOR% %BASENAME%' }
               @{ Label = 'MAME (Standalone)'; Cmd = '%HIDEWINDOW% %STARTDIR%=%EMUDIR% %EMULATOR_MAME% -rompath %GAMEDIR% %BASENAME%' }
           ) }

        @{ Name = 'model3'; FullName = 'Sega Model 3'; Platform = 'arcade'; Theme = 'model3'
           Extension = '.zip .ZIP'
           Commands = @(
               @{ Label = 'Supermodel (Standalone)'; Cmd = '%STARTDIR%=%EMUDIR% %EMULATOR_SUPERMODEL% %INJECT%=%BASENAME%.commands %ROM%' }
               @{ Label = 'MAME (Standalone)'; Cmd = '%HIDEWINDOW% %STARTDIR%=%EMUDIR% %EMULATOR_MAME% -rompath %GAMEDIR% %BASENAME%' }
           ) }

        # MAME-style zips only; GD-ROM CHDs live in a folder named after the
        # zip, so a wider extension list would list them twice.
        @{ Name = 'naomi'; FullName = 'Sega NAOMI'; Platform = 'arcade'; Theme = 'naomi'
           Extension = '.zip .ZIP .7z .7Z'
           Commands = @(
               @{ Label = 'Flycast (Standalone)'; Cmd = '%EMULATOR_FLYCAST% %ROM%' }
               @{ Label = 'Flycast (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\flycast_libretro.dll %ROM%' }
           ) }

        @{ Name = 'naomi2'; FullName = 'Sega NAOMI 2'; Platform = 'arcade'; Theme = 'naomi2'
           Extension = '.zip .ZIP .7z .7Z'
           Commands = @(
               @{ Label = 'Flycast (Standalone)'; Cmd = '%EMULATOR_FLYCAST% %ROM%' }
               @{ Label = 'Flycast (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\flycast_libretro.dll %ROM%' }
           ) }

        @{ Name = 'nes'; FullName = 'Nintendo Entertainment System'; Platform = 'nes'; Theme = 'nes'
           Extension = '.nes .NES .fds .FDS .unif .UNIF .unf .UNF .zip .ZIP .7z .7Z'
           Commands = @(
               @{ Label = 'Mesen (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\mesen_libretro.dll %ROM%' }
           ) }

        @{ Name = 'snes'; FullName = 'Super Nintendo Entertainment System'; Platform = 'snes'; Theme = 'snes'
           Extension = '.smc .SMC .sfc .SFC .swc .SWC .fig .FIG .bs .BS .st .ST .7z .7Z .zip .ZIP'
           Commands = @(
               @{ Label = 'bsnes (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\bsnes_libretro.dll %ROM%' }
               @{ Label = 'bsnes-hd beta (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\bsnes_hd_beta_libretro.dll %ROM%' }
               @{ Label = 'Snes9x (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\snes9x_libretro.dll %ROM%' }
           ) }

        @{ Name = 'gb'; FullName = 'Nintendo Game Boy'; Platform = 'gb'; Theme = 'gb'
           Extension = '.gb .GB .7z .7Z .zip .ZIP'
           Commands = @( @{ Label = 'Gambatte (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\gambatte_libretro.dll %ROM%' } ) }

        @{ Name = 'gbc'; FullName = 'Nintendo Game Boy Color'; Platform = 'gbc'; Theme = 'gbc'
           Extension = '.gbc .GBC .gb .GB .7z .7Z .zip .ZIP'
           Commands = @( @{ Label = 'Gambatte (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\gambatte_libretro.dll %ROM%' } ) }

        @{ Name = 'gba'; FullName = 'Nintendo Game Boy Advance'; Platform = 'gba'; Theme = 'gba'
           Extension = '.gba .GBA .7z .7Z .zip .ZIP'
           Commands = @( @{ Label = 'mGBA (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\mgba_libretro.dll %ROM%' } ) }

        @{ Name = 'nds'; FullName = 'Nintendo DS'; Platform = 'nds'; Theme = 'nds'
           Extension = '.nds .NDS .zip .ZIP .7z .7Z'
           Commands = @(
               @{ Label = 'melonDS (Standalone)'; Cmd = '%EMULATOR_MELONDS% -f %ROM%' }
               @{ Label = 'melonDS (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\melonds_libretro.dll %ROM%' }
           ) }

        @{ Name = 'n64'; FullName = 'Nintendo 64'; Platform = 'n64'; Theme = 'n64'
           Extension = '.n64 .N64 .v64 .V64 .z64 .Z64 .ndd .NDD .zip .ZIP .7z .7Z'
           Commands = @(
               @{ Label = 'Mupen64Plus-Next (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\mupen64plus_next_libretro.dll %ROM%' }
               @{ Label = 'ParaLLEl N64 (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\parallel_n64_libretro.dll %ROM%' }
               @{ Label = 'Parallel Launcher (Standalone)'; Cmd = '%EMULATOR_PARALLEL-LAUNCHER% %ROM%' }
           ) }

        @{ Name = 'mastersystem'; FullName = 'Sega Master System'; Platform = 'mastersystem'; Theme = 'mastersystem'
           Extension = '.sms .SMS .7z .7Z .zip .ZIP'
           Commands = @( @{ Label = 'Genesis Plus GX (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\genesis_plus_gx_libretro.dll %ROM%' } ) }

        @{ Name = 'genesis'; FullName = 'Sega Genesis / Mega Drive'; Platform = 'genesis'; Theme = 'genesis'
           Extension = '.smd .SMD .md .MD .bin .BIN .gen .GEN .7z .7Z .zip .ZIP'
           Commands = @( @{ Label = 'Genesis Plus GX (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\genesis_plus_gx_libretro.dll %ROM%' } ) }

        @{ Name = 'gamegear'; FullName = 'Sega Game Gear'; Platform = 'gamegear'; Theme = 'gamegear'
           Extension = '.gg .GG .7z .7Z .zip .ZIP'
           Commands = @( @{ Label = 'Genesis Plus GX (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\genesis_plus_gx_libretro.dll %ROM%' } ) }

        @{ Name = 'sega32x'; FullName = 'Sega 32X'; Platform = 'sega32x'; Theme = 'sega32x'
           Extension = '.32x .32X .smd .SMD .md .MD .bin .BIN .7z .7Z .zip .ZIP'
           Commands = @( @{ Label = 'PicoDrive (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\picodrive_libretro.dll %ROM%' } ) }

        @{ Name = 'megacd'; FullName = 'Sega CD / Mega CD'; Platform = 'segacd'; Theme = 'segacd'
           Extension = '.cue .CUE .chd .CHD .iso .ISO .ccd .CCD .m3u .M3U .7z .7Z .zip .ZIP'
           Commands = @( @{ Label = 'Genesis Plus GX (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\genesis_plus_gx_libretro.dll %ROM%' } ) }

        @{ Name = 'saturn'; FullName = 'Sega Saturn'; Platform = 'saturn'; Theme = 'saturn'
           Extension = '.cue .CUE .chd .CHD .iso .ISO .ccd .CCD .mds .MDS .m3u .M3U .7z .7Z .zip .ZIP'
           Commands = @( @{ Label = 'Beetle Saturn (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\mednafen_saturn_libretro.dll %ROM%' } ) }

        @{ Name = 'neogeo'; FullName = 'SNK Neo Geo AES / MVS'; Platform = 'neogeo'; Theme = 'neogeo'
           Extension = '.zip .ZIP .7z .7Z'
           Commands = @( @{ Label = 'FB Neo (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\fbneo_libretro.dll %ROM%' } ) }

        @{ Name = 'cps'; FullName = 'Capcom Play System'; Platform = 'arcade'; Theme = 'cps'
           Extension = '.zip .ZIP .7z .7Z'
           Commands = @( @{ Label = 'FB Neo (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\fbneo_libretro.dll %ROM%' } ) }

        @{ Name = 'cps2'; FullName = 'Capcom Play System II'; Platform = 'arcade'; Theme = 'cps2'
           Extension = '.zip .ZIP .7z .7Z'
           Commands = @( @{ Label = 'FB Neo (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\fbneo_libretro.dll %ROM%' } ) }

        @{ Name = 'mame'; FullName = 'Arcade (MAME)'; Platform = 'arcade'; Theme = 'mame'
           Extension = '.zip .ZIP .7z .7Z'
           Commands = @(
               @{ Label = 'MAME (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\mame_libretro.dll %ROM%' }
               @{ Label = 'MAME (Standalone)'; Cmd = '%HIDEWINDOW% %STARTDIR%=%EMUDIR% %EMULATOR_MAME% -rompath %GAMEDIR% %BASENAME%' }
           ) }

        @{ Name = 'atari2600'; FullName = 'Atari 2600'; Platform = 'atari2600'; Theme = 'atari2600'
           Extension = '.a26 .A26 .bin .BIN .rom .ROM .zip .ZIP .7z .7Z'
           Commands = @( @{ Label = 'Stella (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\stella_libretro.dll %ROM%' } ) }

        # The atari800 core only auto-switches INTO 5200 mode (for carts it
        # recognises). Instead of the Linux retroarch-atari800 wrapper,
        # configure-emulators.ps1 writes RetroArch folder options
        # (config\Atari800\<ROM folder>.opt) fixing atari800_system per system.
        @{ Name = 'atari5200'; FullName = 'Atari 5200'; Platform = 'atari5200'; Theme = 'atari5200'
           Extension = '.a52 .A52 .bin .BIN .car .CAR .rom .ROM .zip .ZIP .7z .7Z'
           Commands = @( @{ Label = 'Atari800 (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\atari800_libretro.dll %ROM%' } ) }

        @{ Name = 'atari7800'; FullName = 'Atari 7800 ProSystem'; Platform = 'atari7800'; Theme = 'atari7800'
           Extension = '.a78 .A78 .bin .BIN .zip .ZIP .7z .7Z'
           Commands = @( @{ Label = 'ProSystem (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\prosystem_libretro.dll %ROM%' } ) }

        @{ Name = 'atarilynx'; FullName = 'Atari Lynx'; Platform = 'atarilynx'; Theme = 'atarilynx'
           Extension = '.lnx .LNX .o .O .zip .ZIP .7z .7Z'
           Commands = @( @{ Label = 'Handy (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\handy_libretro.dll %ROM%' } ) }

        @{ Name = 'atari800'; FullName = 'Atari 800'; Platform = 'atari800'; Theme = 'atari800'
           Extension = '.atr .ATR .bas .BAS .bin .BIN .car .CAR .cas .CAS .dcm .DCM .xex .XEX .xfd .XFD .zip .ZIP .7z .7Z'
           Commands = @( @{ Label = 'Atari800 (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\atari800_libretro.dll %ROM%' } ) }

        @{ Name = 'atarist'; FullName = 'Atari ST'; Platform = 'atarist'; Theme = 'atarist'
           Extension = '.st .ST .stx .STX .msa .MSA .dim .DIM .ipf .IPF .zip .ZIP'
           Commands = @( @{ Label = 'Hatari (RetroArch)'; Cmd = '%EMULATOR_RETROARCH% -L %CORE_RETROARCH%\hatari_libretro.dll %ROM%' } ) }

        # Windows OpenBOR games are per-game folders with their own OpenBOR.exe
        # (or .lnk shortcuts to them) -- ES-DE's supported Windows layout. The
        # Linux .pak wrapper is not ported.
        @{ Name = 'openbor'; FullName = 'OpenBOR Game Engine'; Platform = 'openbor'; Theme = 'openbor'
           Extension = '.exe .EXE .lnk .LNK'
           Commands = @(
               @{ Label = 'OpenBOR (Standalone)'; Cmd = '%HIDEWINDOW% %ESCAPESPECIALS% %STARTDIR%=%GAMEDIR% %EMULATOR_OS-SHELL% /C %ROM%' }
           ) }
    )
}
