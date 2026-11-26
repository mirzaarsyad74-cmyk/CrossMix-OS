#!/bin/sh
# SteamOS YouTube Launcher for TrimUI Smart Pro
# Direct graphical video browser & ad-free player launcher.

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"
export PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts:$PATH"
export PYTHONPATH="/mnt/SDCARD/System/lib/python3.11:/mnt/SDCARD/System/lib/python3.11/site-packages:/mnt/SDCARD/System/usr/trimui/scripts:$PYTHONPATH"

# Ensure Python standard library is available
if [ ! -f "/mnt/SDCARD/System/lib/python3.11/os.py" ] && [ -f "/mnt/SDCARD/System/updates/update_001/python.zip" ]; then
    unzip -q -o -d "/mnt/SDCARD/System/" "/mnt/SDCARD/System/updates/update_001/python.zip" 2>/dev/null
fi

# Provision SSL root bundle for YouTube / Python HTTPS
CACERT="/mnt/SDCARD/Apps/SteamLink/cacert.pem"
if [ -f "$CACERT" ]; then
    export SSL_CERT_FILE="$CACERT"
    mkdir -p /etc/ssl/certs 2>/dev/null
    [ ! -f /etc/ssl/certs/ca-certificates.crt ] && cp -f "$CACERT" /etc/ssl/certs/ca-certificates.crt 2>/dev/null
    [ ! -f /etc/ssl/ca-bundle.pem ] && cp -f "$CACERT" /etc/ssl/ca-bundle.pem 2>/dev/null
fi

# Disable Wi-Fi power saving for responsive search and streaming
if [ -f "/mnt/SDCARD/Apps/NetworkBooster/boost.sh" ]; then
    sh "/mnt/SDCARD/Apps/NetworkBooster/boost.sh" --silent >/dev/null 2>&1
fi

# Clean up any lingering framebuffer holders
pkill -9 -f sdl2imgshow 2>/dev/null
pkill -9 -f presenter 2>/dev/null
pkill -9 -f pic2fb 2>/dev/null
chmod +x "$APP_DIR/play.sh" /mnt/SDCARD/System/bin/yt-dlp /mnt/SDCARD/System/bin/python3.11 /mnt/SDCARD/System/bin/mpv 2>/dev/null

echo 1 > /tmp/stay_awake
if [ -x "/mnt/SDCARD/System/bin/python3.11" ]; then
    /mnt/SDCARD/System/bin/python3.11 "$APP_DIR/youtube_gui.py" > "$APP_DIR/youtube.log" 2>&1
else
    python3 "$APP_DIR/youtube_gui.py" > "$APP_DIR/youtube.log" 2>&1
fi
rm -f /tmp/stay_awake
exit 0
