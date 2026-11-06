#!/bin/sh
# SteamOS Handheld OTA Updater Launcher
export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"
export PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts:$PATH"
export PYTHONPATH="/mnt/SDCARD/System/lib/python3.11:/mnt/SDCARD/System/lib/python3.11/site-packages:/mnt/SDCARD/System/usr/trimui/scripts:$PYTHONPATH"

# 1. Supercharge CPU to 1.6 GHz Performance Governor
echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null
echo 1608000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null

# 2. Disable Wi-Fi power saving (stops 802.11 sleep throttling completely)
command -v iw >/dev/null 2>&1 && iw dev wlan0 set power_save off 2>/dev/null
command -v iwconfig >/dev/null 2>&1 && iwconfig wlan0 power off 2>/dev/null

# 3. Kernel TCP window & buffer tuning for blazing downloads (16MB buffers)
sysctl -w net.core.rmem_max=16777216 2>/dev/null
sysctl -w net.core.wmem_max=16777216 2>/dev/null
sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216" 2>/dev/null
sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216" 2>/dev/null

# 4. Ensure Python standard library is ready
if [ ! -f "/mnt/SDCARD/System/lib/python3.11/os.py" ] && [ -f "/mnt/SDCARD/System/updates/update_001/python.zip" ]; then
    unzip -q -o -d "/mnt/SDCARD/System/" "/mnt/SDCARD/System/updates/update_001/python.zip" 2>/dev/null
fi

# 5. Auto-refresh updater scripts from GitHub if Wi-Fi is active
RAW_URL="https://raw.githubusercontent.com/mirzaarsyad74-cmyk/CrossMix-OS/main"
curl -k -s -m 5 "$RAW_URL/System/usr/trimui/scripts/ota_gui.py" -o "/mnt/SDCARD/System/usr/trimui/scripts/ota_gui.py.tmp" 2>/dev/null
if [ -s "/mnt/SDCARD/System/usr/trimui/scripts/ota_gui.py.tmp" ]; then
    mv -f "/mnt/SDCARD/System/usr/trimui/scripts/ota_gui.py.tmp" "/mnt/SDCARD/System/usr/trimui/scripts/ota_gui.py"
    chmod +x "/mnt/SDCARD/System/usr/trimui/scripts/ota_gui.py"
fi
curl -k -s -m 5 "$RAW_URL/System/usr/trimui/scripts/steamos_gui.py" -o "/mnt/SDCARD/System/usr/trimui/scripts/steamos_gui.py.tmp" 2>/dev/null
if [ -s "/mnt/SDCARD/System/usr/trimui/scripts/steamos_gui.py.tmp" ]; then
    mv -f "/mnt/SDCARD/System/usr/trimui/scripts/steamos_gui.py.tmp" "/mnt/SDCARD/System/usr/trimui/scripts/steamos_gui.py"
fi
curl -k -s -m 5 "$RAW_URL/Apps/OTA-update/launch.sh" -o "/mnt/SDCARD/Apps/OTA-update/launch.sh.tmp" 2>/dev/null
if [ -s "/mnt/SDCARD/Apps/OTA-update/launch.sh.tmp" ]; then
    mv -f "/mnt/SDCARD/Apps/OTA-update/launch.sh.tmp" "/mnt/SDCARD/Apps/OTA-update/launch.sh"
    chmod +x "/mnt/SDCARD/Apps/OTA-update/launch.sh"
fi

echo 1 >/tmp/stay_awake
if [ -x "/mnt/SDCARD/System/bin/python3.11" ]; then
    /mnt/SDCARD/System/bin/python3.11 /mnt/SDCARD/System/usr/trimui/scripts/ota_gui.py
else
    python3 /mnt/SDCARD/System/usr/trimui/scripts/ota_gui.py
fi
rm -f /tmp/stay_awake
exit 0
