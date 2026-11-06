#!/bin/sh
# Steam Link Settings Configurator for TrimUI Smart Pro / CrossMix-OS
# Configures Resolution, Sharpness (Fix Blur), Host PC (Local/Internet), Bitrate, FPS & Battery Saver

CONF_DIR="$(cd "$(dirname "$0")" && pwd)"
SETTINGS_FILE="$CONF_DIR/settings.conf"
STEAM_BIN="$CONF_DIR/steamlink"
SELECTOR="/mnt/SDCARD/System/bin/selector"
INFOSCREEN="/mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh"
VK="/mnt/SDCARD/System/bin/VirtualKeyboard"
BG_IMG="/mnt/SDCARD/System/usr/trimui/res/settings_bg.png"
[ ! -f "$BG_IMG" ] && BG_IMG="/mnt/SDCARD/trimui/res/crossmix-os/bg-plain.png"

# 1. Load current persisted settings
if [ -f "$SETTINGS_FILE" ]; then
    . "$SETTINGS_FILE"
fi
RESOLUTION="${RESOLUTION:-720}"
FPS="${FPS:-60}"
LAYOUT="${LAYOUT:-xbox}"
BATTERY_SAVER="${BATTERY_SAVER:-0}"
SHARP_MODE="${SHARP_MODE:-1}"
BITRATE_KBPS="${BITRATE_KBPS:-15000}"
CUSTOM_HOST="${CUSTOM_HOST:-}"

save_settings() {
    cat <<EOF > "$SETTINGS_FILE"
# Steam Link Configuration for TrimUI Smart Pro / CrossMix-OS
RESOLUTION="$RESOLUTION"
FPS="$FPS"
LAYOUT="$LAYOUT"
BATTERY_SAVER="$BATTERY_SAVER"
SHARP_MODE="$SHARP_MODE"
BITRATE_KBPS="$BITRATE_KBPS"
CUSTOM_HOST="$CUSTOM_HOST"
EOF

    # Apply byte patch to steamlink binary at offset 0x34f588
    # 0x30 ('0') = Nearest-neighbor sharp sampling (0 BLUR)
    # 0x31 ('1') = Bilinear filter (blurry)
    if [ -f "$STEAM_BIN" ]; then
        if [ "$SHARP_MODE" = "1" ]; then
            printf '\x30' | dd of="$STEAM_BIN" bs=1 seek=$((0x34f588)) count=1 conv=notrunc 2>/dev/null
        else
            printf '\x31' | dd of="$STEAM_BIN" bs=1 seek=$((0x34f588)) count=1 conv=notrunc 2>/dev/null
        fi
    fi
}

show_info() {
    if [ -x "$INFOSCREEN" ]; then
        "$INFOSCREEN" -m "$1" -t "${2:-2}"
    else
        echo "$1"
    fi
}

