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
| PS2 | PCSX2 | winget (UAC) |
| PS3 | RPCS3 | GitHub release |
| PS4 | shadPS4 | winget |
| PSP | PPSSPP | winget (UAC) |
| PS Vita | Vita3K | winget |
| GameCube, Wii | Dolphin | **manual download** |
| Wii U | Cemu | winget |
| 3DS | Azahar | winget (UAC) |
| DS | melonDS | winget |
| Xbox | xemu | winget |
| Xbox 360 | Xenia Canary | winget |
| Dreamcast, NAOMI, NAOMI 2 | Flycast | GitHub release |
| Sega Model 1 | MAME | winget |
| Sega Model 2 | Model 2 Emulator (MAME as alternative) | **manual download** |
| Sega Model 3 | Supermodel | GitHub release |
| OpenBOR | OpenBOR engine | GitHub release |
| NES, SNES, GB, GBC, GBA, N64, Master System, Genesis, Game Gear, 32X, Mega CD, Saturn, Neo Geo, CPS, CPS2, MAME, Atari 2600/5200/7800/Lynx/800/ST | RetroArch + cores | winget (UAC) + libretro buildbot |

`install-cores.ps1` also installs the Linux tree's extra cores (Neo Geo
Pocket, MSX, Odyssey 2, 3DO, WonderSwan, Virtual Boy, SuperGrafx, Vectrex,
Neo Geo CD, Amiga, C64); ES-DE's bundled Windows configuration already has
systems for those.

Out of scope, as in `macos/`: the Linux tree's per-game PC mod sets, recomp
and decomp ports, Wine game wrappers and mod managers. On Windows those games
and tools run natively and install through their own installers.

## Install and configure

Step by step, with first-launch notes: [INSTALL.md](INSTALL.md). In short,
from an interactive PowerShell window:

```powershell
cd windows
./install-apps.ps1                       # all emulators (approve the UAC prompts)
./install-cores.ps1                      # RetroArch cores
Copy-Item config/localhost.example.psd1 config/localhost.psd1   # optional overrides
./bootstrap.ps1 -Action Configure        # ES-DE systems + emulator paths
# open each emulator once, then:
./configure-emulators.ps1 -Action Configure
```

Every script accepts a preview mode (`-Check` or `-Action Check`) that writes
nothing, and is safe to rerun.

### How it fits together

| Script | Linux counterpart | What it does |
|---|---|---|
| `install-apps.ps1` | `bootstrap_packages`, `install_*` roles | Installs [apps.json](apps.json). winget portable packages and GitHub releases go to `%USERPROFILE%\Emulators\<name>` (no admin needed); installer-based packages go where their installer puts them. Skips anything already installed; `-Update` refreshes GitHub releases; `-Only` limits to some apps |
| `install-cores.ps1` | `retroarch_extras` | Downloads every core referenced in `esde-systems.psd1` plus the extras, into RetroArch's `cores` folder. Never overwrites an existing core unless `-Update` |
| `bootstrap.ps1` | `configure_esde` | Writes `%USERPROFILE%\ES-DE\custom_systems\es_systems.xml` (the 43 systems, their ROM folders and emulator order) and `es_find_rules.xml` (the real path of each installed emulator). Reports or creates ROM folders |
| `configure-emulators.ps1` | `seed_configs`, `gpu.yml` | Emulator tuning, below |

ES-DE merges the two `custom_systems` files with its bundled configuration,
so systems not in the list keep ES-DE's defaults, and emulators are found
wherever they were installed -- no PATH changes, no registry writes. Existing
files are backed up as `<file>.bak.<timestamp>` before a change.

ROM folders default to `%USERPROFILE%\ES-DE\ROMs\<system>`; override the root
or single systems in `config/localhost.psd1`. Missing folders are only
reported unless `CreateRomDirs` is set, so a disconnected drive never turns
into an empty local folder. Also set ES-DE's own ROM directory to the same
root so its bundled systems use it.

## Emulator tuning

`configure-emulators.ps1` applies [config/emulators.psd1](config/emulators.psd1)
to each emulator's own config file:

