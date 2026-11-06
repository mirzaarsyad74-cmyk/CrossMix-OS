#!/bin/sh
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"
export PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts:$PATH"
export PYTHONPATH="/mnt/SDCARD/System/lib/python3.11:/mnt/SDCARD/System/lib/python3.11/site-packages:/mnt/SDCARD/System/usr/trimui/scripts:$PYTHONPATH"

# Auto-sync Steam Link scripts from GitHub if Wi-Fi is active
RAW_URL="https://raw.githubusercontent.com/mirzaarsyad74-cmyk/CrossMix-OS/main/Apps/SteamLink"
curl -k -s -m 3 "$RAW_URL/steam_gui.py" -o "$APP_DIR/steam_gui.py.tmp" 2>/dev/null
if [ -s "$APP_DIR/steam_gui.py.tmp" ]; then
    mv -f "$APP_DIR/steam_gui.py.tmp" "$APP_DIR/steam_gui.py"
    chmod +x "$APP_DIR/steam_gui.py"
fi
curl -k -s -m 3 "$RAW_URL/launch.sh" -o "$APP_DIR/launch.sh.tmp" 2>/dev/null
if [ -s "$APP_DIR/launch.sh.tmp" ]; then
    mv -f "$APP_DIR/launch.sh.tmp" "$APP_DIR/launch.sh"
    chmod +x "$APP_DIR/launch.sh"
fi
curl -k -s -m 3 "$RAW_URL/settings.conf" -o "$APP_DIR/settings.conf.tmp" 2>/dev/null
if [ -s "$APP_DIR/settings.conf.tmp" ]; then
    mv -f "$APP_DIR/settings.conf.tmp" "$APP_DIR/settings.conf"
fi
curl -k -s -m 3 "$RAW_URL/device.json" -o "$APP_DIR/device.json.tmp" 2>/dev/null
if [ -s "$APP_DIR/device.json.tmp" ]; then
    mv -f "$APP_DIR/device.json.tmp" "$APP_DIR/device.json"
fi

if [ -x "/mnt/SDCARD/System/bin/python3.11" ]; then
    /mnt/SDCARD/System/bin/python3.11 "$APP_DIR/steam_gui.py"
else
    python3 "$APP_DIR/steam_gui.py"
fi
exit 0
