#!/bin/sh
export PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts:$PATH"
export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"
source /mnt/SDCARD/System/usr/trimui/scripts/update_common.sh

INFOSCREEN="/mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh"
OTA_BG="/mnt/SDCARD/System/usr/trimui/res/ota_update_bg.png"
SELECTOR="/mnt/SDCARD/System/bin/selector"

cmd=$1

# channel : stable or beta
channel=$(cat "$updatedir/ota_channel.txt" 2>/dev/null)
if [ "$channel" = "" ]; then
    channel="stable"
fi

main() {
    check_connection

    if [ "$cmd" = "check" ]; then
        IP=$(ip route get 1 2>/dev/null | awk '{print $NF;exit}')
        if [ "$IP" != "" ]; then
            get_release_info
            if [ $? -eq 0 ]; then
                exit 0
            fi
        fi
        exit 1
    fi

    rm -f /tmp/cmd_to_run.sh 2>/dev/null

    get_release_info
    if [ $? -eq 1 ]; then
        if [ -x "$INFOSCREEN" ]; then
            $INFOSCREEN -i "$OTA_BG" -m "Your system is up to date!\nInstalled: v$Local_CrossMixVersion" -k "A B" -t 4
        fi
        echo "no release" >/tmp/ota_release_result
        exit 0
    else
        touch "$updatedir/.CrossMixUpdateAvailable"
        sync
    fi

    if [ -f "$updatedir/CrossMix-OS_v$Release_Version.zip" ] || [ -f "/mnt/SDCARD/CrossMix-OS_v$Release_Version.zip" ]; then
        if [ ! -f "$updatedir/CrossMix-OS_v$Release_Version.zip" ] && [ -f "/mnt/SDCARD/CrossMix-OS_v$Release_Version.zip" ]; then
            mv "/mnt/SDCARD/CrossMix-OS_v$Release_Version.zip" "$updatedir/"
        fi
        check_update
        if [ $? -eq 1 ]; then
            download_update
        fi
    else
        download_update
        check_update
    fi

    apply_update
}

get_release_info() {
    Release_assets_info=$(curl -k -s "https://api.github.com/repos/$GITHUB_REPOSITORY/releases/latest")

    if echo "$Release_assets_info" | grep -q '"message": "Not Found"'; then
        rm -f "$updatedir/.CrossMixUpdateAvailable" 2>/dev/null
        return 1
    fi

    Release_asset=$(echo "$Release_assets_info" | jq '.assets[]? | select(.name | contains("CrossMix-OS_v"))')
    Release_url=$(echo "$Release_asset" | jq -r '.browser_download_url')
    Release_FullVersion=$(echo "$Release_asset" | jq -r '.name' | sed 's/^CrossMix-OS_v//g' | sed 's/\.zip$//g')
    Release_Version=$(echo "$Release_FullVersion" | sed 's/-dev.*$//g')
    Release_size=$(echo "$Release_asset" | jq -r '.size')
    Release_size_MB=$((Release_size / 1024 / 1024))
    Release_Date=$(echo "$Release_asset" | jq -r '.created_at')

    Local_CrossMixVersion="$(cat /mnt/SDCARD/System/usr/trimui/crossmix-version.txt 2>/dev/null)"
    Local_Version=$(echo "$Local_CrossMixVersion" | sed 's/-dev.*$//g')

    num_Local_Version=$(get_version "$Local_Version")
    num_Remote_Version=$(get_version "$Release_Version")

    if [ "$num_Local_Version" -gt "$num_Remote_Version" ] || ([ "$num_Local_Version" -eq "$num_Remote_Version" ] && [ "$Local_CrossMixVersion" = "$Release_FullVersion" ]); then
        rm -f "$updatedir/.CrossMixUpdateAvailable" 2>/dev/null
        return 1
    fi

    touch "$updatedir/.CrossMixUpdateAvailable"
    sync
    return 0
}

