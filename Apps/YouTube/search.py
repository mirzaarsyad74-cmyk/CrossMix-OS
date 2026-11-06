#!/usr/bin/env python3
"""
YouTube Search & Trending Formatter for TrimUI Smart Pro / CrossMix-OS
Outputs clean option lines for TrimUI's native selector menu.
"""

import sys
import subprocess
import json

def search_youtube(query, count=8):
    ytdl_bin = "/mnt/SDCARD/System/bin/yt-dlp"
    # Fallback to local python or PATH if not found on dev machine
    cmd = [ytdl_bin, "--flat-playlist", "--dump-json", "--no-warnings", f"ytsearch{count}:{query}"]
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=20)
    except FileNotFoundError:
        # Dev fallback
        cmd[0] = sys.executable
        cmd.insert(1, "System/bin/yt-dlp")
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=20)
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
            # Truncate title if too long for screen
            if len(title) > 42:
                title = title[:39] + "..."
            dur = item.get("duration_string", "")
            chan = item.get("channel") or item.get("uploader") or ""
            if len(chan) > 16:
                chan = chan[:14] + ".."
            
            # Format: [Duration] Title - Channel [ID:xxxxxx]
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
    
    # Handle category presets
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
