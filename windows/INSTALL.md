# Installing on Windows 10/11

This guide covers the first phase of Windows support. The commands are meant
to be run on the target PC, in PowerShell; reading this document installs
nothing.

## What gets installed

| Application | Role | winget ID |
|---|---|---|
| ES-DE | Frontend for browsing the library and launching games | `ES-DE.EmulationStation-DE` |
| Dolphin | GameCube and Wii | `DolphinEmulator.Dolphin` |
| PCSX2 | PlayStation 2 | `PCSX2Team.PCSX2` |
| DuckStation | PlayStation 1 | `Stenzek.DuckStation` |
| PPSSPP | PSP | `PPSSPPTeam.PPSSPP` |
| RetroArch | NES, SNES, Genesis, GBA, Game Boy/Color, Atari and more via cores | `Libretro.RetroArch` |

[apps.json](apps.json) is the list the scripts actually use, plus a `future`
list of confirmed-available `winget` packages (shadPS4, RPCS3 excluded --
see below --, Cemu, Azahar, Eden, Xenia, xemu, Vita3K, Ship of Harkinian,
2 Ship 2 Harkinian) not yet wired into the default install.

RPCS3 has **no** `winget` package by upstream policy (they discourage
third-party redistribution of builds) -- get it from
[rpcs3.net](https://rpcs3.net/) manually if you want PS3.

No ROMs, BIOS, firmware or keys are supplied by this project or by these
installers.

## 1. Check the environment

`winget` ships with modern Windows 10/11 as part of "App Installer". Confirm
it's present:

```powershell
winget --version
```

If missing, install "App Installer" from the Microsoft Store first.

## 2. Install the applications

From the repository root:

```powershell
cd windows
./install-apps.ps1
```

This reads [apps.json](apps.json) and runs `winget install` for each entry,
skipping anything already installed. It never removes packages that aren't
on the list.

### Inspecting the list

```powershell
./install-apps.ps1 -List     # print id / name / winget id, installs nothing
./install-apps.ps1 -Check    # report installed vs. missing, installs nothing
```

To add an application, add an entry to the `apps` array in `apps.json` (or
promote one from `future`) with its `wingetId`, `exeNames` and, if it needs
one, `esdeEmulatorDir` -- see [README.md](README.md#architecture-and-next-steps).

## 3. Configure your library paths

Create the local override only if it does not exist yet:

```powershell
if (-not (Test-Path windows/config/localhost.psd1)) {
    Copy-Item windows/config/localhost.example.psd1 windows/config/localhost.psd1
}
```

Edit it with your ROM library root and, if you have a split library, per-system
overrides:

```powershell
@{
    EsdeHome = "$env:USERPROFILE\ES-DE"
    RomRoot  = "D:\Games\roms"
    RomPaths = @{
        ps2 = '\\NAS\Games\roms\ps2'
    }
    CreateRomDirs = $false
}
```

The default `RomRoot` is `%USERPROFILE%\ES-DE\ROMs`, matching what ES-DE's
own first-run wizard suggests. Missing directories are only reported, never
created -- a disconnected network or USB drive must not silently become an
empty local folder. Set `CreateRomDirs = $true` explicitly to opt in to
creating missing local directories.

## 4. Review and apply

```powershell
./bootstrap.ps1 -Action Check
./bootstrap.ps1 -Action Configure
```

`-Action Check` previews without writing; `-Action Configure` writes. What it
writes: a directory junction under `<EsdeHome>\Emulators\<name>\` for any
installed emulator ES-DE's own find-rules can't already see on PATH or in the
registry, and (only if `CreateRomDirs` is `$true`) missing ROM directories.
No PATH variable is modified and no registry keys are written -- delete a
junction under `Emulators\` to undo it.

## 5. First launch

1. Open Dolphin, PCSX2, DuckStation and PPSSPP once each and finish their
   first-run setup.
2. In PCSX2 and DuckStation, select your own PS1/PS2 BIOS.
3. Open RetroArch, then use **Online Updater > Core Downloader** to fetch
   cores for the systems you want. `winget` only installs the RetroArch
   application, not cores.
4. Configure your controller in each emulator.
5. Open ES-DE. On first run it asks for a ROM directory -- point it at the
   same path as `RomRoot` in `config/localhost.psd1`.
6. Add your games at the configured per-system paths (e.g. `ROMs\gc`,
   `ROMs\ps2`, ...) and launch one game per system. Check video, audio,
   controller input, clean exit, and saving/loading.

This phase automates installation and emulator discovery. BIOS, controllers
and graphics settings are still configured inside each emulator, and the
automated test in `tests/verify.ps1` is no substitute for testing with real
games.

## Verification

```powershell
pwsh windows/tests/verify.ps1
```

Runs `bootstrap.ps1` for real against a temporary sandbox directory, never
against your actual `%USERPROFILE%\ES-DE`. It never calls `winget` and
installs nothing. See [README.md](README.md#verification) for what it checks.

See [README.md](README.md) for architecture, scope boundaries, and how to add
more emulators from the `future` list.
