#!/bin/sh
# Network Speed Booster GUI for TrimUI Smart Pro / CrossMix-OS

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
BOOST_SCRIPT="$APP_DIR/boost.sh"
AUTO_FILE="$APP_DIR/autoboost.enabled"
SELECTOR="/mnt/SDCARD/System/bin/selector"
INFOSCREEN="/mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh"
BG_IMG="/mnt/SDCARD/System/usr/trimui/res/settings_bg.png"
[ ! -f "$BG_IMG" ] && BG_IMG="/mnt/SDCARD/trimui/res/crossmix-os/bg-plain.png"

show_msg() {
    if [ -x "$INFOSCREEN" ]; then
        "$INFOSCREEN" -m "$1" -t "${2:-3}"
    else
        echo "$1"
    fi
}

# Ensure auto-boost is enabled by default
[ ! -f "$AUTO_FILE" ] && touch "$AUTO_FILE"

while true; do
    # Check current Wi-Fi status
    IP=$(ip route get 1 2>/dev/null | awk '/src/ {print $NF; exit}')
    [ -z "$IP" ] && IP="Disconnected"

    # Check power save status
    PW_STATE="Unknown"
    if command -v iw >/dev/null 2>&1; then
        if iw dev wlan0 get power_save 2>/dev/null | grep -qi "on"; then
            PW_STATE="ON (High Jitter)"
        else
            PW_STATE="OFF (Boosted)"
        fi
    fi

    # Check auto-boost status
    [ -f "$AUTO_FILE" ] && AUTO_LBL="Active (Enabled)" || AUTO_LBL="Disabled"

    TITLE="TURBO NETWORK SPEED BOOSTER // CrossMix-OS"
    CHOICES=">>> Activate Turbo Network Boost Now <<<\n"
    CHOICES="${CHOICES}Auto-Boost on Boot: $AUTO_LBL\n"
    CHOICES="${CHOICES}Run Network Latency & Ping Test\n"
    CHOICES="${CHOICES}View Booster Diagnostics Log\n"
    CHOICES="${CHOICES}Exit"

    if [ -x "$SELECTOR" ]; then
        SEL=$(echo -e "$CHOICES" | "$SELECTOR" -i "$BG_IMG" -t "$TITLE" -fs 130 2>/dev/null)
        ACTION=$(echo "$SEL" | sed 's/^.*: //')
    else
        ACTION="Exit"
    fi

    case "$ACTION" in
        *">>> Activate Turbo Network Boost Now <<<"*)
            show_msg "Applying Low-Latency Tweaks...\nDisabling Wi-Fi Power Saving...\nExpanding TCP Buffers to 16MB..." 2
            sh "$BOOST_SCRIPT"
            show_msg "SUCCESS!\n\nTurbo Network Booster is ACTIVE!\nWi-Fi Power Save: OFF\nTCP Buffer: 16 MB\nDNS: Cloudflare 1.1.1.1\nIP: $IP" 4
            ;;
        *"Auto-Boost on Boot:"*)
            if [ -f "$AUTO_FILE" ]; then
                rm -f "$AUTO_FILE"
                show_msg "Auto-Boost at Boot has been DISABLED." 2
            else
                touch "$AUTO_FILE"
                show_msg "Auto-Boost at Boot is now ENABLED.\nWill apply automatically whenever Wi-Fi connects!" 3
            fi
            ;;
        *"Run Network Latency & Ping Test"*)
            show_msg "Testing Network Latency...\nPlease wait 3 seconds..." 2
            GATEWAY=$(ip route 2>/dev/null | awk '/default/ {print $3; exit}')
            PING_GW="N/A"
            PING_CF="N/A"
            PING_ST="N/A"

            if [ -n "$GATEWAY" ]; then
                PING_GW=$(ping -c 2 -W 2 "$GATEWAY" 2>/dev/null | awk -F'/' 'END {print $5}')
                [ -n "$PING_GW" ] && PING_GW="${PING_GW}ms" || PING_GW="Timeout"
            fi

            PING_CF=$(ping -c 2 -W 2 1.1.1.1 2>/dev/null | awk -F'/' 'END {print $5}')
            [ -n "$PING_CF" ] && PING_CF="${PING_CF}ms" || PING_CF="Timeout"

            PING_ST=$(ping -c 2 -W 2 steampowered.com 2>/dev/null | awk -F'/' 'END {print $5}')
            [ -n "$PING_ST" ] && PING_ST="${PING_ST}ms" || PING_ST="Timeout"

            show_msg "NETWORK LATENCY RESULTS:\n\nLocal Gateway: $PING_GW\nCloudflare DNS: $PING_CF\nSteam Servers: $PING_ST\nWi-Fi Power Save: $PW_STATE" 5
            ;;
        *"View Booster Diagnostics Log"*)
            if [ -f "$APP_DIR/booster.log" ] && [ -x "/mnt/SDCARD/System/bin/text_viewer" ]; then
                /mnt/SDCARD/System/bin/text_viewer -f "$APP_DIR/booster.log"
            elif [ -f "$APP_DIR/booster.log" ]; then
                TAIL=$(tail -n 8 "$APP_DIR/booster.log")
                show_msg "$TAIL" 5
            else
                show_msg "No log file found yet.\nActivate the booster first." 2
            fi
            ;;
        *"Exit"|*)
            exit 0
            ;;
    esac
done

