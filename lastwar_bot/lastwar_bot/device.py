from __future__ import annotations

import logging
import random
import time

import adbutils
import cv2
import numpy as np

log = logging.getLogger(__name__)


class Device:
    """Thin ADB wrapper with humanized input."""

    def __init__(self, serial: str, action_delay: tuple[float, float], tap_jitter: int):
        self.serial = serial
        self.action_delay = action_delay
        self.tap_jitter = tap_jitter
        self._adb = adbutils.AdbClient()
        self._dev: adbutils.AdbDevice | None = None

    @property
    def dev(self) -> adbutils.AdbDevice:
        if self._dev is None:
            if ":" in self.serial:
                host, port = self.serial.rsplit(":", 1)
                self._adb.connect(f"{host}:{port}", timeout=10)
            self._dev = self._adb.device(self.serial)
        return self._dev

    def screenshot(self) -> np.ndarray:
        """Return current screen as a BGR numpy array."""
        img = self.dev.screenshot()
        return cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)

    def tap(self, x: int, y: int) -> None:
        jx = x + random.randint(-self.tap_jitter, self.tap_jitter)
        jy = y + random.randint(-self.tap_jitter, self.tap_jitter)
        log.debug("tap (%d, %d)", jx, jy)
        self.dev.click(jx, jy)
        self.pause()

    def swipe(self, x1: int, y1: int, x2: int, y2: int, duration: float = 0.35) -> None:
        self.dev.swipe(x1, y1, x2, y2, duration)
        self.pause()

    def back(self) -> None:
        self.dev.keyevent("KEYCODE_BACK")
        self.pause()

    def pause(self, factor: float = 1.0) -> None:
        lo, hi = self.action_delay
        time.sleep(random.uniform(lo, hi) * factor)

    # --- app lifecycle -----------------------------------------------------

    def app_running(self, package: str) -> bool:
        out = self.dev.shell(["pidof", package])
        return bool(out.strip())

    def start_app(self, package: str) -> None:
        log.info("starting app %s", package)
        self.dev.shell(
            ["monkey", "-p", package, "-c", "android.intent.category.LAUNCHER", "1"]
        )

    def stop_app(self, package: str) -> None:
        log.info("force-stopping app %s", package)
        self.dev.shell(["am", "force-stop", package])
