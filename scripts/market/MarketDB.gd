extends Node
class_name MarketDB

var upgrades: Dictionary = {}  # id -> UpgradeDef
var items: Dictionary = {}     # id -> ItemDef

const UPGRADE_CATALOG_PATH := "res://scripts/market/catalogs/catalog_upgrades.tres"
const ITEM_CATALOG_PATH    := "res://scripts/market/catalogs/catalog_items.tres"

func _ready() -> void:
								print("=== MARKETDB _READY START ===")
								_load_catalogs()
								print("MarketDB _ready completed")
								print("Final items in MarketDB: ", items.keys())
								print("Final upgrades in MarketDB: ", upgrades.keys())
								print("=== MARKETDB _READY END ===")

func _load_catalogs() -> void:
								print("=== MARKETDB _LOAD_CATALOGS START ===")
								# Try to load from catalogs first
								var catalog_loaded = false
								
								# Upgrades
								print("Loading upgrade catalog from: ", UPGRADE_CATALOG_PATH)
								var upgrade_catalog: Resource = load(UPGRADE_CATALOG_PATH)
								if upgrade_catalog == null:
																print("ERROR: Upgrade catalog not found at ", UPGRADE_CATALOG_PATH)
																push_warning("MarketDB: upgrade catalog not found at %s" % UPGRADE_CATALOG_PATH)
								else:
																print("Upgrade catalog loaded successfully: ", upgrade_catalog)
																# Try different ways to get upgrades
																var upgrades_array = null
																if upgrade_catalog.has_method("get_upgrades"):
																								upgrades_array = upgrade_catalog.get_upgrades()
																								print("Got upgrades via get_upgrades method")
																elif "upgrades" in upgrade_catalog:
																								upgrades_array = upgrade_catalog.get("upgrades")
																								print("Got upgrades via 'upgrades' property")
																else:
																								# Try to get as property
																								upgrades_array = upgrade_catalog.get("upgrades")
																								print("Got upgrades via direct property access")
																
																if upgrades_array != null:
																								print("Upgrades array size: ", upgrades_array.size())
																								for u in upgrades_array:
																																if u:
																																								upgrades[u.id] = u
																																								print("Loaded upgrade: ", u.id, " - ", u.display_name)
																								catalog_loaded = true
																else:
																								print("ERROR: Could not get upgrades array from catalog")
																								push_warning("MarketDB: catalog_upgrades.tres has no 'upgrades' array. Is it an UpgradeCatalog resource?")

								# Items
								print("Loading item catalog from: ", ITEM_CATALOG_PATH)
								var item_catalog: Resource = load(ITEM_CATALOG_PATH)
								if item_catalog == null:
																print("ERROR: Item catalog not found at ", ITEM_CATALOG_PATH)
																push_warning("MarketDB: item catalog not found at %s" % ITEM_CATALOG_PATH)
								else:
																print("Item catalog loaded successfully: ", item_catalog)
																# Try different ways to get items
																var items_array = null
																if item_catalog.has_method("get_items"):
																								items_array = item_catalog.get_items()
																								print("Got items via get_items method")
																elif "items" in item_catalog:
																								items_array = item_catalog.get("items")
																								print("Got items via 'items' property")
																else:
																								# Try to get as property
																								items_array = item_catalog.get("items")
																								print("Got items via direct property access")
																
																if items_array != null:
																								print("Items array size: ", items_array.size())
																								for it in items_array:
																																if it:
																																								items[it.id] = it
																																								print("Loaded item: ", it.id, " - ", it.display_name)
																								catalog_loaded = true
																else:
																								print("ERROR: Could not get items array from catalog")
																								push_warning("MarketDB: catalog_items.tres has no 'items' array. Is it an ItemCatalog resource?")
								
								# Fallback: Load items directly if catalog failed
								if not catalog_loaded or items.size() == 0:
																print("Catalog loading failed, using fallback direct loading...")
																_load_items_fallback()
								
								print("Final items count: ", items.size())
								print("Final upgrades count: ", upgrades.size())
								print("=== MARKETDB _LOAD_CATALOGS END ===")

