#!/bin/sh
# SteamOS YouTube Launcher for TrimUI Smart Pro
# Direct graphical video browser & ad-free player launcher.

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"
export PATH="/mnt/SDCARD/System/bin:$PATH"

# Ensure Python standard library is available
if [ ! -f "/mnt/SDCARD/System/lib/python3.11/os.py" ] && [ -f "/mnt/SDCARD/System/updates/update_001/python.zip" ]; then
    unzip -q -o -d "/mnt/SDCARD/System/" "/mnt/SDCARD/System/updates/update_001/python.zip" 2>/dev/null
fi

echo 1 > /tmp/stay_awake
if [ -x "/mnt/SDCARD/System/bin/python3.11" ]; then
    /mnt/SDCARD/System/bin/python3.11 "$APP_DIR/youtube_gui.py"
else
    python3 "$APP_DIR/youtube_gui.py"
fi
rm -f /tmp/stay_awake
exit 0
