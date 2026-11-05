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
  * `Emus/STEAM/`: Direct launcher entry in the main games menu.
  * `Roms/STEAM/`: Steam shortcuts and scripts.
  * `Apps/SteamLink/`: Native ARM64 Linux Steam Remote Play client with direct framebuffer rendering and Xbox 360 controller mapping.
  * `Apps/CloudRedirect/`: Stream hub for Steam Remote Play, Moonlight Cloud Streaming, and custom Cloud host IPs.
  * `Apps/PortMaster/`: Retained for native PC game ports (e.g. Celeste).

---

## 4. Hardware Management (Fast Charging & LEDs)

* **PMIC**: X-Powers AXP2202.
* **Fast Charging (2.0A / 10W)**:
  * Handled by background daemon `System/usr/trimui/scripts/fast_charge_daemon.sh`.
  * Controls `axp2202-usb/current_max` and `axp2202-battery/constant_charge_current_max`.
* **Visual & LED Animations**:
  * On-screen OSD banner via `System/usr/trimui/osd/show_fast_charge_msg.sh`.
  * Electric Cyan (`#00E5FF`) stick ring breathing pulse via `/sys/class/led_anim/`.
* **Thermal Protection**:
  * Automatically throttles current back to 1.2A if battery temperature exceeds $43^\circ\text{C}$.
