from .base import Task


class AllianceHelp(Task):
    """Open the alliance panel and press 'Help All'."""

    name = "alliance_help"
    required_templates = ("alliance_button", "alliance_help_all")

    def run(self) -> None:
        # The little hands icon over the alliance button means help is pending;
        # if we captured it, use it to skip pointless panel visits.
        if self.vision.has_template("alliance_help_pending"):
            if not self.vision.find(self.device.screenshot(), "alliance_help_pending"):
                self.log.info("no help requests pending")
                return

        self.tap_template("alliance_button")
        if self.tap_template("alliance_help_all", timeout=6, required=False):
            self.log.info("helped allies")
        else:
            self.log.info("no 'Help All' button — nothing to help")
