#!/bin/sh
export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:/mnt/SDCARD/Apps/PortMaster/PortMaster:$LD_LIBRARY_PATH"
export PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts:$PATH"

echo 1 >/tmp/stay_awake
/mnt/SDCARD/System/usr/trimui/scripts/ota_update.sh
rm -f /tmp/stay_awake
