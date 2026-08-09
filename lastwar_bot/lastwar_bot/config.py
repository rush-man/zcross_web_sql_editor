from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = ROOT / "config" / "config.yaml"
EXAMPLE_PATH = ROOT / "config" / "config.example.yaml"
TEMPLATE_DIR = ROOT / "templates"
DEBUG_DIR = ROOT / "debug"


@dataclass
class TaskConfig:
    enabled: bool = True
    cooldown: float = 600.0
    extra: dict[str, Any] = field(default_factory=dict)


@dataclass
class Config:
    serial: str = "localhost:5555"
    package: str = "com.fun.lastwar.gp"
    threshold: float = 0.86
    ocr_lang: str = "eng"
    action_delay: tuple[float, float] = (0.4, 1.4)
    tap_jitter: int = 4
    tick: float = 5.0
    lost_timeout: float = 120.0
    paused: bool = False
    tasks: dict[str, TaskConfig] = field(default_factory=dict)

    @classmethod
    def load(cls, path: Path | None = None) -> "Config":
        path = path or (CONFIG_PATH if CONFIG_PATH.exists() else EXAMPLE_PATH)
        raw = yaml.safe_load(path.read_text()) or {}

        device = raw.get("device", {})
        vision = raw.get("vision", {})
        humanize = raw.get("humanize", {})
        sched = raw.get("scheduler", {})

        tasks = {}
        for name, tc in (raw.get("tasks") or {}).items():
            tc = tc or {}
            known = {"enabled", "cooldown"}
            tasks[name] = TaskConfig(
                enabled=bool(tc.get("enabled", True)),
                cooldown=float(tc.get("cooldown", 600)),
                extra={k: v for k, v in tc.items() if k not in known},
            )

        delay = humanize.get("action_delay", [0.4, 1.4])
        return cls(
            serial=os.environ.get("LASTWAR_DEVICE_SERIAL")
            or device.get("serial", "localhost:5555"),
            package=device.get("package", "com.fun.lastwar.gp"),
            threshold=float(vision.get("threshold", 0.86)),
            ocr_lang=vision.get("ocr_lang", "eng"),
            action_delay=(float(delay[0]), float(delay[1])),
            tap_jitter=int(humanize.get("tap_jitter", 4)),
            tick=float(sched.get("tick", 5)),
            lost_timeout=float(sched.get("lost_timeout", 120)),
            paused=bool(raw.get("paused", False)),
            tasks=tasks,
        )
