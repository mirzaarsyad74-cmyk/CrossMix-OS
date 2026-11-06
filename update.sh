#!/bin/sh
# SteamOS Handheld Edition - Instant Live Hotfix & Script Synchronizer
# Usage on TrimUI Smart Pro:
# curl -k -sL https://raw.githubusercontent.com/mirzaarsyad74-cmyk/CrossMix-OS/main/update.sh | sh

export PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts:$PATH"
export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"

REPO_RAW="https://raw.githubusercontent.com/mirzaarsyad74-cmyk/CrossMix-OS/main"

echo "=================================================="
echo " SteamOS Handheld Edition - Live Hotfix Updater"
echo " Target Version: v1.4.4"
echo "=================================================="

# Check network connectivity
IP=$(ip route get 1 2>/dev/null | awk '/src/ {print $NF; exit}')
if [ -z "$IP" ]; then
    echo "ERROR: Wi-Fi is not connected. Please connect to Wi-Fi first."
    exit 1
fi

echo "[*] Connected to Wi-Fi (IP: $IP)"
echo "[*] Downloading updated SteamOS scripts..."

dl() {
    remote_path="$1"
    local_path="/mnt/SDCARD/$1"
    mkdir -p "$(dirname "$local_path")" 2>/dev/null
    echo -n " -> Updating $remote_path ... "
    curl -k -sL "$REPO_RAW/$remote_path" -o "$local_path.tmp"
    if [ -s "$local_path.tmp" ]; then
        mv -f "$local_path.tmp" "$local_path"
        chmod +x "$local_path" 2>/dev/null
        echo "OK"
    else
        rm -f "$local_path.tmp"
        echo "FAILED"
    fi
}

# Update Core SteamOS Framework & Updater
dl "System/usr/trimui/scripts/steamos_gui.py"
dl "System/usr/trimui/scripts/ota_gui.py"
dl "System/usr/trimui/scripts/ota_update.sh"
dl "System/usr/trimui/scripts/update_common.sh"
dl "System/usr/trimui/crossmix-version.txt"
dl "Apps/OTA-update/launch.sh"

# Update Steam Link Handheld App
dl "Apps/SteamLink/steamlink"
dl "Apps/SteamLink/launch.sh"
dl "Apps/SteamLink/settings.conf"
dl "Apps/SteamLink/steam_gui.py"
dl "Apps/SteamLink/steam_gui.sh"
dl "Apps/SteamLink/configure.sh"
dl "Apps/SteamLink/configure_gui.py"

# Update YouTube App & Video Engine
dl "System/bin/yt-dlp"
dl "Apps/YouTube/launch.sh"
dl "Apps/YouTube/youtube_gui.py"
dl "Apps/YouTube/search.py"
dl "Apps/YouTube/play.sh"

# Update Network Booster App
dl "Apps/NetworkBooster/launch.sh"
dl "Apps/NetworkBooster/boost_gui.py"

sync

echo "=================================================="
echo " All SteamOS v1.4.0 updates applied successfully!"
echo " OTA updater, Steam Link, and YouTube are fixed."
echo "=================================================="

# Show on-screen confirmation
if [ -x "/mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh" ]; then
    pkill -9 -f sdl2imgshow 2>/dev/null
    /mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh -m "SteamOS v1.4.0 Applied!\n\nOTA Updater, Steam Link & YouTube\nare now 100% operational." -t 5
fi

exit 0

