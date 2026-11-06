#!/usr/bin/env python3
"""
SteamOS Steam Link Handheld Hub GUI for TrimUI Smart Pro (1280x720)
Direct graphical remote play launcher, pairing guide, and host diagnostic hub.
"""

import os
import sys
import time
import subprocess
import json

# Ensure access to shared SteamOS GUI framework
sys.path.insert(0, "/mnt/SDCARD/System/usr/trimui/scripts")
sys.path.insert(0, "System/usr/trimui/scripts")

from steamos_gui import (
    SteamOSRenderer, DisplayEngine, Gamepad,
    COLOR_CYAN_FOCUS, COLOR_CYAN_GLOW, COLOR_CARD_SELECTED, COLOR_CARD_BG,
    COLOR_CARD_BORDER, COLOR_TEXT_PRIMARY, COLOR_TEXT_SECONDARY, COLOR_TEXT_DIM,
    COLOR_GREEN_ACCENT, COLOR_AMBER_ACCENT
)

APP_DIR = os.path.dirname(os.path.abspath(__file__))
DEV_JSON = os.path.join(APP_DIR, "device.json")
SETTINGS_CONF = os.path.join(APP_DIR, "settings.conf")
CONFIGURE_GUI = os.path.join(APP_DIR, "configure_gui.py")
LAUNCH_SH = os.path.join(APP_DIR, "launch.sh")
BOOST_SH = "/mnt/SDCARD/Apps/NetworkBooster/launch.sh"


def get_ip_address():
    try:
        res = subprocess.run(["ip", "route", "get", "1"], stdout=subprocess.PIPE, text=True, timeout=2)
        for part in res.stdout.split():
            if "." in part and len(part.split(".")) == 4:
                return part
    except Exception:
        pass
    return "192.168.1.100"


def check_pairing():
    """Checks if valid device.json exists with secret."""
    if os.path.exists(DEV_JSON):
        try:
            with open(DEV_JSON, "r", encoding="utf-8") as f:
                data = json.load(f)
                secret = data.get("secret", "")
                steamid = data.get("steamid", 0)
                if secret and steamid != 0:
                    return True, data
        except Exception:
            pass
    return False, {}


def load_settings():
    cfg = {
        "RESOLUTION": "720",
        "FPS": "60",
        "LAYOUT": "xbox",
        "BATTERY_SAVER": "0",
        "BITRATE_KBPS": "15000",
        "CUSTOM_HOST": ""
    }
    if os.path.exists(SETTINGS_CONF):
        try:
            with open(SETTINGS_CONF, "r", encoding="utf-8") as f:
                for line in f:
                    if "=" in line:
                        k, v = line.strip().split("=", 1)
                        cfg[k.strip()] = v.strip('"\' ')
        except Exception:
            pass
    return cfg


