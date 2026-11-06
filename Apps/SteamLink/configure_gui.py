#!/usr/bin/env python3
"""
SteamOS Steam Link Settings Configurator GUI for TrimUI Smart Pro (1280x720)
Direct graphical configuration of streaming resolution, framerate, bitrate,
controller button mapping, battery saver, and remote connection over internet.
"""

import os
import sys
import time
import subprocess

# Ensure access to shared SteamOS GUI framework
sys.path.insert(0, "/mnt/SDCARD/System/usr/trimui/scripts")
sys.path.insert(0, "System/usr/trimui/scripts")

from steamos_gui import (
    SteamOSRenderer, DisplayEngine, Gamepad,
    COLOR_CYAN_FOCUS, COLOR_CYAN_GLOW, COLOR_CARD_SELECTED, COLOR_CARD_BG,
    COLOR_CARD_BORDER, COLOR_TEXT_PRIMARY, COLOR_TEXT_SECONDARY, COLOR_GREEN_ACCENT
)

APP_DIR = os.path.dirname(os.path.abspath(__file__))
SETTINGS_CONF = os.path.join(APP_DIR, "settings.conf")
DEV_JSON = os.path.join(APP_DIR, "device.json")
VK_BIN = "/mnt/SDCARD/System/bin/VirtualKeyboard"


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
                    if "=" in line:
                        k, v = line.strip().split("=", 1)
                        cfg[k.strip()] = v.strip('"\' ')
        except Exception:
            pass
    return cfg


def save_settings(cfg):
    try:
        with open(SETTINGS_CONF, "w", encoding="utf-8") as f:
            for k, v in cfg.items():
                f.write(f'{k}="{v}"\n')
    except Exception:
        pass


def run_virtual_keyboard(title="Enter Steam Host IP"):
    if os.path.exists(VK_BIN) and os.access(VK_BIN, os.X_OK):
        try:
            res = subprocess.run([VK_BIN, "-t", title], stdout=subprocess.PIPE, text=True)
            raw = res.stdout
            if "[VKStart]" in raw and "[VKEnd]" in raw:
                start = raw.find("[VKStart]") + len("[VKStart]")
                end = raw.find("[VKEnd]")
                return raw[start:end].strip()
        except Exception:
            pass
    return ""


