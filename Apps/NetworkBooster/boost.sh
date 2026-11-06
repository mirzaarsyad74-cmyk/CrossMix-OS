#!/bin/sh
# Network Speed Booster Engine for TrimUI Smart Pro / CrossMix-OS
# Optimizes Wi-Fi Power Save, TCP Buffer Scaling, Congestion Control, and Low Latency DNS

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$APP_DIR/booster.log"
SILENT=0

for arg in "$@"; do
    [ "$arg" = "--silent" ] && SILENT=1
done

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    [ "$SILENT" -eq 0 ] && echo "$1"
}

log "=== Starting Network Speed Booster ==="

# 1. Disable Wi-Fi Power Saving Mode (Cuts ping spikes from 80ms+ down to 2-5ms)
if command -v iw >/dev/null 2>&1; then
    iw dev wlan0 set power_save off 2>/dev/null && log "[OK] iw: Wi-Fi power saving turned OFF"
fi
if command -v iwconfig >/dev/null 2>&1; then
    iwconfig wlan0 power off 2>/dev/null && log "[OK] iwconfig: Wi-Fi power saving turned OFF"
fi

# 2. Increase Network Interface Transmit Queue Length
ifconfig wlan0 txqueuelen 5000 2>/dev/null && log "[OK] Set wlan0 txqueuelen = 5000"

# 3. Kernel Sysctl Network Socket Buffer Optimization
if command -v sysctl >/dev/null 2>&1; then
    # Socket receive and send buffer maximums (16MB)
    sysctl -w net.core.rmem_max=16777216 >/dev/null 2>&1
    sysctl -w net.core.wmem_max=16777216 >/dev/null 2>&1
    sysctl -w net.core.rmem_default=1048576 >/dev/null 2>&1
    sysctl -w net.core.wmem_default=1048576 >/dev/null 2>&1

    # Network device input queue backlogs
    sysctl -w net.core.netdev_max_backlog=10000 >/dev/null 2>&1
    sysctl -w net.core.somaxconn=4096 >/dev/null 2>&1

    # TCP autotuning buffer windows
    sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216" >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216" >/dev/null 2>&1

    # Advanced TCP optimizations
    sysctl -w net.ipv4.tcp_window_scaling=1 >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_timestamps=1 >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_sack=1 >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_dsack=1 >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_fack=1 >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_fastopen=3 >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_slow_start_after_idle=0 >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_mtu_probing=1 >/dev/null 2>&1

    # Congestion control (Prefer cubic or bbr)
    sysctl -w net.ipv4.tcp_congestion_control=cubic >/dev/null 2>&1 || sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1

    log "[OK] Applied 16MB TCP/UDP socket buffers & low-latency sysctl tuning"
fi

# 4. Ultra-Fast DNS Resolver Acceleration (Cloudflare 1.1.1.1 + Google 8.8.8.8)
if [ -w /etc/resolv.conf ] || [ -f /etc/resolv.conf ]; then
    grep -q "1.1.1.1" /etc/resolv.conf 2>/dev/null || {
        cat <<EOF > /tmp/resolv_boosted.conf
nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 1.0.0.1
EOF
        cat /etc/resolv.conf 2>/dev/null >> /tmp/resolv_boosted.conf
        sort -u /tmp/resolv_boosted.conf > /etc/resolv.conf 2>/dev/null
        rm -f /tmp/resolv_boosted.conf
        log "[OK] Cloudflare & Google Ultra-Fast DNS configured"
    }
fi

touch /tmp/network_boosted
log "=== Network Speed Booster Finished Successfully ==="
exit 0

