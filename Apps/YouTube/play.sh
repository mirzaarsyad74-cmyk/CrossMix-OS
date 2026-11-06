#!/bin/sh
# YouTube Video Player Launcher for TrimUI Smart Pro / CrossMix-OS
# Plays video via MPV + yt-dlp with 100% Ad-Blocking & Handheld Controller Support

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
MPV_BIN="/mnt/SDCARD/System/bin/mpv"
YTDL_BIN="/mnt/SDCARD/System/bin/yt-dlp"
GPTOKEYB="/mnt/SDCARD/Apps/PortMaster/PortMaster/gptokeyb2"
GPTK_CONF="$APP_DIR/youtube.gptk"
INFOSCREEN="/mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh"
SETTINGS_FILE="$APP_DIR/settings.conf"

export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"
export PATH="/mnt/SDCARD/System/bin:$PATH"

TARGET_URL="$1"
if [ -z "$TARGET_URL" ]; then
    [ -x "$INFOSCREEN" ] && "$INFOSCREEN" -m "Error: No video URL provided!" -t 2
    exit 1
fi

# If video ID was passed, prepend full URL
case "$TARGET_URL" in
    http*|www*) ;;
    *) TARGET_URL="https://www.youtube.com/watch?v=$TARGET_URL" ;;
esac

# Load user settings
[ -f "$SETTINGS_FILE" ] && . "$SETTINGS_FILE"
MAX_RES="${MAX_RES:-720}"
SPONSOR_BLOCK="${SPONSOR_BLOCK:-1}"

# Format selector based on resolution
case "$MAX_RES" in
    1080) YTDL_FMT="bestvideo[height<=1080]+bestaudio/best[height<=1080]/best" ;;
    720)  YTDL_FMT="bestvideo[height<=720]+bestaudio/best[height<=720]/best" ;;
    480)  YTDL_FMT="bestvideo[height<=480]+bestaudio/best[height<=480]/best" ;;
    360)  YTDL_FMT="bestvideo[height<=360]+bestaudio/best[height<=360]/best" ;;
    audio) YTDL_FMT="bestaudio/best" ;;
    *)    YTDL_FMT="bestvideo[height<=720]+bestaudio/best[height<=720]/best" ;;
esac

# SponsorBlock arguments
YTDL_RAW="sponsorblock-mark=all"
[ "$SPONSOR_BLOCK" = "1" ] && YTDL_RAW="sponsorblock-mark=all,sponsorblock-remove=sponsor"

# Show buffering splash
[ -x "$INFOSCREEN" ] && "$INFOSCREEN" -m "Connecting to YouTube...\nFetching Ad-Free Stream...\nPlease wait 2 seconds." -t 2 &

# Start controller mapping daemon
echo 1 > /tmp/stay_awake
touch /var/trimui_inputd/sticks_disabled

if [ -x "$GPTOKEYB" ] && [ -f "$GPTK_CONF" ]; then
    killall -9 gptokeyb2 2>/dev/null
    "$GPTOKEYB" "mpv" -c "$GPTK_CONF" &
    GPTO_PID=$!
fi

# Launch MPV with native hardware video decode and ad-free stream extraction
"$MPV_BIN" \
    --ytdl=yes \
    --ytdl-path="$YTDL_BIN" \
    --ytdl-format="$YTDL_FMT" \
    --script-opts="ytdl_hook-ytdl_path=$YTDL_BIN" \
    --ytdl-raw-options="$YTDL_RAW" \
    --hwdec=auto \
    --fs \
    --force-window=immediate \
    --keep-open=no \
    --osd-level=1 \
    --osd-font-size=24 \
    --title="YouTube Ad-Free Player" \
    "$TARGET_URL"

# Cleanup
[ -n "$GPTO_PID" ] && kill -9 "$GPTO_PID" 2>/dev/null
killall -9 gptokeyb2 2>/dev/null
rm -f /var/trimui_inputd/sticks_disabled
rm -f /tmp/stay_awake
exit 0
