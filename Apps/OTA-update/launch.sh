#!/bin/sh
# SteamOS Handheld OTA Updater Launcher
export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"
export PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts:$PATH"
export PYTHONPATH="/mnt/SDCARD/System/lib/python3.11:/mnt/SDCARD/System/lib/python3.11/site-packages:/mnt/SDCARD/System/usr/trimui/scripts:$PYTHONPATH"

# 1. Save CPU scaling state & boost to 1.6 GHz Performance Governor for fast downloads
CPU_DEV="/sys/devices/system/cpu/cpu0/cpufreq"
OLD_GOV="$(cat "$CPU_DEV/scaling_governor" 2>/dev/null)"
OLD_MAX_FREQ="$(cat "$CPU_DEV/scaling_max_freq" 2>/dev/null)"
echo performance > "$CPU_DEV/scaling_governor" 2>/dev/null
echo 1608000 > "$CPU_DEV/scaling_max_freq" 2>/dev/null

# 2. Disable Wi-Fi power saving & apply 16MB TCP buffers
if [ -f "/mnt/SDCARD/Apps/NetworkBooster/boost.sh" ]; then
    sh "/mnt/SDCARD/Apps/NetworkBooster/boost.sh" --silent >/dev/null 2>&1
else
    command -v iw >/dev/null 2>&1 && iw dev wlan0 set power_save off 2>/dev/null
    command -v iwconfig >/dev/null 2>&1 && iwconfig wlan0 power off 2>/dev/null
    sysctl -w net.core.rmem_max=16777216 2>/dev/null
    sysctl -w net.core.wmem_max=16777216 2>/dev/null
    sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216" 2>/dev/null
    sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216" 2>/dev/null
fi

# 3. Ensure Python standard library is ready
if [ ! -f "/mnt/SDCARD/System/lib/python3.11/os.py" ] && [ -f "/mnt/SDCARD/System/updates/update_001/python.zip" ]; then
    unzip -q -o -d "/mnt/SDCARD/System/" "/mnt/SDCARD/System/updates/update_001/python.zip" 2>/dev/null
fi

PY_BIN="/mnt/SDCARD/System/bin/python3.11"
[ -x "$PY_BIN" ] || PY_BIN="$(command -v python3 2>/dev/null)"

# 4. Safe auto-refresh of updater scripts from GitHub (verify HTTP 200 and syntax before replacing)
RAW_URL="https://raw.githubusercontent.com/mirzaarsyad74-cmyk/CrossMix-OS/main"
sync_py() {
    src="$1"; dst="$2"
    if curl -k -fsSL -m 5 "$src" -o "$dst.tmp" 2>/dev/null && [ -s "$dst.tmp" ]; then
        if [ -n "$PY_BIN" ] && "$PY_BIN" -m py_compile "$dst.tmp" 2>/dev/null; then
            mv -f "$dst.tmp" "$dst"
            chmod +x "$dst" 2>/dev/null
            return 0
        fi
    fi
    rm -f "$dst.tmp"
    return 1
}

sync_py "$RAW_URL/System/usr/trimui/scripts/steamos_gui.py" "/mnt/SDCARD/System/usr/trimui/scripts/steamos_gui.py"
sync_py "$RAW_URL/System/usr/trimui/scripts/ota_gui.py" "/mnt/SDCARD/System/usr/trimui/scripts/ota_gui.py"

if curl -k -fsSL -m 5 "$RAW_URL/Apps/OTA-update/launch.sh" -o "/mnt/SDCARD/Apps/OTA-update/launch.sh.tmp" 2>/dev/null && [ -s "/mnt/SDCARD/Apps/OTA-update/launch.sh.tmp" ] && head -n 1 "/mnt/SDCARD/Apps/OTA-update/launch.sh.tmp" | grep -q "^#!/bin/sh"; then
    mv -f "/mnt/SDCARD/Apps/OTA-update/launch.sh.tmp" "/mnt/SDCARD/Apps/OTA-update/launch.sh"
    chmod +x "/mnt/SDCARD/Apps/OTA-update/launch.sh"
else
    rm -f "/mnt/SDCARD/Apps/OTA-update/launch.sh.tmp"
fi

echo 1 >/tmp/stay_awake
if [ -n "$PY_BIN" ]; then
    "$PY_BIN" /mnt/SDCARD/System/usr/trimui/scripts/ota_gui.py "$@"
fi
rm -f /tmp/stay_awake

# Restore CPU scaling state cleanly
[ -n "$OLD_GOV" ] && echo "$OLD_GOV" > "$CPU_DEV/scaling_governor" 2>/dev/null
[ -n "$OLD_MAX_FREQ" ] && echo "$OLD_MAX_FREQ" > "$CPU_DEV/scaling_max_freq" 2>/dev/null
exit 0
