#!/usr/bin/env python3
"""Send actual X11 keyboard/mouse events through a running Korean IME.

Requires an isolated DISPLAY, Korean XIM server and xdotool; no Unicode paste,
Godot InputEvent injection or build/export. Use the project's pinned Godot.
"""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--project-dir", type=Path, default=Path.cwd())
    parser.add_argument("--script", required=True, type=Path)
    parser.add_argument("--activate-fcitx", action="store_true")
    args = parser.parse_args()
    if not os.environ.get("DISPLAY"):
        parser.error("An isolated X11 display with a real Korean IME is required")
    command = [str(args.godot.resolve()), "--path", str(args.project_dir.resolve()),
               "--windowed", "--resolution", "1920x1080", "--position", "0,0",
               "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
               "--script", str(args.script.resolve())]
    process = subprocess.Popen(command, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True)
    try:
        for line in process.stdout:
            print(line, end="", flush=True)
            fields = line.split()
            if line.startswith("OS_FOCUS "):
                subprocess.run(["xdotool", "windowfocus", fields[1]], check=True)
            elif line.startswith("OS_CLICK "):
                subprocess.run(["xdotool", "mousemove", fields[1], fields[2],
                                "click", "1"], check=True)
                if args.activate_fcitx:
                    # Establish the XIM context before activating its Hangul engine.
                    time.sleep(.4)
                    subprocess.run(["xdotool", "key", "Shift_L"], check=True)
                    time.sleep(.4)
                    subprocess.run(["fcitx5-remote", "-o"], check=True)
                    subprocess.run(["fcitx5-remote", "-s", "hangul"], check=True)
            elif line.startswith("OS_KEY "):
                subprocess.run(["xdotool", "key", "--clearmodifiers", fields[1]],
                               check=True)
        return process.wait()
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()


if __name__ == "__main__":
    sys.exit(main())
