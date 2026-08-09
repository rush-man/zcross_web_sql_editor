from .base import Task


class RadarTasks(Task):
    """Claim finished radar missions and dispatch the new ones."""

    name = "radar_tasks"
    required_templates = ("radar_button", "radar_claim", "radar_go")

    MAX_MISSIONS = 6

    def run(self) -> None:
        self.tap_template("radar_button")
        claimed = started = 0
        for _ in range(self.MAX_MISSIONS):
            screen = self.device.screenshot()
            m = self.vision.find(screen, "radar_claim")
            if m:
                self.device.tap(m.x, m.y)
                # claim usually pops a reward dialog
                self.screens.close_popups()
                claimed += 1
                continue
            m = self.vision.find(screen, "radar_go")
            if m:
                self.device.tap(m.x, m.y)
                started += 1
                continue
            break
        self.log.info("radar: claimed %d, started %d", claimed, started)
