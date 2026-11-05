#!/bin/sh

MSG="${1:-⚡ FAST CHARGING: 2.0A (10W)}"
PCT="${2}"

[ -n "$PCT" ] && FULL_MSG="$MSG - ${PCT}%" || FULL_MSG="$MSG"

VOL_MSG_JSON="\n\
{ \n\
    \"type\":\"chargeron\", \n\
    \"id\":\"com.trimui.osd.msg.fastcharge\", \n\
    \"duration\":2500, \n\
    \"size\":0, \n\
    \"x\":440, \n\
    \"y\":560, \n\
    \"w\":400, \n\
    \"h\":80, \n\
    \"message\":\" $FULL_MSG\", \n\
    \"font\":\"\", \n\
    \"bg\":\"\", \n\
    \"icon\":\"\", \n\
    \"fontsize\":22, \n\
    \"fontcolor\":\"00E5FFFF\" \n\
} \n"

if [ -w "/tmp/trimui_osd/osd_toast_ms2" ]; then
    echo -e "$VOL_MSG_JSON" > /tmp/trimui_osd/osd_toast_ms2
elif [ -e "/tmp/trimui_osd/osd_toast_ms2" ]; then
    echo -e "$VOL_MSG_JSON" > /tmp/trimui_osd/osd_toast_ms2
fi

