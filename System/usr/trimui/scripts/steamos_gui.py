#!/usr/bin/env python3
"""
SteamOS Handheld GUI Framework for TrimUI Smart Pro (1280x720)
Inspired by Valve Steam Deck Gaming Mode & DroidDeck UI.
Provides a unified, responsive, high-performance direct framebuffer GUI toolkit.
"""

import os
import sys
import time
import select
import struct
import subprocess
from PIL import Image, ImageDraw, ImageFont

# Screen dimensions
SCREEN_W = 1280
SCREEN_H = 720

# SteamOS / Steam Deck Color Palette
COLOR_STEAM_BG_TOP       = (14, 20, 27)       # #0e141b (Deep Steam Navy)
COLOR_STEAM_BG_BOTTOM    = (22, 32, 45)       # #16202d
COLOR_CARD_BG            = (18, 25, 36)       # #121924
COLOR_CARD_BORDER        = (32, 44, 62)       # #202c3e
COLOR_CARD_SELECTED      = (27, 40, 56)       # #1b2838 (Steam Highlight Navy)
COLOR_CYAN_FOCUS         = (26, 159, 255)     # #1a9fff (Steam Deck Electric Blue)
COLOR_CYAN_GLOW          = (0, 212, 255)      # #00d4ff
COLOR_TEXT_PRIMARY       = (240, 246, 252)    # #f0f6fc (Pure White)
COLOR_TEXT_SECONDARY     = (143, 152, 160)    # #8f98a0 (Steam Text Grey)
COLOR_TEXT_DIM           = (90, 100, 115)     # #5a6473
COLOR_GREEN_ACCENT       = (76, 217, 100)     # #4cd964 (Online Green)
COLOR_AMBER_ACCENT       = (255, 179, 0)      # #ffb300 (Warning)
COLOR_RED_ACCENT         = (255, 59, 48)      # #ff3b30 (Alert)


class FontResolver:
    """Finds available TTF fonts on TrimUI Smart Pro and host systems."""
    def __init__(self):
        self._cache = {}
        paths = [
            "/mnt/SDCARD/System/resources/DejaVuSans.ttf",
            "/mnt/SDCARD/Apps/Terminal/resources/Hack-Bold.ttf",
            "/mnt/SDCARD/Apps/Terminal/resources/Hack-Regular.ttf",
            "System/resources/DejaVuSans.ttf",
            "Apps/Terminal/resources/Hack-Bold.ttf",
            "Apps/Terminal/resources/Hack-Regular.ttf",
            "C:/Users/admin/Documents/CrossMix-OS/System/resources/DejaVuSans.ttf",
            "C:/Users/admin/Documents/CrossMix-OS/Apps/Terminal/resources/Hack-Bold.ttf",
            "C:/Users/admin/Documents/CrossMix-OS/Apps/Terminal/resources/Hack-Regular.ttf"
        ]
        self.primary = None
        self.bold = None
        for p in paths:
            if os.path.exists(p):
                if "Bold" in p and not self.bold:
                    self.bold = p
                elif not self.primary:
                    self.primary = p
        if not self.primary:
            self.primary = self.bold

    def get(self, size, bold=False):
        k = (size, bold)
        if k in self._cache:
            return self._cache[k]
        fn = self.bold if (bold and self.bold) else self.primary
        try:
            if fn and os.path.exists(fn):
                font = ImageFont.truetype(fn, size)
            else:
                font = ImageFont.load_default()
        except Exception:
            font = ImageFont.load_default()
        self._cache[k] = font
        return font


