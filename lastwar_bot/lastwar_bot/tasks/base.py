from __future__ import annotations

import logging
import time

from ..device import Device
from ..screens import Screens
from ..vision import Vision


class Task:
    """One automated activity. Subclasses set `name`, `required_templates`
    and implement `run()`, which is always entered from the base view."""

    name: str = ""
    required_templates: tuple[str, ...] = ()

    def __init__(self, device: Device, vision: Vision, screens: Screens):
        self.device = device
        self.vision = vision
        self.screens = screens
        self.log = logging.getLogger(f"task.{self.name}")

    def ready(self) -> bool:
        return not self.missing_templates()

    def missing_templates(self) -> list[str]:
        return [t for t in self.required_templates if not self.vision.has_template(t)]

    def run(self) -> None:
        raise NotImplementedError

    # --- helpers shared by tasks --------------------------------------------

    def tap_template(self, name: str, timeout: float = 8.0,
                     required: bool = True) -> bool:
        """Wait for a template to appear, tap it. False if it never showed."""
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            m = self.vision.find(self.device.screenshot(), name)
            if m:
                self.device.tap(m.x, m.y)
                return True
            time.sleep(0.5)
        if required:
            raise RuntimeError(f"template '{name}' not found within {timeout}s")
        return False

    def wait_for(self, name: str, timeout: float = 8.0) -> bool:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if self.vision.find(self.device.screenshot(), name):
                return True
            time.sleep(0.5)
        return False
