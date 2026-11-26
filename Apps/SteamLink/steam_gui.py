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

# Ensure access to shared libraries and SteamOS GUI framework
for _p in (
    "/mnt/SDCARD/System/lib/python3.11/site-packages",
    "/mnt/SDCARD/System/lib/python3.11",
    "/mnt/SDCARD/System/usr/trimui/scripts",
    "System/usr/trimui/scripts",
):
    if os.path.exists(_p) and _p not in sys.path:
        sys.path.insert(0, _p)

from steamos_gui import (
    SteamOSRenderer, DisplayEngine, Gamepad,
    COLOR_CYAN_FOCUS, COLOR_CARD_BG,
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
        res = subprocess.run(["ip", "route", "get", "1"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=2)
        for part in res.stdout.split():
            if "." in part and len(part.split(".")) == 4:
                return part
    except Exception:
        pass
    return "Not Connected"


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
        "SHARP_MODE": "1",
        "BITRATE_KBPS": "15000",
        "CUSTOM_HOST": ""
    }
    if os.path.exists(SETTINGS_CONF):
        try:
            with open(SETTINGS_CONF, "r", encoding="utf-8") as f:
                for line in f:
                    if "=" in line and not line.strip().startswith("#"):
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
        renderer.draw_top_bar(draw, "STEAM LINK", "LOCAL WI-FI REMOTE PLAY")

        # Two main panels: Left = Host & Connection, Right = Stream Profile
        lx, ly, lw, lh = 50, 85, 570, 560
        rx, ry, rw, rh = 650, 85, 580, 560

        draw.rounded_rectangle([lx, ly, lx + lw, ly + lh], radius=16, fill=COLOR_CARD_BG, outline=COLOR_CARD_BORDER, width=2)
        draw.line([lx + 30, ly, lx + 200, ly], fill=COLOR_CYAN_FOCUS, width=3)

        draw.rounded_rectangle([rx, ry, rx + rw, ry + rh], radius=16, fill=COLOR_CARD_BG, outline=COLOR_CARD_BORDER, width=2)
        draw.line([rx + 30, ry, rx + 200, ry], fill=COLOR_GREEN_ACCENT, width=3)

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

        draw.rounded_rectangle([lx + 30, ly + 95, lx + 320, ly + 125], radius=15, fill=(15, 35, 45) if is_paired else (45, 30, 10), outline=status_col, width=1)
        draw.text((lx + 45, ly + 102), f"● {status_text}", font=font_badge, fill=status_col)

        guide_box = [lx + 25, ly + 145, lx + lw - 25, ly + lh - 25]
        draw.rounded_rectangle(guide_box, radius=12, fill=(11, 15, 23), outline=(26, 36, 52), width=1)

        draw.text((lx + 45, ly + 165), "HOW TO CONNECT (SAME WI-FI):", font=font_badge, fill=COLOR_CYAN_FOCUS)

        steps = [
            ("1. Same Wi-Fi Network", "Connect both PC and TrimUI to the same router."),
            ("2. Enable PC Remote Play", "On PC Steam: Settings > Remote Play > Enable."),
            ("3. Pair with 4-Digit PIN", "Press [Y] to show PIN, enter on PC Steam Settings."),
            ("4. Customize Stream", "Press [X] to change Resolution, FPS, & Layout.")
        ]

        sy = ly + 200
        for title, desc in steps:
            draw.text((lx + 45, sy), f"► {title}", font=renderer.fonts.get(14, bold=True), fill=COLOR_TEXT_PRIMARY)
            draw.text((lx + 65, sy + 22), desc, font=renderer.fonts.get(12, bold=False), fill=COLOR_TEXT_SECONDARY)
            sy += 58

        draw.text((lx + 45, ly + lh - 48), f"Handheld LAN IP: {local_ip}", font=renderer.fonts.get(12, bold=False), fill=COLOR_TEXT_DIM)

        # Right Panel: Active Stream Profile (dynamically reflects user settings)
        draw.text((rx + 30, ry + 25), "STREAMING PROFILE", font=font_badge, fill=COLOR_GREEN_ACCENT)
        draw.text((rx + 30, ry + 52), "Hardware Configuration", font=font_big, fill=COLOR_TEXT_PRIMARY)

        is_eco = (cfg.get("BATTERY_SAVER", "0") == "1")
        eff_res = "480" if (is_eco and cfg.get("RESOLUTION", "720") in ("720", "1080", "auto")) else cfg.get("RESOLUTION", "720")
        eff_fps = "30" if is_eco else cfg.get("FPS", "60")
        is_sharp = (cfg.get("SHARP_MODE", "1") == "1")
        sharp_str = "Razor Sharp (0 Blur)" if is_sharp else "Smooth Bilinear"
        res_str = f"{eff_res}p @ {eff_fps} FPS"
        layout_str = "Xbox Standard (ABXY)" if cfg.get("LAYOUT", "xbox") == "xbox" else "Nintendo Physical (BAYX)"
        try:
            btr_mbps = int(cfg.get("BITRATE_KBPS", "15000")) // 1000
        except Exception:
            btr_mbps = 15
        if is_eco and btr_mbps > 4:
            btr_mbps = 3
        bitrate_str = f"{btr_mbps} Mbps (Low Latency)"
        eco_str = "Eco Mode (1.0 GHz)" if is_eco else "Performance (1.6 GHz)"

        profile_rows = [
            ("Display Target", res_str, COLOR_CYAN_FOCUS),
            ("Controller Mapping", layout_str, COLOR_TEXT_PRIMARY),
            ("Target Bitrate", bitrate_str, COLOR_TEXT_PRIMARY),
            ("Audio Stream", "Stereo Low-Latency", COLOR_TEXT_PRIMARY),
            ("SoC Governor", eco_str, COLOR_AMBER_ACCENT if is_eco else COLOR_GREEN_ACCENT),
            ("Display Filter", sharp_str, COLOR_TEXT_PRIMARY),
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
            ("Y", "Pair New PC", False),
            ("X", "Settings", False),
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
            gamepad.close()
            subprocess.run([sys.executable, CONFIGURE_GUI])
            gamepad.reopen()
        elif btn == "START":
            if os.path.exists(BOOST_SH):
                gamepad.close()
                subprocess.run([BOOST_SH])
                gamepad.reopen()
        elif btn == "Y":
            if os.path.exists(DEV_JSON):
                try:
                    os.remove(DEV_JSON)
                except Exception:
                    pass
            canvas, draw = renderer.create_canvas()
            renderer.draw_top_bar(draw, "STEAM LINK", "PAIRING WITH PC")
            draw.text((640, 360), "Connecting in Pairing Mode...\nLook for the 4-digit PIN on this screen!", font=renderer.fonts.get(22, bold=True), fill=COLOR_CYAN_FOCUS, anchor="mm")
            display.blit(canvas)
            gamepad.close()
            subprocess.run([LAUNCH_SH, "--pair"])
            break
        elif btn == "A":
            canvas, draw = renderer.create_canvas()
            renderer.draw_top_bar(draw, "STEAM LINK", "STARTING STREAM")
            draw.text((640, 360), "Connecting to Steam Remote Play...\nHold SELECT + START to disconnect.", font=renderer.fonts.get(24, bold=True), fill=COLOR_CYAN_FOCUS, anchor="mm")
            display.blit(canvas)

            gamepad.close()
            subprocess.run([LAUNCH_SH])
            break

    gamepad.close()


if __name__ == "__main__":
    main()
