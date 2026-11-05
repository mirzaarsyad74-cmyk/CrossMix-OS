# Steam Link for CrossMix-OS (TrimUI Smart Pro)

Native Steam Remote Play client for TrimUI Smart Pro with official Steam branding, English interface, configurable resolution/FPS, Xbox & Nintendo controller layouts, and Battery Saver mode.

## Quick Setup:
1. Ensure your TrimUI Smart Pro and your gaming PC are connected to the same Wi-Fi network.
2. Launch Steam on your PC.
3. Open "Steam Link" from the Apps or STEAM system menu.
4. A 4-digit PIN code will appear on the device screen.
5. On your PC Steam client, go to:
   Steam -> Settings -> Remote Play -> Pair Steam Link
6. Enter the 4-digit PIN shown on your TrimUI screen.
7. Pairing is saved! Your PC Steam library is now ready to stream directly.

## Configurable Resolution & FPS:
You can choose your streaming resolution and framerate via:
- Launchlist presets in the STEAM menu (Select or Y key).
- Individual shortcuts in the STEAM ROMs list (1080p, 720p, 480p, Battery Saver).
- Interactive configuration menu ("Steam Settings.sh" or "Apps/SteamLink/configure.sh").
- Direct editing of `Apps/SteamLink/settings.conf`.

Available Options:
- Resolution: Auto (720p native), 1080p (Super-sampling FHD), 720p (Native 1:1), 480p (Balanced), 320p (Ultra Save).
- Framerate: Auto, 60 FPS (Ultra Smooth), 30 FPS (Power Saver).

## Controller Button Layouts (X A B Y):
TrimUI Smart Pro hardware mapping is configured via `Apps/SteamLink/gamecontrollerdb.txt` and `SDL_GAMECONTROLLERCONFIG`:
- Xbox Layout (Default & Recommended):
  - Bottom button (TrimUI B) = Xbox A (Jump / Confirm)
  - Right button (TrimUI A) = Xbox B (Cancel / Back)
  - Left button (TrimUI Y) = Xbox X (Action / Reload)
  - Top button (TrimUI X) = Xbox Y (Menu / Map)
- Nintendo Layout:
  - Matches the physical button letters printed on the TrimUI shell.

## Battery Saver Mode:
Activating Battery Saver mode:
- Throttles CPU clock to 1.008 GHz on-demand (reducing SoC power draw by >40%).
- Caps stream to 480p @ 30 FPS with optimized bitrate (3500 kbps) to minimize Wi-Fi and decode power.
- Shuts off analog stick RGB LED ring animations.
- Dims display backlight to 40%.
- Automatically restores full performance when streaming exits.

## Shortcuts:
- Exit Stream: Hold SELECT + START simultaneously.
