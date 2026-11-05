#!/bin/sh
# CrossMix-OS Fast Charging & Animation Manager (AXP2202 PMIC)

USB_ONLINE="/sys/class/power_supply/axp2202-usb/online"
USB_CUR_MAX="/sys/class/power_supply/axp2202-usb/current_max"
BAT_CHG_MAX="/sys/class/power_supply/axp2202-battery/constant_charge_current_max"
BAT_TEMP="/sys/class/power_supply/axp2202-battery/temp"
BAT_CAP="/sys/class/power_supply/axp2202-battery/capacity"

OSD_MSG="/mnt/SDCARD/System/usr/trimui/osd/show_fast_charge_msg.sh"
LED_DIR="/sys/class/led_anim"

TARGET_CURRENT=2000000 # 2.0A Fast Charge (10W)
SAFE_CURRENT=1200000   # 1.2A Safe Fallback

WAS_CHARGING=0
THROTTLED=0

play_fast_charge_led_anim() {
    if [ -d "$LED_DIR" ]; then
        chmod a+w "$LED_DIR"/* 2>/dev/null
        echo 1 > "$LED_DIR/effect_enable" 2>/dev/null
        echo "00E5FF" > "$LED_DIR/effect_rgb_hex_lr" 2>/dev/null # Electric Cyan
        echo 8 > "$LED_DIR/effect_cycles_lr" 2>/dev/null
        echo 250 > "$LED_DIR/effect_duration_lr" 2>/dev/null     # Rapid pulse
        echo 2 > "$LED_DIR/effect_lr" 2>/dev/null                # Breathing animation
    fi
}

restore_normal_led() {
    if [ -x "/mnt/SDCARD/System/etc/led_config.sh" ]; then
        /mnt/SDCARD/System/etc/led_config.sh &
    elif [ -d "$LED_DIR" ]; then
        echo 0 > "$LED_DIR/effect_enable" 2>/dev/null
    fi
}

while true; do
    if [ -f "$USB_ONLINE" ]; then
        IS_CHARGING=$(cat "$USB_ONLINE" 2>/dev/null || echo 0)
    else
        IS_CHARGING=0
    fi

    if [ "$IS_CHARGING" = "1" ]; then
        # Just plugged in
        if [ "$WAS_CHARGING" = "0" ]; then
            WAS_CHARGING=1
            THROTTLED=0
            
            # Unlock 2.0A charging limit on AXP2202 PMIC
            [ -w "$USB_CUR_MAX" ] && echo "$TARGET_CURRENT" > "$USB_CUR_MAX" 2>/dev/null
            [ -w "$BAT_CHG_MAX" ] && echo "$TARGET_CURRENT" > "$BAT_CHG_MAX" 2>/dev/null

            CAP=$(cat "$BAT_CAP" 2>/dev/null || echo "")
            
            # Show animated Electric Cyan OSD Banner
            [ -x "$OSD_MSG" ] && "$OSD_MSG" "⚡ FAST CHARGE: 2.0A (10W)" "$CAP"
            
            # Trigger stick LED pulse animation
            play_fast_charge_led_anim
        else
            # Continuous thermal protection check while charging
            CUR_TEMP=$(cat "$BAT_TEMP" 2>/dev/null || echo 0)
            
            # If battery temp exceeds 43 C, throttle back to 1.2A to protect cell
            if [ "$CUR_TEMP" -gt 430 ] && [ "$THROTTLED" = "0" ]; then
                THROTTLED=1
                [ -w "$USB_CUR_MAX" ] && echo "$SAFE_CURRENT" > "$USB_CUR_MAX" 2>/dev/null
                [ -w "$BAT_CHG_MAX" ] && echo "$SAFE_CURRENT" > "$BAT_CHG_MAX" 2>/dev/null
                
                CAP=$(cat "$BAT_CAP" 2>/dev/null || echo "")
                [ -x "$OSD_MSG" ] && "$OSD_MSG" "⚠️ THERMAL PROTECT: 1.2A" "$CAP"
            fi
        fi
    else
        # Just unplugged
        if [ "$WAS_CHARGING" = "1" ]; then
            WAS_CHARGING=0
            THROTTLED=0
            restore_normal_led
        fi
    fi

    sleep 3
done

