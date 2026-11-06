# AGENT Guidelines & Release Rules: CrossMix-OS

This document specifies mandatory rules and operational protocols for any AI agent or automated pipeline working on the **CrossMix-OS** codebase.

---

## 1. Always Auto-Increment Version on Every Release / Update (Mandatory for OTA)

Whenever updates, improvements, bug fixes, or new features are committed to the repository, **always increment the version number** (e.g. `1.3.0` -> `1.3.1` -> `1.3.2`).

### Why This Is Mandatory:
The TrimUI Smart Pro Over-The-Air (OTA) updater (`System/usr/trimui/scripts/update_ota_release.sh`) queries the latest GitHub Release asset from `mirzaarsyad74-cmyk/CrossMix-OS` and extracts the remote version from the filename `CrossMix-OS_v<VERSION>.zip`. It compares this with the local version in `/mnt/SDCARD/System/usr/trimui/crossmix-version.txt`.

**If the remote version $\le$ local version:**
The device reports:
> *"No new major version of CrossMix available."*

Therefore, **without an incremented version number, existing devices in the wild will NEVER receive or detect the update!**

### Files and Steps to Update on Every Version Bump:
1. **`System/usr/trimui/crossmix-version.txt`**:
   * Update the single-line version string:
     ```text
     X.Y.Z
     ```
2. **Git Tag**:
   * Tag the commit with `vX.Y.Z`:
     ```bash
     git tag -a vX.Y.Z -m "CrossMix-OS vX.Y.Z"
     git push origin vX.Y.Z
     ```
3. **GitHub Release**:
   * Push the tag or trigger the GitHub Actions release workflow:
     ```bash
     POST /repos/mirzaarsyad74-cmyk/CrossMix-OS/actions/workflows/CrossMix%20Release.yml/dispatches
     {"ref": "main", "inputs": {"tag_name": "vX.Y.Z"}}
     ```
   * Ensure the published asset is named:
     `CrossMix-OS_vX.Y.Z.zip`

---

## 2. Automated GitHub Release Pipeline

* **Repository**: `https://github.com/mirzaarsyad74-cmyk/CrossMix-OS`
* **Workflow**: `.github/workflows/CrossMix Release.yml`
* **Trigger**: Automatic on pushing any tag matching `v*` (or manual `workflow_dispatch`).
* **Artifact Limit**: The release asset `CrossMix-OS_v<VERSION>.zip` must remain **under 2.0 GiB (2,147,483,648 bytes)** to comply with GitHub's hard release asset limit.

---

## 3. Pure Steam & Cloud Streaming Architecture

* **No Legacy Emulators**: Do not commit legacy emulator cores, ROM packs, or BIOS files (`RetroArch/`, `BIOS/`, `Best/`).
* **Dedicated Steam Environment**:
  * `Emus/STEAM/`: Direct launcher entry in the main games menu with launchlist presets (Auto, 1080p, 720p, 480p, Battery Saver, Ultra Battery Saver, Settings).
  * `Roms/STEAM/`: Steam shortcuts, resolution presets, and settings menu launcher.
  * `Apps/SteamLink/`: Native ARM64 Linux Steam Remote Play client with direct framebuffer rendering, official Steam vector icon, 100% English UI, and TrimUI hardware button mapping.
  * `Apps/PortMaster/`: Retained for native PC game ports (e.g. Celeste).

---

## 4. Steam Link Settings & Optimization Engine

* **Official Steam Branding**:
  * Employs the authentic Valve Steam logo across `Emus/STEAM/`, `Icons/Default/Emus/STEAM.png`, `Apps/SteamLink/icon.png`, and theme icon packs.
  * Custom dark vignette background in `Backgrounds/Default/STEAM.png` and boxart in `Imgs/STEAM/`.
* **English Translation**:
  * All legacy Portuguese UI strings, status toasts, pairing guidance, and button prompts are patched in-place to natural English.
* **Controller Button Mapping (X A B Y)**:
  * Default Xbox mapping: Bottom=A, Right=B, Left=X, Top=Y (standard for Steam and PC games).
  * Alternate Nintendo mapping option: Physical labels (East=A, South=B, North=X, West=Y).
  * Enforced via `Apps/SteamLink/gamecontrollerdb.txt` and exported `SDL_GAMECONTROLLERCONFIG`.
* **Resolution & FPS Configuration**:
  * Resolution options: `Auto` (720p), `1080p` (Super-sampled FHD), `720p` (Native 1:1), `480p` (Balanced), `320p` (Ultra Save).
  * FPS options: `Auto` (60 FPS), `60 FPS`, `30 FPS`.
* **Battery Saver Mode**:
  * Throttles CPU clock to 1008 MHz with `ondemand` governor.
  * Caps stream to 480p @ 30 FPS at 3500 kbps to minimize decode and Wi-Fi radio power.
  * Shuts off analog stick RGB LED ring animation and dims display backlight to 40%.
  * Restores clocks, backlight, and LEDs on exit.
