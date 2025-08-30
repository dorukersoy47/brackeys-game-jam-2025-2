---

# Brackeys Game Jam 2025.2 — Market System (Godot 4)

A Godot 4.x game project featuring a comprehensive **market/shop system** for item and upgrade management. Built for **Brackeys Game Jam 2025.2**.

## Table of Contents

* [Overview](#overview)
* [Architecture](#architecture)
* [Core Systems](#core-systems)

  * [MarketDB](#marketdb)
  * [MarketController](#marketcontroller)
  * [ShopOverlay](#shopoverlay)
  * [Save System](#save-system)
* [Content](#content)

  * [Items](#items)
  * [Upgrades](#upgrades)
* [UI/UX](#uiux)
* [Gameplay Integration](#gameplay-integration)
* [Project Structure](#project-structure)
* [Getting Started](#getting-started)
* [Development Notes](#development-notes)
* [Known Issues](#known-issues)
* [Roadmap](#roadmap)
* [Contributing](#contributing)
* [License](#license)
* [Acknowledgments](#acknowledgments)

---

## Overview

Players can **purchase items and upgrades** to enhance their runs. The market supports both **pre-run (stash)** and **mid-run** purchases, with persistent progression via a JSON save system.

* **Engine:** Godot 4.x
* **Language:** GDScript
* **Pattern:** Component-based with autoload singletons
* **UI:** CanvasLayer-based overlays with responsive layout

---

## Architecture

**High level**

* Data-driven catalogs for items & upgrades
* Centralized purchase logic (validation, price scaling)
* UI overlay that dynamically builds item/upgrade cards
* JSON save with migration

**Key autoloads**

* `GameState.gd`, `Save.gd`, `RNG.gd`

---

## Core Systems

### MarketDB

**Path:** `scripts/market/MarketDB.gd`
**Role:** Central DB for items & upgrades.
**Highlights:**

* Loads from `.tres` catalogs with **fallback** to hardcoded defs
* Manages up to **6 items** and **6 upgrades** out of the box

### MarketController

**Path:** `scripts/market/MarketController.gd`
**Role:** All purchase logic & validation.
**Highlights:**

* Price calculation with modifiers and **level-based scaling**
* Supports **pre-run stash** and **mid-run** purchases
* Signal-driven feedback

**Example flow**

```gdscript
func buy_item(item_def: ItemDef) -> bool:
	if not can_afford(item_def):
		purchase_denied.emit("Not enough coins")
		return false
	save.data.coins_banked -= item_def.cost
	save.add_item_to_stash(item_def.id)
	purchase_ok.emit("item", item_def.id)
	return true
```

### ShopOverlay

**Path:** `scripts/ui/ShopOverlay.gd`
**Role:** Main market UI.
**Highlights:**

* **Tabbed** (Upgrades / Items)
* Dynamic card generation
* Real-time loadout & affordability feedback
* Responsive layout

### Save System

**Path:** `scripts/autoload/Save.gd`
**Role:** Persistent player data.
**Highlights:**

* **JSON** save (`user://save.json`)
* Tracks coins, upgrades, owned items, loadout
* **Auto-save** after purchases/equips
* **Migration** for compatibility

---

## Content

### Items

All items are **active**, **common**, **stackable** (max stack `3`), with **max stash 15** (`5 × max_stack`).

| ID          | Name      | Cost | Description                               | Effect / Notes |
| ----------- | --------- | ---: | ----------------------------------------- | -------------- |
| `bomb`      | Bomb      |   80 | Clear all bullets on screen               | Active item    |
| `shield`    | Shield    |  120 | Grants a guard that blocks next damage    | Active item    |
| `coolant`   | Coolant   |  140 | Reduce heat by 1 tier for 10s             | Active item    |
| `harvester` | Harvester |  100 | Double coin pickups for 8s                | Active item    |
| `anchor`    | Anchor    |  130 | Freeze furnace for 2s (mobile phase only) | Active item    |
| `beacon`    | Beacon    |  160 | Force shrine spawn within 5s              | Active item    |

### Upgrades

All upgrades max at **level 5**. Price scales per curve (`steep`, `flat`, `default`).

| ID             | Name             | Stat Key       | Description                        | Max |
| -------------- | ---------------- | -------------- | ---------------------------------- | --: |
| `hp`           | Health Upgrade   | `hp`           | Increases player health            |   5 |
| `move`         | Speed Boost      | `move`         | Increases movement speed           |   5 |
| `dash_iframes` | Dash Enhancement | `dash_iframes` | Improves dash invincibility frames |   5 |
| `coin_rate`    | Coin Magnet      | `coin_rate`    | Increases coin collection rate     |   5 |
| `cashout`      | Fast Cashout     | `cashout`      | Speeds up coin banking             |   5 |
| `insurance`    | Death Insurance  | `insurance`    | Provides death protection benefits |   5 |

---

## UI/UX

**Visual**

* Dark theme with **amber/gold accents**
* Full-screen dim; centered panel (min **800×600**)
* Buttons color-coded: **green** (available), **red** (unavailable), **gray** (maxed)

**Layout**

* Header: Title + coins
* Tabs: **UPGRADES** / **ITEMS** with active-state styling
* Scroll area: Item/upgrade cards
* Footer: **3 loadout slots** (equip state feedback)

**Card Content**

* **Upgrades:** name, `Lv x/5`, description, cost, `[UPGRADE]`
* **Items:** name (`Owned: n`), description, rarity, cost, `[BUY] [EQUIP]`

**Interaction**

* Large, touch-friendly controls (buttons \~140×40, font 14px)
* Scrollable lists; responsive anchors

---

## Gameplay Integration

**Access Points**

* Start Menu (pre-run purchases/upgrades)
* Shrines (mid-run purchases with unbanked coins)
* Optional: Pause menu (if enabled)

**Economy**

* Start with **0** coins; earn via play
* Items: **80–160** coins
* Upgrades: **base cost + scaling** per curve

**Progression**

* Short-term: run-specific items
* Long-term: permanent upgrades
* Strategic **3-slot loadout**

---

## Project Structure

```
├── scripts/
│   ├── market/
│   │   ├── MarketController.gd
│   │   ├── MarketDB.gd
│   │   ├── catalogs/
│   │   │   ├── catalog_items.tres
│   │   │   └── catalog_upgrades.tres
│   │   ├── ItemDef.gd
│   │   ├── UpgradeDef.gd
│   │   ├── ItemEffect.gd
│   │   ├── ItemCatalog.gd
│   │   └── UpgradeCatalog.gd
│   ├── ui/
│   │   ├── ShopOverlay.gd
│   │   ├── StartOverlay.gd
│   │   ├── EndOverlay.gd
│   │   ├── UI.gd
│   │   └── TemptationModal.gd
│   ├── gameplay/
│   │   ├── Player.gd
│   │   ├── Arena.gd
│   │   ├── Furnace.gd
│   │   ├── Shrine.gd
│   │   ├── Bullet.gd
│   │   ├── BulletPool.gd
│   │   ├── PatternController.gd
│   │   ├── Specials.gd
│   │   ├── TemptationSpawner.gd
│   │   └── Pickup.gd
│   └── autoload/
│       ├── GameState.gd
│       ├── Save.gd
│       └── RNG.gd
├── scenes/
│   ├── ShopOverlay.tscn
│   ├── Main.tscn
│   ├── Player.tscn
│   ├── Arena.tscn
│   ├── UI.tscn
│   └── StartOverlay.tscn
├── art/
│   ├── Player-64x64.png
│   ├── bullets/
│   │   └── fireball-32x32.png
│   └── tilemap/
├── fonts/
├── audio/
└── project.godot
```

---

## Getting Started

### Prerequisites

* **Godot 4.x** (or later)
* Windows / macOS / Linux

### Clone

```bash
git clone https://github.com/dorukersoy47/brackeys-game-jam-2025-2.git
cd brackeys-game-jam-2025-2
```

### Open

1. Launch Godot
2. Import `project.godot`
3. Wait for imports to finish

### Run

* Press **F5** or click **Play**
* From the main menu, open the **Shop**, browse **Items/Upgrades**, and purchase with earned coins

---

## Development Notes

**Catalog System**

* Items/upgrades defined via `.tres` resources
* Hardcoded **fallback** if catalogs fail to load
* Easy to extend

**Purchase & Loadout**

* 3 **equip slots**
* Validation ensures only **owned** items equip
* Runtime effects supplied by item effect scenes

**Data Models**

```gdscript
# ItemDef.gd
class_name ItemDef
extends Resource
@export var id: StringName
@export var display_name: String
@export var desc: String
@export var cost: int
@export var kind: int      # 0 = ACTIVE
@export var stackable: bool
@export var max_stack: int
@export var rarity: String
@export var effect_scene: PackedScene
```

```gdscript
# UpgradeDef.gd
class_name UpgradeDef
extends Resource
@export var id: StringName
@export var display_name: String
@export var desc: String
@export var stat_key: String
@export var base_cost: int
@export var max_level: int
@export var curve: String  # "steep", "flat", "default"
```

**Save System**

* JSON at `user://save.json`
* Auto-saves on purchase/equip
* Migration keeps older saves compatible

---

## Known Issues

* Catalogs: Fallback to hardcoded defs if `.tres` load fails
* UI scaling: Very small screens may need refinement
* Performance: Very large lists can impact scroll performance

---

## Roadmap

* Purchase animations & enhanced feedback
* UI sound effects
* Full gamepad/controller navigation
* Localization (multi-language)
* Advanced filtering & sorting for large inventories

---

## Contributing

* Follow existing **GDScript** style and project conventions
* Maintain **UI consistency** with the defined design system
* Keep **save compatibility** (update migrations as needed)
* Optimize where possible for target platforms

**Adding Items**

1. Add to `catalog_items.tres`
2. Create effect scene under `scripts/market/effects/`
3. Ensure UI shows data correctly
4. Test purchase & equip

**Adding Upgrades**

1. Add to `catalog_upgrades.tres`
2. Implement stat handling in relevant systems
3. Balance base cost & curve
4. Test progression and effects

---

## License

Created for **Brackeys Game Jam 2025.2**.
Check individual asset/resource license files included in the repository.

---

## Acknowledgments

* **Brackeys Game Jam** — for the event and inspiration
* **Godot Engine** — for the engine and tooling
* **Community** — for feedback and support

---
