from .base import Task


class DailyFreeGift(Task):
    """Claim the free daily chest(s) from the shop/gift entry point."""

    name = "daily_free_gift"
    required_templates = ("gift_entry", "gift_free_claim")

    def run(self) -> None:
        self.tap_template("gift_entry")
        if self.tap_template("gift_free_claim", timeout=6, required=False):
            self.screens.close_popups()
            self.log.info("claimed free daily gift")
        else:
            self.log.info("free gift already claimed")
