class_name RunInventory
extends Node
signal changed

var items := {}  # {id: count}, only for run lifespan
var equipped := []  # ids (copied from Save.loadout at run start)
var max_slots := 3  # tunable, upgradeable later if desired
var active_item_cursor := 0

@onready var market_db: MarketDB = get_node("/root/DB")
@onready var save: Node = get_node("/root/Save")

func _ready() -> void:
		add_to_group("RunInventory")

func setup_for_run(save_data, market_db_ref):
		items.clear()
		equipped = save_data.loadout.duplicate()
		
		# Add equipped items to run inventory
		for id in equipped:
				items[id] = (items.get(id, 0) + 1)
		
		active_item_cursor = 0
		emit_signal("changed")

func add_item(id: StringName, count: int = 1):
		var item_def = market_db.get_item(id)
		if not item_def:
				return
		
		items[id] = clamp(items.get(id, 0) + count, 0, item_def.max_stack)
		emit_signal("changed")

func consume(id: StringName) -> bool:
		if items.get(id, 0) <= 0: 
				return false
		
		items[id] -= 1
		if items[id] <= 0:
				items.erase(id)
		
		emit_signal("changed")
		return true

func count(id: StringName) -> int:
		return items.get(id, 0)

func get_equipped_items() -> Array:
		return equipped.duplicate()

func get_active_item() -> StringName:
		if equipped.is_empty():
				return ""
		return equipped[active_item_cursor]

func cycle_active_item():
		if equipped.size() <= 1:
				return
		
		active_item_cursor = (active_item_cursor + 1) % equipped.size()
		emit_signal("changed")

func set_active_item_cursor(index: int):
		if index >= 0 and index < equipped.size():
				active_item_cursor = index
				emit_signal("changed")

func can_equip_item(id: StringName) -> bool:
		return equipped.size() < max_slots and count(id) > 0

func equip_item(id: StringName) -> bool:
		if not can_equip_item(id):
				return false
		
		equipped.append(id)
		emit_signal("changed")
		return true

func unequip_item(id: StringName) -> bool:
		var index = equipped.find(id)
		if index == -1:
				return false
		
		equipped.remove_at(index)
		if active_item_cursor >= equipped.size() and equipped.size() > 0:
				active_item_cursor = equipped.size() - 1
		
		emit_signal("changed")
		return true
