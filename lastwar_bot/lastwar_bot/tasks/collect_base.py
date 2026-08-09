from .base import Task


class CollectBase(Task):
    """Tap every floating resource bubble visible in the base view."""

    name = "collect_base"
    required_templates = ("bubble_gold", "bubble_food", "bubble_iron")

    def run(self) -> None:
        collected = 0
        # bubbles re-spawn their neighbours' positions after a tap, so re-scan
        for _ in range(4):
            screen = self.device.screenshot()
            matches = []
            for tpl in self.required_templates:
                matches += self.vision.find_all(screen, tpl)
            if not matches:
                break
            for m in matches:
                self.device.tap(m.x, m.y)
                collected += 1
        self.log.info("collected %d resource bubbles", collected)
