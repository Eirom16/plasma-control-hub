#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Drive an actual native drag on the smoke test's private Xvfb display."""
import ctypes
import os
import sys
import time

if os.environ.get("CONTROLHUB_POINTER_TEST") != "1":
    raise SystemExit("Pointer injection is restricted to the isolated integration test")
x11 = ctypes.CDLL("libX11.so.6")
xtst = ctypes.CDLL("libXtst.so.6")
x11.XOpenDisplay.restype = ctypes.c_void_p
x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
x11.XFlush.argtypes = [ctypes.c_void_p]
x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
xtst.XTestFakeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
xtst.XTestFakeButtonEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
display = x11.XOpenDisplay(None)
if not display:
    raise SystemExit("Cannot open the test display")
sx, sy, tx, ty = map(int, sys.argv[1:])
xtst.XTestFakeMotionEvent(display, -1, sx, sy, 0)
x11.XFlush(display)
time.sleep(0.1)
xtst.XTestFakeButtonEvent(display, 1, 1, 0)
x11.XFlush(display)
for step in range(1, 21):
    time.sleep(0.025)
    x = round(sx + (tx - sx) * step / 20)
    y = round(sy + (ty - sy) * step / 20)
    xtst.XTestFakeMotionEvent(display, -1, x, y, 0)
    x11.XFlush(display)
time.sleep(0.15)
xtst.XTestFakeButtonEvent(display, 1, 0, 0)
x11.XFlush(display)
x11.XCloseDisplay(display)
