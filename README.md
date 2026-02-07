# EdgeTX SD Card Contents

This repo contains the SD Card contents for all supported EdgeTX Radios.

## Preparing your SD Card

Tools like [Buddy](https://buddy.edgetx.org) will do most of this automatically for you with a couple of clicks.

However, if you want to do this manually:
1. Download the appropriate zip file for your radio (either listed below, or in [sdcard.json](https://github.com/EdgeTX/edgetx-sdcard/blob/master/sdcard.json)) from the [releases page](https://github.com/EdgeTX/edgetx-sdcard/releases) (expand the Assets heading if you don't see the files).
2. Unzip the zip archive and put the contents onto a FAT32-formatted (NOT exFAT!) SD Card (preferably smaller than 32GB).
3. If you want the voice pack also, download your preferred voicepack language from the [Voice Pack Repo](https://github.com/EdgeTX/edgetx-sdcard-sounds/releases), unzip the archive, and add it to your SD card.

## Platforms

The contents of this repository are organised by color type and screen size, with zip archives generated for each color type and screen size.

A non-exhaustive list of targets (look at the [sdcard.json](https://github.com/EdgeTX/edgetx-sdcard/blob/master/sdcard.json) if you are unable to figure out out which one applies to your handset from this list) includes:

### Black and White Screen
- **bw128x64.zip** (128x64 pixel)
    - FrSky Taranis Q X7 ACCESS
    - iFlight Commando 8
    - Jumper T20
    - Jumper T-Pro v2
    - RadioMaster Boxer
    - RadioMaster Pocket
    - RadioMaster TX12 mkII
    - RadioMaster MT12
    - RadioMaster Zorro
- **bw212x64.zip** (212x64 pixel, "wide screen")
    - FrSky Taranis X9D+ 2019

### Colour Screen
- **c320x240.zip** (320x240 pixel, landscape orientation)
    - Flysky PA01
- **c320x480.zip** (320x480 pixel, portrait orientation)
    - Flysky Nirvana NV14
    - Flysky Elysium EL18
- **c480x272.zip** (480x272 pixel, landscape orientation)
    - FrSky Horus x10s
    - FrSky Horus x12s
    - Jumper T16
    - Jumper T18
    - RadioMaster TX16s / TX16s mkII
- **c480x320.zip** (480x320 pixel, landscape orientation)
    - Flysky PL18
    - Flysky Paladin EV (PL18EV)
    - Jumper T15
    - Jumper T15 Pro
    - RadioMaster TX15
- **c800x480.zip** (800x480 pixel, landscape orientation)
    - RadioMaster TX16S MK3

## For Developers

### Working with Symlinks (Linux/macOS/Windows)

This repository uses symlinks to avoid duplicating shared template files across different screen sizes. The same `.lua`, `.txt` files, and `img/` folders are used across multiple screen configurations, with only the `.yml` configuration files being unique to each screen size.

**For Linux and macOS users:** Symlinks work natively. Just clone and go.

**For Windows users:** You need to enable symlink support:

1. **Enable Developer Mode:**
   - Open Settings → Privacy & Security → For Developers
   - Toggle "Developer Mode" to ON
   - This allows Git to create symlinks without requiring administrator privileges

2. **Configure Git:**
```cmd
   git config --global core.symlinks true
```

3. **Clone the repository:**
```cmd
   git clone https://github.com/EdgeTX/edgetx-sdcard.git
```

**If you cannot enable Developer Mode** (e.g., corporate restrictions), symlinks will appear as small text files containing the link path. You can still work on the repository using the sync script below.

### Sync Script for Windows (Without Symlink Support)

If you cannot use symlinks on Windows, use this batch script to manually sync shared files from the canonical location to all screen size variants:

**`sync-shared.bat`:**
```batch
@echo off
setlocal enabledelayedexpansion

echo Syncing shared template files...
echo.

set CANONICAL=sdcard\color\TEMPLATES\1.Wizard
set VARIANTS=c320x240 c320x480 c480x272 c480x320 c800x480

for %%V in (%VARIANTS%) do (
    set TARGET=sdcard\%%V\TEMPLATES\1.Wizard
    echo Syncing to !TARGET!...

    REM Copy .lua and .txt files
    for %%F in (%CANONICAL%\*.lua %CANONICAL%\*.txt) do (
        copy /Y "%%F" "!TARGET!\" >nul
    )

    REM Copy img directory
    xcopy /E /I /Y "%CANONICAL%\img" "!TARGET!\img" >nul

    echo   Done.
)

echo.
echo All shared files synced successfully!
echo Remember to commit your changes when ready.
pause
```

**Usage:**
1. Save this as `sync-shared.bat` in the repository root
2. After editing any `.lua`, `.txt` files, or images in `sdcard/color/TEMPLATES/1.Wizard/`, run the script
3. The script will copy the shared files to all variant directories
4. Commit your changes as normal

**Note:** Only edit the `.yml` files directly in each variant directory (e.g., `sdcard/c480x272/TEMPLATES/1.Wizard/*.yml`). All other files should be edited in the canonical `color/` directory and then synced using this script.
