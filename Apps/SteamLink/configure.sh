#!/bin/sh
# Steam Link Settings Configurator for TrimUI Smart Pro / CrossMix-OS

CONF_DIR="$(cd "$(dirname "$0")" && pwd)"
SETTINGS_FILE="$CONF_DIR/settings.conf"
INFOSCREEN="/mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh"

# Load current settings or defaults
if [ -f "$SETTINGS_FILE" ]; then
    . "$SETTINGS_FILE"
fi
RESOLUTION="${RESOLUTION:-auto}"
FPS="${FPS:-auto}"
LAYOUT="${LAYOUT:-xbox}"
BATTERY_SAVER="${BATTERY_SAVER:-0}"

show_msg() {
    if [ -x "$INFOSCREEN" ]; then
        "$INFOSCREEN" -m "$1" -t "${2:-2}"
    else
        echo "$1"
    fi
}

ask_key() {
    # $1: Message, $2: valid keys, $3: timeout
    if [ -x "$INFOSCREEN" ]; then
        "$INFOSCREEN" -m "$1" -k "$2" -t "${3:-15}"
    else
        read -r ans
        echo "$ans"
    fi
}

# 1. Choose Resolution
RES_PROMPT="[ Steam Link Resolution ]\nCurrent: $RESOLUTION\n\nUP: Auto (720p)\nRIGHT: 1080p (FHD)\nDOWN: 720p (Native)\nLEFT: 480p (Balanced)\nY: 320p (Ultra Save)\nB: Cancel / Keep Current"
KEY=$(ask_key "$RES_PROMPT" "UP RIGHT DOWN LEFT Y B" 20)
case "$KEY" in
    UP) RESOLUTION="auto" ;;
    RIGHT) RESOLUTION="1080" ;;
    DOWN) RESOLUTION="720" ;;
    LEFT) RESOLUTION="480" ;;
    Y) RESOLUTION="320" ;;
    B|timeout) ;;
esac

# 2. Choose FPS
FPS_PROMPT="[ Steam Link Framerate ]\nCurrent: $FPS\n\nUP: Auto (60 FPS)\nRIGHT: 60 FPS (Ultra Smooth)\nLEFT: 30 FPS (Power Saver)\nB: Skip"
KEY=$(ask_key "$FPS_PROMPT" "UP RIGHT LEFT B" 15)
case "$KEY" in
    UP) FPS="auto" ;;
    RIGHT) FPS="60" ;;
    LEFT) FPS="30" ;;
    B|timeout) ;;
esac

# 3. Choose Controller Layout
LAYOUT_PROMPT="[ Controller Button Mapping ]\nCurrent: $LAYOUT\n\nA: Xbox Layout (A=Bottom, B=Right)\n   *Standard for Steam & PC Games\n\nX: Nintendo Layout (A=Right, B=Bottom)\n   *Matches physical TrimUI labels\n\nB: Skip"
KEY=$(ask_key "$LAYOUT_PROMPT" "A X B" 15)
case "$KEY" in
    A) LAYOUT="xbox" ;;
    X) LAYOUT="nintendo" ;;
    B|timeout) ;;
esac

# 4. Choose Battery Saver Mode
SAVER_STR="OFF"
[ "$BATTERY_SAVER" = "1" ] && SAVER_STR="ON"
SAVER_PROMPT="[ Battery Saver Mode ]\nCurrent: $SAVER_STR\n\nA: Enable Battery Saver (30 FPS, 1GHz, LEDs Off)\nB: Disable Battery Saver (Full Performance)\nY: Skip"
KEY=$(ask_key "$SAVER_PROMPT" "A B Y" 15)
case "$KEY" in
    A) BATTERY_SAVER="1" ;;
    B) BATTERY_SAVER="0" ;;
    Y|timeout) ;;
esac

# Save settings
cat <<EOF > "$SETTINGS_FILE"
# Steam Link Configuration for TrimUI Smart Pro / CrossMix-OS
RESOLUTION="$RESOLUTION"
FPS="$FPS"
LAYOUT="$LAYOUT"
BATTERY_SAVER="$BATTERY_SAVER"
CUSTOM_HOST="$CUSTOM_HOST"
EOF

SAVER_LABEL="OFF"
[ "$BATTERY_SAVER" = "1" ] && SAVER_LABEL="ON (Power Save)"

show_msg "Settings Saved Successfully!\n\nResolution: $RESOLUTION\nFramerate: $FPS\nLayout: $LAYOUT\nBattery Saver: $SAVER_LABEL" 3
exit 0
