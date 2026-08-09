# Last War Automation Bot

Headless automation bot for **Last War: Survival**, designed to run 24/7 on a
Linux server. It drives the game purely through the UI — screenshots in, taps
out — using ADB against an Android container ([redroid](https://github.com/remote-android/redroid-doc))
or any emulator/phone reachable over ADB.

> **Disclaimer:** automating gameplay violates the game's Terms of Service and
> can get the account banned. Use a farm/secondary account you are prepared to
> lose. This project is for personal/educational use on your own account only.

## How it works

```
┌────────────────────────── docker compose ──────────────────────────┐
│                                                                    │
│  ┌───────────────┐   adb (tcp 5555)   ┌───────────────────────┐    │
│  │   redroid     │◄───────────────────│        bot            │    │
│  │  (Android 11) │   screencap/tap    │  scheduler → tasks    │    │
│  │  + Last War   │                    │  vision (OpenCV/OCR)  │    │
│  └───────────────┘                    └───────────────────────┘    │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

- `device.py` — thin ADB wrapper: screenshot, tap, swipe, key events.
- `vision.py` — OpenCV template matching + Tesseract OCR for numbers/timers.
- `screens.py` — screen recognition and "get me back to base view" recovery.
- `scheduler.py` — priority loop; each task declares a cooldown and runs when due.
- `tasks/` — one module per automated activity (collect resources, alliance
  help, train troops, radar missions…). Adding a task = subclass `Task`,
  register it, drop in the template images it needs.

The bot is **template driven**: it finds buttons by matching small reference
images (`templates/*.png`) cropped from screenshots of *your* device at *your*
resolution. Templates are not shipped — capture them once with the helper tool
(5–10 minutes), see below.

## Quick start

### 1. Bring up Android + install the game

```bash
cd lastwar_bot
docker compose up -d redroid
adb connect localhost:5555
# Install Last War (APK from your own device: `adb pull` it, or use an APK you own)
adb -s localhost:5555 install lastwar.apk
```

Log into the game once manually — use `scrcpy -s localhost:5555` from your
desktop for an interactive screen. Finish the tutorial, bind the account.

### 2. Capture templates

```bash
pip install -r requirements.txt
python -m lastwar_bot.capture --serial localhost:5555
```

The tool takes a screenshot, opens a simple crop flow, and saves named
templates into `templates/`. `templates/README.md` lists every template each
task needs. Tasks whose templates are missing are skipped automatically with a
warning — you can start with just `base_view_anchor` + one task and grow.

### 3. Configure and run

```bash
cp config/config.example.yaml config/config.yaml   # edit to taste
python -m lastwar_bot                              # local run
# or 24/7:
docker compose up -d --build bot
```

Logs go to stdout (`docker compose logs -f bot`); on any unexpected error the
bot saves a full screenshot to `debug/` so you can see what it was looking at,
then recovers to the base view and continues.

## Configuration

Everything lives in `config/config.yaml` — device serial, per-task
enable/cooldown, match threshold, human-like delay ranges. See the commented
`config/config.example.yaml`.

## Implemented tasks

| Task              | What it does                                                | Default cooldown |
|-------------------|-------------------------------------------------------------|------------------|
| `collect_base`    | Taps floating resource bubbles on the base view             | 10 min           |
| `alliance_help`   | Opens alliance panel, presses "Help All"                    | 5 min            |
| `train_troops`    | Re-queues troop training in each idle barracks              | 30 min           |
| `radar_tasks`     | Claims completed radar missions and starts new ones         | 15 min           |
| `daily_free_gift` | Claims free daily chest(s)                                  | 6 h              |

## Roadmap ideas

- Resource gathering on the world map (march management, tile OCR)
- Secretary/VS-day aware scheduling profiles
- Telegram notifications (shield down, captcha/verification detected → pause)
- Multi-account rotation (one redroid per account)
