#!/bin/sh
export PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts:$PATH"
export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"
source /mnt/SDCARD/System/usr/trimui/scripts/update_common.sh

INFOSCREEN="/mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh"
OTA_BG="/mnt/SDCARD/System/usr/trimui/res/ota_update_bg.png"

run_bootstrap() {
    curl -k -s "https://raw.githubusercontent.com/$GITHUB_REPOSITORY/main/_assets/scripts/ota_bootstrap.sh" | sh
}

main() {
    # Check internet connection
    if ! wget -q --spider https://github.com >/dev/null 2>&1; then
        if [ -x "$INFOSCREEN" ]; then
            $INFOSCREEN -i "$OTA_BG" -m "No Internet Connection!\nPlease connect to Wi-Fi to use OTA Updater." -k "A B" -t 4
        fi
        exit 2
    fi

    # Run bootstrap to fetch latest scripts
    run_bootstrap >/dev/null 2>&1

    mkdir -p "$updatedir"
    echo -e "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n\n" >>"$updatedir/ota_release.log"
    echo -e "${timestamp}\n" >>"$updatedir/ota_release.log"
    /mnt/SDCARD/System/usr/trimui/scripts/update_ota_release.sh 2>&1 | tee -a "$updatedir/ota_release.log"

    # Clean up any stray background imgshow or terminal
    pkill -f sdl2imgshow 2>/dev/null
    killall -2 SimpleTerminal 2>/dev/null
}

main "$@"
