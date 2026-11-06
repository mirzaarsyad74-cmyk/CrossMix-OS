#!/usr/bin/env python3
"""
SteamOS YouTube Handheld GUI for TrimUI Smart Pro (1280x720)
Direct graphical video browser & ad-free player launcher.
"""

import os
import sys
import time
import subprocess
import json
import traceback

# Ensure access to shared libraries and SteamOS GUI framework
for p in [
    "/mnt/SDCARD/System/lib/python3.11/site-packages",
    "/mnt/SDCARD/System/lib/python3.11",
    "/mnt/SDCARD/System/usr/trimui/scripts",
    "System/usr/trimui/scripts"
]:
    if os.path.exists(p) and p not in sys.path:
        sys.path.insert(0, p)

from steamos_gui import SteamOSRenderer, DisplayEngine, Gamepad, COLOR_CYAN_FOCUS, COLOR_CARD_SELECTED, COLOR_CARD_BG, COLOR_CARD_BORDER, COLOR_TEXT_PRIMARY, COLOR_TEXT_SECONDARY, COLOR_GREEN_ACCENT

APP_DIR = os.path.dirname(os.path.abspath(__file__))
SETTINGS_CONF = os.path.join(APP_DIR, "settings.conf")
PLAY_SH = os.path.join(APP_DIR, "play.sh")
SEARCH_PY = os.path.join(APP_DIR, "search.py")
VK_BIN = "/mnt/SDCARD/System/bin/VirtualKeyboard"


def load_settings():
    res = "720"
    sponsor = "1"
    if os.path.exists(SETTINGS_CONF):
        try:
            with open(SETTINGS_CONF, "r", encoding="utf-8") as f:
                for line in f:
                    if line.startswith("MAX_RES="):
                        res = line.strip().split("=")[1].strip('"\'')
                    elif line.startswith("SPONSOR_BLOCK="):
                        sponsor = line.strip().split("=")[1].strip('"\'')
        except Exception:
            pass
    return res, sponsor


def save_settings(res, sponsor):
    try:
        with open(SETTINGS_CONF, "w", encoding="utf-8") as f:
            f.write(f'MAX_RES="{res}"\n')
            f.write(f'SPONSOR_BLOCK="{sponsor}"\n')
    except Exception:
        pass


