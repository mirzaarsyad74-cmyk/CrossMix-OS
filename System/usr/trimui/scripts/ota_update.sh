#!/bin/sh
export PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts:$PATH"
export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"

# Ensure Python standard library is available
if [ ! -f "/mnt/SDCARD/System/lib/python3.11/os.py" ] && [ -f "/mnt/SDCARD/System/updates/update_001/python.zip" ]; then
    unzip -q -o -d "/mnt/SDCARD/System/" "/mnt/SDCARD/System/updates/update_001/python.zip" 2>/dev/null
fi

if [ -f "/mnt/SDCARD/System/usr/trimui/scripts/ota_gui.py" ] && [ -x "/mnt/SDCARD/System/bin/python3.11" ]; then
    exec /mnt/SDCARD/System/bin/python3.11 /mnt/SDCARD/System/usr/trimui/scripts/ota_gui.py "$@"
else
    exec python3 /mnt/SDCARD/System/usr/trimui/scripts/ota_gui.py "$@"
fi
