#!/bin/sh

/mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh -m "Applying \"$(basename "$0" .sh)\" by default..."

json_file="/mnt/SDCARD/System/etc/crossmix.json"

if [ ! -f "$json_file" ]; then
    echo "{}" >"$json_file"
fi

/mnt/SDCARD/System/bin/jq '. += {"Tailscale": 0}' "$json_file" >"/tmp/json_file.tmp" && mv "/tmp/json_file.tmp" "$json_file"
sync

TAILSCALED="/mnt/SDCARD/System/bin/tailscaled"
TAILSCALE="/mnt/SDCARD/System/bin/tailscale"
[ -x "$TAILSCALE" ] && $TAILSCALE down 2>/dev/null
pkill -9 -f tailscaled 2>/dev/null
pkill -9 -f tailscale 2>/dev/null


# we modify the DB entries to reflect the current state
/mnt/SDCARD/System/usr/trimui/scripts/mainui_state_update.sh "Tailscale" "disabled"

sleep 0.1
