#!/bin/sh
# SteamOS Handheld Edition - Instant Live Hotfix & Script Synchronizer
# Usage on TrimUI Smart Pro:
# curl -k -fsSL https://raw.githubusercontent.com/mirzaarsyad74-cmyk/CrossMix-OS/main/update.sh | sh

export PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts:$PATH"
export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"
export PYTHONPATH="/mnt/SDCARD/System/lib/python3.11:/mnt/SDCARD/System/lib/python3.11/site-packages:/mnt/SDCARD/System/usr/trimui/scripts:$PYTHONPATH"

REPO_RAW="https://raw.githubusercontent.com/mirzaarsyad74-cmyk/CrossMix-OS/main"
TARGET_VER="1.4.10"
NO_UI=0
for arg in "$@"; do
    [ "$arg" = "--no-ui" ] && NO_UI=1
done

echo "=================================================="
echo " SteamOS Handheld Edition - Live Hotfix Updater"
echo " Target Version: v$TARGET_VER"
echo "=================================================="

# Check network connectivity
IP=$(ip route get 1 2>/dev/null | awk '/src/ {print $NF; exit}')
if [ -z "$IP" ]; then
    echo "ERROR: Wi-Fi is not connected. Please connect to Wi-Fi first."
    exit 1
fi

echo "[*] Connected to Wi-Fi (IP: $IP)"
echo "[*] Downloading updated SteamOS scripts & binaries..."

PY_BIN="/mnt/SDCARD/System/bin/python3.11"
[ -x "$PY_BIN" ] || PY_BIN="$(command -v python3 2>/dev/null)"
FAIL_COUNT=0

dl() {
    remote_path="$1"
    local_path="/mnt/SDCARD/$1"
    mkdir -p "$(dirname "$local_path")" 2>/dev/null
    echo -n " -> Updating $remote_path ... "
    if ! curl -k -fsSL --retry 2 --max-time 30 "$REPO_RAW/$remote_path" -o "$local_path.tmp" 2>/dev/null || [ ! -s "$local_path.tmp" ]; then
        rm -f "$local_path.tmp"
        echo "FAILED"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi

    # Validate text scripts aren't HTML error pages, and validate Python syntax where applicable
    case "$local_path" in
        *.py)
            if [ "$(basename "$local_path")" != "yt-dlp.py" ] && [ -n "$PY_BIN" ]; then
                if ! "$PY_BIN" -m py_compile "$local_path.tmp" 2>/dev/null; then
                    rm -f "$local_path.tmp"
                    echo "CORRUPT"
                    FAIL_COUNT=$((FAIL_COUNT + 1))
                    return 1
                fi
            fi
            ;;
        *.sh)
            if head -n 1 "$local_path.tmp" | grep -qi "<html"; then
                rm -f "$local_path.tmp"
                echo "INVALID"
                FAIL_COUNT=$((FAIL_COUNT + 1))
                return 1
            fi
            ;;
    esac

    mv -f "$local_path.tmp" "$local_path"
    chmod +x "$local_path" 2>/dev/null
    echo "OK"
    return 0
}

# Update Core SteamOS Framework & Updater
dl "System/usr/trimui/scripts/steamos_gui.py"
dl "System/usr/trimui/scripts/steamos_boot_anim.py"
dl "System/usr/trimui/scripts/ota_gui.py"
dl "System/usr/trimui/scripts/ota_update.sh"
dl "System/usr/trimui/scripts/update_common.sh"
dl "System/usr/trimui/crossmix-version.txt"
dl "Apps/OTA-update/launch.sh"
dl "Apps/OTA-update/keys.gptk"

# Update Steam Link Handheld App
dl "Apps/SteamLink/steamlink"
dl "Apps/SteamLink/launch.sh"
dl "Apps/SteamLink/steam_gui.py"
dl "Apps/SteamLink/steam_gui.sh"
dl "Apps/SteamLink/configure.sh"
dl "Apps/SteamLink/configure_gui.py"
dl "Apps/SteamLink/config.json"
dl "Apps/SteamLinkSettings/launch.sh"

# Preserve local user Steam Link settings (only install default if missing, and clear old Tailscale test IP)
if [ ! -f "/mnt/SDCARD/Apps/SteamLink/settings.conf" ]; then
    dl "Apps/SteamLink/settings.conf"
elif grep -q 'CUSTOM_HOST="100\.120\.175\.117"' "/mnt/SDCARD/Apps/SteamLink/settings.conf" 2>/dev/null; then
    sed -i 's/CUSTOM_HOST="100\.120\.175\.117"/CUSTOM_HOST=""/' "/mnt/SDCARD/Apps/SteamLink/settings.conf" 2>/dev/null
fi

# Update YouTube App & Video Engine (including intact yt-dlp.py zipapp!)
dl "System/bin/yt-dlp"
dl "System/bin/yt-dlp.py"
dl "Apps/YouTube/launch.sh"
dl "Apps/YouTube/youtube_gui.py"
dl "Apps/YouTube/search.py"
dl "Apps/YouTube/play.sh"
dl "Apps/YouTube/youtube.gptk"

# Update Network Booster App
dl "Apps/NetworkBooster/launch.sh"
dl "Apps/NetworkBooster/boost_gui.py"
dl "Apps/NetworkBooster/boost.sh"

sync

NEW_VER=$(cat /mnt/SDCARD/System/usr/trimui/crossmix-version.txt 2>/dev/null | tr -d '[:space:]')
NEW_VER="${NEW_VER:-$TARGET_VER}"

echo "=================================================="
echo " SteamOS v$NEW_VER sync finished (failures: $FAIL_COUNT)"
echo "=================================================="

# Show on-screen confirmation only when run standalone interactively
if [ "$NO_UI" -eq 0 ] && [ -x "/mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh" ]; then
    pkill -9 -f sdl2imgshow 2>/dev/null
    /mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh -m "SteamOS v$NEW_VER Applied!\n\nOTA Updater, Steam Link & YouTube\nare updated." -t 5
fi

[ "$FAIL_COUNT" -eq 0 ] || exit 1
exit 0
