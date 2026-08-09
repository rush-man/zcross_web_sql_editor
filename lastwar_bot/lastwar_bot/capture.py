"""Template capture helper.

Usage:
    python -m lastwar_bot.capture --serial localhost:5555

Workflow per template:
  1. Navigate the game (via scrcpy or on the device) to show the UI element.
  2. Press ENTER here to grab a screenshot; it is saved to debug/capture.png.
  3. Open it in any image viewer, note the crop box of the element.
  4. Enter "<name> <x> <y> <w> <h>" to save templates/<name>.png.

Keep crops tight around the distinctive part of a button/icon (no busy
background), roughly 30-80 px on a side. templates/README.md lists the
names each task expects.
"""

from __future__ import annotations

import argparse

import cv2

from .config import Config, DEBUG_DIR, TEMPLATE_DIR
from .device import Device


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serial", default=None, help="ADB serial (default: from config)")
    args = parser.parse_args()

    config = Config.load()
    serial = args.serial or config.serial
    device = Device(serial, action_delay=(0.1, 0.2), tap_jitter=0)
    TEMPLATE_DIR.mkdir(exist_ok=True)
    DEBUG_DIR.mkdir(exist_ok=True)

    print(__doc__)
    print(f"Connected to {serial}. Ctrl-C to quit.\n")

    screen = None
    while True:
        try:
            line = input("ENTER = new screenshot | '<name> <x> <y> <w> <h>' = crop > ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            return

        if not line:
            screen = device.screenshot()
            path = DEBUG_DIR / "capture.png"
            cv2.imwrite(str(path), screen)
            print(f"screenshot {screen.shape[1]}x{screen.shape[0]} saved to {path}")
            continue

        if screen is None:
            print("take a screenshot first (press ENTER)")
            continue

        parts = line.split()
        if len(parts) != 5:
            print("expected: <name> <x> <y> <w> <h>")
            continue
        name, *nums = parts
        try:
            x, y, w, h = map(int, nums)
        except ValueError:
            print("x/y/w/h must be integers")
            continue
        crop = screen[y:y + h, x:x + w]
        if crop.size == 0:
            print("crop box is outside the screenshot")
            continue
        out = TEMPLATE_DIR / f"{name}.png"
        cv2.imwrite(str(out), crop)
        print(f"saved {out} ({w}x{h})")


if __name__ == "__main__":
    main()
