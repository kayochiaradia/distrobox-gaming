# Windows console emulation

Native Windows 10/11 companion to the Linux distrobox setup. The first
baseline installs [ES-DE](https://es-de.org) plus Dolphin (GameCube/Wii),
PCSX2 (PS2), DuckStation (PS1), PPSSPP (PSP) and RetroArch (NES, SNES,
Genesis/Mega Drive, GBA, Game Boy/Color, Atari and more via cores), then wires
each emulator up so ES-DE can find it. Same initial scope as [macos/](../macos/README.md).

## Intentional scope boundary

This baseline is **native Windows apps only**, installed with `winget`. There
is no Distrobox, no Linux container, no WSL requirement. Windows PC games
never needed Wine/Proton in the first place -- they just run -- so nothing
from the Linux tree's Wine/Proton/mod-manager roles is reproduced here.

Unlike [macos/](../macos/README.md) and the Linux `ansible/` tree, there is
**no custom `es_systems.xml` to generate**. ES-DE ships a complete Windows
`es_systems.xml` and `es_find_rules.xml` out of the box, already covering
Dolphin, PCSX2, DuckStation, PPSSPP, RetroArch, RPCS3, Cemu, Azahar, Xenia,
xemu, Vita3K and more (see `future` in [apps.json](apps.json)). The work this
baseline actually does is: install the apps, and make sure ES-DE's own
find-rules (PATH, registry, or its `Emulators\<name>\` convention) can
actually locate each one.

Other emulators most of the Linux tree's optional roles cover (shadPS4,
RPCS3, Cemu, Azahar, Eden, Xenia, xemu, Vita3K, several native
recomps/decomps like Ship of Harkinian) all have real `winget` packages too --
see the `future` list in [apps.json](apps.json) -- but are not part of the
installed-by-default set yet. Adding one is a matter of moving its entry from
`future` to `apps` with the right `exeNames`/`esdeEmulatorDir`, the same
pattern the five current entries follow.

NexusMods mod sets, PS3/Switch DLC batch installers, per-game RPCS3/PCSX2
tuning, arcade Wine frontends and ROM-hack patch tooling from the Linux tree
are not ported. They are either Linux/Wine-specific automation with no
Windows equivalent needed (Windows games just run) or genuinely future work.

## Install and configure

For the application list and step-by-step instructions, see
[Installing on Windows](INSTALL.md).

From the repository root, in PowerShell:

```powershell
cd windows
./install-apps.ps1
Copy-Item config/localhost.example.psd1 config/localhost.psd1
notepad config/localhost.psd1   # set your ROM paths
./bootstrap.ps1 -Action Check
./bootstrap.ps1 -Action Configure
```

`install-apps.ps1` installs every app in [apps.json](apps.json) via `winget`;
rerunning it skips anything already installed and never removes packages.
`bootstrap.ps1 -Action Check` previews without writing anything; `-Action
Configure` creates a directory junction under `<EsdeHome>\Emulators\<name>\`
for any emulator ES-DE's own find-rules can't already see (no PATH mutation,
no registry writes -- delete the junction to undo), and reports (or, opt-in,
creates) the per-system ROM directories.

## First launch and validation

1. Open ES-DE. Its first-run wizard asks for a ROM directory -- point it at
   the same `RomRoot` you set in `config/localhost.psd1` (default
   `%USERPROFILE%\ES-DE\ROMs`), or keep the two in sync.
2. Open Dolphin, PCSX2, DuckStation and PPSSPP once each and finish their
   first-run setup. PCSX2 and DuckStation need your own PS2/PS1 BIOS.
3. Open RetroArch once, then **Online Updater > Core Downloader** to install
   cores for the systems you want (nes, snes, genesis, gba, gbc, ...).
   `winget` does not install cores.
4. Add your existing games at the configured paths. This project does not
   supply ROMs, BIOS, firmware, keys or game packages.
5. Launch one game per system from ES-DE. Check video, audio, controller
   input, clean exit, saving and loading.
6. Run `./bootstrap.ps1 -Action Configure` again; an unchanged setup should
   report every emulator already `Detected = True` and every junction
   unchanged.

## Verification

```powershell
pwsh windows/tests/verify.ps1
```

The test runs `bootstrap.ps1` for real against a temporary `EsdeHome`/
`RomRoot` -- it never touches your actual ES-DE install. It checks
`apps.json` shape, that `-Action Check` writes nothing, that `-Action
Configure` creates and then idempotently re-creates the same junction, and
that ROM directories are only created when `CreateRomDirs` is explicitly set.
It never calls `winget` and installs nothing.

## Architecture and next steps

Keep platform installation, commands and configuration under `windows/`, same
as `macos/`. This baseline shares no code with the Linux tree or with
`macos/`. Do not fold Windows concerns into the Linux roles or the macOS
scripts, or vice versa.

Next steps: real-game validation of these five systems on Windows, then
moving more of the `future` list in `apps.json` (shadPS4, RPCS3, Cemu,
Azahar, Eden, Xenia, xemu, Vita3K, the native recomp/decomp ports) into the
installed-by-default set once each has a confirmed `exeNames`/find-rule
mapping.

## Sources

- [ES-DE downloads and guide](https://www.es-de.org/)
- [ES-DE Windows `es_systems.xml`](https://gitlab.com/es-de/emulationstation-de/-/blob/master/resources/systems/windows/es_systems.xml)
- [ES-DE Windows `es_find_rules.xml`](https://gitlab.com/es-de/emulationstation-de/-/blob/master/resources/systems/windows/es_find_rules.xml)
- [winget](https://learn.microsoft.com/windows/package-manager/winget/)

Winget package IDs and ES-DE find-rule paths were checked on 2026-09-17.
