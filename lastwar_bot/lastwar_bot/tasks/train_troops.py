from .base import Task


class TrainTroops(Task):
    """Re-queue troop training in every barracks showing an idle marker."""

    name = "train_troops"
    required_templates = ("barracks_idle", "train_button", "train_confirm")

    MAX_BARRACKS = 4

    def run(self) -> None:
        trained = 0
        for _ in range(self.MAX_BARRACKS):
            screen = self.device.screenshot()
            m = self.vision.find(screen, "barracks_idle")
            if not m:
                break
            self.device.tap(m.x, m.y)
            if not self.tap_template("train_button", timeout=6, required=False):
                self.device.back()
                continue
            # confirm uses whatever troop count the game pre-fills (max affordable)
            self.tap_template("train_confirm", timeout=6, required=False)
            trained += 1
            self.screens.goto_base(timeout=20)
        self.log.info("queued training in %d barracks", trained)