download_update() {
    local selected_action=""
    if [ -x "$SELECTOR" ]; then
        eval "choice=\$($SELECTOR -i \"$OTA_BG\" -t \"CrossMix-OS v$Release_Version ($Release_size_MB MB) Available!\" -fs 140 -c \"Download & Install Update\" \"Cancel\")"
        selected_action=$(printf '%s\n' "$choice" | sed 's/^.*: //')
    else
        selected_action="Download & Install Update"
    fi

    if [ "$selected_action" != "Download & Install Update" ]; then
        if [ -x "$INFOSCREEN" ]; then
            $INFOSCREEN -i "$OTA_BG" -m "Update canceled." -t 2
        fi
        echo "user cancel" >/tmp/ota_release_result
        exit 0
    fi

    check_available_space "$(($Release_size_MB + 500))"
    if [ $? -eq 1 ]; then
        if [ -x "$INFOSCREEN" ]; then
            $INFOSCREEN -i "$OTA_BG" -m "Error: Not enough storage space!\nPlease free up at least $(($Release_size_MB + 500)) MB." -k "A B" -t 4
        fi
        exit 3
    fi

    check_filesystem
    rm -f "$updatedir/CrossMix-OS_v$Release_Version.zip"

    download_file "$Release_url" -f "$updatedir/CrossMix-OS_v$Release_Version.zip" -t "CrossMix-OS v$Release_Version"
    if [ $? -ne 0 ] || [ ! -f "$updatedir/CrossMix-OS_v$Release_Version.zip" ]; then
        if [ -x "$INFOSCREEN" ]; then
            $INFOSCREEN -i "$OTA_BG" -m "Download failed!\nPlease check your internet connection." -k "A B" -t 4
        fi
        echo "download failed" >/tmp/ota_release_result
        exit 1
    fi
}

check_update() {
    Downloaded_size=$(stat -c %s "$updatedir/CrossMix-OS_v$Release_Version.zip" 2>/dev/null)
    if [ "$Downloaded_size" -eq "$Release_size" ]; then
        return 0
    else
        rm -f "$updatedir/CrossMix-OS_v$Release_Version.zip"
        return 1
    fi
}

apply_update() {
    local selected_action=""
    if [ -x "$SELECTOR" ]; then
        eval "choice=\$($SELECTOR -i \"$OTA_BG\" -t \"CrossMix-OS v$Release_Version Downloaded!\" -fs 140 -c \"Apply Update & Reboot\" \"Cancel\")"
        selected_action=$(printf '%s\n' "$choice" | sed 's/^.*: //')
    else
        selected_action="Apply Update & Reboot"
    fi

    if [ "$selected_action" = "Apply Update & Reboot" ]; then
        UpdateScript="https://raw.githubusercontent.com/$GITHUB_REPOSITORY/refs/tags/v$Release_Version/System/usr/trimui/scripts/crossmix_update.sh"
        DownloadPath="/mnt/SDCARD/System/usr/trimui/scripts/crossmix_update.sh"

        download_file "$UpdateScript" -f "$DownloadPath" -t "Update Script"
        chmod +x "$DownloadPath" 2>/dev/null

        if [ -x "$INFOSCREEN" ]; then
            $INFOSCREEN -i "$OTA_BG" -m "Update applied!\nRebooting to run installation..." -t 4 &
        fi

        mv "$updatedir/CrossMix-OS_v$Release_Version.zip" "/mnt/SDCARD/"
        echo "success" >/tmp/ota_release_result
        sync
        sleep 4
        reboot
    else
        if [ -x "$INFOSCREEN" ]; then
            $INFOSCREEN -i "$OTA_BG" -m "Applying update canceled." -t 2
        fi
        echo "user cancel" >/tmp/ota_release_result
        exit 0
    fi
}

get_version() { echo "$@" | tr -d '[:alpha:]' | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }

main "$@"
