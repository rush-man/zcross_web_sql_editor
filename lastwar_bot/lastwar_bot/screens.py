from __future__ import annotations

import logging
import time

import numpy as np

from .device import Device
from .vision import Vision

log = logging.getLogger(__name__)

# Screens the bot can recognize, in the order we test for them.
# Each maps to the anchor template that uniquely identifies it.
SCREEN_ANCHORS = {
    "base": "base_view_anchor",          # e.g. the HQ building / bottom bar in base view
    "world": "world_view_anchor",        # world map indicator
    "alliance": "alliance_panel_anchor",
    "barracks": "barracks_panel_anchor",
    "radar": "radar_panel_anchor",
    "popup": "popup_close_x",            # generic dialog with an X close button
}


class Screens:
    """Screen recognition + navigation recovery."""

    def __init__(self, device: Device, vision: Vision):
        self.device = device
        self.vision = vision

    def identify(self, screen: np.ndarray) -> str | None:
        for name, anchor in SCREEN_ANCHORS.items():
            if self.vision.find(screen, anchor):
                return name
        return None

    def close_popups(self, screen: np.ndarray | None = None, max_rounds: int = 5) -> np.ndarray:
        """Dismiss stacked dialogs (X buttons, then BACK) until none remain."""
        for _ in range(max_rounds):
            screen = self.device.screenshot() if screen is None else screen
            m = self.vision.find(screen, "popup_close_x")
            if m:
                self.device.tap(m.x, m.y)
                screen = None
                continue
            return screen
        return self.device.screenshot()

    def goto_base(self, timeout: float = 60.0) -> bool:
        """Recover to the base (city) view from wherever we are."""
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            screen = self.close_popups()
            where = self.identify(screen)
            if where == "base":
                return True
            if where == "world":
                # world/base toggle button sits in the same spot in both views
                m = self.vision.find(screen, "world_base_toggle")
                if m:
                    self.device.tap(m.x, m.y)
                    continue
            # In a sub-panel or unknown screen: BACK usually walks up.
            log.debug("goto_base: on %s, pressing BACK", where or "unknown")
            self.device.back()
        log.warning("goto_base: failed within %.0fs", timeout)
        return False
