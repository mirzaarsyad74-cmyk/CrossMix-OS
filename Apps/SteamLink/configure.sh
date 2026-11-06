#!/bin/sh
# SteamOS Steam Link Configurator Launcher
CONF_DIR="$(cd "$(dirname "$0")" && pwd)"
export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"
export PATH="/mnt/SDCARD/System/bin:$PATH"

if [ -x "/mnt/SDCARD/System/bin/python3.11" ]; then
    /mnt/SDCARD/System/bin/python3.11 "$CONF_DIR/configure_gui.py"
else
    python3 "$CONF_DIR/configure_gui.py"
fi
exit 0
