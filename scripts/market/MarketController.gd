extends Node
class_name MarketController

signal purchase_ok(kind: StringName, id: StringName)
signal purchase_denied(reason: String)

var price_modifiers := {
		"shrine_markup": 1.25,
		"rotation_discount": 0.9,
}

@onready var market_db: MarketDB = get_node("/root/DB")
@onready var save: Node = get_node("/root/Save")

func _ready() -> void:
		# (Optional) Local log
		if not purchase_ok.is_connected(_on_purchase_ok):
				purchase_ok.connect(_on_purchase_ok)
		if not purchase_denied.is_connected(_on_purchase_denied):
				purchase_denied.connect(_on_purchase_denied)

func get_upgrade_price(def: UpgradeDef) -> int:
		var lvl: int = int(save.get_upgrade(def.stat_key))
		var k: float
		match def.curve:
				"steep":
						k = 1.35
				"flat":
						k = 1.10
				_:
						k = 1.20
		return int(round(def.base_cost * pow(k, max(0, lvl - 1))))

func can_buy_upgrade(def: UpgradeDef) -> bool:
		var lvl: int = int(save.get_upgrade(def.stat_key))
		if lvl >= def.max_level:
				return false
		return int(save.data.coins_banked) >= get_upgrade_price(def)

func buy_upgrade(def: UpgradeDef) -> bool:
		if not can_buy_upgrade(def):
				purchase_denied.emit("Not enough coins or max level.")
				return false
		var cost: int = get_upgrade_price(def)
		save.data.coins_banked = int(save.data.coins_banked) - cost
		save.inc_upgrade(def.stat_key)
		purchase_ok.emit("upgrade", def.id)
		return true

func can_buy_item(def: ItemDef, count: int = 1) -> bool:
		return int(save.data.coins_banked) >= def.cost * count

func buy_item_to_stash(def: ItemDef, count: int = 1) -> bool:
		if not can_buy_item(def, count):
				purchase_denied.emit("Not enough coins.")
				return false
		var cost: int = def.cost * count
		save.data.coins_banked = int(save.data.coins_banked) - cost
		save.add_item_to_stash(def.id, count)
		purchase_ok.emit("item", def.id)
		return true

# Mid-run purchases disabled - pre-run only
func buy_item_midrun(gs: Node, run_inv: Node, def: ItemDef, shrine_price: int) -> bool:
		purchase_denied.emit("Mid-run purchases disabled. Use pre-run market only.")
		return false

func _on_purchase_ok(kind: StringName, id: StringName) -> void:
		print("Purchase OK: ", kind, " ", id)

func _on_purchase_denied(reason: String) -> void:
		print("Purchase denied: ", reason)