func _load_items_fallback() -> void:
								print("=== MARKETDB _LOAD_ITEMS_FALLBACK START ===")
								# Define items directly in code with new tool names and effects
								var item_definitions = [
																{
																								"id": "flour_burst",
																								"display_name": "Flour Burst",
																								"desc": "Clear all bullets on screen + 2s dust cloud (reduces visibility by ~20% alpha overlay)",
																								"cost": 80,
																								"kind": 0,  # ACTIVE
																								"stackable": true,
																								"max_stack": 3,
																								"rarity": "common",
																								"effect_scene": preload("res://scripts/market/effects/FlourBurstEffect.tscn"),
																								"one_time_use": true
																},
																{
																								"id": "oven_mitt",
																								"display_name": "Oven Mitt",
																								"desc": "Arms after 0.7s; blocks next hit",
																								"cost": 120,
																								"kind": 0,  # ACTIVE
																								"stackable": true,
																								"max_stack": 3,
																								"rarity": "common",
																								"effect_scene": preload("res://scripts/market/effects/OvenMittEffect.tscn"),
																								"one_time_use": true
																},
																{
																								"id": "ice_bath",
																								"display_name": "Ice Bath",
																								"desc": "Drop heat tier (when Heat exists) or −pattern speed 10% for 10s; while active −10% tips multiplier",
																								"cost": 140,
																								"kind": 0,  # ACTIVE
																								"stackable": true,
																								"max_stack": 3,
																								"rarity": "uncommon",
																								"effect_scene": preload("res://scripts/market/effects/IceBathEffect.tscn"),
																								"one_time_use": true
																},
																{
																								"id": "tip_jar",
																								"display_name": "Tip Jar",
																								"desc": "8s double tips; magnet also tugs minor hazards (very low force)",
																								"cost": 100,
																								"kind": 0,  # ACTIVE
																								"stackable": true,
																								"max_stack": 3,
																								"rarity": "common",
																								"effect_scene": preload("res://scripts/market/effects/TipJarEffect.tscn"),
																								"one_time_use": true
																},
																{
																								"id": "proofing_weight",
																								"display_name": "Proofing Weight",
																								"desc": "Freeze moving hazards 2s; roots player 0.3s on cast",
																								"cost": 130,
																								"kind": 0,  # ACTIVE
																								"stackable": true,
																								"max_stack": 3,
																								"rarity": "uncommon",
																								"effect_scene": preload("res://scripts/market/effects/ProofingWeightEffect.tscn"),
																								"one_time_use": true
																},
																{
																								"id": "till_sweep",
																								"display_name": "Till Sweep",
																								"desc": "Instantly bank +100 tips; −10% total multiplier for 30s (when Heat/Graze integrate later)",
																								"cost": 160,
																								"kind": 0,  # ACTIVE
																								"stackable": true,
																								"max_stack": 3,
																								"rarity": "rare",
																								"effect_scene": preload("res://scripts/market/effects/TillSweepEffect.tscn"),
																								"one_time_use": true
																}
								]
								
								print("Creating ", item_definitions.size(), " items via fallback...")
								for item_data in item_definitions:
																var item = ItemDef.new()
																item.id = item_data.id
																item.display_name = item_data.display_name
																item.desc = item_data.desc
																item.cost = item_data.cost
																item.kind = item_data.kind
																item.stackable = item_data.stackable
																item.max_stack = item_data.max_stack
																item.rarity = item_data.rarity
																item.effect_scene = item_data.effect_scene
																item.one_time_use = item_data.one_time_use
																
																items[item.id] = item
																print("Fallback created item: ", item.id, " - ", item.display_name)
								
								print("=== MARKETDB _LOAD_ITEMS_FALLBACK END ===")

func get_upgrade(id: StringName) -> UpgradeDef:
								return upgrades.get(id, null)

func get_item(id: StringName) -> ItemDef:
								return items.get(id, null)

func get_all_upgrades() -> Array:
								return upgrades.values()

func get_all_items() -> Array:
								return items.values()

func is_one_time_use(id: StringName) -> bool:
								# Check if an item is one-time use
								var item = get_item(id)
								if item:
												return item.one_time_use
								return false

func get_tool_description(id: StringName) -> String:
								# Get a formatted description for tool UI
								var item = get_item(id)
								if item:
												var desc = item.display_name
												if item.one_time_use:
																desc += " (One-Time Use)"
												desc += "\n" + item.desc
												desc += "\nCost: %d 🪙" % item.cost
												return desc
								return "Unknown Tool"

func get_all_tools() -> Array:
								# Get all one-time use items (tools)
								var tools = []
								for item in items.values():
												if item.one_time_use:
																tools.append(item)
								return tools

func get_tool_by_index(index: int) -> ItemDef:
								# Get tool by index (useful for UI)
								var tools = get_all_tools()
								if index >= 0 and index < tools.size():
												return tools[index]
								return null
