# Template images

Capture these with `python -m lastwar_bot.capture` from **your** device at
**your** resolution (the docker-compose redroid runs 720x1280 — keep it fixed
after capturing). Crop tightly around the distinctive part of each element.

Tasks whose templates are missing are skipped with a log warning, so you can
start small and add more over time.

## Navigation (needed by everything)

| Template                 | What to crop                                             |
|--------------------------|----------------------------------------------------------|
| `base_view_anchor`       | Something always visible only in base view (e.g. a fixed bottom-bar icon) |
| `world_view_anchor`      | Something always visible only on the world map           |
| `world_base_toggle`      | The base/world switch button (bottom-left)               |
| `popup_close_x`          | The standard X button that closes dialogs                |

## collect_base

| Template       | What to crop                          |
|----------------|---------------------------------------|
| `bubble_gold`  | Floating gold-collect bubble           |
| `bubble_food`  | Floating food-collect bubble           |
| `bubble_iron`  | Floating iron-collect bubble           |

## alliance_help

| Template                 | What to crop                                  |
|--------------------------|-----------------------------------------------|
| `alliance_button`        | Alliance button in the bottom bar             |
| `alliance_help_all`      | The "Help All" button inside the alliance UI  |
| `alliance_help_pending`  | (optional) hands icon over the alliance button when help is requested |
| `alliance_panel_anchor`  | Header/title of the alliance panel            |

## train_troops

| Template                | What to crop                                    |
|-------------------------|--------------------------------------------------|
| `barracks_idle`         | The "zzz"/idle indicator over an idle barracks   |
| `train_button`          | The train button in the barracks dialog          |
| `train_confirm`         | The confirm button on the troop-count dialog     |
| `barracks_panel_anchor` | Header of the barracks dialog                    |

## radar_tasks

| Template             | What to crop                                |
|----------------------|----------------------------------------------|
| `radar_button`       | Radar entry point in base view               |
| `radar_claim`        | The claim button on a completed mission      |
| `radar_go`           | The go/dispatch button on a new mission      |
| `radar_panel_anchor` | Header of the radar panel                    |

## daily_free_gift

| Template          | What to crop                            |
|-------------------|------------------------------------------|
| `gift_entry`      | Entry point for daily gifts/shop         |
| `gift_free_claim` | The "Free"/claim button on the daily chest |