class DisplayEngine:
    """High-speed blitter that puts frames on the hardware LCD screen."""
    def __init__(self):
        self.pic2fb = "/mnt/SDCARD/System/bin/pic2fb"
        self.has_pic2fb = os.path.exists(self.pic2fb) and os.access(self.pic2fb, os.X_OK)
        self.fb0 = "/dev/fb0"
        self.has_fb0 = os.path.exists(self.fb0)
        self.tmp_png = "/tmp/steamos_frame.png"

    def blit(self, image):
        if self.has_pic2fb:
            try:
                image.save(self.tmp_png, "PNG", compress_level=1)
                subprocess.run([self.pic2fb, self.tmp_png], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                return True
            except Exception:
                pass
        if self.has_fb0:
            try:
                raw = image.convert("RGBA").tobytes()
                with open(self.fb0, "wb") as f:
                    f.write(raw)
                return True
            except Exception:
                pass
        return False


class Gamepad:
    """Robust non-blocking multi-device event listener for TrimUI Smart Pro controller."""
    def __init__(self):
        self.fds = []
        for i in range(8):
            node = f"/dev/input/event{i}"
            if os.path.exists(node):
                try:
                    fd = os.open(node, os.O_RDONLY | os.O_NONBLOCK)
                    self.fds.append(fd)
                except Exception:
                    pass

    def poll(self):
        """Returns single key event 'A', 'B', 'X', 'Y', 'UP', 'DOWN', 'LEFT', 'RIGHT', 'START', 'SELECT', 'MENU'."""
        if not self.fds:
            return None
        EVENT_SZ = 24
        try:
            readable, _, _ = select.select(self.fds, [], [], 0)
            for fd in readable:
                data = os.read(fd, EVENT_SZ * 16)
                for i in range(0, len(data), EVENT_SZ):
                    chunk = data[i:i + EVENT_SZ]
                    if len(chunk) < EVENT_SZ:
                        continue
                    _, _, ev_type, ev_code, ev_val = struct.unpack("qqHHi", chunk)
                    # EV_KEY (1)
                    if ev_type == 1 and ev_val == 1:
                        if ev_code in (305, 1): return "A"
                        if ev_code in (304, 2): return "B"
                        if ev_code in (307, 3): return "Y"
                        if ev_code in (308, 4): return "X"
                        if ev_code in (315, 297): return "START"
                        if ev_code in (314, 296): return "SELECT"
                        if ev_code in (316, 139): return "MENU"
                        if ev_code in (103, 544): return "UP"
                        if ev_code in (108, 545): return "DOWN"
                        if ev_code in (105, 546): return "LEFT"
                        if ev_code in (106, 547): return "RIGHT"
                    # EV_ABS (3)
                    elif ev_type == 3:
                        # D-Pad HAT (16/17) or Analog Y (1)
                        if ev_code in (17, 1):
                            if ev_val < -100 or ev_val == -1: return "UP"
                            elif ev_val > 100 or ev_val == 1: return "DOWN"
                        # D-Pad HAT (16) or Analog X (0)
                        elif ev_code in (16, 0):
                            if ev_val < -100 or ev_val == -1: return "LEFT"
                            elif ev_val > 100 or ev_val == 1: return "RIGHT"
        except Exception:
            pass
        return None

    def close(self):
        for fd in self.fds:
            try:
                os.close(fd)
            except Exception:
                pass
        self.fds.clear()


class SteamOSRenderer:
    """Generates Steam Deck / DroidDeck style 1280x720 graphical screens."""
    def __init__(self):
        self.fonts = FontResolver()

    def create_canvas(self):
        img = Image.new("RGB", (SCREEN_W, SCREEN_H), COLOR_STEAM_BG_TOP)
        draw = ImageDraw.Draw(img)
        # Vertical Steam Deck slate gradient
        for y in range(SCREEN_H):
            ratio = y / float(SCREEN_H)
            r = int(COLOR_STEAM_BG_TOP[0] * (1 - ratio) + COLOR_STEAM_BG_BOTTOM[0] * ratio)
            g = int(COLOR_STEAM_BG_TOP[1] * (1 - ratio) + COLOR_STEAM_BG_BOTTOM[1] * ratio)
            b = int(COLOR_STEAM_BG_TOP[2] * (1 - ratio) + COLOR_STEAM_BG_BOTTOM[2] * ratio)
            draw.line([(0, y), (SCREEN_W, y)], fill=(r, g, b))
        return img, draw

    def draw_top_bar(self, draw, title="STEAM DECK", subtitle=""):
        """Draws official Steam Deck Top Bar: Steam Deck logo, view title, clock, battery, wifi."""
        # Horizontal subtle divider line
        draw.line([(0, 60), (SCREEN_W, 60)], fill=COLOR_CARD_BORDER, width=1)
        draw.line([(30, 60), (320, 60)], fill=COLOR_CYAN_FOCUS, width=2)

        # Steam Deck circular logo glyph
        cx, cy = 52, 30
        draw.ellipse([cx - 14, cy - 14, cx + 14, cy + 14], outline=COLOR_CYAN_FOCUS, width=2)
        draw.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=COLOR_CYAN_FOCUS)

        # Title
        font_brand = self.fonts.get(20, bold=True)
        draw.text((80, 20), "STEAM", font=font_brand, fill=COLOR_TEXT_PRIMARY)
        if subtitle:
            font_sub = self.fonts.get(14, bold=False)
            draw.text((155, 23), f"// {subtitle}", font=font_sub, fill=COLOR_CYAN_FOCUS)

        # Right status cluster: Wi-Fi, Battery, Clock
        font_status = self.fonts.get(13, bold=True)
        cur_time = time.strftime("%I:%M %p")
        
        # Wi-Fi icon dot
        draw.ellipse([1080, 26, 1090, 36], fill=COLOR_GREEN_ACCENT)
        draw.text((1100, 22), "WI-FI", font=font_status, fill=COLOR_TEXT_SECONDARY)

        # Clock
        draw.text((1170, 22), cur_time, font=font_status, fill=COLOR_TEXT_PRIMARY)

    def draw_bottom_bar(self, draw, buttons):
        """Draws Steam Deck bottom pill legend: buttons is list of (btn_letter, label, is_primary)."""
        draw.line([(0, 660), (SCREEN_W, 660)], fill=COLOR_CARD_BORDER, width=1)
        font_glyph = self.fonts.get(13, bold=True)
        font_lbl = self.fonts.get(13, bold=False)

        x = 40
        y = 672
        for btn, label, primary in buttons:
            lbl_w = int(draw.textlength(label, font=font_lbl))
            pill_w = 34 + lbl_w + 14
            pill_h = 30

            bg_col = (20, 60, 95) if primary else (24, 32, 44)
            border_col = COLOR_CYAN_FOCUS if primary else (40, 52, 70)
            draw.rounded_rectangle([x, y, x + pill_w, y + pill_h], radius=15, fill=bg_col, outline=border_col, width=1)

            # Circle glyph
            c_fill = COLOR_CYAN_FOCUS if primary else (60, 75, 95)
            c_text = (10, 15, 25) if primary else COLOR_TEXT_PRIMARY
            draw.ellipse([x + 5, y + 4, x + 25, y + 24], fill=c_fill)
            draw.text((x + 10, y + 5), btn, font=font_glyph, fill=c_text)

            draw.text((x + 31, y + 7), label, font=font_lbl, fill=COLOR_TEXT_PRIMARY)
            x += pill_w + 16

    def draw_menu_list(self, draw, items, selected_idx, x=50, y=85, w=1180, h=555):
        """Renders an interactive Steam Deck menu with glowing cyan focus."""
        item_h = 62
        visible_count = min(len(items), h // (item_h + 8))
        
        # Scroll offset calculation
        start_idx = 0
        if selected_idx >= visible_count:
            start_idx = selected_idx - visible_count + 1

        draw_y = y
        for i in range(start_idx, min(len(items), start_idx + visible_count)):
            title, desc, badge = items[i]
            is_sel = (i == selected_idx)

            card_box = [x, draw_y, x + w, draw_y + item_h]
            if is_sel:
                # Glowing Steam Deck Cyan Card Focus
                draw.rounded_rectangle(card_box, radius=12, fill=COLOR_CARD_SELECTED, outline=COLOR_CYAN_FOCUS, width=2)
                # Left focus indicator pill
                draw.rounded_rectangle([x + 4, draw_y + 12, x + 10, draw_y + item_h - 12], radius=3, fill=COLOR_CYAN_FOCUS)
                title_col = COLOR_TEXT_PRIMARY
                desc_col = COLOR_CYAN_GLOW
            else:
                draw.rounded_rectangle(card_box, radius=12, fill=COLOR_CARD_BG, outline=COLOR_CARD_BORDER, width=1)
                title_col = COLOR_TEXT_PRIMARY
                desc_col = COLOR_TEXT_SECONDARY

            # Text inside item
            font_title = self.fonts.get(18, bold=True)
            font_desc = self.fonts.get(13, bold=False)
            draw.text((x + 28, draw_y + 11), title, font=font_title, fill=title_col)
            draw.text((x + 28, draw_y + 35), desc, font=font_desc, fill=desc_col)

            # Badge on right
            if badge:
                font_badge = self.fonts.get(12, bold=True)
                bw = int(draw.textlength(badge, font=font_badge)) + 18
                bx = x + w - bw - 20
                by = draw_y + (item_h - 26) // 2
                badge_bg = (10, 80, 120) if is_sel else (30, 42, 58)
                draw.rounded_rectangle([bx, by, bx + bw, by + 26], radius=13, fill=badge_bg, outline=COLOR_CYAN_FOCUS if is_sel else COLOR_CARD_BORDER, width=1)
                draw.text((bx + 9, by + 5), badge, font=font_badge, fill=COLOR_TEXT_PRIMARY)

            draw_y += item_h + 8

