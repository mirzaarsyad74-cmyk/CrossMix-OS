#!/bin/sh
# Steam Link Launcher for TrimUI Smart Pro / CrossMix-OS
# Features: Configurable Resolution (Auto/1080/720/480/320), FPS (Auto/60/30),
# Button Mapping (Xbox/Nintendo), Battery Saver Engine, and English UI.

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$APP_DIR" || exit 1

export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# 1. Load persisted configuration
SETTINGS_FILE="$APP_DIR/settings.conf"
if [ -f "$SETTINGS_FILE" ]; then
    . "$SETTINGS_FILE"
fi

RESOLUTION="${RESOLUTION:-720}"
FPS="${FPS:-60}"
LAYOUT="${LAYOUT:-xbox}"
BATTERY_SAVER="${BATTERY_SAVER:-0}"
SHARP_MODE="${SHARP_MODE:-1}"
BITRATE_KBPS="${BITRATE_KBPS:-15000}"

# 1b. Configure Razor-Sharp Render Quality
if [ "$SHARP_MODE" = "1" ]; then
    export SDL_RENDER_SCALE_QUALITY=0
    export SDL_HINT_RENDER_SCALE_QUALITY=0
else
    export SDL_RENDER_SCALE_QUALITY=1
    export SDL_HINT_RENDER_SCALE_QUALITY=1
fi

# 1c. Trigger Turbo Network Speed Booster for zero stream latency
BOOSTER="/mnt/SDCARD/Apps/NetworkBooster/boost.sh"
if [ -f "$BOOSTER" ]; then
    sh "$BOOSTER" --silent >/dev/null 2>&1 &
fi

# 2. Parse command-line override arguments
for arg in "$@"; do
    case "$arg" in
        config|settings|--config-menu)
            exec "$APP_DIR/configure.sh"
            exit 0
            ;;
        1080|1080p|--1080)
            RESOLUTION="1080"
            BATTERY_SAVER="0"
            ;;
        720|720p|--720)
            RESOLUTION="720"
            BATTERY_SAVER="0"
            ;;
        480|480p|--480)
            RESOLUTION="480"
            BATTERY_SAVER="0"
            ;;
        320|320p|--320)
            RESOLUTION="320"
            ;;
        auto|--auto)
            RESOLUTION="auto"
            ;;
        battery|powersave|--battery-saver)
            BATTERY_SAVER="1"
            ;;
        performance|--performance)
            BATTERY_SAVER="0"
            ;;
        xbox|--xbox)
            LAYOUT="xbox"
            ;;
        nintendo|--nintendo)
            LAYOUT="nintendo"
            ;;
    esac
done

# 3. Check Wi-Fi connection
IP=$(ip route get 1 2>/dev/null | awk '/src/ {print $NF; exit}')
if [ -z "$IP" ]; then
    if [ -f "/mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh" ]; then
        /mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh -m "Wi-Fi is not connected!\nPlease connect to Wi-Fi first." -t 4
    fi
    exit 1
fi

# 4. Resolve Resolution & FPS values
# TrimUI Smart Pro native resolution: 1280x720 @ 60Hz
TARGET_W=1280
TARGET_H=720
TARGET_FPS=60
TARGET_BITRATE="${BITRATE_KBPS:-15000}"

case "$RESOLUTION" in
    1080)
        TARGET_W=1920
        TARGET_H=1080
        TARGET_BITRATE=20000
        ;;
    720)
        TARGET_W=1280
        TARGET_H=720
        TARGET_BITRATE="${BITRATE_KBPS:-15000}"
        ;;
    480)
        TARGET_W=854
        TARGET_H=480
        TARGET_BITRATE=6000
        ;;
    320)
        TARGET_W=568
        TARGET_H=320
        TARGET_BITRATE=3000
        ;;
    auto|*)
        TARGET_W=1280
        TARGET_H=720
        TARGET_BITRATE="${BITRATE_KBPS:-15000}"
        ;;
esac

case "$FPS" in
    30)
        TARGET_FPS=30
        ;;
    60)
        TARGET_FPS=60
        ;;
    auto|*)
        TARGET_FPS=60
        ;;
esac