def main():
    renderer = SteamOSRenderer()
    display = DisplayEngine()
    gamepad = Gamepad()

    while True:
        is_paired, dev_data = check_pairing()
        cfg = load_settings()
        local_ip = get_ip_address()

        canvas, draw = renderer.create_canvas()
        renderer.draw_top_bar(draw, "STEAM LINK", "REMOTE PLAY GAMING HUB")

        # Two main panels: Left = Host & Connection, Right = Stream Profile
        lx, ly, lw, lh = 50, 85, 570, 560
        rx, ry, rw, rh = 650, 85, 580, 560

        draw.rounded_rectangle([lx, ly, lx + lw, ly + lh], radius=16, fill=COLOR_CARD_BG, outline=COLOR_CARD_BORDER, width=2)
        draw.line([lx + 30, ly, lx + 200, ly], fill=COLOR_CYAN_FOCUS, width=3)

        draw.rounded_rectangle([rx, ry, rx + rw, ry + rh], radius=16, fill=COLOR_CARD_BG, outline=COLOR_CARD_BORDER, width=2)
        draw.line([rx + 30, ry, rx + 200, ry], fill=COLOR_GREEN_ACCENT, width=3)

        # Left Panel: Host Information & Status
        font_badge = renderer.fonts.get(12, bold=True)
        font_big = renderer.fonts.get(26, bold=True)
        font_lbl = renderer.fonts.get(14, bold=False)
        font_val = renderer.fonts.get(16, bold=True)

        draw.text((lx + 30, ly + 25), "CONNECTION STATUS", font=font_badge, fill=COLOR_CYAN_FOCUS)
        
        if is_paired:
            host_name = dev_data.get("device_name", "Host PC")
            draw.text((lx + 30, ly + 52), host_name, font=font_big, fill=COLOR_TEXT_PRIMARY)
            status_text = "PAIRED & READY TO STREAM"
            status_col = COLOR_GREEN_ACCENT
        else:
            draw.text((lx + 30, ly + 52), "No Host Paired Yet", font=font_big, fill=COLOR_AMBER_ACCENT)
            status_text = "FIRST-TIME PAIRING REQUIRED"
            status_col = COLOR_AMBER_ACCENT

        # Status badge
        draw.rounded_rectangle([lx + 30, ly + 95, lx + 320, ly + 125], radius=15, fill=(15, 35, 45) if is_paired else (45, 30, 10), outline=status_col, width=1)
        draw.text((lx + 45, ly + 102), f"● {status_text}", font=font_badge, fill=status_col)

        # Connection Guidance Box
        guide_box = [lx + 25, ly + 145, lx + lw - 25, ly + lh - 25]
        draw.rounded_rectangle(guide_box, radius=12, fill=(11, 15, 23), outline=(26, 36, 52), width=1)

        draw.text((lx + 45, ly + 165), "HOW TO CONNECT:", font=font_badge, fill=COLOR_CYAN_FOCUS)

        steps = [
            ("1. Local Network", "Ensure PC & TrimUI are on the same Wi-Fi."),
            ("2. PC Steam Client", "In Steam: Settings > Remote Play > Enable."),
            ("3. Pairing PIN", "Click 'Pair Steam Link' on PC & enter 4-digit PIN."),
            ("4. Remote Over Internet", "Set Custom Host in Settings to play outside home!")
        ]

        sy = ly + 200
        for title, desc in steps:
            draw.text((lx + 45, sy), f"► {title}", font=renderer.fonts.get(14, bold=True), fill=COLOR_TEXT_PRIMARY)
            draw.text((lx + 65, sy + 22), desc, font=renderer.fonts.get(12, bold=False), fill=COLOR_TEXT_SECONDARY)
            sy += 58

        draw.text((lx + 45, ly + lh - 48), f"Handheld IP: {local_ip}", font=renderer.fonts.get(12, bold=False), fill=COLOR_TEXT_DIM)

        # Right Panel: Active Stream Profile
        draw.text((rx + 30, ry + 25), "STREAMING PROFILE", font=font_badge, fill=COLOR_GREEN_ACCENT)
        draw.text((rx + 30, ry + 52), "Hardware Configuration", font=font_big, fill=COLOR_TEXT_PRIMARY)

        res_str = f"{cfg.get('RESOLUTION', '720')}p 60 FPS (Native Sharp)"
        layout_str = "Xbox Standard (ABXY)" if cfg.get("LAYOUT") == "xbox" else "Nintendo Physical (BAYX)"
        bitrate_str = f"{int(cfg.get('BITRATE_KBPS', '15000')) // 1000} Mbps (Ultra-Low Latency)"
        eco_str = "Performance (1.6 GHz)" if cfg.get("BATTERY_SAVER") == "0" else "Eco Mode (1.0 GHz)"

        profile_rows = [
            ("Display Resolution", res_str, COLOR_CYAN_FOCUS),
            ("Controller Mapping", layout_str, COLOR_TEXT_PRIMARY),
            ("Target Bitrate", bitrate_str, COLOR_TEXT_PRIMARY),
            ("Audio Stream", "Stereo Low-Latency", COLOR_TEXT_PRIMARY),
            ("SoC Governor", eco_str, COLOR_GREEN_ACCENT),
            ("Display Filter", "Razor Sharp (0 Blur)", COLOR_TEXT_PRIMARY),
        ]

        py = ry + 115
        for lbl, val, val_col in profile_rows:
            draw.line([rx + 30, py, rx + rw - 30, py], fill=(24, 32, 46), width=1)
            draw.text((rx + 30, py + 14), lbl, font=font_lbl, fill=COLOR_TEXT_SECONDARY)
            draw.text((rx + rw - 30, py + 12), val, font=font_val, fill=val_col, anchor="ra")
            py += 62

        # Bottom Actions
        renderer.draw_bottom_bar(draw, [
            ("A", "Launch Remote Play", True),
            ("X", "Steam Settings", False),
            ("Y", "Network Booster", False),
            ("B", "Exit", False)
        ])
        display.blit(canvas)

        btn = None
        while btn is None:
            btn = gamepad.poll()
            time.sleep(0.04)

        if btn == "B":
            break
        elif btn == "X":
            # Open Steam Settings GUI
            subprocess.run([sys.executable, CONFIGURE_GUI])
        elif btn == "Y":
            # Open Network Booster
            if os.path.exists(BOOST_SH):
                subprocess.run([BOOST_SH])
        elif btn == "A":
            # Launch Steam Link Client
            canvas, draw = renderer.create_canvas()
            renderer.draw_top_bar(draw, "STEAM LINK", "STARTING STREAM")
            draw.text((640, 360), "Connecting to Steam Remote Play...\nPress MENU to disconnect.", font=renderer.fonts.get(24, bold=True), fill=COLOR_CYAN_FOCUS, anchor="mm")
            display.blit(canvas)

            # Release gamepad input descriptors before launching exclusive SDL2 engine
            gamepad.close()
            subprocess.run([LAUNCH_SH])
            break

    gamepad.close()


if __name__ == "__main__":
    main()

