from __future__ import annotations

from ..config import Config
from ..device import Device
from ..screens import Screens
from ..vision import Vision
from .alliance_help import AllianceHelp
from .base import Task
from .collect_base import CollectBase
from .daily_free_gift import DailyFreeGift
from .radar_tasks import RadarTasks
from .train_troops import TrainTroops

TASK_CLASSES: list[type[Task]] = [
    # priority order: first due task in this list wins the tick
    AllianceHelp,
    CollectBase,
    RadarTasks,
    TrainTroops,
    DailyFreeGift,
]


def build_tasks(config: Config, device: Device, vision: Vision,
                screens: Screens) -> list[Task]:
    return [cls(device, vision, screens) for cls in TASK_CLASSES]