# 5. Battery Saver Optimization
CPU_DEV="/sys/devices/system/cpu/cpu0/cpufreq"
OLD_GOV="$(cat "$CPU_DEV/scaling_governor" 2>/dev/null)"
OLD_MAX_FREQ="$(cat "$CPU_DEV/scaling_max_freq" 2>/dev/null)"

if [ "$BATTERY_SAVER" = "1" ]; then
    # In Battery Saver mode:
    # Cap to 480p @ 30 FPS if resolution was set higher
    if [ "$TARGET_H" -gt 480 ]; then
        TARGET_W=854
        TARGET_H=480
    fi
    TARGET_FPS=30
    [ "$TARGET_BITRATE" -gt 4000 ] && TARGET_BITRATE=3500

    # Throttle CPU clock to 1008 MHz with ondemand governor (cuts SoC power by ~40%)
    echo ondemand > "$CPU_DEV/scaling_governor" 2>/dev/null
    echo 1008000 > "$CPU_DEV/scaling_max_freq" 2>/dev/null

    # Disable analog stick RGB LED rings to conserve battery
    echo 0 > /sys/class/led_anim/effect_enable 2>/dev/null

    # Dim backlight to 40% if higher
    if [ -w "/sys/class/backlight/backlight/brightness" ]; then
        CUR_BRIGHT="$(cat /sys/class/backlight/backlight/brightness 2>/dev/null)"
        [ "${CUR_BRIGHT:-100}" -gt 40 ] && echo 40 > /sys/class/backlight/backlight/brightness 2>/dev/null
    fi
else
    # High Performance mode:
    # 1.6 GHz performance governor
    echo performance > "$CPU_DEV/scaling_governor" 2>/dev/null
    echo 1608000 > "$CPU_DEV/scaling_max_freq" 2>/dev/null

    # Disable Wi-Fi power saving to avoid network latency/jitter
    command -v iw >/dev/null 2>&1 && iw dev wlan0 set power_save off 2>/dev/null
fi

# 6. Controller Mapping Setup
# Xbox mapping (Standard PC/Steam): A=Bottom (b0), B=Right (b1), X=Left (b2), Y=Top (b3)
# Nintendo mapping (TrimUI physical): A=Right (b1), B=Bottom (b0), X=Top (b3), Y=Left (b2)
if [ "$LAYOUT" = "nintendo" ]; then
    BTNS="a:b1,b:b0,x:b3,y:b2"
else
    BTNS="a:b0,b:b1,x:b2,y:b3"
fi
MAP_COMMON="$BTNS,leftshoulder:b4,rightshoulder:b5,lefttrigger:b6,righttrigger:b7,back:b8,start:b9,guide:b10,leftstick:b11,rightstick:b12,dpup:b13,dpdown:b14,dpleft:b15,dpright:b16,leftx:a0,lefty:a1,rightx:a2,righty:a3,platform:Linux,"

cat <<EOF > "$APP_DIR/gamecontrollerdb.txt"
190000004b4800000111000000010000,retrogame_joypad,$MAP_COMMON
030000004b4800000111000000010000,retrogame_joypad,$MAP_COMMON
050000004b4800000111000000010000,retrogame_joypad,$MAP_COMMON
19000000010000000100000000010000,Deeplay-keys,$MAP_COMMON
03000000010000000100000000010000,Deeplay-keys,$MAP_COMMON
05000000010000000100000000010000,Deeplay-keys,$MAP_COMMON
EOF

export SDL_GAMECONTROLLERCONFIG_FILE="$APP_DIR/gamecontrollerdb.txt"
export SDL_GAMECONTROLLERCONFIG="190000004b4800000111000000010000,retrogame_joypad,$MAP_COMMON
19000000010000000100000000010000,Deeplay-keys,$MAP_COMMON"

# 7. Sync stream settings with device.json (Only when legitimately paired)
DEV_JSON="$APP_DIR/device.json"
PAIRED_ID=""
PAIRED_SECRET=""
PAIRED_NAME="TrimUI Smart Pro"
PAIRED_STEAMID=""
PAIRED_AT=""

