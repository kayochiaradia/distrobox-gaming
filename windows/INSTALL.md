# Installing on Windows 10/11

Run these steps on the target PC in PowerShell. No Administrator rights are
needed: every emulator is installed as a portable build. Reading this document
installs nothing. See [README.md](README.md) for the system list and design.

No ROMs, BIOS, firmware, keys or game packages are supplied.

## 1. Prerequisites

```powershell
winget --version
```

If `winget` is missing, install "App Installer" from the Microsoft Store.
Windows 10 also needs a recent build for `tar.exe` (built in since 1803),
which extracts the `.7z`/`.rar` GitHub releases.

If scripts are blocked, allow them for this window only:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

## 2. Optional overrides

Defaults need no configuration: emulators (including portable ES-DE) at
`%USERPROFILE%\Emulators`, ROMs at `%USERPROFILE%\ES-DE\ROMs\<system>`, BIOS at
`%USERPROFILE%\ES-DE\BIOS`, all on `C:`. To change any of them:

```powershell
cd windows
if (-not (Test-Path config/localhost.psd1)) {
    Copy-Item config/localhost.example.psd1 config/localhost.psd1
}
notepad config/localhost.psd1
```

Use `%USERPROFILE%`-style placeholders, not `$env:USERPROFILE` -- PowerShell
data files can't evaluate `$env:`. Per-system ROM folders go in `RomPaths`:

```powershell
RomPaths = @{
    ps2 = 'C:\Games\PS2'
}
```

## 3. Install the emulators

```powershell
./install-apps.ps1 -List     # what will be installed, and from where
./install-apps.ps1           # install everything
./install-apps.ps1 -Check    # what is installed, and where
```

Rerunning skips what is already installed; `-Only rpcs3,flycast` limits the
run; `-Update` refreshes
the release-based emulators (ES-DE, RetroArch, PCSX2, PPSSPP, Azahar, RPCS3,
Flycast, Supermodel, OpenBOR).

Two emulators can't be downloaded by script:

- **Dolphin** (GameCube/Wii): download the current release from
  [dolphin-emu.org](https://dolphin-emu.org/download/) in a browser and
  extract it so the exe is at `%USERPROFILE%\Emulators\Dolphin-x64\Dolphin.exe`.
- **Model 2 Emulator** (Sega Model 2): place ElSemi's Model 2 Emulator so the
  exe is at `%USERPROFILE%\Emulators\m2emulator\EMULATOR.EXE`; step 7 points
  its `EMULATOR.INI` at your model2 ROM folder. Until then, pick MAME for
  model2 in ES-DE.

## 4. Install the RetroArch cores

```powershell
./install-cores.ps1 -Check
./install-cores.ps1
```

Downloads the cores for NES, SNES, Game Boy, GBA, N64, Sega 8/16/32-bit,
Saturn, arcade, Atari and the extra systems from the libretro buildbot into
RetroArch's `cores` folder, plus the asset packs (menus, controller autoconfig,
cheats, databases, shaders, overlays; ~245 MB, skip with `-NoAssets`). Existing
files are left alone unless `-Update`.

## 5. Connect everything to ES-DE

```powershell
./bootstrap.ps1 -Action Check
./bootstrap.ps1 -Action Configure
```

Writes `es_systems.xml` and `es_find_rules.xml` into the ES-DE home's
`custom_systems\` (inside the portable ES-DE folder, detected automatically),
plus the PS4/arcade gamelists and scraped art, and sets ES-DE's ROM directory.
Rerun it whenever you install or move an emulator or add games. To create the
empty per-system ROM folders:

```powershell
./bootstrap.ps1 -Action Configure -CreateRomDirs $true
```

Close ES-DE before running it, then start ES-DE again.

Add Start Menu shortcuts (a `distrobox-gaming` folder) for ES-DE and every
installed emulator -- the portable ones have no installer to do it:

```powershell
./install-shortcuts.ps1 -Action Configure
```

## 6. First launch

1. Open ES-DE once (Start Menu > distrobox-gaming > ES-DE) so it creates its
   settings, close it, and rerun `./bootstrap.ps1 -Action Configure` -- that
   points ES-DE's ROM directory at `RomRoot`.
2. Open each emulator you'll use once so it writes its own config, and do
   its first-run setup:
   - PCSX2, DuckStation: select your PS2/PS1 BIOS.
   - RPCS3: install the PS3 firmware (`PS3UPDAT.PUP`).
   - Eden: add your `prod.keys` and firmware.
   - xemu: select your Xbox BIOS, flash and HDD image.
   - Flycast: place `naomi.zip`, `naomi2.zip`, `awbios.zip` in its data
     folder for NAOMI games.
   - Cemu: point it at your Wii U keys if your dumps need them.
3. Configure your controller in each emulator.

## 7. Apply emulator tuning

```powershell
./configure-emulators.ps1 -Action Check
./configure-emulators.ps1 -Action Configure
```

Applies the same graphics, widescreen and controller defaults as the Linux
setup, minus the Linux-only ones (see
[BIOS and emulator tuning](README.md#bios-and-emulator-tuning)). Emulators that aren't installed
or haven't been opened yet are skipped. Changed files are backed up as
`<file>.bak.<timestamp>`; copy one back to undo.

**BIOS:** put your own dumps in `BiosRoot` (default `%USERPROFILE%\ES-DE\BIOS`)
with the same layout as an EmuDeck `Emulation\bios` folder -- PS1/PS2 BIOS at
the top, `dc\naomi.zip` etc. for Flycast, `bios7.bin`/`bios9.bin`/`dsfirmware.bin`
for melonDS, `mcpx_1.0.bin`/`Complex_4627.bin`/`xbox_hdd.qcow2` for xemu,
`ps4\sys_modules\` for shadPS4, the Atari ROMs for RetroArch. This step copies
them into each installed emulator or points its config at them; anything
absent is skipped. See [BIOS and emulator tuning](README.md#bios-and-emulator-tuning).

## 8. Play

Put your games in the per-system folders -- same layouts as Linux:

- PS3: extracted game folders named `<Title>.ps3`
- PS4: `ps4\CUSAxxxxx\eboot.bin`
- PS Vita: install the game in Vita3K first, then create `<Game name>.psvita`
  containing its title ID (e.g. `PCSF00007`), per ES-DE's guide
- OpenBOR: one folder per game with its own `OpenBOR.exe` (copy the engine
  from `%USERPROFILE%\Emulators\OpenBOR`), or a `.lnk` shortcut to it

Launch one game per system from ES-DE and check video, audio, controller
input, clean exit, and saving/loading. The automated tests are no substitute
for that.

## Shortcut: everything at once

Steps 3 to 7 in one command, and a final check:

```powershell
./site.ps1
```

Run it again after opening each emulator once, so their settings get applied.
Later on: `./verify-setup.ps1` checks the installation, `./backup.ps1` /
`./restore.ps1 -Latest -Action Configure` save and restore your configuration,
and `./reset-configs.ps1` puts the managed settings back. See
[Maintenance](README.md#maintenance).

## Verification

```powershell
powershell -ExecutionPolicy Bypass -File windows/tests/verify.ps1
```

Runs the scripts against temporary directories only, never your real setup,
and downloads nothing. See [README.md](README.md#verification).