# Main Settings Loop
while true; do
    case "$RESOLUTION" in
        1080) R_LBL="1080p FHD" ;;
        720)  R_LBL="720p Native (Sharpest)" ;;
        480)  R_LBL="480p Balanced" ;;
        320)  R_LBL="320p Ultra Save" ;;
        auto|*) R_LBL="Auto (720p)" ;;
    esac

    [ "$SHARP_MODE" = "1" ] && S_LBL="Razor Sharp (0 Blur)" || S_LBL="Smooth Bilinear"
    [ "$FPS" = "30" ] && F_LBL="30 FPS (Power Saver)" || F_LBL="60 FPS (Ultra Smooth)"
    [ "$LAYOUT" = "nintendo" ] && L_LBL="Nintendo Layout" || L_LBL="Xbox Standard Layout"
    [ "$BATTERY_SAVER" = "1" ] && B_LBL="ON (Eco Mode)" || B_LBL="OFF (Performance)"
    [ -n "$CUSTOM_HOST" ] && H_LBL="$CUSTOM_HOST (Remote / Direct)" || H_LBL="Auto-Discovery (Local Wi-Fi)"
    BTR_MBPS=$((BITRATE_KBPS / 1000))

    TITLE="STEAM LINK SETTINGS // CrossMix-OS"
    CHOICES="Resolution: $R_LBL"
    CHOICES="$CHOICES\nImage Sharpness: $S_LBL"
    CHOICES="$CHOICES\nHost Connection: $H_LBL"
    CHOICES="$CHOICES\nVideo Bitrate: ${BTR_MBPS} Mbps"
    CHOICES="$CHOICES\nFramerate: $F_LBL"
    CHOICES="$CHOICES\nController Mapping: $L_LBL"
    CHOICES="$CHOICES\nBattery Saver: $B_LBL"
    CHOICES="$CHOICES\n>>> Launch Steam Link Now <<<"
    CHOICES="$CHOICES\nExit to Main Menu"

    if [ -x "$SELECTOR" ]; then
        SEL=$(echo -e "$CHOICES" | "$SELECTOR" -i "$BG_IMG" -t "$TITLE" -fs 130 2>/dev/null)
        ACTION=$(echo "$SEL" | sed 's/^.*: //')
    else
        ACTION="Exit to Main Menu"
    fi

    case "$ACTION" in
        *"Resolution:"*)
            SUB_CHOICES="720p Native [Razor Sharp 1280x720 - RECOMMENDED]\n1080p FHD [1920x1080 Downsampled]\n480p Balanced [854x480 Low Power]\n320p Ultra Save [568x320]\nBack"
            SUB_SEL=$(echo -e "$SUB_CHOICES" | "$SELECTOR" -i "$BG_IMG" -t "Choose Steam Stream Resolution" -fs 130 2>/dev/null)
            SUB_ACT=$(echo "$SUB_SEL" | sed 's/^.*: //')
            case "$SUB_ACT" in
                *"720p"*)  RESOLUTION="720"; SHARP_MODE="1"; save_settings ;;
                *"1080p"*) RESOLUTION="1080"; save_settings ;;
                *"480p"*)  RESOLUTION="480"; save_settings ;;
                *"320p"*)  RESOLUTION="320"; save_settings ;;
            esac
            ;;
        *"Image Sharpness:"*)
            SUB_CHOICES="Razor Sharp [Point Sampling - NO BLUR - RECOMMENDED]\nSmooth [Bilinear Filter - Softer Pixels]\nBack"
            SUB_SEL=$(echo -e "$SUB_CHOICES" | "$SELECTOR" -i "$BG_IMG" -t "Select Image Sharpness Filter" -fs 130 2>/dev/null)
            SUB_ACT=$(echo "$SUB_SEL" | sed 's/^.*: //')
            case "$SUB_ACT" in
                *"Razor Sharp"*) SHARP_MODE="1"; save_settings ;;
                *"Smooth"*)      SHARP_MODE="0"; save_settings ;;
            esac
            ;;
        *"Host Connection:"*)
            SUB_CHOICES="Auto-Discovery [Local Wi-Fi Network]\nEnter PC IP or Domain [Internet / Remote Play / Tailscale]\nClear Host IP\nBack"
            SUB_SEL=$(echo -e "$SUB_CHOICES" | "$SELECTOR" -i "$BG_IMG" -t "Host PC Connection Mode" -fs 130 2>/dev/null)
            SUB_ACT=$(echo "$SUB_SEL" | sed 's/^.*: //')
            case "$SUB_ACT" in
                *"Auto-Discovery"*)
                    CUSTOM_HOST=""
                    save_settings
                    show_info "Switched to Auto-Discovery on local Wi-Fi." 2
                    ;;
                *"Enter PC IP"*)
                    NEW_HOST=""
                    if [ -x "$VK" ]; then
                        VK_RAW=$("$VK" -t "Enter PC IP or Hostname" 2>/dev/null)
                        NEW_HOST=$(echo "$VK_RAW" | grep -o '\[VKStart\].*\[VKEnd\]' | sed -e 's/\[VKStart\]//' -e 's/\[VKEnd\]//' | tr -d ' ')
                    fi
                    if [ -n "$NEW_HOST" ]; then
                        CUSTOM_HOST="$NEW_HOST"
                        save_settings
                        show_info "Host set to: $CUSTOM_HOST\nWill connect directly across Internet / LAN!" 3
                    fi
                    ;;
                *"Clear Host IP"*)
                    CUSTOM_HOST=""
                    save_settings
                    show_info "Saved host cleared." 2
                    ;;
            esac
            ;;
        *"Video Bitrate:"*)
            SUB_CHOICES="20 Mbps [Maximum Clarity / 5GHz Wi-Fi]\n15 Mbps [High Clarity - Recommended]\n12 Mbps [Standard]\n8 Mbps [Balanced]\n4 Mbps [Eco / Weak Wi-Fi]\nBack"
            SUB_SEL=$(echo -e "$SUB_CHOICES" | "$SELECTOR" -i "$BG_IMG" -t "Select Stream Bitrate Limit" -fs 130 2>/dev/null)
            SUB_ACT=$(echo "$SUB_SEL" | sed 's/^.*: //')
            case "$SUB_ACT" in
                *"20 Mbps"*) BITRATE_KBPS="20000"; save_settings ;;
                *"15 Mbps"*) BITRATE_KBPS="15000"; save_settings ;;
                *"12 Mbps"*) BITRATE_KBPS="12000"; save_settings ;;
                *"8 Mbps"*)  BITRATE_KBPS="8000"; save_settings ;;
                *"4 Mbps"*)  BITRATE_KBPS="4000"; save_settings ;;
            esac
            ;;
        *"Framerate:"*)
            SUB_CHOICES="60 FPS [Ultra Smooth Gameplay]\n30 FPS [Battery Saver Mode]\nBack"
            SUB_SEL=$(echo -e "$SUB_CHOICES" | "$SELECTOR" -i "$BG_IMG" -t "Select Stream Framerate Target" -fs 130 2>/dev/null)
            SUB_ACT=$(echo "$SUB_SEL" | sed 's/^.*: //')
            case "$SUB_ACT" in
                *"60 FPS"*) FPS="60"; save_settings ;;
                *"30 FPS"*) FPS="30"; save_settings ;;
            esac
            ;;
        *"Controller Mapping:"*)
            SUB_CHOICES="Xbox Standard [A=Bottom, B=Right, X=Left, Y=Top - Standard PC]\nNintendo Layout [A=Right, B=Bottom, X=Top, Y=Left - TrimUI physical]\nBack"
            SUB_SEL=$(echo -e "$SUB_CHOICES" | "$SELECTOR" -i "$BG_IMG" -t "Select Controller Button Mapping" -fs 130 2>/dev/null)
            SUB_ACT=$(echo "$SUB_SEL" | sed 's/^.*: //')
            case "$SUB_ACT" in
                *"Xbox"*)     LAYOUT="xbox"; save_settings ;;
                *"Nintendo"*) LAYOUT="nintendo"; save_settings ;;
            esac
            ;;
        *"Battery Saver:"*)
            [ "$BATTERY_SAVER" = "1" ] && BATTERY_SAVER="0" || BATTERY_SAVER="1"
            save_settings
            ;;
        *">>> Launch Steam Link Now <<<"*)
            save_settings
            exec "$CONF_DIR/launch.sh"
            exit 0
            ;;
        *"Exit"|*)
            save_settings
            exit 0
            ;;
    esac
done