| Emulator | Config file | What is applied |
|---|---|---|
| PCSX2 | `%USERPROFILE%\Documents\PCSX2\inis\PCSX2.ini` | 6x upscale, 16x AF, FXAA, widescreen patches, texture replacements, fast CDVD, save state on exit, SDL Xbox-style Pad1, Select+Start/L1/R1 hotkeys |
| DuckStation | `%LOCALAPPDATA%\DuckStation\settings.ini` | 8x resolution, JINC2 filtering, 2x MSAA, PGXP, widescreen hack, 4x CD read/seek, VSync, texture replacements, BIOS folder |
| RetroArch | `retroarch.cfg` + `config\<core>\` next to RetroArch | Xbox-style menu confirm/cancel; bsnes-hd widescreen, melonDS glcore, ParaLLEl-N64 Vulkan core options |
| Dolphin | `%USERPROFILE%\Documents\Dolphin Emulator\Config` | your own controller profiles, if listed |
| GPU | `HKCU\...\DirectX\UserGpuPreferences` | "High performance" GPU per emulator, **only when the PC has more than one GPU** |

A config file the emulator hasn't written yet is skipped, never created
half-baked, so launch each emulator once first. Upscale values target a
high-end discrete GPU; lower them on weaker hardware.

The DuckStation list was checked on 2026-09-17 against a live install
(0.1-11752): every key exists in the `settings.ini` DuckStation writes itself
and differs from its Windows default. PCSX2 and RetroArch follow the
installers' documented defaults and are not verified live yet.

Not tuned yet: the Linux tree's Flycast, Supermodel, xemu, Cemu, melonDS and
shadPS4 settings. Several of those depend on the maintainer's own files (NAS
NVRAM packs, an 8BitDo Cemu profile, the Driveclub patch, specific BIOS dump
names), and the rest need the same live check the DuckStation list got.

### What was not ported

Settings from the Linux tree that do nothing, or the wrong thing, on Windows:

| Linux setting | Why it is not on Windows |
|---|---|
| `VK_ICD_FILENAMES`, `--nvidia`, `lib32-nvidia-utils`, `LD_LIBRARY_PATH` | Container/Vulkan-loader workarounds for NVIDIA + AMD iGPU. Windows drivers handle this; hybrid PCs get the per-exe GPU preference instead |
| PCSX2 `Renderer = 14` / DuckStation `Renderer = Vulkan` | Forced Vulkan to pair with the ICD trick. On Windows, `Automatic` already picks D3D12 or Vulkan per GPU |
| PCSX2 `UI.Language = en-US` | Fixes a missing locale inside the container. On Windows it would just force an English UI |
| PCSX2 `CdvdPrecache`, DuckStation `LoadImageToRAM` | Read-ahead because the Linux ROMs live on a NAS over NFS. Here the ROMs are local |
| RetroArch `audio_driver = pulse` | PulseAudio doesn't exist on Windows |
| DuckStation `TrueColor`, `ScaledDithering`, `DisableInterlacing`, `ForceNTSCTimings`, `StartupFastBoot`, `AutoLoadCheats`, `ReadThread` | Not present in current DuckStation builds (renamed to `DitheringMode`/`DeinterlacingMode`, whose defaults already match, or removed) |
| Values that already equal the Windows default | Writing them changes nothing |
| DuckStation per-game GT1/GT2 overrides and cheats, Dolphin 8BitDo profiles | Specific to the Linux maintainer's own games and controller. The same mechanism exists here, empty by default |
| `retroarch-snes` auto-picker, `retroarch-atari800` mode switch, `flycast-hires`/gamescope, Xenia `.xbla` stubs, OpenBOR `.pak` wrapper, Wine launchers | Linux wrapper scripts. Windows uses the plain emulator command (bsnes default with bsnes-hd as alternative; OpenBOR uses ES-DE's per-game-folder layout) |
| Walker `.desktop` launchers, zsh + starship, udev rules, UID/GID 1026 | Linux desktop/container plumbing. Windows installers create Start Menu shortcuts |

## Known issues

- **UAC:** the ES-DE, RetroArch, PCSX2, PPSSPP and Azahar installers need
  Administrator approval. Run `install-apps.ps1` from an interactive window;
  from a non-interactive session winget reports the install as cancelled.
- **Dolphin:** dolphin-emu.org and its mirror answer `403 Forbidden` to
  scripted downloads, and winget only has the 2016 5.0 release. Download the
  current release in a browser and extract it so `Dolphin.exe` is at
  `%USERPROFILE%\Emulators\Dolphin-x64\Dolphin.exe`.
- **Model 2 Emulator:** no official download host or release feed. Place it
  so `EMULATOR.EXE` is at `%USERPROFILE%\Emulators\m2emulator\EMULATOR.EXE`
  and set `[RomDirs] Dir1=` in its `EMULATOR.INI` to your model2 ROM folder.
  Meanwhile MAME is available as the alternative emulator for model2.
- **Interrupted installs:** a winget portable install that fails midway can
  leave a registration with no files. `install-apps.ps1` detects that, removes
  the orphaned registration and retries.
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

Live-tested on 2026-09-17 on Windows 11 with an RTX 5080: RPCS3, shadPS4,
Eden, Cemu, melonDS, xemu, Xenia Canary, Vita3K, Flycast, Supermodel, MAME,
OpenBOR and DuckStation installed through `install-apps.ps1` (including
`.7z`/`.rar` extraction), and `bootstrap.ps1` generated the ES-DE files for
them. The UAC-gated apps, Dolphin and Model 2 Emulator were not installed in
that session, and no game has been launched through ES-DE on Windows yet.

## Architecture

Keep Windows installation, commands and configuration under `windows/`. It
shares no code with `ansible/` or `macos/`; do not fold Windows concerns into
either. Shared helpers live in `lib/common.ps1`. `.psd1` config files use
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