def main():
    renderer = SteamOSRenderer()
    display = DisplayEngine()
    gamepad = Gamepad()

    cfg = load_settings()
    selected_idx = 0

    res_options = ["720", "1080", "480", "320"]
    fps_options = ["60", "30"]
    layout_options = ["xbox", "nintendo"]
    bitrate_options = ["10000", "15000", "20000", "30000", "5000"]

    while True:
        # Build live setting labels
        cur_res = cfg.get("RESOLUTION", "720")
        res_lbl = f"{cur_res}p (Native 1:1)" if cur_res == "720" else f"{cur_res}p"
        
        cur_fps = cfg.get("FPS", "60")
        fps_lbl = f"{cur_fps} FPS"

        cur_layout = cfg.get("LAYOUT", "xbox")
        layout_lbl = "Xbox (A=Bottom, B=Right)" if cur_layout == "xbox" else "Nintendo (A=Right, B=Bottom)"

        cur_btr = int(cfg.get("BITRATE_KBPS", "15000")) // 1000
        btr_lbl = f"{cur_btr} Mbps"

        sharp_lbl = "Razor Sharp (0 Blur)" if cfg.get("SHARP_MODE") == "1" else "Bilinear Filter"
        eco_lbl = "Enabled (Eco Mode)" if cfg.get("BATTERY_SAVER") == "1" else "Disabled (Max Performance)"

        host_val = cfg.get("CUSTOM_HOST", "")
        host_lbl = host_val if host_val else "Auto (Local Wi-Fi Discovery)"

        menu_items = [
            (f"Stream Resolution: {res_lbl}", "Cycle through 720p / 1080p / 480p / 320p", res_lbl),
            (f"Framerate Target: {fps_lbl}", "Switch between 60 FPS (Ultra Smooth) and 30 FPS", fps_lbl),
            (f"Controller Mapping: {layout_lbl}", "Swap A/B and X/Y button orientation", cur_layout.upper()),
            (f"Video Bitrate: {btr_lbl}", "Adjust bandwidth for connection quality", btr_lbl),
            (f"Image Sharpness: {sharp_lbl}", "Toggle pixel-perfect crispness vs smooth scaling", "SHARP" if cfg.get("SHARP_MODE") == "1" else "SMOOTH"),
            (f"Battery Saver: {eco_lbl}", "Underclock CPU to 1.0 GHz & turn off LED rings", "ECO" if cfg.get("BATTERY_SAVER") == "1" else "PERF"),
            (f"Custom Host IP: {host_lbl}", "Optional manual PC IP on local network (Leave empty for Auto)", "IP"),
            ("Clear Pairing Data (Repair Device)", "Delete device.json to pair with a new host PC", "RESET"),
            ("Save & Return to Steam Link Hub", "All changes are applied immediately", "SAVE")
        ]

        canvas, draw = renderer.create_canvas()
        renderer.draw_top_bar(draw, "STEAM SETTINGS", "CONFIGURATION & MAPPING")
        renderer.draw_menu_list(draw, menu_items, selected_idx, x=50, y=85, w=1180, h=555)
        renderer.draw_bottom_bar(draw, [
            ("A", "Cycle / Change Setting", True),
            ("B", "Save & Back", False)
        ])
        display.blit(canvas)

        btn = None
        while btn is None:
            btn = gamepad.poll()
            time.sleep(0.04)

        if btn == "UP":
            selected_idx = (selected_idx - 1) % len(menu_items)
        elif btn == "DOWN":
            selected_idx = (selected_idx + 1) % len(menu_items)
        elif btn == "B":
            save_settings(cfg)
            break
        elif btn == "A":
            if selected_idx == 0:  # Resolution
                i = res_options.index(cur_res) if cur_res in res_options else 0
                cfg["RESOLUTION"] = res_options[(i + 1) % len(res_options)]
            elif selected_idx == 1:  # FPS
                i = fps_options.index(cur_fps) if cur_fps in fps_options else 0
                cfg["FPS"] = fps_options[(i + 1) % len(fps_options)]
            elif selected_idx == 2:  # Layout
                i = layout_options.index(cur_layout) if cur_layout in layout_options else 0
                cfg["LAYOUT"] = layout_options[(i + 1) % len(layout_options)]
            elif selected_idx == 3:  # Bitrate
                btr_str = cfg.get("BITRATE_KBPS", "15000")
                i = bitrate_options.index(btr_str) if btr_str in bitrate_options else 0
                cfg["BITRATE_KBPS"] = bitrate_options[(i + 1) % len(bitrate_options)]
            elif selected_idx == 4:  # Sharpness
                cfg["SHARP_MODE"] = "0" if cfg.get("SHARP_MODE") == "1" else "1"
            elif selected_idx == 5:  # Battery Saver
                cfg["BATTERY_SAVER"] = "0" if cfg.get("BATTERY_SAVER") == "1" else "1"
            elif selected_idx == 6:  # Custom Host
                new_ip = run_virtual_keyboard("Enter PC IP or Hostname")
                if new_ip:
                    cfg["CUSTOM_HOST"] = new_ip
                else:
                    cfg["CUSTOM_HOST"] = ""
            elif selected_idx == 7:  # Clear Pairing
                if os.path.exists(DEV_JSON):
                    os.remove(DEV_JSON)
                # Quick confirmation toast
                canvas, draw = renderer.create_canvas()
                renderer.draw_top_bar(draw, "STEAM SETTINGS", "PAIRING RESET")
                draw.text((640, 360), "Pairing data cleared!\nSteam Link will enter 4-digit PIN mode on next start.", font=renderer.fonts.get(22, bold=True), fill=COLOR_GREEN_ACCENT, anchor="mm")
                display.blit(canvas)
                time.sleep(2)
            elif selected_idx == 8:  # Save & Return
                save_settings(cfg)
                break

    save_settings(cfg)
    gamepad.close()


if __name__ == "__main__":
    main()