* **Interactive Configuration**:
  * Built-in on-screen GUI menu `Apps/SteamLink/configure.sh` using TrimUI `infoscreen.sh`.

---

## 6. Mandatory Rule: Always Provide Real Native Dynamic GUI (No Raw ASCII / No Fake Static Mockups)

* **Always Build Real Graphical Interfaces (GUI)**:
  Every user-facing application, setup wizard, updater, or configuration tool must provide a **100% native graphical user interface**.
* **Zero Raw Terminal / ASCII Usage**:
  Never expose raw command-line consoles, terminal emulators (`SimpleTerminal`), or text-mode ASCII box scripts (`shellect.sh`) to the user. All background operations (`wget`, `curl`, `7z`, `fsck`) must be silenced (`>/dev/null 2>&1` or logged to disk) while a high-fidelity graphical UI displays real-time progress.
* **Strict Ban on Baked-in Static Mockups**:
  Never bake fake dynamic UI elements (such as static progress bars, fake download speeds, fake percentage numbers, or fake changelogs) directly into background image files (`.png`).
  * Background images must only be clean, unadorned obsidian canvas frames.
  * All titles, version numbers, progress bars, percentages, metrics, and button badges must be rendered **dynamically at runtime** via the native Python framebuffer engine (`pic2fb` / `/dev/fb0`) or TrimUI SDL2 dialog engines (`presenter` / `selector`).
* **Gamepad Navigation**:
  All GUIs must support direct gamepad controls (`D-Pad`, `A` to Confirm, `B` to Cancel/Back, `X`/`Y` for Secondary Actions) without requiring physical keyboards.

---

## 7. Hardware Management (Fast Charging & LEDs)

* **PMIC**: X-Powers AXP2202.
* **Fast Charging (2.0A / 10W)**:
  * Handled by background daemon `System/usr/trimui/scripts/fast_charge_daemon.sh`.
  * Controls `axp2202-usb/current_max` and `axp2202-battery/constant_charge_current_max`.
* **Visual & LED Animations**:
  * On-screen OSD banner via `System/usr/trimui/osd/show_fast_charge_msg.sh`.
  * Electric Cyan (`#00E5FF`) stick ring breathing pulse via `/sys/class/led_anim/`.
* **Thermal Protection**:
  * Automatically throttles current back to 1.2A if battery temperature exceeds $43^\circ\text{C}$.

---

## 8. Dual-Tier OTA Update Architecture (Fast System Update vs Full OS & ROMs Image)

The Over-The-Air (OTA) updater (`System/usr/trimui/scripts/ota_gui.py` and `Apps/OTA-update/launch.sh`) MUST ALWAYS provide an explicit dual-tier choice to the user whenever a new firmware version is available:

1. **[A] Fast System Update (~15 MB, ~10 seconds)**
   * **Target**: Active users who only need updated system scripts, Steam Link handheld client, YouTube video player, network booster, and core configurations.
   * **Payload**: Only updated shell scripts, Python GUI engines, and ARM64 binaries (`Apps/`, `System/usr/trimui/scripts/`, `System/bin/`).
   * **Execution**: Synchronized via high-speed GitHub raw streaming (`update.sh`), completing in ~10 seconds and eliminating the need to re-download 960+ MB of static ROMs and emulators.

2. **[X] Full OS & ROMs Archive (~962 MB, Complete Image)**
   * **Target**: Users performing a fresh reinstall, system repair, or upgrading the entire RetroArch emulator collection, cores, base roms, media, and themes.
   * **High-Speed C-Native Download Engine**:
     * **Native Subprocess**: Must use compiled `curl-aarch64` / `curl` in a dedicated background subprocess instead of single-threaded Python `urllib`.
     * **Mandatory HTTP Byte-Range Resume (`-C -`)**: Auto-resumes from existing `.tmp` bytes so no download progress is lost if interrupted.
     * **16MB Kernel TCP Buffers**: Configures `net.core.rmem_max=16777216` and `net.ipv4.tcp_rmem` for high-speed WAN throughput.
     * **Wi-Fi Power Save Disabled**: Explicitly executes `iw dev wlan0 set power_save off` and `iwconfig wlan0 power off` to prevent 802.11 sleep throttling.
     * **CPU Performance Governor**: Locks CPU to 1.6 GHz (`performance` governor) during download and verification.
     * **Decoupled GUI Blitting**: GUI updates are throttled to once every 0.75s to ensure Pillow PNG compression does not starve the network socket.

3. **Gamepad Controls on Update Available Screen**:
   * `[A]` **Fast System Update**: Instant delta update (~15 MB, 10s).
   * `[X]` **Full OS & ROMs Archive**: Complete system download (~962 MB) with resume.
   * `[B]` **Cancel**: Abort and return to Main Menu.


