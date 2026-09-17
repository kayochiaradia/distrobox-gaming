# Windows console emulation

Native Windows 10/11 counterpart of the Linux distrobox setup. It installs
[ES-DE](https://es-de.org) and a native Windows emulator for **every console
and arcade system the Linux tree defines**, installs the RetroArch cores those
systems use, and generates ES-DE's system and emulator configuration.

No Distrobox, no WSL, no Wine: Windows emulators and Windows games run
natively. No Ansible either (there is no supported Ansible control node on
Windows) -- the scripts are plain PowerShell 5.1, which ships with Windows.
Everything lives on `C:`.

## Systems

The 43 systems in [config/esde-systems.psd1](config/esde-systems.psd1): all 41
from `ansible/group_vars/all/esde.yml`, plus Wii U and PS Vita, which the Linux
tree installs emulators for without an ES-DE entry. The first emulator listed
is ES-DE's default, matching the Linux choice.

| Systems | Emulator | Install source |
|---|---|---|
| Switch | Eden (Ryujinx as alternative) | winget |
| PS1 | DuckStation (Beetle PSX cores as alternatives) | winget |
| PS2 | PCSX2 | GitHub release (portable) |
| PS3 | RPCS3 | GitHub release |
| PS4 | shadPS4 | winget |
| PSP | PPSSPP | GitHub release (portable) |
| PS Vita | Vita3K | winget |
| GameCube, Wii | Dolphin | **manual download** |
| Wii U | Cemu | winget |
| 3DS | Azahar | GitHub release (portable) |
| DS | melonDS | winget |
| Xbox | xemu | winget |
| Xbox 360 | Xenia Canary | winget |
| Dreamcast, NAOMI, NAOMI 2 | Flycast | GitHub release |
| Sega Model 1 | MAME | winget |
| Sega Model 2 | Model 2 Emulator (MAME as alternative) | **manual download** |
| Sega Model 3 | Supermodel | GitHub release |
| OpenBOR | OpenBOR engine | GitHub release |
| NES, SNES, GB, GBC, GBA, N64, Master System, Genesis, Game Gear, 32X, Mega CD, Saturn, Neo Geo, CPS, CPS2, MAME, Atari 2600/5200/7800/Lynx/800/ST | RetroArch + cores | libretro buildbot (portable) |

`install-cores.ps1` also installs the Linux tree's extra cores (Neo Geo
Pocket, MSX, Odyssey 2, 3DO, WonderSwan, Virtual Boy, SuperGrafx, Vectrex,
Neo Geo CD, Amiga, C64); ES-DE's bundled Windows configuration already has
systems for those.

