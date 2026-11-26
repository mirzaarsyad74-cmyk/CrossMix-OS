#!/usr/bin/env python3
"""
YouTube Search & Trending Formatter for TrimUI Smart Pro / CrossMix-OS
Outputs clean option lines formatted with [ID:<video_id>] for youtube_gui.py.
"""

import sys
import os
import subprocess
import json


def search_youtube(query, count=8):
    python_bin = "/mnt/SDCARD/System/bin/python3.11"
    ytdl_bin = "/mnt/SDCARD/System/bin/yt-dlp.py"

    env = os.environ.copy()
    env["PYTHONPATH"] = f"/mnt/SDCARD/System/lib/python3.11:/mnt/SDCARD/System/lib/python3.11/site-packages:{env.get('PYTHONPATH', '')}"
    env["LD_LIBRARY_PATH"] = f"/mnt/SDCARD/System/lib:/usr/trimui/lib:{env.get('LD_LIBRARY_PATH', '')}"

    cacert = "/mnt/SDCARD/Apps/SteamLink/cacert.pem"
    if os.path.exists(cacert) and "SSL_CERT_FILE" not in env:
        env["SSL_CERT_FILE"] = cacert

    yt_args = [
        "--flat-playlist",
        "--dump-json",
        "--no-warnings",
        "--no-check-certificates",
        f"ytsearch{count}:{query}",
    ]

    if os.path.exists(python_bin) and os.path.exists(ytdl_bin):
        cmd = [python_bin, ytdl_bin] + yt_args
    elif os.path.exists("System/bin/yt-dlp.py"):
        cmd = [sys.executable, "System/bin/yt-dlp.py"] + yt_args
    else:
        cmd = ["yt-dlp"] + yt_args

    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=28, env=env)
    except Exception as e:
        print(f"Error querying YouTube: {e}", file=sys.stderr)
        return []

    if proc.returncode != 0 and proc.stderr:
        print(proc.stderr.strip(), file=sys.stderr)

    results = []
    for line in proc.stdout.strip().splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            item = json.loads(line)
            vid_id = item.get("id", "")
            if not vid_id:
                continue
            title = item.get("title", "Untitled")
            if len(title) > 48:
                title = title[:45] + "..."
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

    for e in search_youtube(query, count):
        print(e)
