from __future__ import annotations

import datetime as dt
import logging
import time

import cv2

from .config import Config, DEBUG_DIR
from .device import Device
from .screens import Screens
from .tasks import build_tasks
from .tasks.base import Task
from .vision import Vision

log = logging.getLogger(__name__)


class Scheduler:
    """Main loop: keep the game alive, run whichever task is due next."""

    def __init__(self, config: Config):
        self.config = config
        self.device = Device(config.serial, config.action_delay, config.tap_jitter)
        self.vision = Vision(config.threshold, config.ocr_lang)
        self.screens = Screens(self.device, self.vision)
        self.tasks: list[Task] = build_tasks(config, self.device, self.vision, self.screens)
        self._last_run: dict[str, float] = {}
        self._last_ok = time.monotonic()

    def run_forever(self) -> None:
        log.info("scheduler started with tasks: %s",
                 ", ".join(t.name for t in self.tasks) or "(none)")
        while True:
            try:
                self._tick()
            except KeyboardInterrupt:
                log.info("stopping")
                return
            except Exception:
                log.exception("tick failed")
                self._dump_debug("tick-error")
                time.sleep(self.config.tick)
            time.sleep(self.config.tick)

    def _tick(self) -> None:
        # config is re-read each tick so `paused` / cooldowns can be flipped live
        self.config = Config.load()
        if self.config.paused:
            log.debug("paused")
            return

        if not self.device.app_running(self.config.package):
            self.device.start_app(self.config.package)
            time.sleep(30)  # give the game time to boot to a recognizable screen
            return

        task = self._next_due()
        if task is None:
            self._watchdog()
            return

        log.info("running task: %s", task.name)
        if not self.screens.goto_base():
            self._handle_lost()
            return
        self._last_ok = time.monotonic()

        try:
            task.run()
            self._last_run[task.name] = time.monotonic()
            log.info("task %s done", task.name)
        except Exception:
            log.exception("task %s failed", task.name)
            self._dump_debug(task.name)
            # cooldown applies anyway so a broken task can't spin the loop
            self._last_run[task.name] = time.monotonic()
        finally:
            self.screens.goto_base(timeout=30)

    def _next_due(self) -> Task | None:
        now = time.monotonic()
        for task in self.tasks:
            tc = self.config.tasks.get(task.name)
            if tc and not tc.enabled:
                continue
            cooldown = tc.cooldown if tc else 600.0
            if now - self._last_run.get(task.name, -1e9) >= cooldown:
                if task.ready():
                    return task
                log.warning("task %s skipped: missing templates %s",
                            task.name, ", ".join(task.missing_templates()))
                self._last_run[task.name] = now  # don't re-warn every tick
        return None

    def _watchdog(self) -> None:
        """If nothing has been recognizable for too long, restart the game."""
        screen = self.device.screenshot()
        if self.screens.identify(screen) is not None:
            self._last_ok = time.monotonic()
        elif time.monotonic() - self._last_ok > self.config.lost_timeout:
            self._handle_lost()

    def _handle_lost(self) -> None:
        log.warning("screen not recognized for too long — restarting game")
        self._dump_debug("lost")
        self.device.stop_app(self.config.package)
        time.sleep(3)
        self.device.start_app(self.config.package)
        self._last_ok = time.monotonic()
        time.sleep(30)

    def _dump_debug(self, tag: str) -> None:
        try:
            DEBUG_DIR.mkdir(exist_ok=True)
            stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
            path = DEBUG_DIR / f"{stamp}-{tag}.png"
            cv2.imwrite(str(path), self.device.screenshot())
            log.info("debug screenshot saved: %s", path)
        except Exception:
            log.exception("failed to save debug screenshot")
