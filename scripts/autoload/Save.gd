extends Node
# NOTE: Do NOT give this script a `class_name` if your autoload is also named "Save".
# That avoids the class-vs-singleton name collision.

const SAVE_PATH := "user://save.json"

# Explicitly type the dictionary to avoid "inferred from Variant" warnings.
var data: Dictionary = {
				"schema_version": 2,
				"coins_banked": 0,
				"upgrades": {
								"hp": 1, "dash_iframes": 0, "move": 0,
								"coin_rate": 0, "cashout": 0, "free_hit": 0
				},
				"streak": 0,
				"best": {"survival": 0.0, "peak_bm": 1.0, "biscuits": 0},
				"options": {"screenshake": true, "reduced_flash": false, "insurance": false},
				"items_owned": {
								"bomb": 0,
								"shield": 0,
								"coolant": 0,
								"harvester": 0,
								"anchor": 0,
								"beacon": 0
				},
				"loadout": []
}

# Runtime-only cache - not persisted across app restarts
var unbanked_tips: int = 0

func _ready() -> void:
				load_game()

func load_game() -> void:
				if not FileAccess.file_exists(SAVE_PATH):
								save_game()
								return
				var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
				if f:
								var txt: String = f.get_as_text()
								var parsed: Variant = JSON.parse_string(txt)
								if typeof(parsed) == TYPE_DICTIONARY:
												data = (parsed as Dictionary)
												# Migration: ensure new fields exist
												_migrate_save_data()

func _migrate_save_data() -> void:
				# Schema version migration
				var schema_version = data.get("schema_version", 1)
				
				# Migration v1 → v2
				if schema_version < 2:
						# Ensure coins_banked exists
						if not data.has("coins_banked"):
								data["coins_banked"] = 0
						
						# Set schema version to 2
						data["schema_version"] = 2
				
				# Ensure items_owned exists
				if not data.has("items_owned"):
								data["items_owned"] = {
												"bomb": 0,
												"shield": 0,
												"coolant": 0,
												"harvester": 0,
												"anchor": 0,
												"beacon": 0
								}
				
				# Ensure loadout exists
				if not data.has("loadout"):
								data["loadout"] = []
				
				# Ensure all item types exist in items_owned
				var default_items = ["bomb", "shield", "coolant", "harvester", "anchor", "beacon"]
				var items_owned = data["items_owned"] as Dictionary
				for item in default_items:
								if not items_owned.has(item):
												items_owned[item] = 0

func save_game() -> void:
				# Atomic save: write to temporary file first, then rename
				var temp_path := SAVE_PATH + ".tmp"
				var f := FileAccess.open(temp_path, FileAccess.WRITE)
				if f:
						f.store_string(JSON.stringify(data))
						f.close()
						# Rename temporary file to actual save file
						var dir := DirAccess.open("user://")
						if dir:
								dir.rename(temp_path.get_file(), SAVE_PATH.get_file())
				else:
						# Fallback to direct write if atomic write fails
						f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
						if f:
								f.store_string(JSON.stringify(data))

func add_bank(amount: int) -> void:
				var safe_amount: int = max(amount, 0)
				var current: int = int(data.get("coins_banked", 0))
				data["coins_banked"] = current + safe_amount
				save_game()

func set_option(key: String, value: Variant) -> void:
				var opts: Dictionary = (data.get("options", {}) as Dictionary)
				opts[key] = value
				data["options"] = opts
				save_game()

func get_upgrade(key: String) -> int:
				var ups: Dictionary = (data.get("upgrades", {}) as Dictionary)
				return int(ups.get(key, 0))

func inc_upgrade(key: String) -> void:
				var ups: Dictionary = (data.get("upgrades", {}) as Dictionary)
				ups[key] = int(ups.get(key, 0)) + 1
				data["upgrades"] = ups
				save_game()

# Item management methods
func get_item_count(id: StringName) -> int:
				return int(data.items_owned.get(id, 0))

func add_item_to_stash(id: StringName, n: int = 1) -> void:
				data.items_owned[id] = get_item_count(id) + n
				save_game()

func consume_item_from_stash(id: StringName, n: int = 1) -> bool:
				var c := get_item_count(id)
				if c < n: return false
				data.items_owned[id] = c - n
				save_game()
				return true

func set_loadout(ids: Array) -> void:
				data.loadout = ids.duplicate()
				save_game()

func get_loadout() -> Array:
				return data.loadout.duplicate()

func do_death_cleanup() -> void:
				# Death cleanup: wipe unbanked coins and unused consumables
				unbanked_tips = 0
				
				# Remove unused consumables from owned inventory
				# Keep only items that are equipped in the loadout
				var equipped_items = data.loadout.duplicate()
				var items_to_keep = {}
				
				# Count how many of each item are equipped
				for item_id in equipped_items:
						items_to_keep[item_id] = items_to_keep.get(item_id, 0) + 1
				
				# Reset all item counts to 0
				for item_id in data.items_owned:
						data.items_owned[item_id] = 0
				
				# Restore only the equipped items
				for item_id in items_to_keep:
						data.items_owned[item_id] = items_to_keep[item_id]
				
				# Save the changes
				save_game()
