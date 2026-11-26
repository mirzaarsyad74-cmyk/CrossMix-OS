#!/bin/sh
# SteamOS YouTube Video Player Launcher for TrimUI Smart Pro
# Plays video via MPV + yt-dlp with Handheld Controller Support

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
MPV_BIN="/mnt/SDCARD/System/bin/mpv"
YTDL_BIN="/mnt/SDCARD/System/bin/yt-dlp"
GPTOKEYB="/mnt/SDCARD/Apps/PortMaster/PortMaster/gptokeyb2"
GPTK_CONF="$APP_DIR/youtube.gptk"
SETTINGS_FILE="$APP_DIR/settings.conf"

export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"
export PATH="/mnt/SDCARD/System/bin:$PATH"
export PYTHONPATH="/mnt/SDCARD/System/lib/python3.11:/mnt/SDCARD/System/lib/python3.11/site-packages:$PYTHONPATH"

# Provision SSL root bundle for yt-dlp / curl inside mpv
CACERT="/mnt/SDCARD/Apps/SteamLink/cacert.pem"
if [ -f "$CACERT" ]; then
    export SSL_CERT_FILE="$CACERT"
    mkdir -p /etc/ssl/certs 2>/dev/null
    [ ! -f /etc/ssl/certs/ca-certificates.crt ] && cp -f "$CACERT" /etc/ssl/certs/ca-certificates.crt 2>/dev/null
fi

TARGET_URL="$1"
[ -z "$TARGET_URL" ] && exit 1

case "$TARGET_URL" in
    http*|www*|ytsearch*) ;;
    *)
        # If raw text with spaces was passed instead of a video ID, use ytsearch1:
        case "$TARGET_URL" in
            *" "*) TARGET_URL="ytsearch1:$TARGET_URL" ;;
            *)     TARGET_URL="https://www.youtube.com/watch?v=$TARGET_URL" ;;
        esac
        ;;
esac

# Load user settings
[ -f "$SETTINGS_FILE" ] && . "$SETTINGS_FILE"
MAX_RES="${MAX_RES:-720}"
SPONSOR_BLOCK="${SPONSOR_BLOCK:-1}"

case "$MAX_RES" in
    1080) YTDL_FMT="bestvideo[height<=1080][vcodec^=avc]+bestaudio/bestvideo[height<=1080]+bestaudio/best[height<=1080]/best" ;;
    720)  YTDL_FMT="bestvideo[height<=720][vcodec^=avc]+bestaudio/bestvideo[height<=720]+bestaudio/best[height<=720]/best" ;;
    480)  YTDL_FMT="bestvideo[height<=480][vcodec^=avc]+bestaudio/bestvideo[height<=480]+bestaudio/best[height<=480]/best" ;;
    360)  YTDL_FMT="bestvideo[height<=360][vcodec^=avc]+bestaudio/bestvideo[height<=360]+bestaudio/best[height<=360]/best" ;;
    *)    YTDL_FMT="bestvideo[height<=720][vcodec^=avc]+bestaudio/bestvideo[height<=720]+bestaudio/best[height<=720]/best" ;;
esac

YTDL_RAW="no-check-certificates="
if [ "$SPONSOR_BLOCK" = "1" ]; then
    YTDL_RAW="${YTDL_RAW},sponsorblock-mark=sponsor"
fi

echo 1 > /tmp/stay_awake
touch /var/trimui_inputd/sticks_disabled

# Clean up all background framebuffer display holders and wipe /dev/fb0 cleanly before MPV
pkill -9 -f infoscreen 2>/dev/null
pkill -9 -f sdl2imgshow 2>/dev/null
pkill -9 -f presenter 2>/dev/null
pkill -9 -f pic2fb 2>/dev/null
[ -w "/dev/fb0" ] && cat /dev/zero > /dev/fb0 2>/dev/null
sleep 0.1

# Start controller mapping daemon
GPTO_PID=""
if [ -x "$GPTOKEYB" ] && [ -f "$GPTK_CONF" ]; then
    killall -9 gptokeyb2 2>/dev/null
    "$GPTOKEYB" "mpv" -c "$GPTK_CONF" &
    GPTO_PID=$!
fi

# Launch MPV with native SDL2 video output
if [ -x "$MPV_BIN" ]; then
    chmod +x "$MPV_BIN" "$YTDL_BIN" 2>/dev/null
    "$MPV_BIN" \
        --vo=sdl,gpu \
        --ao=alsa,sdl \
        --ytdl=yes \
        --ytdl-path="$YTDL_BIN" \
        --script-opts="ytdl_hook-ytdl_path=$YTDL_BIN" \
        --ytdl-format="$YTDL_FMT" \
        --ytdl-raw-options="$YTDL_RAW" \
        --hwdec=auto \
        --fs \
        --force-window=immediate \
        --keep-open=no \
        --osd-level=1 \
        --osd-font-size=24 \
        --title="SteamOS YouTube Player" \
        "$TARGET_URL"
fi

# Cleanup
[ -n "$GPTO_PID" ] && kill -9 "$GPTO_PID" 2>/dev/null
killall -9 gptokeyb2 2>/dev/null
rm -f /var/trimui_inputd/sticks_disabled
rm -f /tmp/stay_awake
exit 0
