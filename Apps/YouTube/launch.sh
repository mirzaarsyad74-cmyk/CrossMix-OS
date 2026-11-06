#!/bin/sh
# YouTube Main Handheld UI for TrimUI Smart Pro / CrossMix-OS
# Complete Gamepad-driven Ad-Free YouTube Browser & Player

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
PLAY_SH="$APP_DIR/play.sh"
SEARCH_PY="$APP_DIR/search.py"
SETTINGS_FILE="$APP_DIR/settings.conf"
SELECTOR="/mnt/SDCARD/System/bin/selector"
INFOSCREEN="/mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh"
VK="/mnt/SDCARD/System/bin/VirtualKeyboard"
PYTHON_BIN="/mnt/SDCARD/System/bin/python3.11"
BG_IMG="/mnt/SDCARD/System/usr/trimui/res/library_bg.png"
[ ! -f "$BG_IMG" ] && BG_IMG="/mnt/SDCARD/trimui/res/crossmix-os/bg-plain.png"

export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"
export PATH="/mnt/SDCARD/System/bin:$PATH"

# 1. Check Wi-Fi connection
IP=$(ip route get 1 2>/dev/null | awk '/src/ {print $NF; exit}')
if [ -z "$IP" ]; then
    [ -x "$INFOSCREEN" ] && "$INFOSCREEN" -m "Wi-Fi is not connected!\nPlease connect to Wi-Fi to watch YouTube." -t 4
    exit 1
fi

# 2. Trigger Network Booster for smooth streaming
if [ -f "/mnt/SDCARD/Apps/NetworkBooster/boost.sh" ]; then
    sh "/mnt/SDCARD/Apps/NetworkBooster/boost.sh" --silent >/dev/null 2>&1 &
fi

# 3. Load or initialize settings
[ -f "$SETTINGS_FILE" ] && . "$SETTINGS_FILE"
MAX_RES="${MAX_RES:-720}"
SPONSOR_BLOCK="${SPONSOR_BLOCK:-1}"

save_settings() {
    cat <<EOF > "$SETTINGS_FILE"
MAX_RES="$MAX_RES"
SPONSOR_BLOCK="$SPONSOR_BLOCK"
EOF
}

show_msg() {
    if [ -x "$INFOSCREEN" ]; then
        "$INFOSCREEN" -m "$1" -t "${2:-3}"
    else
        echo "$1"
    fi
}

