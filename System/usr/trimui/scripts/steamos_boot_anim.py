#!/usr/bin/env python3
"""
SteamOS Boot Animation Player for TrimUI Smart Pro (1280x720)
Plays the custom animated Steam Deck startup sequence directly on /dev/fb0.
"""

import os
import sys
import time
import subprocess

FRAME_DIR = "/mnt/SDCARD/System/usr/trimui/res/boot_anim"
if not os.path.exists(FRAME_DIR):
    FRAME_DIR = "System/usr/trimui/res/boot_anim"

PIC2FB = "/mnt/SDCARD/System/bin/pic2fb"
HAS_PIC2FB = os.path.exists(PIC2FB) and os.access(PIC2FB, os.X_OK)
FB0 = "/dev/fb0"
HAS_FB0 = os.path.exists(FB0)

def main():
    if not os.path.exists(FRAME_DIR):
        return

    frames = sorted([os.path.join(FRAME_DIR, f) for f in os.listdir(FRAME_DIR) if f.endswith(".png")])
    if not frames:
        return

    for frame in frames:
        if HAS_PIC2FB:
            subprocess.run([PIC2FB, frame], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif HAS_FB0:
            try:
                from PIL import Image
                img = Image.open(frame).convert("RGBA")
                with open(FB0, "wb") as f:
                    f.write(img.tobytes())
            except Exception:
                pass
        time.sleep(0.06)

    # Hold final frame for 0.4s
    time.sleep(0.4)

if __name__ == "__main__":
    main()
