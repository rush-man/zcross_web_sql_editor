import logging

from .config import Config
from .scheduler import Scheduler


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)-7s %(name)s: %(message)s",
    )
    config = Config.load()
    logging.getLogger(__name__).info(
        "connecting to device %s (game package %s)", config.serial, config.package
    )
    Scheduler(config).run_forever()


if __name__ == "__main__":
    main()
