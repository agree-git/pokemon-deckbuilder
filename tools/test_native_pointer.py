#!/usr/bin/env python3
"""Run the graphical X11 pointer regression with Python stdlib + system XTest.

Activate Godot 4.7.2 and DISPLAY first. No signal emission or synthetic Godot
input is used: XTest injects mouse movement and button events at screen pixels.
"""
import argparse
import ctypes
import os
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", choices=["native_pointer_probe", "native_expedition_probe"], default="native_pointer_probe")
    args = parser.parse_args()
    x11 = ctypes.CDLL("libX11.so.6")
    xtest = ctypes.CDLL("libXtst.so.6")
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XSetInputFocus.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int, ctypes.c_ulong]
    x11.XFlush.argtypes = [ctypes.c_void_p]
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    xtest.XTestFakeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
    xtest.XTestFakeButtonEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
    display = x11.XOpenDisplay(os.environ.get("DISPLAY", "").encode())
    if not display:
        sys.exit("An X11 display is required")
    command = ["godot", "--path", str(Path(__file__).resolve().parents[1]),
               "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
               "--script", f"res://tests/{args.probe}.gd"]
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    try:
        for line in process.stdout:
            if not line.startswith("OS_CLICK "):
                print(line, end="", flush=True)
            if line.startswith("OS_FOCUS "):
                x11.XSetInputFocus(display, int(line.split()[1]), 2, 0)
                x11.XFlush(display)
            if line.startswith("OS_CLICK "):
                _, pos_x, pos_y = line.split()
                xtest.XTestFakeMotionEvent(display, -1, int(pos_x), int(pos_y), 0)
                xtest.XTestFakeButtonEvent(display, 1, 1, 20)
                xtest.XTestFakeButtonEvent(display, 1, 0, 20)
                x11.XFlush(display)
        return process.wait(timeout=20)
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()
        x11.XCloseDisplay(display)


if __name__ == "__main__":
    sys.exit(main())
