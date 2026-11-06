#!/bin/sh
# Steam Link In-Game & Handheld Configurator for TrimUI Smart Pro / CrossMix-OS
# Allows live configuration of Resolution, FPS, Bitrate, Xbox/Nintendo Mapping,
# Battery Saver, Razor-Sharp Anti-Blur mode, and Remote Internet / Tailscale connection.

CONF_DIR="$(cd "$(dirname "$0")" && pwd)"
SETTINGS_FILE="$CONF_DIR/settings.conf"
SELECTOR="/mnt/SDCARD/System/bin/selector"
INFOSCREEN="/mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh"
VK="/mnt/SDCARD/System/bin/VirtualKeyboard"
BG_IMG="/mnt/SDCARD/System/usr/trimui/res/settings_bg.png"
[ ! -f "$BG_IMG" ] && BG_IMG="/mnt/SDCARD/trimui/res/crossmix-os/bg-plain.png"

TMP_MAIN="/tmp/steam_menu.txt"
TMP_SUB="/tmp/steam_sub.txt"

# Default configuration values
RESOLUTION="720"
FPS="60"
LAYOUT="xbox"
BATTERY_SAVER="0"
SHARP_MODE="1"
BITRATE_KBPS="15000"
CUSTOM_HOST=""

# Load persisted settings if file exists
if [ -f "$SETTINGS_FILE" ]; then
    . "$SETTINGS_FILE"
fi

save_settings() {
    cat <<EOF > "$SETTINGS_FILE"
RESOLUTION="$RESOLUTION"
FPS="$FPS"
LAYOUT="$LAYOUT"
BATTERY_SAVER="$BATTERY_SAVER"
SHARP_MODE="$SHARP_MODE"
BITRATE_KBPS="$BITRATE_KBPS"
CUSTOM_HOST="$CUSTOM_HOST"
EOF
}

show_info() {
    if [ -x "$INFOSCREEN" ]; then
        "$INFOSCREEN" -m "$1" -t "${2:-3}"
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

    cat <<EOF > "$TMP_MAIN"
Resolution: $R_LBL
Image Sharpness: $S_LBL
Host Connection: $H_LBL
Video Bitrate: ${BTR_MBPS} Mbps
Framerate: $F_LBL
Controller Mapping: $L_LBL
Battery Saver: $B_LBL
Connection Guide (Same & Different Network)
>>> Launch Steam Link Now <<<
Exit to Main Menu
EOF

    if [ -x "$SELECTOR" ]; then
        SEL=$("$SELECTOR" -i "$BG_IMG" -t "$TITLE" -fs 125 -cf "$TMP_MAIN" 2>/dev/null)
        ACTION=$(echo "$SEL" | sed 's/^.*: //')
    else
        ACTION="Exit to Main Menu"
    fi

    case "$ACTION" in
        *"Resolution:"*)
            cat <<EOF > "$TMP_SUB"
720p Native [Razor Sharp 1280x720 - RECOMMENDED]
1080p FHD [1920x1080 Downsampled]
480p Balanced [854x480 Low Power]
320p Ultra Save [568x320]
Back
EOF
            SUB_SEL=$("$SELECTOR" -i "$BG_IMG" -t "Choose Steam Stream Resolution" -fs 125 -cf "$TMP_SUB" 2>/dev/null)
            SUB_ACT=$(echo "$SUB_SEL" | sed 's/^.*: //')
            case "$SUB_ACT" in
                *"720p"*)  RESOLUTION="720"; SHARP_MODE="1"; save_settings ;;
                *"1080p"*) RESOLUTION="1080"; save_settings ;;
                *"480p"*)  RESOLUTION="480"; save_settings ;;
                *"320p"*)  RESOLUTION="320"; save_settings ;;
            esac
            ;;
        *"Image Sharpness:"*)
            cat <<EOF > "$TMP_SUB"
Razor Sharp [Point Sampling - NO BLUR - RECOMMENDED]
Smooth [Bilinear Filter - Softer Pixels]
Back
EOF
            SUB_SEL=$("$SELECTOR" -i "$BG_IMG" -t "Select Image Sharpness Filter" -fs 125 -cf "$TMP_SUB" 2>/dev/null)
            SUB_ACT=$(echo "$SUB_SEL" | sed 's/^.*: //')
            case "$SUB_ACT" in
                *"Razor Sharp"*) SHARP_MODE="1"; save_settings ;;
                *"Smooth"*)      SHARP_MODE="0"; save_settings ;;
            esac
            ;;
        *"Host Connection:"*)
            cat <<EOF > "$TMP_SUB"
Auto-Discovery [Local Wi-Fi Network]
Enter PC IP or Domain [Internet / Remote Play / Tailscale]
Clear Host IP
Back
EOF
            SUB_SEL=$("$SELECTOR" -i "$BG_IMG" -t "Host PC Connection Mode" -fs 125 -cf "$TMP_SUB" 2>/dev/null)
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
            cat <<EOF > "$TMP_SUB"
20 Mbps [Maximum Clarity / 5GHz Wi-Fi]
15 Mbps [High Clarity - Recommended]
12 Mbps [Standard]
8 Mbps [Balanced]
4 Mbps [Eco / Weak Wi-Fi]
Back
EOF
            SUB_SEL=$("$SELECTOR" -i "$BG_IMG" -t "Select Stream Bitrate Limit" -fs 125 -cf "$TMP_SUB" 2>/dev/null)
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
            cat <<EOF > "$TMP_SUB"
60 FPS [Ultra Smooth Gameplay]
30 FPS [Battery Saver Mode]
Back
EOF
            SUB_SEL=$("$SELECTOR" -i "$BG_IMG" -t "Select Stream Framerate Target" -fs 125 -cf "$TMP_SUB" 2>/dev/null)
            SUB_ACT=$(echo "$SUB_SEL" | sed 's/^.*: //')
            case "$SUB_ACT" in
                *"60 FPS"*) FPS="60"; save_settings ;;
                *"30 FPS"*) FPS="30"; save_settings ;;
            esac
            ;;
        *"Controller Mapping:"*)
            cat <<EOF > "$TMP_SUB"
Xbox Standard [A=Bottom, B=Right, X=Left, Y=Top - Standard PC]
Nintendo Layout [A=Right, B=Bottom, X=Top, Y=Left - TrimUI physical]
Back
EOF
            SUB_SEL=$("$SELECTOR" -i "$BG_IMG" -t "Select Controller Button Mapping" -fs 125 -cf "$TMP_SUB" 2>/dev/null)
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
        *"Connection Guide"*)
            show_info "HOW TO CONNECT STEAM LINK:\n\n1. SAME NETWORK (HOME WI-FI):\n   - Open Steam on PC\n   - Launch Steam Link on TrimUI\n   - Enter the 4-digit PIN in Steam on PC: Settings > Remote Play > Pair Steam Link.\n\n2. DIFFERENT NETWORK / INTERNET:\n   - Set 'Host Connection' to your PC IP or Tailscale IP\n   - Or enable Tailscale VPN from Apps menu for zero-config global mesh play anywhere!" 8
            ;;
        *">>> Launch Steam Link Now <<<"*)
            save_settings
            rm -f "$TMP_MAIN" "$TMP_SUB" 2>/dev/null
            exec "$CONF_DIR/launch.sh"
            exit 0
            ;;
        *"Exit"|*)
            save_settings
            rm -f "$TMP_MAIN" "$TMP_SUB" 2>/dev/null
            exit 0
            ;;
    esac
done
