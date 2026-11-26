#!/bin/sh
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"
export PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts:$PATH"
export PYTHONPATH="/mnt/SDCARD/System/lib/python3.11:/mnt/SDCARD/System/lib/python3.11/site-packages:/mnt/SDCARD/System/usr/trimui/scripts:$PYTHONPATH"

# Ensure Python standard library is available
if [ ! -f "/mnt/SDCARD/System/lib/python3.11/os.py" ] && [ -f "/mnt/SDCARD/System/updates/update_001/python.zip" ]; then
    unzip -q -o -d "/mnt/SDCARD/System/" "/mnt/SDCARD/System/updates/update_001/python.zip" 2>/dev/null
fi

PY_BIN="/mnt/SDCARD/System/bin/python3.11"
[ -x "$PY_BIN" ] || PY_BIN="$(command -v python3 2>/dev/null)"

# Safe auto-sync of Steam Link scripts (never overwrite settings.conf or corrupt on HTTP error)
RAW_URL="https://raw.githubusercontent.com/mirzaarsyad74-cmyk/CrossMix-OS/main/Apps/SteamLink"
if curl -k -fsSL -m 4 "$RAW_URL/steam_gui.py" -o "$APP_DIR/steam_gui.py.tmp" 2>/dev/null && [ -s "$APP_DIR/steam_gui.py.tmp" ]; then
    if [ -n "$PY_BIN" ] && "$PY_BIN" -m py_compile "$APP_DIR/steam_gui.py.tmp" 2>/dev/null; then
        mv -f "$APP_DIR/steam_gui.py.tmp" "$APP_DIR/steam_gui.py"
        chmod +x "$APP_DIR/steam_gui.py"
    else
        rm -f "$APP_DIR/steam_gui.py.tmp"
    fi
else
    rm -f "$APP_DIR/steam_gui.py.tmp"
fi

if curl -k -fsSL -m 4 "$RAW_URL/launch.sh" -o "$APP_DIR/launch.sh.tmp" 2>/dev/null && [ -s "$APP_DIR/launch.sh.tmp" ] && head -n 1 "$APP_DIR/launch.sh.tmp" | grep -q "^#!/bin/sh"; then
    mv -f "$APP_DIR/launch.sh.tmp" "$APP_DIR/launch.sh"
    chmod +x "$APP_DIR/launch.sh"
else
    rm -f "$APP_DIR/launch.sh.tmp"
fi

if [ ! -f "$APP_DIR/settings.conf" ]; then
    curl -k -fsSL -m 4 "$RAW_URL/settings.conf" -o "$APP_DIR/settings.conf.tmp" 2>/dev/null && [ -s "$APP_DIR/settings.conf.tmp" ] && mv -f "$APP_DIR/settings.conf.tmp" "$APP_DIR/settings.conf" || rm -f "$APP_DIR/settings.conf.tmp"
fi

if [ -n "$PY_BIN" ]; then
    "$PY_BIN" "$APP_DIR/steam_gui.py"
fi
exit 0
