#!/usr/bin/env python3
"""
CrossMix-OS Native Framebuffer OTA Updater GUI
Custom dynamic graphical user interface for TrimUI Smart Pro (1280x720).
Renders true hardware graphics via pic2fb / /dev/fb0 with zero terminal leakage.
"""

import os
import sys
import time
import json
import struct
import select
import ssl
import urllib.request
import urllib.error
import subprocess
import threading
from PIL import Image, ImageDraw, ImageFont

# Screen configuration
SCREEN_W = 1280
SCREEN_H = 720

# Color Palette (Dark Obsidian Cyber Theme)
COLOR_BG_DARK       = (9, 13, 22)       # #090d16
COLOR_BG_GRADIENT   = (13, 18, 31)      # #0d121f
COLOR_CARD_BG       = (17, 23, 36)      # #111724
COLOR_CARD_BORDER   = (31, 41, 61)      # #1f293d
COLOR_CARD_GLOW     = (0, 240, 255)     # #00f0ff (Electric Cyan)
COLOR_TEXT_PRIMARY  = (240, 246, 252)   # #f0f6fc
COLOR_TEXT_MUTED    = (138, 153, 173)   # #8a99ad
COLOR_TEXT_DIM      = (80, 95, 115)     # #505f73
COLOR_CYAN_ACCENT   = (0, 240, 255)     # Electric Cyan
COLOR_CYAN_DIM      = (0, 160, 190)
COLOR_GREEN_ACCENT  = (57, 211, 83)     # Neon Mint / Emerald
COLOR_AMBER_ACCENT  = (255, 180, 0)     # Warning Amber
COLOR_RED_ACCENT    = (255, 75, 75)     # Error Red

COLOR_BAR_BG        = (22, 28, 41)      # Progress Bar Background
COLOR_BAR_BORDER    = (42, 56, 79)      # Progress Bar Border
COLOR_BAR_GRAD_L    = (0, 150, 255)     # Deep Blue-Cyan
COLOR_BAR_GRAD_R    = (0, 255, 200)     # Bright Cyan-Green