Beyond emulation, the Linux tree's optional extras are covered too: DLC,
cheats, per-game tuning, romhacks and HD textures ([Optional
content](#optional-content)), and its native ports, recomps, fan games and mod
tools ([Ports, recomps and PC tools](#ports-recomps-and-pc-tools)). Its
per-game NexusMods mod sets are not ported yet.

## Install and configure

Step by step, with first-launch notes: [INSTALL.md](INSTALL.md). In short,
from PowerShell (no Administrator rights needed):

```powershell
cd windows
./install-apps.ps1                       # all emulators
./install-cores.ps1                      # RetroArch cores
Copy-Item config/localhost.example.psd1 config/localhost.psd1   # optional overrides
./bootstrap.ps1 -Action Configure        # ES-DE systems + emulator paths
./install-shortcuts.ps1 -Action Configure  # Start Menu shortcuts
# open each emulator once, then:
./configure-emulators.ps1 -Action Configure
```

Or all of it in one go, like `ansible-playbook site.yml`: `./site.ps1`
(`-Tags install,cores,esde,desktop,configs,verify` to run a subset).

Every script accepts a preview mode (`-Check` or `-Action Check`) that writes
nothing, and is safe to rerun.

### Optional content

`content.ps1` is the Windows side of the Linux roles that only run when their
tag is passed (`--tags dlcs`, `cheats`, ...). Nothing runs without `-Tags`;
the default action previews, `-Action Configure` applies. Data lives in
[config/content.psd1](config/content.psd1).

| Tag | Linux role | What it does on Windows |
|---|---|---|
| `dlcs` | `install_dlcs` | PS3 `.pkg` DLC/patches from `ROMs\ps3-DLC` into RPCS3's `dev_hdd0\game`, Switch update/DLC `.nsp` from `ROMs\switch_updates` into Eden's NAND -- with the same `extract_ps3_dlc.py` / `install_switch_updates.py` |
| `cheats` | `switch_cheats` | Atmosphere cheats from `ROMs\switch_cheats\<TitleID> - Name\cheats` junctioned into `%APPDATA%\eden\load\<TitleID>\cheats` |
| `rpcs3_configs` | `rpcs3_per_game_configs` | Tuned `custom_configs` per PS3 game from the RPCS3 compatibility API (same `generate_rpcs3_configs.py`; `-Force` overwrites) |
| `pcsx2` | `pcsx2_textures` | Texture packs junctioned into `textures\<serial>\replacements`, the public widescreen/camera `.pnach` patches (plus CRC renames and the GT4 Spec II cheat block), cheats from `ps2-packs\cheats`, and the per-game `gamesettings\<SERIAL>_<CRC>.ini` fixes (GT3/GT4/Spec II, Enthusia, Colin McRae 04/2005, Ridge Racer V) |
| `rom_patches` | `install_rom_patches` | The six IPS/BPS romhacks (DKC GBA colour restoration, Final Fight ONE Arcade Edition, F-Zero Vintage Velocity I/Ace, Super Metroid Redux, Return to Yoshi's Island Demo 2) as separate SHA-1-verified copies beside your originals; `-Revert` removes the copies |
| `hd_textures` | `install_hd_textures` | Dolphin 4K packs (Luigi's Mansion, Sunshine, Skyward Sword, Wind Waker) from `ROMs\HD-textures\dolphin-textures`: only `Load/Textures` is extracted, then junctioned into Dolphin |

The Python helpers run unchanged on the official portable Python that
`install-apps.ps1` installs (with `pip` enabled for `cryptography`, which the
PS3 extractor needs). Links are junctions and hard links, so no Administrator
rights or Developer Mode are needed; sources on a network share are copied,
since junctions can't point at one. Existing non-empty folders are never
replaced, and ROMs, BIOS and saves are never deleted.

The helper scripts the Linux README documents for manual use work the same
way, e.g.:

```powershell
& "$env:USERPROFILE\Emulators\python\python.exe" ..\ansible\roles\install_dlcs\files\check_ps3_updates.py "$env:USERPROFILE\ES-DE\ROMs\ps3" --dlc-dir "$env:USERPROFILE\ES-DE\ROMs\ps3-DLC" --list
```

**Eden Cheats Manager** (the Linux `install_eden_cheats_manager` tool) is
installed by `install-apps.ps1` from its Windows build.

Not ported: `install_smm2_levels` (needs its Rust injector built with a Rust
toolchain) and `steam_trainers`/`install_cheatengine` (Proton prefix tooling;
on Windows, trainers and Cheat Engine run natively).

### Ports, recomps and PC tools

The Linux `install_*` roles for native ports, recompilations, fan games and
mod tools, as two optional groups in [apps.json](apps.json) -- like the
never-tagged Linux roles they only install on request:

```powershell
./install-apps.ps1 -Group ports            # games
./install-apps.ps1 -Group pctools          # mod managers and tools
./install-apps.ps1 -Only soh,sonic3air     # or pick some
./install-shortcuts.ps1 -Action Configure  # Start Menu entries for them
```

Every entry is the project's official Windows build. Several Linux roles run
these under Wine or build them from source; here they are simply the Windows
release. ROMs and game files are never supplied: each port's first run asks
for (or documents where to put) your own copy, as noted below.

| App | Id | Source | Notes |
|---|---|---|---|
| Ship of Harkinian | `soh` | GitHub `HarbourMasters/Shipwright` | Ocarina of Time PC port (Linux install_ship_of_harkinian). First launch asks for your OoT ROM and builds oot.o2r. |
| 2 Ship 2 Harkinian | `2s2h` | GitHub `HarbourMasters/2ship2harkinian` | Majora's Mask PC port. First launch asks for your MM ROM. |
| Starship | `starship` | GitHub `HarbourMasters/Starship` | Star Fox 64 PC port. First launch extracts assets from your Star Fox 64 (USA) (Rev A) ROM. |
| SpaghettiKart | `spaghettikart` | GitHub `HarbourMasters/SpaghettiKart` | Mario Kart 64 PC port. First launch asks for your MK64 ROM. |
| Banjo-Kazooie Recompiled | `banjorecomp` | GitHub `BanjoRecomp/BanjoRecomp` | N64Recomp port. Select your Banjo-Kazooie (USA) ROM in its launcher. |
| Donkey Kong 64 Recompiled | `dk64recomp` | GitHub `Rainchus/Donkey-Kong-64-Recompiled` | N64Recomp port. Select your Donkey Kong 64 (USA) ROM in its launcher. |
| Wave Race 64 Recompiled | `waverace` | GitHub `elliotttate/wave-race-64-recomp` | N64Recomp port (runs under Wine on Linux, native here). Select your Wave Race 64 (USA) (Rev A) ROM. |
| Metroid Prime Hunters Recomp | `mphrecomp` | GitHub `mstan/MetroidPrimeHuntersRecomp` | Needs your Metroid Prime - Hunters (USA) ROM. |
| Perfect Dark | `perfectdark` | GitHub `DabDavis/perfect-dark-dabs-mod` | Perfect Dark PC port. Put your Perfect Dark (USA) (Rev A) ROM in its data folder as pd.ntsc-final.z64. |
| Donkey Kong Country Recomp | `dkc1recomp` | GitHub `elliotttate/DKC1Recomp` | SNES recomp; needs the USA v1.0 ROM. Linux builds it from source with its own patches; upstream ships Windows builds. |
| Donkey Kong Country 2 Recomp | `dkc2recomp` | GitHub `elliotttate/DKC2Recomp` | SNES recomp; needs the USA v1.0 ROM. |
| Donkey Kong Country 3 Recomp | `dkc3recomp` | GitHub `elliotttate/DKC3Recomp` | SNES recomp; needs the USA ROM. |
| Super Mario Bros. Remastered | `smbremastered` | GitHub `JHDev2006/Super-Mario-Bros.-Remastered-Public` | Godot remake; asks for your Super Mario Bros. ROM on first launch. |
| Super Mario World Remastered | `smwremastered` | GitHub `JHDev2006/Super-Mario-World-Remastered-Public` | Godot remake; asks for your Super Mario World (USA) ROM on first launch. |
| Sonic 3 A.I.R. | `sonic3air` | GitHub `Eukaryot/sonic3air` | Asks for your Sonic 3 & Knuckles ROM on first launch. |
| Sonic 2 (2013) - RSDKv4 | `sonic2013` | GitHub `RSDKModding/RSDKv4-Decompilation` | RSDKv4 decompilation; copy your Sonic 2 (2013) Data.rsdk next to the exe. The Linux Sonic 2 Mania mod goes in its mods folder. |
| Cannonball DX (OutRun) | `cannonball` | GitHub `Endprodukt/cannonball-dx` | OutRun engine; put your OutRun MAME romset files in its roms folder. |
| DUDE (Doom 3) | `dude` | GitHub `Inkub0/dude` | Doom 3 source port; needs your Doom 3 game files. |
| Dusk (Twilight Princess) | `dusk` | GitHub `TwilitRealm/dusk` | Twilight Princess PC port; select your GameCube disc image in its launcher. |
| Unleashed Recompiled | `unleashedrecomp` | GitHub `hedge-dev/UnleashedRecomp` | Its first-run installer asks for your Sonic Unleashed (Xbox 360) game files and title update. |
| Star Fox Enhanced | `starfoxenhanced` | GitHub `kandowontu/starfox-enhanced` | SNES Star Fox source port; builds assets from your Star Fox (USA) (Rev 2) ROM on first launch. |
| TriAevum | `triaevum` | GitHub `coccofresco/TriAevum` | Ocarina of Time 3D PC port (Wine on Linux, native here); TriAevumForge extracts your OoT3D ROM. |
| WipEout Phantom Edition | `wipeoutpe` | GitHub `wipeout-phantom-edition/wipeout-phantom-edition` | Needs the original WipEout PC/PS1 data files (see docs/wipeout-pe.md). |
| G-Diffuser (F-Zero X) | `gdiffuser` | GitHub `Zorkats/G-Diffuser` | F-Zero X port; needs your F-Zero X ROM (plus the Expansion Kit disk and 64DD IPL for the Expansion Kit). |
| PrBoom+ RT (Doom II Ray Traced) | `prboomrt` | GitHub `sultim-t/prboom-plus-rt` | Ray-traced Doom; copy your doom2.wad next to the exe. |
| Virtua Racing (Wanszai) | `virtuaracing` | GitHub `wanszai/Virtua-Racing---XBOXONE-Windows` | Model 1 frontend (Wine on Linux, native here); put vr.zip in its roms folder. |
| Virtua Fighter (Wanszai) | `virtuafighter` | GitHub `wanszai/Virtua-Fighter---XboxOne-Windows` | Model 1 frontend; put vf.zip in its roms folder. |
| Ridge Racer Collection (Wanszai) | `ridgeracer` | GitHub `wanszai/Ridge-Racer-Collection` | System 22 frontend (Ridge Racer, RR2, Rave Racer); put the MAME romsets in its roms folder. |
| Sega Rally HD (Wanszai) | `segarally` | GitHub `wanszai/Sega-Rally-Championship-PC-Xbox360-Series-X-` | Model 2 Sega Rally frontend; put srallyc.zip in its roms folder. |
| Streets of Rage Remake | `sorr` | archive.org | Windows fan game (Wine on Linux, native here), same archive.org source as the Linux role. |
| Sonic P-06 | `sonicp06` | **manual** | Project 06 Silver Release has no scripted download; extract it so "Sonic the Hedgehog.exe" is in %USERPROFILE%\Emulators\sonic-p06. |
| Sonic SMS Remake | `sonicsms` | **manual** | No scripted download; extract v1.9 so "Sonic SMS Remake.exe" is in %USERPROFILE%\Emulators\sonic-sms-remake. |
| DKLR | `dklr` | **manual** | No scripted download; extract it so DKLR.exe is in %USERPROFILE%\Emulators\dklr. |
| Parallel Launcher | `parallellauncher` | **manual** | Its GitLab releases carry no files; install from the official site. Also the n64 alternative emulator in ES-DE. |
| Hedge Mod Manager | `hedgemodmanager` | GitHub `hedge-dev/HedgeModManager` | Sonic mod manager (Linux builds it from source; the Windows release is a single exe). |
| Xenia Manager | `xeniamanager` | GitHub `xenia-manager/xenia-manager` | Per-game Xenia configs and title updates (Linux install_xenia runs it under Wine). Xenia Canary itself is installed as a core emulator. |
| Overstrike | `overstrike` | GitHub `Tkachov/Overstrike` | Marvel's Spider-Man mod manager (Linux install_modtools). |
| Ryu Mod Manager | `ryumodmanager` | GitHub `mosamadeeb/RyuModManager` | Yakuza mod manager (Linux install_modtools). |
| SnakeBite | `snakebite` | **manual** | MGSV mod manager (Linux install_modtools); its interactive installer must be run by hand. |
| DOSBox Staging | `dosbox` | GitHub `dosbox-staging/dosbox-staging` | For the Screamer DOS games (Linux install_screamer); point it at your own game copies. |
| Cheat Engine | `cheatengine` | **manual** | Linux install_cheatengine; the official installer bundles offers, so install it by hand. |

Not automated on Windows: **GoldenEye 64 Recompiled** (upstream only publishes
a macOS build; the Linux role compiles it), **Render96ex** (no releases; the
Linux role compiles it with its model/texture packs), **Project Reignition**
and **Mega Man X Regenesis** (distributed via Game Jolt/itch.io, staged by hand
on Linux too). The Linux ROM staging for ports (copying ROMs into each port's
folder under fixed names) is not ported; the notes above say how each port
takes its ROM, based on the projects' documentation -- not yet tried here.
Checked on 2026-09-17: every automated entry downloaded, extracted and was
detected on Windows 11; none has been launched yet.

### Maintenance

| Script | Linux counterpart | What it does |
|---|---|---|
| `site.ps1` | `site.yml` | Full setup: install, cores, ES-DE, shortcuts, emulator configs, verify |
| `reset-configs.ps1` | `reset-configs.yml` | Re-applies managed settings without reinstalling (`-Tags configs,desktop,esde,verify`); changed files are backed up first |
| `backup.ps1` | `backup.yml` | Zips emulator and ES-DE configuration to `%USERPROFILE%\distrobox-gaming-backups` (list with `-List`). No container image to snapshot on Windows -- emulators are reinstalled by `install-apps.ps1` -- so only configs are archived, with the Linux exclusions (caches, shaders, screenshots, logs, saves, states) plus BIOS and ROMs. Items are in [config/maintenance.psd1](config/maintenance.psd1) |
| `restore.ps1` | `restore.yml` | `-Latest` or `-Timestamp`, previewed by default, `-Action Configure` to write. Backs up the current state first, overwrites archived files, leaves other files alone |
| `verify-setup.ps1` | `verify` role | Asserts every automated app is installed, the ES-DE files are valid and point at the installed emulators, RetroArch has every core ES-DE needs, and shortcuts exist; warns about missing manual apps, BiosRoot and shadPS4 firmware. Exits 1 on failure |

### How it fits together

| Script | Linux counterpart | What it does |
|---|---|---|
| `install-apps.ps1` | `bootstrap_packages`, `install_*` roles | Installs [apps.json](apps.json). Everything is a portable build -- winget portable packages, GitHub/GitLab releases, the RetroArch buildbot -- installed into `%USERPROFILE%\Emulators\<name>`, so no Administrator rights are needed. Skips anything already installed; `-Update` refreshes the release-based ones; `-Only` limits to some apps |
| `install-cores.ps1` | `retroarch_extras` | Downloads every core referenced in `esde-systems.psd1` plus the extras into RetroArch's `cores` folder, and the same 8 asset packs as Linux (info, assets, autoconfig, cheats, databases, slang shaders, overlays; ~245 MB, skip with `-NoAssets`). Never overwrites unless `-Update` |
| `bootstrap.ps1` | `configure_esde` | Writes `custom_systems\es_systems.xml` (the 43 systems, their ROM folders and emulator order) and `es_find_rules.xml` (the real path of each installed emulator) into the ES-DE home, generates the PS4 and arcade gamelists, links scraped art into `downloaded_media`, sets ES-DE's ROM directory, and reports or creates ROM folders |
| `configure-emulators.ps1` | `link_storage`, `seed_configs`, `gpu.yml` | BIOS placement and emulator tuning, below |
| `install-shortcuts.ps1` | `desktop_apps`, `install-host-launchers.sh` | Start Menu folder `distrobox-gaming` with a shortcut per installed emulator and ES-DE; removes shortcuts for apps no longer installed |

ES-DE merges the two `custom_systems` files with its bundled configuration,
so systems not in the list keep ES-DE's defaults, and emulators are found
wherever they were installed -- no PATH changes, no registry writes. Existing
files are backed up as `<file>.bak.<timestamp>` before a change.

ROM folders default to `%USERPROFILE%\ES-DE\ROMs\<system>`; override the root
or single systems in `config/localhost.psd1`. Missing folders are only
reported unless `CreateRomDirs` is set, so a disconnected drive never turns
into an empty local folder. ES-DE's own ROM directory setting is pointed at the
same root, so its bundled systems use it too.

The ES-DE home is detected: the portable release (installed by
`install-apps.ps1`, flagged by `portable.txt`) keeps it inside its own folder,
`%USERPROFILE%\Emulators\ES-DE\ES-DE\ES-DE`; otherwise it is
`%USERPROFILE%\ES-DE`. Set `EsdeHome` in `config/localhost.psd1` to override.

### Gamelists and scraped media

Same as the Linux `configure_esde` role, ported from its Python helpers to
PowerShell (Windows has no Python by default):

- **PS4:** a gamelist built from each `CUSAxxxxx\sce_sys\param.sfo`, so games
  show their title instead of `eboot`.
- **Model 1/2/3:** the Skraper `gamelist.xml` in each ROM folder becomes an
  ES-DE gamelist with MAME clone sets hidden (the shortest filename per title
  stays visible). Like on Linux, a regenerated gamelist replaces ES-DE's own
  favorites/play counts for those systems; the previous file is backed up.
- **Scraped art:** Skraper/EmuDeck images (`<rom>\media\<type>\` and
  `<rom>\images\<name>-image|-marquee.*`) are linked into ES-DE's
  `downloaded_media` -- hard links on the same drive (Windows can't symlink
  without Developer Mode), copies across drives. Existing files are kept.
- **ES-DE settings:** `ROMDirectory` and `ParseGamelistOnly` (off by default,
  as on Linux) in `es_settings.xml`, once ES-DE has created it.

## BIOS and emulator tuning

`configure-emulators.ps1` is the counterpart of the Linux `link_storage` and
`seed_configs` roles and `gpu.yml`, driven by [config/emulators.psd1](config/emulators.psd1).

**BIOS and firmware.** Keep your own dumps in one folder, `BiosRoot` (default
`%USERPROFILE%\ES-DE\BIOS`), using the same layout as the Linux
`dg_bios_root` -- so an existing EmuDeck `Emulation\bios` folder works as-is.
The script copies what each installed emulator needs (Windows can't symlink
without Developer Mode) and points config paths at the rest:

| Emulator | From BiosRoot | Goes to |
|---|---|---|
| RetroArch | `5200.ROM`, `ATARIXL.ROM`, `ATARIBAS.ROM`, `ATARIOSA.ROM`, `ATARIOSB.ROM`, `lynxboot.img` | RetroArch `system\` |
| Flycast | `dc\naomi.zip`, `dc\naomi2.zip`, `dc\awbios.zip` | Flycast `data\` |
| melonDS | `bios7.bin`, `bios9.bin`, `dsfirmware.bin` | melonDS `bios\` (copied once; melonDS writes to the firmware) + config paths |
| shadPS4 | `ps4\sys_modules\*` | `%APPDATA%\shadPS4\sys_modules` |
| xemu | `mcpx_1.0.bin`, `Complex_4627.bin`, `xbox_hdd.qcow2` | config paths (used in place, like the Linux symlinks) |
| DuckStation, PCSX2 | the whole folder | BIOS search folder setting |

Everything is optional and skipped when absent. RPCS3 firmware, Switch keys
and Wii U keys still go through each emulator's own UI, as on Linux.

**Settings** applied to each emulator's own config file:

| Emulator | Config file | What is applied |
|---|---|---|
| PCSX2 | `%USERPROFILE%\Documents\PCSX2\inis\PCSX2.ini` | 6x upscale, 16x AF, FXAA, widescreen patches, texture replacements, fast CDVD, save state on exit, SDL Xbox-style Pad1, Select+Start/L1/R1 hotkeys |
| DuckStation | `%LOCALAPPDATA%\DuckStation\settings.ini` | 8x resolution, JINC2 filtering, 2x MSAA, PGXP, widescreen hack, 4x CD read/seek, VSync, texture replacements |
| RetroArch | `config\<core>\` next to RetroArch | bsnes-hd widescreen; per-core video driver for melonDS (glcore) and ParaLLEl-N64 (vulkan); ParaLLEl-N64 Vulkan RDP/LLE RSP |
| Flycast | `emu.cfg` next to Flycast | 4320p internal resolution, widescreen, duplicate frames, no delayed frame swapping |
| Supermodel | `Config\Supermodel.ini` next to Supermodel | fullscreen (needed on Windows), widescreen, wide background |
| xemu | `%APPDATA%\xemu\xemu\xemu.toml` | fullscreen, 3x surface scale, no welcome/update prompts |
| melonDS | `melonDS.toml` next to melonDS | compute renderer at 8x, better polygons, hi-res coordinates, threaded software renderer, direct boot |
| Cemu | `%APPDATA%\Cemu\settings.xml` | fullscreen, VSync, bicubic upscaling, no update/Discord prompts, Wii U game folder |
| Dolphin | `%USERPROFILE%\Documents\Dolphin Emulator\Config` | your own controller profiles, if listed |
| GPU | `HKCU\...\DirectX\UserGpuPreferences` | "High performance" GPU per emulator, **only when the PC has more than one GPU** |

A config file the emulator hasn't written yet is skipped, never created
half-baked, so launch each emulator once first. Upscale values target a
high-end discrete GPU; lower them on weaker hardware.

Verified on 2026-09-17 against live installs: DuckStation 0.1-11752, PCSX2
2.8.2 and RetroArch 1.22.2 (every key exists and differs from the Windows
default), and Flycast 2.7, Supermodel 0.3a, xemu 0.8.136, melonDS 1.1, Cemu 2.6
and PCSX2 (values survive an emulator restart).

Not ported: shadPS4's Driveclub per-game config and patch, Flycast/Supermodel
NVRAM packs and the Cemu 8BitDo controller profile -- all built from the Linux
maintainer's own files.

### What was not ported

Settings from the Linux tree that do nothing, or the wrong thing, on Windows:

| Linux setting | Why it is not on Windows |
|---|---|
| `VK_ICD_FILENAMES`, `--nvidia`, `lib32-nvidia-utils`, `LD_LIBRARY_PATH` | Container/Vulkan-loader workarounds for NVIDIA + AMD iGPU. Windows drivers handle this; hybrid PCs get the per-exe GPU preference instead |
| PCSX2 `Renderer = 14` / DuckStation `Renderer = Vulkan` | Forced Vulkan to pair with the ICD trick. On Windows, `Automatic` already picks D3D12 or Vulkan per GPU |
| PCSX2 `UI.Language = en-US` | Fixes a missing locale inside the container. On Windows it would just force an English UI |
| PCSX2 `CdvdPrecache`, DuckStation `LoadImageToRAM` | Read-ahead because the Linux ROMs live on a NAS over NFS. Here the ROMs are local |
| RetroArch `audio_driver = pulse` | PulseAudio doesn't exist on Windows (the default is `wasapi`) |
| RetroArch `menu_swap_ok_cancel_buttons = true` | Already the Windows default |
| PCSX2 `InputSources.SDL`, `SDLControllerEnhancedMode`, `Pad1.Type`; `TextureReplacementsAsync` | Already the default; the last one was renamed `LoadTextureReplacementsAsync` (default on) |
| PCSX2 `Pad1.DPadUp/DPadDown/DPadLeft/DPadRight` | Not PCSX2 key names -- they are `Up/Down/Left/Right`, which Windows uses. **The Linux tree has the same bug: its D-pad binding is ignored** |
| DuckStation `TrueColor`, `ScaledDithering`, `DisableInterlacing`, `ForceNTSCTimings`, `StartupFastBoot`, `AutoLoadCheats`, `ReadThread` | Not present in current DuckStation builds (renamed to `DitheringMode`/`DeinterlacingMode`, whose defaults already match, or removed) |
| Values that already equal the Windows default | Writing them changes nothing |
| DuckStation per-game GT1/GT2 overrides and cheats, Dolphin 8BitDo profiles | Specific to the Linux maintainer's own games and controller. The same mechanism exists here, empty by default |
| `retroarch-snes` auto-picker, `retroarch-atari800` mode switch, `flycast-hires`/gamescope, Xenia `.xbla` stubs, OpenBOR `.pak` wrapper, Wine launchers | Linux wrapper scripts. Windows uses the plain emulator command (bsnes default with bsnes-hd as alternative; OpenBOR uses ES-DE's per-game-folder layout) |
| Flycast `pvr.rend`, xemu `backend = vulkan`, Cemu audio `api = 4` | Vulkan/PulseAudio choices tied to the Linux stack; Windows keeps each emulator's own default |
| Supermodel `X/YResolution` 3840x2160 and `JOY1_BUTTONn` input remaps, Cemu window size/region/language, melonDS 8BitDo joystick mapping | The maintainer's monitor and controller; Linux joystick button order differs from Windows |
| Cemu `did_show_graphic_pack_download` | Dropped by Cemu 2.6 (it deletes the key on save) |
| Walker `.desktop` launchers, zsh + starship, udev rules, UID/GID 1026 | Linux desktop/container plumbing |

## Known issues

- **Dolphin:** dolphin-emu.org and its mirror answer `403 Forbidden` to
  scripted downloads, and winget only has the 2016 5.0 release. Download the
  current release in a browser and extract it so `Dolphin.exe` is at
  `%USERPROFILE%\Emulators\Dolphin-x64\Dolphin.exe`.
- **Model 2 Emulator:** no official download host or release feed. Place it
  so `EMULATOR.EXE` is at `%USERPROFILE%\Emulators\m2emulator\EMULATOR.EXE`
  and rerun `configure-emulators.ps1`, which points its `[RomDirs]` at your
  model2 ROM folder. Meanwhile MAME is the alternative emulator for model2.
- **Interrupted installs:** a winget portable install that fails midway can
  leave a registration with no files. `install-apps.ps1` detects that, removes
  the orphaned registration and retries.
- **Windows `tar.exe` and Unicode names:** it skips zip entries with non-ASCII
  names (74 in RetroArch's `cheats.zip`), so `.zip` files are extracted with
  .NET instead; `tar.exe` only handles `.7z`/`.rar`.
- **Parallel Launcher** (n64 alternative emulator) is not automated; install
  it yourself if you need it.

## Verification

```powershell
powershell -ExecutionPolicy Bypass -File windows/tests/verify.ps1
```

Runs the real scripts against temporary directories and fixture files --
never against your ES-DE, emulator configs or install folders -- and never
calls winget or downloads anything. It checks that every Linux ES-DE system
exists on Windows, that every default emulator is provided by `apps.json`,
that the generated XML is well formed (including paths with `&` and
brackets), idempotent and backed up before changes, that `Check` modes write
nothing, that INI/cfg edits preserve unmanaged keys, and that folders and
config files are only created when intended.

Live-tested on 2026-09-17 on Windows 11 with an RTX 5080, without
Administrator rights: every automated app in `apps.json` (18) installed
through `install-apps.ps1` (winget portable, GitHub, GitLab and buildbot
sources; `.zip`/`.7z`/`.rar`), all 38 cores and 8 asset packs through
`install-cores.ps1`, then `bootstrap.ps1`, `configure-emulators.ps1` and
`install-shortcuts.ps1` against them. Dolphin and Model 2 Emulator (manual
downloads) were not installed, and no game has been launched through ES-DE on
Windows yet.

## Architecture

Keep Windows installation, commands and configuration under `windows/`. It
shares no code with `ansible/` or `macos/`; do not fold Windows concerns into
either. Shared helpers live in `lib/common.ps1` and `lib/gamelists.ps1`. `.psd1` config files use
`%VAR%` placeholders, never `$env:` (`Import-PowerShellDataFile` rejects it);
`esde-systems.psd1` is loaded without expansion because `%ROM%` and friends
are ES-DE variables.

To add a system: add it to `config/esde-systems.psd1`, add its emulator to
`apps.json` with the ES-DE find-rule name in `emulatorNames`, and run the
tests -- they fail if a default emulator has no app.

## Sources

- [ES-DE user guide and INSTALL.md](https://gitlab.com/es-de/emulationstation-de) -- custom_systems semantics, `%ESPATH%`, Model 2 and OpenBOR setup
- [ES-DE Windows `es_systems.xml`](https://gitlab.com/es-de/emulationstation-de/-/blob/master/resources/systems/windows/es_systems.xml) and [`es_find_rules.xml`](https://gitlab.com/es-de/emulationstation-de/-/blob/master/resources/systems/windows/es_find_rules.xml) -- launch syntax and emulator names
- [libretro buildbot](https://buildbot.libretro.com/nightly/windows/x86_64/latest/)
- [winget](https://learn.microsoft.com/windows/package-manager/winget/)

Package IDs, release assets and ES-DE files were checked on 2026-09-17.