def run_virtual_keyboard(title="Search YouTube"):
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

    max_res, sponsor = load_settings()
    res_modes = ["720", "1080", "480", "360"]
    selected_idx = 0

    while True:
        res_label = f"{max_res}p HD"
        sb_label = "Auto-Skip Sponsors" if sponsor == "1" else "Disabled"

        menu_items = [
            ("Search YouTube (Virtual Keyboard)", "Type any game, video title, or channel", "SEARCH"),
            ("Trending: Gaming & Steam Deck", "Latest handheld and PC gaming highlights", "HOT"),
            ("Retro Gaming Longplays", "Full playthroughs of classic retro console games", "RETRO"),
            ("Tech & Handheld Hardware Reviews", "TrimUI Smart Pro, Steam Deck, & ROG Ally", "TECH"),
            (f"Streaming Quality: {res_label}", "Press [A] to cycle 720p / 1080p / 480p / 360p", res_label),
            (f"SponsorBlock: {sb_label}", "Press [A] to toggle automatic in-video sponsor skip", "AD-FREE"),
            ("Exit to SteamOS Main Menu", "Return to game launcher", "EXIT")
        ]

        canvas, draw = renderer.create_canvas()
        renderer.draw_top_bar(draw, "YOUTUBE", "AD-FREE HANDHELD PLAYER")
        renderer.draw_menu_list(draw, menu_items, selected_idx, x=50, y=85, w=1180, h=555)
        renderer.draw_bottom_bar(draw, [
            ("A", "Select / Open", True),
            ("B", "Exit to Menu", False),
            ("Y", "Quick Search", False)
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
            break
        elif btn == "Y":
            # Quick search shortcut
            q = run_virtual_keyboard("Search YouTube")
            if q:
                play_search_flow(renderer, display, gamepad, q)
        elif btn == "A":
            if selected_idx == 0:  # Search
                q = run_virtual_keyboard("Search YouTube")
                if q:
                    play_search_flow(renderer, display, gamepad, q)
            elif selected_idx == 1:  # Trending Gaming
                play_search_flow(renderer, display, gamepad, "Steam Deck Gaming Highlights")
            elif selected_idx == 2:  # Retro Longplays
                play_search_flow(renderer, display, gamepad, "Retro Gaming Longplay Full Game")
            elif selected_idx == 3:  # Tech Reviews
                play_search_flow(renderer, display, gamepad, "Trimui Smart Pro Handheld Review")
            elif selected_idx == 4:  # Toggle Quality
                curr_idx = res_modes.index(max_res) if max_res in res_modes else 0
                max_res = res_modes[(curr_idx + 1) % len(res_modes)]
                save_settings(max_res, sponsor)
            elif selected_idx == 5:  # Toggle SponsorBlock
                sponsor = "0" if sponsor == "1" else "1"
                save_settings(max_res, sponsor)
            elif selected_idx == 6:  # Exit
                break

    gamepad.close()


def play_search_flow(renderer, display, gamepad, query):
    """Executes YouTube query and displays graphical results list."""
    canvas, draw = renderer.create_canvas()
    renderer.draw_top_bar(draw, "YOUTUBE", f"SEARCH: {query.upper()}")

    # Loading screen
    cx, cy, cw, ch = 200, 180, 880, 360
    draw.rounded_rectangle([cx, cy, cx + cw, cy + ch], radius=16, fill=COLOR_CARD_BG, outline=COLOR_CARD_BORDER, width=2)
    draw.line([cx + 30, cy, cx + 180, cy], fill=COLOR_CYAN_FOCUS, width=3)

    font_t = renderer.fonts.get(24, bold=True)
    font_s = renderer.fonts.get(16, bold=False)
    draw.text((cx + cw // 2, cy + 130), f"Searching YouTube for '{query}'...", font=font_t, fill=COLOR_TEXT_PRIMARY, anchor="mm")
    draw.text((cx + cw // 2, cy + 180), "Fetching ad-free video streams from YouTube CDN...", font=font_s, fill=COLOR_TEXT_SECONDARY, anchor="mm")
    display.blit(canvas)

    # Call search.py
    results = []
    try:
        res = subprocess.run([sys.executable, SEARCH_PY, query, "8"], stdout=subprocess.PIPE, text=True, timeout=12)
        for line in res.stdout.splitlines():
            line = line.strip()
            if line:
                # Format: "Title (Channel) [VIDEO_ID]" or "Title [VIDEO_ID]"
                if "[" in line and "]" in line:
                    vid_id = line[line.rfind("[") + 1:line.rfind("]")]
                    title = line[:line.rfind("[")].strip()
                    results.append((title, f"Video ID: {vid_id}", vid_id))
    except Exception:
        pass

    if not results:
        # Fallback presets if offline or blocked
        results = [
            (f"Search on YouTube: {query}", "Streams live search query", query),
            ("Cancel & Back to Menu", "Return to YouTube Home", "CANCEL")
        ]

    # Present Video Results List
    res_idx = 0
    while True:
        canvas, draw = renderer.create_canvas()
        renderer.draw_top_bar(draw, "YOUTUBE", f"RESULTS FOR: {query.upper()}")
        
        items = [(t, d, "PLAY" if v != "CANCEL" else "BACK") for (t, d, v) in results]
        renderer.draw_menu_list(draw, items, res_idx, x=50, y=85, w=1180, h=555)
        renderer.draw_bottom_bar(draw, [
            ("A", "Play Fullscreen Video", True),
            ("B", "Back to Search Menu", False)
        ])
        display.blit(canvas)

        btn = None
        while btn is None:
            btn = gamepad.poll()
            time.sleep(0.04)

        if btn == "UP":
            res_idx = (res_idx - 1) % len(results)
        elif btn == "DOWN":
            res_idx = (res_idx + 1) % len(results)
        elif btn == "B":
            break
        elif btn == "A":
            target_vid = results[res_idx][2]
            if target_vid == "CANCEL":
                break

            # Launch player
            canvas, draw = renderer.create_canvas()
            renderer.draw_top_bar(draw, "YOUTUBE", "STARTING PLAYBACK")
            draw.text((640, 360), "Launching MPV Hardware Video Player...\nPress MENU to exit during playback.", font=renderer.fonts.get(24, bold=True), fill=COLOR_CYAN_FOCUS, anchor="mm")
            display.blit(canvas)

            # Release gamepad before starting player
            gamepad.close()
            # Invoke play.sh
            subprocess.run([PLAY_SH, target_vid])
            break


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log_file = os.path.join(APP_DIR, "youtube.log")
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(f"\n[Crash at {time.ctime()}]: {e}\n")
            traceback.print_exc(file=f)
        try:
            r = SteamOSRenderer()
            d = DisplayEngine()
            canvas, draw = r.create_canvas()
            r.draw_top_bar(draw, "YOUTUBE", "ERROR ALERT")
            draw.text((640, 360), f"YouTube Encountered an Error:\n{e}\nLogged to {log_file}", font=r.fonts.get(20, bold=True), fill=(255, 75, 75), anchor="mm")
            d.blit(canvas)
            time.sleep(4)
        except Exception:
            pass

