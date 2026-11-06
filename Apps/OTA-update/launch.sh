#!/bin/sh
# SteamOS Handheld OTA Updater Launcher
export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"
export PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts:$PATH"

# Ensure Python standard library is ready
if [ ! -f "/mnt/SDCARD/System/lib/python3.11/os.py" ] && [ -f "/mnt/SDCARD/System/updates/update_001/python.zip" ]; then
    unzip -q -o -d "/mnt/SDCARD/System/" "/mnt/SDCARD/System/updates/update_001/python.zip" 2>/dev/null
fi

echo 1 >/tmp/stay_awake
if [ -x "/mnt/SDCARD/System/bin/python3.11" ]; then
    /mnt/SDCARD/System/bin/python3.11 /mnt/SDCARD/System/usr/trimui/scripts/ota_gui.py
else
    python3 /mnt/SDCARD/System/usr/trimui/scripts/ota_gui.py
fi
rm -f /tmp/stay_awake
exit 0
