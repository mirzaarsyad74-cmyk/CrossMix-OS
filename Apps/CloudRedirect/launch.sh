#!/bin/sh
cd "$(dirname "$0")"

CONFIG_FILE="./server_ip.txt"
[ ! -f "$CONFIG_FILE" ] && echo "192.168.1.100" > "$CONFIG_FILE"

IP=$(cat "$CONFIG_FILE" 2>/dev/null | tr -d '\r\n')

# Check if shellect is available
if [ -x "/mnt/SDCARD/System/usr/trimui/scripts/shellect.sh" ]; then
    CHOICE=$(echo -e "Steam Remote Play\nMoonlight Cloud Stream\nConfigure Host IP (Current: $IP)" | /mnt/SDCARD/System/usr/trimui/scripts/shellect.sh -t "CloudRedirect Stream Hub" -b "Press A to select streaming option.")
    
    case "$CHOICE" in
        "Steam Remote Play")
            exec /mnt/SDCARD/Apps/SteamLink/launch.sh
            ;;
        "Moonlight Cloud Stream")
            if [ -x "/usr/trimui/apps/moonlight/launch.sh" ]; then
                exec /usr/trimui/apps/moonlight/launch.sh
            else
                exec /mnt/SDCARD/Apps/SteamLink/launch.sh
            fi
            ;;
        "Configure Host IP"*)
            /mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh -m "Edit /mnt/SDCARD/Apps/CloudRedirect/server_ip.txt\nto configure your Cloud / PC streaming IP."
            sleep 4
            ;;
        *)
            exec /mnt/SDCARD/Apps/SteamLink/launch.sh
            ;;
    esac
else
    exec /mnt/SDCARD/Apps/SteamLink/launch.sh
fi
