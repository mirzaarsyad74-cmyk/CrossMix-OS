#!/bin/sh
# Steam Link launcher for TrimUI Smart Pro / CrossMix-OS

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$APP_DIR" || exit 1

export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"

# Check if Wi-Fi interface has an IP address
IP=$(ip route get 1 2>/dev/null | awk '/src/ {print $NF; exit}')
if [ -z "$IP" ]; then
    if [ -f "/mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh" ]; then
        /mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh -m "Wi-Fi is not connected!\nPlease connect to Wi-Fi first." -t 4
    fi
    exit 1
fi

# Prevent system sleep / screen blanking while streaming
echo 1 > /tmp/stay_awake

# Optimize CPU governor for smooth H.264 software decoding
GOV_FILE=/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
OLD_GOV="$(cat "$GOV_FILE" 2>/dev/null)"
[ -w "$GOV_FILE" ] && echo performance > "$GOV_FILE"
echo 1608000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null

# Disable Wi-Fi power saving to avoid network latency/jitter
command -v iw >/dev/null 2>&1 && iw dev wlan0 set power_save off 2>/dev/null

# Name displayed in Steam's list of paired devices
export SL_DEVICE_NAME="TrimUI Smart Pro"

# Controller configuration mapping
if [ -f "/usr/lib/gamecontrollerdb.txt" ]; then
    export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib/gamecontrollerdb.txt"
elif [ -f "/mnt/SDCARD/Apps/PortMaster/PortMaster/gamecontrollerdb.txt" ]; then
    export SDL_GAMECONTROLLERCONFIG_FILE="/mnt/SDCARD/Apps/PortMaster/PortMaster/gamecontrollerdb.txt"
fi

chmod +x ./steamlink 2>/dev/null
./steamlink > "$APP_DIR/steamlink.log" 2>&1

# Restore settings on exit
rm -f /tmp/stay_awake
[ -n "$OLD_GOV" ] && [ -w "$GOV_FILE" ] && echo "$OLD_GOV" > "$GOV_FILE" 2>/dev/null
