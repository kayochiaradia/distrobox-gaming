@{
    # install-cores.ps1 installs every core referenced by a command in
    # esde-systems.psd1, plus these extras from the Linux dg_retroarch_cores
    # list. The extras cover systems ES-DE's bundled Windows configuration
    # already defines (Neo Geo Pocket, MSX, Odyssey 2, 3DO, WonderSwan,
    # Virtual Boy, PC Engine SuperGrafx, Vectrex, Neo Geo CD, Amiga, C64), so
    # they work from ES-DE without a custom system entry.
    ExtraCores = @(
        'mednafen_ngp'
        'bluemsx'
        'fmsx'
        'o2em'
        'opera'
        'mednafen_wswan'
        'mednafen_vb'
        'mednafen_supergrafx'
        'vecx'
        'neocd'
        'fceumm'
        'puae'
        'vice_x64'
    )

    BuildbotUrl = 'https://buildbot.libretro.com/nightly/windows/x86_64/latest'

    # Same 8 asset packs as the Linux dg_retroarch_assets (~245 MB total),
    # extracted into the matching folder next to retroarch.exe. A
    # .dg-installed stamp in each folder skips it on later runs.
    AssetsUrl = 'https://buildbot.libretro.com/assets/frontend'
    AssetPacks = @(
        @{ Zip = 'info.zip'; Dir = 'info' }
        @{ Zip = 'assets.zip'; Dir = 'assets' }
        @{ Zip = 'autoconfig.zip'; Dir = 'autoconfig' }
        @{ Zip = 'cheats.zip'; Dir = 'cheats' }
        @{ Zip = 'database-rdb.zip'; Dir = 'database\rdb' }
        @{ Zip = 'database-cursors.zip'; Dir = 'database\cursors' }
        @{ Zip = 'shaders_slang.zip'; Dir = 'shaders' }
        @{ Zip = 'overlays.zip'; Dir = 'overlays' }
    )
}
