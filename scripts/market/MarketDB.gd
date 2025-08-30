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
				# Define items directly in code
				var item_definitions = [
								{
												"id": "bomb",
												"display_name": "Bomb",
												"desc": "Clear all bullets on screen",
												"cost": 80,
												"kind": 0,  # ACTIVE
												"stackable": true,
												"max_stack": 3,
												"rarity": "common",
												"effect_scene": preload("res://scripts/market/effects/BombEffect.tscn")
								},
								{
												"id": "shield",
												"display_name": "Shield",
												"desc": "Grants one temporary guard that blocks next damage",
												"cost": 120,
												"kind": 0,  # ACTIVE
												"stackable": true,
												"max_stack": 3,
												"rarity": "common",
												"effect_scene": preload("res://scripts/market/effects/ShieldEffect.tscn")
								},
								{
												"id": "coolant",
												"display_name": "Coolant",
												"desc": "Reduce heat by 1 tier for 10s",
												"cost": 140,
												"kind": 0,  # ACTIVE
												"stackable": true,
												"max_stack": 3,
												"rarity": "common",
												"effect_scene": preload("res://scripts/market/effects/CoolantEffect.tscn")
								},
								{
												"id": "harvester",
												"display_name": "Harvester",
												"desc": "Double coin pickups for 8s",
												"cost": 100,
												"kind": 0,  # ACTIVE
												"stackable": true,
												"max_stack": 3,
												"rarity": "common",
												"effect_scene": preload("res://scripts/market/effects/HarvesterEffect.tscn")
								},
								{
												"id": "anchor",
												"display_name": "Anchor",
												"desc": "Freeze furnace for 2s, mobile phase only",
												"cost": 130,
												"kind": 0,  # ACTIVE
												"stackable": true,
												"max_stack": 3,
												"rarity": "common",
												"effect_scene": preload("res://scripts/market/effects/AnchorEffect.tscn")
								},
								{
												"id": "beacon",
												"display_name": "Beacon",
												"desc": "Force shrine spawn within 5s",
												"cost": 160,
												"kind": 0,  # ACTIVE
												"stackable": true,
												"max_stack": 3,
												"rarity": "common",
												"effect_scene": preload("res://scripts/market/effects/BeaconEffect.tscn")
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
				# For now, all active items are considered one-time use
				var item = get_item(id)
				if item:
						return item.kind == ItemDef.Kind.ACTIVE
				return false