# Main Application Menu Loop
while true; do
    case "$MAX_RES" in
        1080) Q_LBL="1080p FHD" ;;
        720)  Q_LBL="720p Native (Sharp)" ;;
        480)  Q_LBL="480p Balanced" ;;
        360)  Q_LBL="360p Data Saver" ;;
        audio) Q_LBL="Audio Only" ;;
        *)    Q_LBL="720p Native" ;;
    esac
    [ "$SPONSOR_BLOCK" = "1" ] && SB_LBL="Active (Auto-Skip)" || SB_LBL="Disabled"

    TITLE="YOUTUBE // AD-FREE HANDHELD // CrossMix-OS"
    MENU="Search YouTube (Keyboard)\n"
    MENU="${MENU}Trending: Gaming & Steam Deck\n"
    MENU="${MENU}Trending: Tech & Handheld Reviews\n"
    MENU="${MENU}Retro Gaming Longplays\n"
    MENU="${MENU}Enter Video URL or Video ID\n"
    MENU="${MENU}Playback Quality: $Q_LBL\n"
    MENU="${MENU}SponsorBlock: $SB_LBL\n"
    MENU="${MENU}Ad-Block Status: 100% Active (Zero Ads)\n"
    MENU="${MENU}Exit to Main Menu"

    if [ -x "$SELECTOR" ]; then
        SEL=$(echo -e "$MENU" | "$SELECTOR" -i "$BG_IMG" -t "$TITLE" -fs 125 2>/dev/null)
        ACTION=$(echo "$SEL" | sed 's/^.*: //')
    else
        ACTION="Exit to Main Menu"
    fi

    case "$ACTION" in
        *"Search YouTube"*)
            SEARCH_QUERY=""
            if [ -x "$VK" ]; then
                VK_RAW=$("$VK" -t "Search YouTube" 2>/dev/null)
                SEARCH_QUERY=$(echo "$VK_RAW" | grep -o '\[VKStart\].*\[VKEnd\]' | sed -e 's/\[VKStart\]//' -e 's/\[VKEnd\]//')
            fi
            if [ -n "$SEARCH_QUERY" ]; then
                show_msg "Searching YouTube for:\n'$SEARCH_QUERY'\nPlease wait 3 seconds..." 2
                RESULTS=$("$PYTHON_BIN" "$SEARCH_PY" "$SEARCH_QUERY" 10 2>/dev/null)
                if [ -n "$RESULTS" ]; then
                    RESULTS="${RESULTS}\nBack to Menu"
                    PICK=$(echo -e "$RESULTS" | "$SELECTOR" -i "$BG_IMG" -t "Search: $SEARCH_QUERY" -fs 110 2>/dev/null)
                    CHOICE=$(echo "$PICK" | sed 's/^.*: //')
                    if echo "$CHOICE" | grep -q "\[ID:"; then
                        VID_ID=$(echo "$CHOICE" | grep -o '\[ID:[^]]*\]' | sed 's/\[ID://' | sed 's/\]//')
                        [ -n "$VID_ID" ] && sh "$PLAY_SH" "$VID_ID"
                    fi
                else
                    show_msg "No results found for '$SEARCH_QUERY'." 2
                fi
            fi
            ;;
        *"Trending: Gaming"*)
            show_msg "Loading Gaming & Steam Deck Videos...\nPlease wait 3 seconds..." 2
            RESULTS=$("$PYTHON_BIN" "$SEARCH_PY" --gaming 10 2>/dev/null)
            if [ -n "$RESULTS" ]; then
                RESULTS="${RESULTS}\nBack to Menu"
                PICK=$(echo -e "$RESULTS" | "$SELECTOR" -i "$BG_IMG" -t "Gaming & Steam Deck Videos" -fs 110 2>/dev/null)
                CHOICE=$(echo "$PICK" | sed 's/^.*: //')
                if echo "$CHOICE" | grep -q "\[ID:"; then
                    VID_ID=$(echo "$CHOICE" | grep -o '\[ID:[^]]*\]' | sed 's/\[ID://' | sed 's/\]//')
                    [ -n "$VID_ID" ] && sh "$PLAY_SH" "$VID_ID"
                fi
            else
                show_msg "Failed to fetch videos. Check network connection." 2
            fi
            ;;
        *"Trending: Tech"*)
            show_msg "Loading Tech & Handheld Reviews...\nPlease wait 3 seconds..." 2
            RESULTS=$("$PYTHON_BIN" "$SEARCH_PY" --tech 10 2>/dev/null)
            if [ -n "$RESULTS" ]; then
                RESULTS="${RESULTS}\nBack to Menu"
                PICK=$(echo -e "$RESULTS" | "$SELECTOR" -i "$BG_IMG" -t "Tech & Handheld Reviews" -fs 110 2>/dev/null)
                CHOICE=$(echo "$PICK" | sed 's/^.*: //')
                if echo "$CHOICE" | grep -q "\[ID:"; then
                    VID_ID=$(echo "$CHOICE" | grep -o '\[ID:[^]]*\]' | sed 's/\[ID://' | sed 's/\]//')
                    [ -n "$VID_ID" ] && sh "$PLAY_SH" "$VID_ID"
                fi
            else
                show_msg "Failed to fetch videos. Check network connection." 2
            fi
            ;;
        *"Retro Gaming"*)
            show_msg "Loading Retro Gaming Longplays...\nPlease wait 3 seconds..." 2
            RESULTS=$("$PYTHON_BIN" "$SEARCH_PY" --retro 10 2>/dev/null)
            if [ -n "$RESULTS" ]; then
                RESULTS="${RESULTS}\nBack to Menu"
                PICK=$(echo -e "$RESULTS" | "$SELECTOR" -i "$BG_IMG" -t "Retro Gaming Longplays" -fs 110 2>/dev/null)
                CHOICE=$(echo "$PICK" | sed 's/^.*: //')
                if echo "$CHOICE" | grep -q "\[ID:"; then
                    VID_ID=$(echo "$CHOICE" | grep -o '\[ID:[^]]*\]' | sed 's/\[ID://' | sed 's/\]//')
                    [ -n "$VID_ID" ] && sh "$PLAY_SH" "$VID_ID"
                fi
            else
                show_msg "Failed to fetch videos. Check network connection." 2
            fi
            ;;
        *"Enter Video URL or Video ID"*)
            URL_INPUT=""
            if [ -x "$VK" ]; then
                VK_RAW=$("$VK" -t "Enter YouTube URL or Video ID" 2>/dev/null)
                URL_INPUT=$(echo "$VK_RAW" | grep -o '\[VKStart\].*\[VKEnd\]' | sed -e 's/\[VKStart\]//' -e 's/\[VKEnd\]//')
            fi
            if [ -n "$URL_INPUT" ]; then
                sh "$PLAY_SH" "$URL_INPUT"
            fi
            ;;
        *"Playback Quality:"*)
            Q_MENU="720p Native [Razor Sharp 1280x720 - RECOMMENDED]\n1080p FHD [1920x1080 High Def]\n480p Balanced [Low Bandwidth]\n360p Data Saver\nAudio Only [Music / Podcasts]\nBack"
            Q_PICK=$(echo -e "$Q_MENU" | "$SELECTOR" -i "$BG_IMG" -t "Select YouTube Playback Resolution" -fs 130 2>/dev/null)
            Q_CHOICE=$(echo "$Q_PICK" | sed 's/^.*: //')
            case "$Q_CHOICE" in
                *"720p"*)  MAX_RES="720"; save_settings ;;
                *"1080p"*) MAX_RES="1080"; save_settings ;;
                *"480p"*)  MAX_RES="480"; save_settings ;;
                *"360p"*)  MAX_RES="360"; save_settings ;;
                *"Audio"*) MAX_RES="audio"; save_settings ;;
            esac
            ;;
        *"SponsorBlock:"*)
            [ "$SPONSOR_BLOCK" = "1" ] && SPONSOR_BLOCK="0" || SPONSOR_BLOCK="1"
            save_settings
            ;;
        *"Ad-Block Status:"*)
            show_msg "YOUTUBE AD-BLOCK ENGINE:\n\nStatus: 100% ACTIVE\n\nDirect stream extraction completely bypasses and strips all YouTube advertisements (pre-roll, mid-roll, and overlay ads).\nEnjoy uninterrupted video playback!" 6
            ;;
        *"Exit"|*)
            exit 0
            ;;
    esac
done