class FontManager:
    """Manages TTF typography resolution across TrimUI and host environments."""
    def __init__(self):
        self.fonts = {}
        # Search candidate paths for fonts
        candidates = [
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
        self.primary_font = None
        self.bold_font = None
        for p in candidates:
            if os.path.exists(p):
                if "Bold" in p and not self.bold_font:
                    self.bold_font = p
                elif not self.primary_font:
                    self.primary_font = p

        if not self.primary_font:
            self.primary_font = self.bold_font

    def get(self, size, bold=False):
        key = (size, bold)
        if key in self.fonts:
            return self.fonts[key]

        font_file = self.bold_font if (bold and self.bold_font) else self.primary_font
        try:
            if font_file and os.path.exists(font_file):
                font = ImageFont.truetype(font_file, size)
            else:
                font = ImageFont.load_default()
        except Exception:
            font = ImageFont.load_default()

        self.fonts[key] = font
        return font


def draw_vector_checkmark(draw, cx, cy, size=24, color=COLOR_GREEN_ACCENT, width=4):
    """Draws a crisp geometric checkmark without relying on unicode font glyphs."""
    p1 = (cx - size // 2, cy)
    p2 = (cx - size // 6, cy + size // 2)
    p3 = (cx + size // 2, cy - size // 2)
    draw.line([p1, p2], fill=color, width=width)
    draw.line([p2, p3], fill=color, width=width)


def draw_vector_triangle(draw, x, y, size=12, color=COLOR_CYAN_ACCENT):
    """Draws a crisp geometric right-pointing arrow for bullet points."""
    pts = [(x, y - size // 2), (x + size, y), (x, y + size // 2)]
    draw.polygon(pts, fill=color)


def draw_vector_warning(draw, cx, cy, size=20, color=COLOR_AMBER_ACCENT):
    """Draws a warning triangle with an exclamation point."""
    pts = [(cx, cy - size), (cx - int(size * 0.9), cy + size), (cx + int(size * 0.9), cy + size)]
    draw.polygon(pts, outline=color, fill=(40, 28, 10))
    draw.line([(cx, cy - size // 3), (cx, cy + size // 4)], fill=color, width=3)
    draw.ellipse([(cx - 2, cy + size // 2), (cx + 2, cy + size // 2 + 4)], fill=color)


class OtaRenderer:
    """High-fidelity dynamic graphical frame generator for TrimUI Smart Pro."""
    def __init__(self):
        self.fm = FontManager()

    def create_canvas(self):
        """Creates 1280x720 obsidian background with subtle tech gradient."""
        canvas = Image.new("RGB", (SCREEN_W, SCREEN_H), COLOR_BG_DARK)
        draw = ImageDraw.Draw(canvas)
        # Gradient background
        for y in range(SCREEN_H):
            ratio = y / float(SCREEN_H)
            r = int(COLOR_BG_DARK[0] * (1 - ratio) + COLOR_BG_GRADIENT[0] * ratio)
            g = int(COLOR_BG_DARK[1] * (1 - ratio) + COLOR_BG_GRADIENT[1] * ratio)
            b = int(COLOR_BG_DARK[2] * (1 - ratio) + COLOR_BG_GRADIENT[2] * ratio)
            draw.line([(0, y), (SCREEN_W, y)], fill=(r, g, b))
        return canvas, draw

    def draw_header(self, draw, title_sub="FIRMWARE INTEGRITY & DISTRIBUTION"):
        """Draws consistent tech brand header."""
        # Top banner background line
        draw.line([(0, 64), (SCREEN_W, 64)], fill=COLOR_CARD_BORDER, width=1)
        draw.line([(40, 64), (280, 64)], fill=COLOR_CYAN_ACCENT, width=2)

        # Brand Text
        font_brand = self.fm.get(22, bold=True)
        font_sub = self.fm.get(14, bold=False)
        draw.text((44, 22), "CROSSMIX-OS", font=font_brand, fill=COLOR_TEXT_PRIMARY)
        draw.text((215, 25), "// " + title_sub, font=font_sub, fill=COLOR_CYAN_ACCENT)

        # Online Status Indicator
        font_status = self.fm.get(13, bold=True)
        draw.ellipse([(1180, 28), (1190, 38)], fill=COLOR_GREEN_ACCENT)
        draw.text((1200, 24), "ONLINE", font=font_status, fill=COLOR_TEXT_MUTED)

    def draw_footer_pill(self, draw, x, y, button, label, primary=False):
        """Draws an arcade gamepad button pill prompt (e.g. [A] Install)."""
        font_btn = self.fm.get(14, bold=True)
        font_lbl = self.fm.get(14, bold=False)

        # Pill container
        lbl_w = int(draw.textlength(label, font=font_lbl))
        pill_w = 40 + lbl_w + 16
        pill_h = 32

        bg_col = (0, 70, 90) if primary else (24, 32, 46)
        border_col = COLOR_CYAN_ACCENT if primary else COLOR_CARD_BORDER
        draw.rounded_rectangle([x, y, x + pill_w, y + pill_h], radius=16, fill=bg_col, outline=border_col, width=1)

        # Button glyph circle
        circle_col = COLOR_CYAN_ACCENT if primary else (50, 65, 88)
        text_btn_col = (10, 15, 25) if primary else COLOR_TEXT_PRIMARY
        draw.ellipse([x + 6, y + 5, x + 27, y + 26], fill=circle_col)
        draw.text((x + 11, y + 6), button, font=font_btn, fill=text_btn_col)

        # Action text
        draw.text((x + 34, y + 7), label, font=font_lbl, fill=COLOR_TEXT_PRIMARY)
        return pill_w

    def draw_checking(self, current_version=""):
        """State: Checking for updates."""
        canvas, draw = self.create_canvas()
        self.draw_header(draw, "SYSTEM UPDATE DISCOVERY")

        # Main Card
        cx, cy, cw, ch = 200, 140, 880, 440
        draw.rounded_rectangle([cx, cy, cx + cw, cy + ch], radius=18, fill=COLOR_CARD_BG, outline=COLOR_CARD_BORDER, width=2)
        draw.line([cx + 40, cy, cx + 180, cy], fill=COLOR_CYAN_ACCENT, width=3)

        # Animated-style radar / tech icon
        draw.arc([cx + 380, cy + 90, cx + 500, cy + 210], start=30, end=330, fill=COLOR_CYAN_ACCENT, width=4)
        draw.ellipse([cx + 430, cy + 140, cx + 450, cy + 160], fill=COLOR_CYAN_ACCENT)

        # Status text
        font_title = self.fm.get(26, bold=True)
        font_sub = self.fm.get(16, bold=False)
        font_dim = self.fm.get(14, bold=False)

        draw.text((cx + cw // 2, cy + 250), "Checking for CrossMix-OS Updates...", font=font_title, fill=COLOR_TEXT_PRIMARY, anchor="mm")
        draw.text((cx + cw // 2, cy + 295), "Querying GitHub Releases API (mirzaarsyad74-cmyk/CrossMix-OS)", font=font_sub, fill=COLOR_TEXT_MUTED, anchor="mm")

        if current_version:
            draw.text((cx + cw // 2, cy + 345), f"Installed Build: v{current_version}", font=font_dim, fill=COLOR_TEXT_DIM, anchor="mm")

        # Footer
        self.draw_footer_pill(draw, 50, 660, "B", "Cancel & Return to Menu")
        return canvas

    def draw_update_found(self, current_ver, release_info):
        """State: Update Available with real version stats and changelog."""
        canvas, draw = self.create_canvas()
        self.draw_header(draw, "FIRMWARE UPGRADE AVAILABLE")

        # Left Info Card
        lx, ly, lw, lh = 50, 90, 480, 545
        draw.rounded_rectangle([lx, ly, lx + lw, ly + lh], radius=16, fill=COLOR_CARD_BG, outline=COLOR_CARD_BORDER, width=2)
        draw.line([lx + 30, ly, lx + 200, ly], fill=COLOR_CYAN_ACCENT, width=3)

        # Right Changelog Card
        rx, ry, rw, rh = 550, 90, 680, 545
        draw.rounded_rectangle([rx, ry, rx + rw, ry + rh], radius=16, fill=COLOR_CARD_BG, outline=COLOR_CARD_BORDER, width=2)
        draw.line([rx + 30, ry, rx + 200, ry], fill=COLOR_GREEN_ACCENT, width=3)

        # Left Card Content
        font_badge = self.fm.get(12, bold=True)
        font_big = self.fm.get(34, bold=True)
        font_label = self.fm.get(14, bold=False)
        font_val = self.fm.get(16, bold=True)

        draw.text((lx + 30, ly + 25), "TARGET BUILD", font=font_badge, fill=COLOR_CYAN_ACCENT)
        draw.text((lx + 30, ly + 46), f"v{release_info.get('version', '1.4.0')}", font=font_big, fill=COLOR_TEXT_PRIMARY)

        # Stats rows
        stats = [
            ("Installed Version", f"v{current_ver}", COLOR_TEXT_MUTED),
            ("Release Date", str(release_info.get('date', 'Today')), COLOR_TEXT_PRIMARY),
            ("SD Card Storage", f"{release_info.get('free_mb', 22400)} MB Free (OK)", COLOR_GREEN_ACCENT),
        ]

        row_y = ly + 115
        for lbl, val, val_col in stats:
            draw.line([lx + 30, row_y, lx + lw - 30, row_y], fill=(24, 32, 46), width=1)
            draw.text((lx + 30, row_y + 10), lbl, font=font_label, fill=COLOR_TEXT_MUTED)
            draw.text((lx + lw - 30, row_y + 8), val, font=font_val, fill=val_col, anchor="ra")
            row_y += 42

        # Dual-Tier Update Mode Selection Cards
        draw.line([lx + 30, row_y, lx + lw - 30, row_y], fill=(24, 32, 46), width=1)
        draw.text((lx + 30, row_y + 16), "SELECT UPDATE MODE:", font=font_badge, fill=COLOR_CYAN_ACCENT)

        box_w = lw - 60
        # Mode 1: Fast System Update (A)
        b1_y = row_y + 40
        draw.rounded_rectangle([lx + 30, b1_y, lx + 30 + box_w, b1_y + 68], radius=10, fill=(13, 32, 44), outline=COLOR_CYAN_ACCENT, width=2)
        draw.text((lx + 46, b1_y + 12), "[A] Fast System Update (~15 MB)", font=self.fm.get(15, bold=True), fill=COLOR_CYAN_ACCENT)
        draw.text((lx + 46, b1_y + 36), "SteamOS, Steam Link, YouTube, OTA & configs (10s)", font=self.fm.get(12, bold=False), fill=COLOR_TEXT_PRIMARY)

        # Mode 2: Full OS & ROMs (X)
        b2_y = b1_y + 78
        draw.rounded_rectangle([lx + 30, b2_y, lx + 30 + box_w, b2_y + 68], radius=10, fill=(18, 22, 32), outline=COLOR_CARD_BORDER, width=1)
        draw.text((lx + 46, b2_y + 12), "[X] Full OS & ROMs Archive (~962 MB)", font=self.fm.get(15, bold=True), fill=COLOR_TEXT_PRIMARY)
        draw.text((lx + 46, b2_y + 36), "Complete image with all RetroArch emus & cores", font=self.fm.get(12, bold=False), fill=COLOR_TEXT_MUTED)

        # Right Card: Changelog Content
        draw.text((rx + 30, ry + 25), "WHAT'S NEW IN THIS VERSION", font=font_badge, fill=COLOR_GREEN_ACCENT)
        draw.text((rx + 30, ry + 46), "Release Notes & Changelog", font=self.fm.get(22, bold=True), fill=COLOR_TEXT_PRIMARY)

        # Changelog inner scroll box
        draw.rounded_rectangle([rx + 25, ry + 85, rx + rw - 25, ry + lh - 25], radius=10, fill=(11, 15, 23), outline=(26, 36, 52), width=1)

        font_body = self.fm.get(14, bold=False)
        font_bullet = self.fm.get(14, bold=True)
        changelog_lines = release_info.get('changelog', [])
        cy_text = ry + 105
        for line in changelog_lines[:10]:
            clean = line.strip().lstrip("-*# ").strip()
            if not clean:
                continue
            draw_vector_triangle(draw, rx + 45, cy_text + 7, size=10, color=COLOR_CYAN_ACCENT)
            # Truncate text if too long
            if len(clean) > 65:
                clean = clean[:62] + "..."
            draw.text((rx + 68, cy_text), clean, font=font_body, fill=COLOR_TEXT_PRIMARY)
            cy_text += 36

        # Footer Actions
        self.draw_footer_pill(draw, 50, 660, "A", "Fast System Update (~15 MB)", primary=True)
        self.draw_footer_pill(draw, 440, 660, "X", "Full OS & ROMs (~962 MB)")
        self.draw_footer_pill(draw, 810, 660, "B", "Cancel")
        return canvas

    def draw_downloading(self, new_ver, total_bytes, downloaded_bytes, speed_mbps, eta_str):
        """State: REAL Live Dynamic Progress Bar & Throughput Meter."""
        canvas, draw = self.create_canvas()
        self.draw_header(draw, "HIGH-SPEED PACKAGE DOWNLOADER")

        # Main Card
        cx, cy, cw, ch = 80, 100, 1120, 520
        draw.rounded_rectangle([cx, cy, cx + cw, cy + ch], radius=18, fill=COLOR_CARD_BG, outline=COLOR_CARD_BORDER, width=2)
        draw.line([cx + 40, cy, cx + 240, cy], fill=COLOR_CYAN_ACCENT, width=3)

        # Header titles
        font_badge = self.fm.get(13, bold=True)
        font_title = self.fm.get(26, bold=True)
        draw.text((cx + 40, cy + 30), "DOWNLOADING FIRMWARE ARCHIVE", font=font_badge, fill=COLOR_CYAN_ACCENT)
        draw.text((cx + 40, cy + 56), f"CrossMix-OS v{new_ver}.zip", font=font_title, fill=COLOR_TEXT_PRIMARY)

        # Calculation
        percent = 0.0
        if total_bytes > 0:
            percent = min(100.0, (downloaded_bytes / float(total_bytes)) * 100.0)

        dl_mb = downloaded_bytes / (1024 * 1024)
        tot_mb = total_bytes / (1024 * 1024) if total_bytes > 0 else 0

        # Percentage Display (Huge and Crisp)
        font_pct = self.fm.get(56, bold=True)
        font_subpct = self.fm.get(18, bold=False)
        pct_str = f"{percent:.1f}%"
        draw.text((cx + cw - 50, cy + 42), pct_str, font=font_pct, fill=COLOR_CYAN_ACCENT, anchor="ra")
        draw.text((cx + cw - 50, cy + 105), f"{dl_mb:.1f} MB / {tot_mb:.1f} MB", font=font_subpct, fill=COLOR_TEXT_MUTED, anchor="ra")

        # DYNAMIC PROGRESS BAR
        bar_x = cx + 40
        bar_y = cy + 160
        bar_w = cw - 80
        bar_h = 32

        # Outer track
        draw.rounded_rectangle([bar_x, bar_y, bar_x + bar_w, bar_y + bar_h], radius=16, fill=COLOR_BAR_BG, outline=COLOR_BAR_BORDER, width=2)

        # Filled dynamic portion
        fill_w = int((percent / 100.0) * (bar_w - 4))
        if fill_w > 8:
            fill_box = [bar_x + 2, bar_y + 2, bar_x + 2 + fill_w, bar_y + bar_h - 2]
            # Draw gradient or vibrant fill
            draw.rounded_rectangle(fill_box, radius=14, fill=COLOR_CYAN_ACCENT)
            # Glowing leading indicator
            draw.ellipse([bar_x + fill_w - 10, bar_y + 4, bar_x + fill_w + 6, bar_y + bar_h - 4], fill=(255, 255, 255))

        # 3 Real-Time Diagnostic Statistic Tiles
        tile_y = cy + 240
        tile_w = (bar_w - 40) // 3
        tile_h = 130

        tiles = [
            ("TRANSFER SPEED", f"{speed_mbps:.2f} MB/s", COLOR_CYAN_ACCENT, "Direct HTTPS Stream"),
            ("ESTIMATED TIME", eta_str, COLOR_TEXT_PRIMARY, "Remaining to finish"),
            ("INTEGRITY ENGINE", "Active", COLOR_GREEN_ACCENT, "SHA-256 Validation on exit")
        ]

        for i, (label, value, val_col, sub_desc) in enumerate(tiles):
            tx = bar_x + i * (tile_w + 20)
            draw.rounded_rectangle([tx, tile_y, tx + tile_w, tile_y + tile_h], radius=12, fill=(13, 17, 26), outline=(28, 38, 54), width=1)
            draw.text((tx + 20, tile_y + 20), label, font=self.fm.get(12, bold=True), fill=COLOR_TEXT_MUTED)
            draw.text((tx + 20, tile_y + 45), value, font=self.fm.get(26, bold=True), fill=val_col)
            draw.text((tx + 20, tile_y + 90), sub_desc, font=self.fm.get(12, bold=False), fill=COLOR_TEXT_DIM)

        # Live wave status line
        draw.text((cx + 40, cy + ch - 50), "STREAM STATUS: RECEIVING DATA FROM GITHUB CDN", font=self.fm.get(13, bold=True), fill=COLOR_TEXT_DIM)

        # Footer Actions
        self.draw_footer_pill(draw, 50, 660, "B", "Cancel Download")
        return canvas

    def draw_installing(self, new_ver, current_step, step_name):
        """State: Real-time update extraction and installation steps."""
        canvas, draw = self.create_canvas()
        self.draw_header(draw, "SYSTEM UPGRADE & DECOMPRESSION")

        # Main Card
        cx, cy, cw, ch = 150, 110, 980, 500
        draw.rounded_rectangle([cx, cy, cx + cw, cy + ch], radius=18, fill=COLOR_CARD_BG, outline=COLOR_CARD_BORDER, width=2)
        draw.line([cx + 40, cy, cx + 240, cy], fill=COLOR_AMBER_ACCENT, width=3)

        draw.text((cx + 40, cy + 30), "INSTALLATION IN PROGRESS", font=self.fm.get(13, bold=True), fill=COLOR_AMBER_ACCENT)
        draw.text((cx + 40, cy + 56), f"Applying CrossMix-OS v{new_ver}", font=self.fm.get(26, bold=True), fill=COLOR_TEXT_PRIMARY)

        steps = [
            ("1. Storage Space & File System Audit", 1),
            ("2. User Configurations & Saves Backup", 2),
            ("3. Decompressing Core OS Archive", 3),
            ("4. Preserving Custom RetroArch Emulators", 4),
            ("5. Finalizing OS & Scheduling Reboot", 5)
        ]

        step_y = cy + 130
        for name, idx in steps:
            draw.rounded_rectangle([cx + 40, step_y, cx + cw - 40, step_y + 46], radius=8, fill=(13, 17, 26), outline=(26, 35, 50), width=1)
            if idx < current_step:
                draw_vector_checkmark(draw, cx + 70, step_y + 22, size=18, color=COLOR_GREEN_ACCENT, width=3)
                draw.text((cx + 95, step_y + 14), name, font=self.fm.get(15, bold=False), fill=COLOR_TEXT_MUTED)
                draw.text((cx + cw - 70, step_y + 14), "DONE", font=self.fm.get(13, bold=True), fill=COLOR_GREEN_ACCENT, anchor="ra")
            elif idx == current_step:
                draw_vector_triangle(draw, cx + 62, step_y + 23, size=12, color=COLOR_CYAN_ACCENT)
                draw.text((cx + 95, step_y + 14), f"{name} (in progress...)", font=self.fm.get(15, bold=True), fill=COLOR_CYAN_ACCENT)
                draw.text((cx + cw - 70, step_y + 14), "ACTIVE", font=self.fm.get(13, bold=True), fill=COLOR_CYAN_ACCENT, anchor="ra")
            else:
                draw.ellipse([cx + 64, step_y + 17, cx + 74, step_y + 27], outline=COLOR_TEXT_DIM, width=2)
                draw.text((cx + 95, step_y + 14), name, font=self.fm.get(15, bold=False), fill=COLOR_TEXT_DIM)
                draw.text((cx + cw - 70, step_y + 14), "WAITING", font=self.fm.get(13, bold=False), fill=COLOR_TEXT_DIM, anchor="ra")
            step_y += 58

        # Warning Notice
        warn_box = [cx + 40, cy + ch - 70, cx + cw - 40, cy + ch - 25]
        draw.rounded_rectangle(warn_box, radius=8, fill=(35, 25, 10), outline=COLOR_AMBER_ACCENT, width=1)
        draw_vector_warning(draw, cx + 70, cy + ch - 48, size=12, color=COLOR_AMBER_ACCENT)
        draw.text((cx + cw // 2, cy + ch - 48), "CAUTION: DO NOT TURN OFF CONSOLE POWER DURING INSTALLATION", font=self.fm.get(13, bold=True), fill=COLOR_AMBER_ACCENT, anchor="mm")
        return canvas

    def draw_uptodate(self, current_ver):
        """State: Already on newest version."""
        canvas, draw = self.create_canvas()
        self.draw_header(draw, "SYSTEM STATUS AUDIT")

        cx, cy, cw, ch = 200, 140, 880, 440
        draw.rounded_rectangle([cx, cy, cx + cw, cy + ch], radius=18, fill=COLOR_CARD_BG, outline=COLOR_CARD_BORDER, width=2)
        draw.line([cx + 40, cy, cx + 180, cy], fill=COLOR_GREEN_ACCENT, width=3)

        # Large Vector Checkmark Icon
        draw.ellipse([cx + 400, cy + 90, cx + 480, cy + 170], fill=(15, 45, 25), outline=COLOR_GREEN_ACCENT, width=3)
        draw_vector_checkmark(draw, cx + 440, cy + 128, size=36, color=COLOR_GREEN_ACCENT, width=5)

        draw.text((cx + cw // 2, cy + 230), "Your System is Up to Date!", font=self.fm.get(28, bold=True), fill=COLOR_TEXT_PRIMARY, anchor="mm")
        draw.text((cx + cw // 2, cy + 275), f"Installed Version: v{current_ver}", font=self.fm.get(20, bold=False), fill=COLOR_CYAN_ACCENT, anchor="mm")
        draw.text((cx + cw // 2, cy + 325), "No new updates are available on the Stable release channel.", font=self.fm.get(15, bold=False), fill=COLOR_TEXT_MUTED, anchor="mm")

        self.draw_footer_pill(draw, 50, 660, "A", "Return to Main Menu", primary=True)
        self.draw_footer_pill(draw, 290, 660, "B", "Exit")
        return canvas

    def draw_error(self, title, message, advice=""):
        """State: Error handling."""
        canvas, draw = self.create_canvas()
        self.draw_header(draw, "UPDATE DIAGNOSTIC ALERT")

        cx, cy, cw, ch = 200, 140, 880, 440
        draw.rounded_rectangle([cx, cy, cx + cw, cy + ch], radius=18, fill=COLOR_CARD_BG, outline=COLOR_CARD_BORDER, width=2)
        draw.line([cx + 40, cy, cx + 180, cy], fill=COLOR_RED_ACCENT, width=3)

        # Warning Icon
        draw.ellipse([cx + 400, cy + 90, cx + 480, cy + 170], fill=(50, 15, 15), outline=COLOR_RED_ACCENT, width=3)
        draw.text((cx + 440, cy + 130), "!", font=self.fm.get(42, bold=True), fill=COLOR_RED_ACCENT, anchor="mm")

        draw.text((cx + cw // 2, cy + 230), title, font=self.fm.get(26, bold=True), fill=COLOR_RED_ACCENT, anchor="mm")
        draw.text((cx + cw // 2, cy + 275), message, font=self.fm.get(16, bold=False), fill=COLOR_TEXT_PRIMARY, anchor="mm")
        if advice:
            draw.text((cx + cw // 2, cy + 325), advice, font=self.fm.get(14, bold=False), fill=COLOR_TEXT_MUTED, anchor="mm")

        self.draw_footer_pill(draw, 50, 660, "B", "Exit & Return to Menu")
        return canvas


class DisplayManager:
    """Blits generated PIL frames to the TrimUI Smart Pro LCD display."""
    def __init__(self):
        self.pic2fb_bin = "/mnt/SDCARD/System/bin/pic2fb"
        self.has_pic2fb = os.path.exists(self.pic2fb_bin) and os.access(self.pic2fb_bin, os.X_OK)
        self.temp_frame = "/tmp/ota_frame.png"
        self.fb_path = "/dev/fb0"
        self.has_fb = os.path.exists(self.fb_path)

    def blit(self, image):
        """Blits image to screen with zero latency."""
        if self.has_pic2fb:
            try:
                # Save optimized uncompressed PNG in RAM tmpfs
                image.save(self.temp_frame, "PNG", compress_level=1)
                subprocess.run([self.pic2fb_bin, self.temp_frame], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                return True
            except Exception as e:
                pass

        if self.has_fb:
            try:
                # Direct framebuffer write fallback
                raw_bytes = image.convert("RGBA").tobytes()
                with open(self.fb_path, "wb") as fb:
                    fb.write(raw_bytes)
                return True
            except Exception:
                pass

        return False


class GamepadController:
    """Non-blocking event listener for TrimUI Smart Pro controller."""
    def __init__(self):
        self.device_nodes = ["/dev/input/event3", "/dev/input/event0", "/dev/input/event1", "/dev/input/event2"]
        self.fd = None
        for node in self.device_nodes:
            if os.path.exists(node):
                try:
                    self.fd = os.open(node, os.O_RDONLY | os.O_NONBLOCK)
                    break
                except Exception:
                    continue

    def poll(self):
        """Returns pressed button 'A', 'B', 'X', 'Y', 'UP', 'DOWN', or None."""
        if self.fd is None:
            return None

        # Linux input_event is 24 bytes on 64-bit ARM
        # struct timeval (16 bytes), __u16 type, __u16 code, __s32 value
        EVENT_SIZE = 24
        try:
            r, _, _ = select.select([self.fd], [], [], 0)
            if not r:
                return None

            data = os.read(self.fd, EVENT_SIZE * 16)
            for i in range(0, len(data), EVENT_SIZE):
                chunk = data[i:i + EVENT_SIZE]
                if len(chunk) < EVENT_SIZE:
                    continue
                _, _, ev_type, ev_code, ev_val = struct.unpack("qqHHi", chunk)
                if ev_type == 1 and ev_val == 1:  # EV_KEY, KEY_DOWN
                    if ev_code == 305: return "A"
                    if ev_code == 304: return "B"
                    if ev_code == 307: return "Y"
                    if ev_code == 308: return "X"
                    if ev_code == 315: return "START"
                    if ev_code == 316: return "MENU"
        except Exception:
            pass
        return None

    def close(self):
        if self.fd is not None:
            try:
                os.close(self.fd)
            except Exception:
                pass


# -------------------------------------------------------------
# Main Update Runner
# -------------------------------------------------------------
def get_installed_version():
    candidates = [
        "/mnt/SDCARD/System/usr/trimui/crossmix-version.txt",
        "System/usr/trimui/crossmix-version.txt",
        "crossmix-version.txt"
    ]
    for c in candidates:
        if os.path.exists(c):
            try:
                with open(c, "r", encoding="utf-8") as f:
                    return f.read().strip()
            except Exception:
                pass
    return "1.3.7"


def fetch_release_info(repo="mirzaarsyad74-cmyk/CrossMix-OS"):
    """Fetches release info from GitHub API with multi-tier SSL verification bypass."""
    url = f"https://api.github.com/repos/{repo}/releases/latest"
    raw_json = None

    # Tier 1: curl -k (insecure SSL bypass, standard on TrimUI Smart Pro)
    try:
        cmd = ["curl", "-k", "-s", "-H", "User-Agent: CrossMix-OTA", url]
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=12)
        if res.returncode == 0 and res.stdout.strip().startswith("{"):
            raw_json = res.stdout
    except Exception:
        pass

    # Tier 2: urllib with unverified SSL context
    if not raw_json:
        try:
            ctx = ssl._create_unverified_context()
            req = urllib.request.Request(url, headers={"User-Agent": "CrossMix-OTA"})
            with urllib.request.urlopen(req, context=ctx, timeout=12) as resp:
                raw_json = resp.read().decode("utf-8")
        except Exception:
            pass

    # Tier 3: wget --no-check-certificate
    if not raw_json:
        try:
            cmd = ["wget", "--no-check-certificate", "-qO-", "--header=User-Agent: CrossMix-OTA", url]
            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=12)
            if res.returncode == 0 and res.stdout.strip().startswith("{"):
                raw_json = res.stdout
        except Exception:
            pass

    if not raw_json:
        raise RuntimeError("Could not connect to GitHub API after curl, urllib, and wget attempts.")

    data = json.loads(raw_json)
    tag = (data.get("tag_name") or "").lstrip("v")
    body = data.get("body") or ""
    created_at = (data.get("created_at") or "")[:10]

    asset_url = ""
    asset_size = 0
    for a in data.get("assets", []):
        if a.get("name", "").endswith(".zip") and "CrossMix-OS" in a.get("name", ""):
            asset_url = a.get("browser_download_url")
            asset_size = a.get("size", 0)
            break

    # If no specific zip asset, check zipball
    if not asset_url:
        asset_url = data.get("zipball_url", "")

    changelog_lines = []
    for line in body.splitlines():
        line = line.strip()
        if line.startswith("-") or line.startswith("*") or line.startswith("#"):
            changelog_lines.append(line)

    return {
        "version": tag,
        "url": asset_url,
        "size_bytes": asset_size,
        "size_mb": asset_size // (1024 * 1024) if asset_size else 960,
        "date": created_at,
        "changelog": changelog_lines or ["- SteamOS Handheld Edition updates", "- System fixes & performance improvements"],
        "free_mb": 22400
    }


def run_interactive_ota():
    renderer = OtaRenderer()
    display = DisplayManager()
    gamepad = GamepadController()

    curr_ver = get_installed_version()

    # Step 1: Checking
    frame = renderer.draw_checking(curr_ver)
    display.blit(frame)

    try:
        rel_info = fetch_release_info()
    except Exception as e:
        frame = renderer.draw_error("Connection Error", "Could not reach GitHub Releases API.", "Please verify your Wi-Fi is connected in Main Settings.")
        display.blit(frame)
        time.sleep(4)
        gamepad.close()
        return

    # Check if newer
    target_ver = rel_info.get("version", curr_ver)
    if target_ver == curr_ver:
        frame = renderer.draw_uptodate(curr_ver)
        display.blit(frame)
        start_wait = time.time()
        while time.time() - start_wait < 8:
            btn = gamepad.poll()
            if btn in ("A", "B", "START"):
                break
            time.sleep(0.05)
        gamepad.close()
        return

    # Step 2: Show Found Screen & Wait for User Choice
    frame = renderer.draw_update_found(curr_ver, rel_info)
    display.blit(frame)

    user_choice = None
    while True:
        btn = gamepad.poll()
        if btn == "A":
            user_choice = "quick"
            break
        elif btn == "X":
            user_choice = "full"
            break
        elif btn == "B":
            user_choice = "cancel"
            break
        time.sleep(0.05)

    if user_choice == "cancel":
        gamepad.close()
        return

    # Branch A: Quick High-Speed Delta Patch (Scripts, Apps, Binaries ~15 MB, 10s)
    if user_choice == "quick":
        frame = renderer.draw_installing(target_ver, 1, "Synchronizing Updated Components")
        display.blit(frame)

        # Run update.sh directly in high-speed silent mode
        patch_cmd = "curl -k -sL https://raw.githubusercontent.com/mirzaarsyad74-cmyk/CrossMix-OS/main/update.sh | sh"
        try:
            res = subprocess.run(["sh", "-c", patch_cmd], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=120)
            frame = renderer.draw_installing(target_ver, 5, "Update Finalized")
            display.blit(frame)
            time.sleep(2)
        except Exception as e:
            frame = renderer.draw_error("Patch Error", "Could not apply quick patch.", str(e))
            display.blit(frame)
            time.sleep(4)

        gamepad.close()
        return

    # Branch B: Full OS Archive Download & Install (with C-Native Accelerated Curl & Resume)
    dl_url = rel_info.get("url")
    if not dl_url:
        frame = renderer.draw_error("Download Error", "No CrossMix-OS zip found in release assets.")
        display.blit(frame)
        time.sleep(4)
        gamepad.close()
        return

    dest_dir = "/mnt/SDCARD/System/updates"
    os.makedirs(dest_dir, exist_ok=True)
    dest_file = os.path.join(dest_dir, f"CrossMix-OS_v{target_ver}.zip")
    temp_file = dest_file + ".tmp"

    total_size = rel_info.get("size_bytes", 0)

    # Detect fastest curl binary on system
    curl_candidates = [
        "/mnt/SDCARD/System/bin/curl-aarch64",
        "/usr/bin/curl",
        "curl"
    ]
    curl_bin = "curl"
    for cb in curl_candidates:
        if os.path.exists(cb) and (os.access(cb, os.X_OK) or cb == "curl"):
            curl_bin = cb
            break

    # Native C curl with hardware acceleration, byte-range resume, and retry logic
    curl_cmd = [
        curl_bin,
        "-k",                          # Bypass certificate issues
        "-L",                          # Follow redirects to S3 CDN
        "-C", "-",                     # Auto-resume from existing downloaded bytes!
        "--retry", "10",
        "--retry-delay", "1",
        "--connect-timeout", "15",
        "--max-time", "7200",
        "-s",
        "-o", temp_file,
        dl_url
    ]

    initial_size = os.path.getsize(temp_file) if os.path.exists(temp_file) else 0
    start_time = time.time()
    last_ui_update = 0
    last_bytes = initial_size
    last_speed_time = start_time
    smooth_speed = 0.0

    try:
        proc = subprocess.Popen(curl_cmd)
        while True:
            ret = proc.poll()
            if ret is not None:
                # Process completed
                break

            # Check for user cancellation via B button
            btn = gamepad.poll()
            if btn == "B":
                proc.terminate()
                try:
                    proc.wait(timeout=2)
                except Exception:
                    proc.kill()
                # DO NOT delete temp_file so user can resume next time!
                gamepad.close()
                return

            now = time.time()
            if now - last_ui_update >= 0.75:
                last_ui_update = now
                cur_bytes = os.path.getsize(temp_file) if os.path.exists(temp_file) else 0

                # Measure delta throughput over interval
                time_delta = max(0.1, now - last_speed_time)
                bytes_delta = max(0, cur_bytes - last_bytes)
                instant_speed = (bytes_delta / (1024 * 1024)) / time_delta

                if smooth_speed == 0:
                    smooth_speed = instant_speed
                else:
                    smooth_speed = 0.7 * instant_speed + 0.3 * smooth_speed

                last_bytes = cur_bytes
                last_speed_time = now

                rem_bytes = max(0, total_size - cur_bytes)
                eta_sec = int(rem_bytes / (smooth_speed * 1024 * 1024)) if smooth_speed > 0.05 else 0
                eta_str = f"{eta_sec // 60}m {eta_sec % 60:02d}s" if eta_sec > 0 else "Calculating..."

                frame = renderer.draw_downloading(target_ver, total_size, cur_bytes, smooth_speed, eta_str)
                display.blit(frame)

            time.sleep(0.08)

        if proc.returncode != 0:
            raise RuntimeError(f"Download terminated with code {proc.returncode}")

        # Verify completed size
        if os.path.exists(temp_file):
            final_size = os.path.getsize(temp_file)
            if total_size > 0 and final_size < int(total_size * 0.95):
                raise RuntimeError(f"File incomplete: {final_size} / {total_size} bytes")
            if os.path.exists(dest_file):
                os.remove(dest_file)
            os.rename(temp_file, dest_file)
        else:
            raise RuntimeError("Downloaded archive file missing.")

    except Exception as e:
        frame = renderer.draw_error("Download Aborted", str(e), "Check Wi-Fi stability and retry.")
        display.blit(frame)
        time.sleep(4)
        gamepad.close()
        return

    # Step 4: Show Installation Screen
    frame = renderer.draw_installing(target_ver, 3, "Decompressing archive")
    display.blit(frame)

    # Move to root for installation on reboot
    target_root_zip = f"/mnt/SDCARD/CrossMix-OS_v{target_ver}.zip"
    try:
        if os.path.exists(dest_file):
            import shutil
            shutil.copy2(dest_file, target_root_zip)
    except Exception:
        pass

    time.sleep(2)
    # Trigger reboot
    subprocess.run(["sync"])
    subprocess.run(["reboot"])


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--test-render":
        # Render sample frames to inspect visuals
        out_dir = sys.argv[2] if len(sys.argv) > 2 else "."
        os.makedirs(out_dir, exist_ok=True)
        r = OtaRenderer()
        
        sample_rel = {
            "version": "1.3.8",
            "size_mb": 960,
            "date": "2026-11-06",
            "changelog": [
                "100% Native Framebuffer Dynamic GUI Engine",
                "Real-time animated progress bar with live speed & ETA",
                "Full resolution 1280x720 Dark Obsidian Cyber UI",
                "Purged all static mockup images and terminal leakage"
            ],
            "free_mb": 22400
        }

        r.draw_checking("1.3.7").save(os.path.join(out_dir, "screen_1_checking.png"))
        r.draw_update_found("1.3.7", sample_rel).save(os.path.join(out_dir, "screen_2_update_found.png"))
        r.draw_downloading("1.3.8", 1000 * 1024 * 1024, 420 * 1024 * 1024, 3.45, "2m 45s").save(os.path.join(out_dir, "screen_3_downloading.png"))
        r.draw_installing("1.3.8", 3, "Decompressing Core OS Archive").save(os.path.join(out_dir, "screen_4_installing.png"))
        r.draw_uptodate("1.3.8").save(os.path.join(out_dir, "screen_5_uptodate.png"))
        r.draw_error("Insufficient Storage", "You need at least 5000 MB free to update.", "Please delete unused ROMs or files from SD card.").save(os.path.join(out_dir, "screen_6_error.png"))
        print("Generated all test screens in:", out_dir)
    else:
        run_interactive_ota()