if [ -f "$DEV_JSON" ]; then
    PAIRED_SECRET=$(grep -o '"secret":[ ]*"[^"]*"' "$DEV_JSON" 2>/dev/null | awk -F'"' '{print $4}')
    PAIRED_ID=$(grep -o '"device_id":[ ]*[0-9]*' "$DEV_JSON" 2>/dev/null | awk -F: '{print $2}' | tr -d ' ')
    PAIRED_STEAMID=$(grep -o '"steamid":[ ]*[0-9]*' "$DEV_JSON" 2>/dev/null | awk -F: '{print $2}' | tr -d ' ')
    PAIRED_NAME=$(grep -o '"device_name":[ ]*"[^"]*"' "$DEV_JSON" 2>/dev/null | awk -F'"' '{print $4}')
    PAIRED_AT=$(grep -o '"paired_at":[ ]*"[^"]*"' "$DEV_JSON" 2>/dev/null | awk -F'"' '{print $4}')

    if [ -n "$PAIRED_SECRET" ] && [ -n "$PAIRED_STEAMID" ] && [ "$PAIRED_STEAMID" != "0" ]; then
        # Device is legitimately paired! Update streaming resolution/FPS/bitrate/host:
        cat <<EOF > "$DEV_JSON"
{
  "device_id": ${PAIRED_ID:-0},
  "secret": "${PAIRED_SECRET}",
  "device_name": "${PAIRED_NAME:-TrimUI Smart Pro}",
  "steamid": ${PAIRED_STEAMID},
  "paired_at": "${PAIRED_AT:-}",
  "host": "${CUSTOM_HOST:-}",
  "width": $TARGET_W,
  "height": $TARGET_H,
  "fps": $TARGET_FPS,
  "bitrate_kbps": $TARGET_BITRATE
}
EOF
    else
        # Incomplete / dummy pairing file - remove it so steamlink triggers 4-digit PIN pairing!
        rm -f "$DEV_JSON"
    fi
fi

# 8. Device naming & wake lock & SSL certificates
export SL_DEVICE_NAME="TrimUI Smart Pro"
echo 1 > /tmp/stay_awake

# Link SSL root certificate bundle for Steam Cloud pairing over Internet
mkdir -p /etc/ssl/certs 2>/dev/null
if [ -f "$APP_DIR/cacert.pem" ]; then
    cp -f "$APP_DIR/cacert.pem" /etc/ssl/ca-bundle.pem 2>/dev/null
    cp -f "$APP_DIR/cacert.pem" /etc/ssl/certs/ca-certificates.crt 2>/dev/null
fi
export SSL_CERT_FILE="$APP_DIR/cacert.pem"

chmod +x "$APP_DIR/steamlink" 2>/dev/null

# Clean up all background framebuffer display holders before launching exclusive SDL2 engine
pkill -9 -f sdl2imgshow 2>/dev/null
pkill -9 -f presenter 2>/dev/null
pkill -9 -f pic2fb 2>/dev/null
pkill -9 -f steam_gui 2>/dev/null
sleep 0.2

if [ -f "$DEV_JSON" ] && [ -n "$CUSTOM_HOST" ]; then
    "$APP_DIR/steamlink" --host "$CUSTOM_HOST" > "$APP_DIR/steamlink.log" 2>&1
    EXIT_CODE=$?
else
    "$APP_DIR/steamlink" > "$APP_DIR/steamlink.log" 2>&1
    EXIT_CODE=$?
fi

# If steamlink exited with an error, display last error line from log
if [ $EXIT_CODE -ne 0 ] && [ -s "$APP_DIR/steamlink.log" ]; then
    ERR_LINE=$(grep -E -i "error|fail|refused|busy|timeout" "$APP_DIR/steamlink.log" 2>/dev/null | tail -n 1)
    if [ -n "$ERR_LINE" ] && [ -f "/mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh" ]; then
        /mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh -m "Steam Link: $ERR_LINE" -t 4
    fi
fi

# 9. Restore system state on exit
rm -f /tmp/stay_awake
[ -n "$OLD_GOV" ] && echo "$OLD_GOV" > "$CPU_DEV/scaling_governor" 2>/dev/null
[ -n "$OLD_MAX_FREQ" ] && echo "$OLD_MAX_FREQ" > "$CPU_DEV/scaling_max_freq" 2>/dev/null
[ -n "$CUR_BRIGHT" ] && echo "$CUR_BRIGHT" > /sys/class/backlight/backlight/brightness 2>/dev/null
# Re-enable LED animations if they were enabled
echo 1 > /sys/class/led_anim/effect_enable 2>/dev/null
exit 0
