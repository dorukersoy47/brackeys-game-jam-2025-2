@tool
extends Node

const ITEM_DEF_PATH := "res://scripts/market/ItemDef.gd"
const UPGRADE_DEF_PATH := "res://scripts/market/UpgradeDef.gd"

const OUT_ITEMS_DIR := "res://scripts/market/items"
const OUT_UPGRADES_DIR := "res://scripts/market/upgrades"
const ITEM_CATALOG_PATH := "res://scripts/market/catalogs/catalog_items.tres"
const UPGRADE_CATALOG_PATH := "res://scripts/market/catalogs/catalog_upgrades.tres"

# Paste your JSON arrays here:
const ITEMS := [
	{"id":"bomb","display_name":"Bomb","desc":"Clear all bullets on screen","cost":80,"kind":0,"stackable":true,"max_stack":3,"rarity":"common","effect_scene":"res://scripts/market/effects/BombEffect.tscn"},
	{"id":"shield","display_name":"Shield","desc":"Grants one temporary guard that blocks next damage","cost":120,"kind":0,"stackable":true,"max_stack":3,"rarity":"common","effect_scene":"res://scripts/market/effects/ShieldEffect.tscn"},
	{"id":"coolant","display_name":"Coolant","desc":"Reduce heat by 1 tier and slow heat growth for 10s","cost":140,"kind":0,"stackable":true,"max_stack":3,"rarity":"uncommon","effect_scene":"res://scripts/market/effects/CoolantEffect.tscn"},
	{"id":"harvester","display_name":"Harvester","desc":"Double coin collection rate for 8 seconds","cost":100,"kind":0,"stackable":true,"max_stack":3,"rarity":"common","effect_scene":"res://scripts/market/effects/HarvesterEffect.tscn"},
	{"id":"anchor","display_name":"Anchor","desc":"Freeze furnace movement and attacks for 2 seconds (mobile phase only)","cost":130,"kind":0,"stackable":true,"max_stack":3,"rarity":"uncommon","effect_scene":"res://scripts/market/effects/AnchorEffect.tscn"},
	{"id":"beacon","display_name":"Beacon","desc":"Force a shrine to spawn within 5 seconds","cost":160,"kind":0,"stackable":true,"max_stack":3,"rarity":"rare","effect_scene":"res://scripts/market/effects/BeaconEffect.tscn"}
]
const UPGRADES := [
	{"id":"hp","display_name":"Health Upgrade","desc":"Increase max HP by 1","base_cost":100,"max_level":5,"curve":"linear","stat_key":"hp","per_level_value":1.0},
	{"id":"move","display_name":"Speed Boost","desc":"Increase movement speed by 10%","base_cost":80,"max_level":3,"curve":"linear","stat_key":"move","per_level_value":0.1},
	{"id":"dash_iframes","display_name":"Dash Enhancement","desc":"Increase dash invulnerability frames","base_cost":120,"max_level":3,"curve":"linear","stat_key":"dash_iframes","per_level_value":0.05},
	{"id":"coin_rate","display_name":"Coin Magnet","desc":"Increase coin collection range","base_cost":150,"max_level":2,"curve":"linear","stat_key":"coin_rate","per_level_value":0.2},
	{"id":"cashout","display_name":"Fast Cashout","desc":"Reduce cashout channeling time","base_cost":90,"max_level":3,"curve":"linear","stat_key":"cashout","per_level_value":0.2},
	{"id":"insurance","display_name":"Death Insurance","desc":"Salvage 5% of coins on death","base_cost":200,"max_level":1,"curve":"linear","stat_key":"insurance","per_level_value":1.0}
]

@export var run_import := false : set = _set_run_import

func _set_run_import(v: bool) -> void:
	if not v: return
	_import_all()
	run_import = false
	print("✅ Catalog import complete.")

func _import_all() -> void:
	var ItemDef = load(ITEM_DEF_PATH)
	var UpgradeDef = load(UPGRADE_DEF_PATH)
	if ItemDef == null or UpgradeDef == null:
		push_error("Missing ItemDef/UpgradeDef. Check paths.")
		return

	DirAccess.make_dir_recursive_absolute(OUT_ITEMS_DIR)
	DirAccess.make_dir_recursive_absolute(OUT_UPGRADES_DIR)

	var item_paths: Array[String] = []
	for d in ITEMS:
		var r: Resource = ItemDef.new()
		r.id = d.id
		r.display_name = d.display_name
		r.desc = d.desc
		r.cost = d.cost
		r.kind = int(d.kind)  # 0=ACTIVE
		r.stackable = bool(d.stackable)
		r.max_stack = int(d.max_stack)
		r.rarity = StringName(d.rarity)
		r.effect_scene = load(d.effect_scene)
		var path := "%s/%s.tres" % [OUT_ITEMS_DIR, d.id]
		var err := ResourceSaver.save(r, path)
		if err != OK: push_error("Save failed: %s (%s)" % [path, err])
		item_paths.append(path)

	var up_paths: Array[String] = []
	for d in UPGRADES:
		var r: Resource = UpgradeDef.new()
		r.id = d.id
		r.display_name = d.display_name
		r.desc = d.desc
		r.base_cost = int(d.base_cost)
		r.max_level = int(d.max_level)
		r.curve = StringName(d.curve)
		r.stat_key = StringName(d.stat_key)
		r.per_level_value = float(d.per_level_value)
		var path := "%s/%s.tres" % [OUT_UPGRADES_DIR, d.id]
		var err := ResourceSaver.save(r, path)
		if err != OK: push_error("Save failed: %s (%s)" % [path, err])
		up_paths.append(path)

	# (Optional) Fill catalogs if they exist:
	var item_catalog := load(ITEM_CATALOG_PATH)
	if item_catalog and "items" in item_catalog:
		item_catalog.items = []
		for p in item_paths: item_catalog.items.append(load(p))
		ResourceSaver.save(item_catalog, ITEM_CATALOG_PATH)

	var up_catalog := load(UPGRADE_CATALOG_PATH)
	if up_catalog and "upgrades" in up_catalog:
		up_catalog.upgrades = []
		for p in up_paths: up_catalog.upgrades.append(load(p))
		ResourceSaver.save(up_catalog, UPGRADE_CATALOG_PATH)
