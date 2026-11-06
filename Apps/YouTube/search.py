#!/usr/bin/env python3
"""
YouTube Search & Trending Formatter for TrimUI Smart Pro / CrossMix-OS
Outputs clean option lines for TrimUI's native selector menu.
"""

import sys
import os
import subprocess
import json

def search_youtube(query, count=8):
    python_bin = "/mnt/SDCARD/System/bin/python3.11"
    ytdl_bin = "/mnt/SDCARD/System/bin/yt-dlp.py"
    
    if os.path.exists(python_bin) and os.path.exists(ytdl_bin):
        cmd = [python_bin, ytdl_bin, "--flat-playlist", "--dump-json", "--no-warnings", f"ytsearch{count}:{query}"]
    elif os.path.exists("System/bin/yt-dlp.py"):
        cmd = [sys.executable, "System/bin/yt-dlp.py", "--flat-playlist", "--dump-json", "--no-warnings", f"ytsearch{count}:{query}"]
    else:
        cmd = ["yt-dlp", "--flat-playlist", "--dump-json", "--no-warnings", f"ytsearch{count}:{query}"]
        
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=25)
    except Exception as e:
        print(f"Error querying YouTube: {e}", file=sys.stderr)
        return []

    results = []
    for line in proc.stdout.strip().split("\n"):
        line = line.strip()
        if not line:
            continue
        try:
            item = json.loads(line)
            vid_id = item.get("id", "")
            title = item.get("title", "Untitled")
            if len(title) > 42:
                title = title[:39] + "..."
            dur = item.get("duration_string", "")
            chan = item.get("channel") or item.get("uploader") or ""
            if len(chan) > 16:
                chan = chan[:14] + ".."
            
            dur_prefix = f"[{dur}] " if dur else ""
            chan_suffix = f" ({chan})" if chan else ""
            entry = f"{dur_prefix}{title}{chan_suffix} [ID:{vid_id}]"
            results.append(entry)
        except Exception:
            continue
    return results

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: search.py <query> [count]")
        sys.exit(1)
        
    query = sys.argv[1]
    count = int(sys.argv[2]) if len(sys.argv) > 2 else 8
    
    if query == "--gaming":
        query = "gaming trailers gameplay steam deck"
    elif query == "--tech":
        query = "retro handhelds gaming tech review"
    elif query == "--retro":
        query = "retro gaming longplay retroarch"
        
    entries = search_youtube(query, count)
    if not entries:
        print("No videos found. Check Wi-Fi connection.")
    else:
        for e in entries:
            print(e)
