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

TARGET_URL="$1"
[ -z "$TARGET_URL" ] && exit 1

case "$TARGET_URL" in
    http*|www*) ;;
    *) TARGET_URL="https://www.youtube.com/watch?v=$TARGET_URL" ;;
esac

# Load user settings
[ -f "$SETTINGS_FILE" ] && . "$SETTINGS_FILE"
MAX_RES="${MAX_RES:-720}"
SPONSOR_BLOCK="${SPONSOR_BLOCK:-1}"

case "$MAX_RES" in
    1080) YTDL_FMT="bestvideo[height<=1080]+bestaudio/best[height<=1080]/best" ;;
    720)  YTDL_FMT="bestvideo[height<=720]+bestaudio/best[height<=720]/best" ;;
    480)  YTDL_FMT="bestvideo[height<=480]+bestaudio/best[height<=480]/best" ;;
    360)  YTDL_FMT="bestvideo[height<=360]+bestaudio/best[height<=360]/best" ;;
    *)    YTDL_FMT="bestvideo[height<=720]+bestaudio/best[height<=720]/best" ;;
esac

echo 1 > /tmp/stay_awake
touch /var/trimui_inputd/sticks_disabled

# Start controller mapping daemon
GPTO_PID=""
if [ -x "$GPTOKEYB" ] && [ -f "$GPTK_CONF" ]; then
    killall -9 gptokeyb2 2>/dev/null
    "$GPTOKEYB" "mpv" -c "$GPTK_CONF" &
    GPTO_PID=$!
fi

# Launch MPV with native SDL2 video output
if [ -x "$MPV_BIN" ]; then
    "$MPV_BIN" \
        --vo=sdl,gpu \
        --ao=alsa,sdl \
        --ytdl=yes \
        --ytdl-path="$YTDL_BIN" \
        --script-opts="ytdl_hook-ytdl_path=$YTDL_BIN" \
        --ytdl-format="$YTDL_FMT" \
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
