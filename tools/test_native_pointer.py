#!/usr/bin/env python3
"""Run the graphical X11 pointer and shortcut regression with Python stdlib + system XTest.

Activate Godot 4.7.2 and DISPLAY first. No signal emission or synthetic Godot
input is used: XTest injects mouse movement, button events, and keyboard events.
"""
import argparse
import ctypes
import os
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe", choices=["native_pointer_probe", "native_expedition_probe", "native_tactical_probe", "native_journey_probe", "native_start_probe", "native_tooltip_probe", "native_growth_probe", "native_campaign_probe", "native_camp_probe", "native_save_probe"], default="native_pointer_probe")
    args = parser.parse_args()
    x11 = ctypes.CDLL("libX11.so.6")
    xtest = ctypes.CDLL("libXtst.so.6")
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XSetInputFocus.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int, ctypes.c_ulong]
    x11.XStringToKeysym.argtypes = [ctypes.c_char_p]
    x11.XStringToKeysym.restype = ctypes.c_ulong
    x11.XKeysymToKeycode.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
    x11.XKeysymToKeycode.restype = ctypes.c_ubyte
    xtest.XTestFakeKeyEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
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
            if not line.startswith(("OS_CLICK ", "OS_MOVE ", "OS_KEY ")):
                print(line, end="", flush=True)
            if line.startswith("OS_FOCUS "):
                x11.XSetInputFocus(display, int(line.split()[1]), 2, 0)
                x11.XFlush(display)
            if line.startswith("OS_KEY "):
                symbol = line.split()[1]
                code = x11.XKeysymToKeycode(display, x11.XStringToKeysym(symbol.encode("ascii")))
                if not code:
                    raise RuntimeError(f"Unknown X11 key symbol: {symbol}")
                xtest.XTestFakeKeyEvent(display, code, 1, 20)
                xtest.XTestFakeKeyEvent(display, code, 0, 20)
                x11.XFlush(display)
            if line.startswith(("OS_CLICK ", "OS_MOVE ")):
                _, pos_x, pos_y = line.split()
                xtest.XTestFakeMotionEvent(display, -1, int(pos_x), int(pos_y), 0)
                if line.startswith("OS_CLICK "):
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
