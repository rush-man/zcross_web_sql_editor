from __future__ import annotations

import logging
import re
from dataclasses import dataclass
from pathlib import Path

import cv2
import numpy as np

from .config import TEMPLATE_DIR

log = logging.getLogger(__name__)


@dataclass
class Match:
    x: int          # center x
    y: int          # center y
    score: float
    w: int
    h: int


class Vision:
    def __init__(self, threshold: float, ocr_lang: str = "eng"):
        self.threshold = threshold
        self.ocr_lang = ocr_lang
        self._cache: dict[str, np.ndarray | None] = {}

    def template(self, name: str) -> np.ndarray | None:
        """Load templates/<name>.png (cached). None if not captured yet."""
        if name not in self._cache:
            path = TEMPLATE_DIR / f"{name}.png"
            if path.exists():
                self._cache[name] = cv2.imread(str(path), cv2.IMREAD_COLOR)
            else:
                self._cache[name] = None
        return self._cache[name]

    def has_template(self, name: str) -> bool:
        return self.template(name) is not None

    def find(self, screen: np.ndarray, name: str,
             threshold: float | None = None) -> Match | None:
        """Best match of a template on screen, or None below threshold."""
        tpl = self.template(name)
        if tpl is None:
            log.debug("template %s not captured, skipping", name)
            return None
        res = cv2.matchTemplate(screen, tpl, cv2.TM_CCOEFF_NORMED)
        _, max_val, _, max_loc = cv2.minMaxLoc(res)
        if max_val < (threshold if threshold is not None else self.threshold):
            return None
        h, w = tpl.shape[:2]
        return Match(max_loc[0] + w // 2, max_loc[1] + h // 2, float(max_val), w, h)

    def find_all(self, screen: np.ndarray, name: str,
                 threshold: float | None = None) -> list[Match]:
        """All non-overlapping matches (e.g. every resource bubble on screen)."""
        tpl = self.template(name)
        if tpl is None:
            return []
        thr = threshold if threshold is not None else self.threshold
        res = cv2.matchTemplate(screen, tpl, cv2.TM_CCOEFF_NORMED)
        h, w = tpl.shape[:2]
        matches: list[Match] = []
        res = res.copy()
        while True:
            _, max_val, _, max_loc = cv2.minMaxLoc(res)
            if max_val < thr:
                break
            matches.append(
                Match(max_loc[0] + w // 2, max_loc[1] + h // 2, float(max_val), w, h)
            )
            # suppress the neighbourhood so we don't return the same spot again
            x0 = max(0, max_loc[0] - w // 2)
            y0 = max(0, max_loc[1] - h // 2)
            res[y0:max_loc[1] + h, x0:max_loc[0] + w] = -1.0
        return matches

    # --- OCR ----------------------------------------------------------------

    def read_text(self, screen: np.ndarray,
                  region: tuple[int, int, int, int] | None = None) -> str:
        """OCR a region (x, y, w, h) of the screen."""
        import pytesseract

        img = screen
        if region:
            x, y, w, h = region
            img = screen[y:y + h, x:x + w]
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        gray = cv2.resize(gray, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
        _, thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        return pytesseract.image_to_string(thresh, lang=self.ocr_lang).strip()

    def read_number(self, screen: np.ndarray,
                    region: tuple[int, int, int, int] | None = None) -> int | None:
        """OCR a number like '1.2M', '345K' or '12,345'. None if unreadable."""
        text = self.read_text(screen, region)
        m = re.search(r"([\d.,]+)\s*([KMB]?)", text.upper())
        if not m:
            return None
        try:
            value = float(m.group(1).replace(",", ""))
        except ValueError:
            return None
        return int(value * {"": 1, "K": 1e3, "M": 1e6, "B": 1e9}[m.group(2)])
