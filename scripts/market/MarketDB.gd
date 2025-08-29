extends Node
class_name MarketDB

var upgrades: Dictionary = {}  # id -> UpgradeDef
var items: Dictionary = {}     # id -> ItemDef

const UPGRADE_CATALOG_PATH := "res://scripts/market/catalogs/catalog_upgrades.tres"
const ITEM_CATALOG_PATH    := "res://scripts/market/catalogs/catalog_items.tres"

func _ready() -> void:
	_load_catalogs()

func _load_catalogs() -> void:
	# Upgrades
	var upgrade_catalog: Resource = load(UPGRADE_CATALOG_PATH)
	if upgrade_catalog == null:
		push_warning("MarketDB: upgrade catalog not found at %s" % UPGRADE_CATALOG_PATH)
	else:
		if "upgrades" in upgrade_catalog:
			var arr: Array = upgrade_catalog.get("upgrades")
			for u in arr:
				if u:
					upgrades[u.id] = u
		else:
			push_warning("MarketDB: catalog_upgrades.tres has no 'upgrades' array. Is it an UpgradeCatalog resource?")

	# Items
	var item_catalog: Resource = load(ITEM_CATALOG_PATH)
	if item_catalog == null:
		push_warning("MarketDB: item catalog not found at %s" % ITEM_CATALOG_PATH)
	else:
		if "items" in item_catalog:
			var arr2: Array = item_catalog.get("items")
			for it in arr2:
				if it:
					items[it.id] = it
		else:
			push_warning("MarketDB: catalog_items.tres has no 'items' array. Is it an ItemCatalog resource?")

func get_upgrade(id: StringName) -> UpgradeDef:
	return upgrades.get(id, null)

func get_item(id: StringName) -> ItemDef:
	return items.get(id, null)

func get_all_upgrades() -> Array:
	return upgrades.values()

func get_all_items() -> Array:
	return items.values()
