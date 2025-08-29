extends CanvasLayer
class_name ShopOverlay

signal closed

@export var pause_game: bool = true

@export var dim_path: NodePath
@export var panel_path: NodePath
@export var close_button_path: NodePath
@export var tab_upgrades_path: NodePath
@export var tab_items_path: NodePath
@export var coins_label_path: NodePath
@export var list_container_path: NodePath

@onready var save_node: Node = get_node("/root/Save")

var dim: ColorRect
var panel: Panel
var btn_close: Button
var btn_tab_up: Button
var btn_tab_it: Button
var lbl_coins: Label
var list_container: VBoxContainer

var shop_items: Array = [
	{"id":"health_upgrade","name":"Health Upgrade","description":"Increase max HP by 1","cost":100,"max_level":5,"upgrade_key":"hp"},
	{"id":"speed_upgrade","name":"Speed Boost","description":"Increase movement speed by 10%","cost":80,"max_level":3,"upgrade_key":"move"},
	{"id":"dash_upgrade","name":"Dash Enhancement","description":"Increase dash invulnerability frames","cost":120,"max_level":3,"upgrade_key":"dash_iframes"},
	{"id":"coin_magnet","name":"Coin Magnet","description":"Increase coin collection range","cost":150,"max_level":2,"upgrade_key":"coin_rate"},
	{"id":"fast_cashout","name":"Fast Cashout","description":"Reduce cashout channeling time","cost":90,"max_level":3,"upgrade_key":"cashout"},
	{"id":"insurance","name":"Death Insurance","description":"Salvage 5% of coins on death","cost":200,"max_level":1,"upgrade_key":"insurance"}
]

func _ready() -> void:
	# HIGHER than StartOverlay
	layer = max(layer, 200)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true

	_resolve_refs()
	_setup_modal_behavior()
	_connect_buttons()
	_update_coins_label()
	_show_upgrades_tab()

	# Only pause if opened from gameplay; Start menu will set pause_game=false
	if pause_game:
		get_tree().paused = true

func _exit_tree() -> void:
	if pause_game:
		get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close()

# ---------- Setup ----------

func _resolve_refs() -> void:
	dim = _get_node_safe(dim_path, "Dim") as ColorRect
	panel = _get_node_safe(panel_path, "Panel") as Panel
	btn_close = _get_node_safe(close_button_path, "CloseButton") as Button
	btn_tab_up = _get_node_safe(tab_upgrades_path, "TabUpgrades") as Button
	btn_tab_it = _get_node_safe(tab_items_path, "TabItems") as Button
	lbl_coins = _get_node_safe(coins_label_path, "CoinsLabel") as Label
	list_container = _get_node_safe(list_container_path, "ItemsList") as VBoxContainer

func _get_node_safe(path: NodePath, fallback: String) -> Node:
	if path != NodePath("") and has_node(path):
		return get_node(path)
	return find_child(fallback, true, false)

func _setup_modal_behavior() -> void:
	# Dim should block clicks to the StartOverlay behind
	if dim:
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
		dim.z_index = 0
		# ensure full screen coverage
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	if panel:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.z_index = 1

func _connect_buttons() -> void:
	if btn_close and not btn_close.pressed.is_connected(_on_close):
		btn_close.pressed.connect(_on_close)
	if btn_tab_up and not btn_tab_up.pressed.is_connected(_show_upgrades_tab):
		btn_tab_up.pressed.connect(_show_upgrades_tab)
	if btn_tab_it and not btn_tab_it.pressed.is_connected(_show_items_tab):
		btn_tab_it.pressed.connect(_show_items_tab)

# ---------- Close ----------

func _on_close() -> void:
	emit_signal("closed")
	queue_free()

# ---------- Tabs / UI ----------

func _show_upgrades_tab() -> void:
	_clear_list()
	_populate_upgrades()

func _show_items_tab() -> void:
	_clear_list()
	_populate_items_placeholder()

func _update_coins_label() -> void:
	if lbl_coins and typeof(save_node) == TYPE_OBJECT:
		var coins := int((save_node.get("data") as Dictionary).get("coins_banked", 0))
		lbl_coins.text = "Coins: %d" % coins

func _clear_list() -> void:
	if list_container:
		for c in list_container.get_children():
			c.queue_free()

func _populate_upgrades() -> void:
	if list_container == null or typeof(save_node) != TYPE_OBJECT:
		return
	var data := save_node.get("data") as Dictionary
	var ups := data.get("upgrades", {}) as Dictionary
	var coins := int(data.get("coins_banked", 0))

	for item_dict in shop_items:
		var item := item_dict as Dictionary
		var level := int(ups.get(item.get("upgrade_key"), 0))
		var max_level := int(item.get("max_level"))
		var cost := int(item.get("cost"))
		var can_upgrade := level < max_level
		var can_afford := coins >= cost

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_lbl := Label.new()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.text = "%s (Lv %d/%d)" % [item.get("name"), level, max_level]
		row.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = str(item.get("description"))
		desc_lbl.add_theme_color_override("font_color", Color.GRAY)
		row.add_child(desc_lbl)

		var buy_btn := Button.new()
		if can_upgrade and can_afford:
			buy_btn.text = "Buy %d" % cost
			buy_btn.pressed.connect(func(): _buy_upgrade(item))
		elif not can_upgrade:
			buy_btn.text = "MAX"
			buy_btn.disabled = true
		else:
			buy_btn.text = "Can't Afford"
			buy_btn.disabled = true
		row.add_child(buy_btn)

		list_container.add_child(row)

func _populate_items_placeholder() -> void:
	if list_container == null:
		return
	var info := Label.new()
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.text = "Consumables coming soon!"
	info.add_theme_font_size_override("font_size", 18)
	list_container.add_child(info)

func _buy_upgrade(item: Dictionary) -> void:
	if typeof(save_node) != TYPE_OBJECT:
		return
	var data := save_node.get("data") as Dictionary
	var coins := int(data.get("coins_banked", 0))
	var cost := int(item.get("cost"))

	if coins < cost:
		return

	data["coins_banked"] = coins - cost

	var ups := data.get("upgrades", {}) as Dictionary
	var key := str(item.get("upgrade_key"))
	ups[key] = int(ups.get(key, 0)) + 1
	data["upgrades"] = ups

	if save_node.has_method("save_game"):
		save_node.call("save_game")

	_update_coins_label()
	_show_upgrades_tab()
