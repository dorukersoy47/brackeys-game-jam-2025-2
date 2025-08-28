extends CanvasLayer

signal overlay_closed

# Autoloads
var save: Node = null
var gs: GameStateData = null

# Scene refs
var _root: Control = null
var _dim: ColorRect = null
var _panel: Panel = null
var _title: Label = null
var _btn_close: Button = null
var _coins_lbl: Label = null
var _btn_upgrades: Button = null
var _btn_items: Button = null
var _items_container: VBoxContainer = null

var current_category: String = "upgrades"

var shop_items: Array[Dictionary] = [
	{"id":"health_upgrade","name":"Health Upgrade","description":"Increase max HP by 1","cost":100,"max_level":5,"upgrade_key":"hp"},
	{"id":"speed_upgrade","name":"Speed Boost","description":"Increase movement speed by 10%","cost":80,"max_level":3,"upgrade_key":"move"},
	{"id":"dash_upgrade","name":"Dash Enhancement","description":"Increase dash invulnerability frames","cost":120,"max_level":3,"upgrade_key":"dash_iframes"},
	{"id":"coin_magnet","name":"Coin Magnet","description":"Increase coin collection range","cost":150,"max_level":2,"upgrade_key":"coin_rate"},
	{"id":"fast_cashout","name":"Fast Cashout","description":"Reduce cashout channeling time","cost":90,"max_level":3,"upgrade_key":"cashout"},
	{"id":"insurance","name":"Death Insurance","description":"Salvage 5% of coins on death","cost":200,"max_level":1,"upgrade_key":"insurance"}
]

func _ready() -> void:
	# Layer below StartOverlay (100) but above game UI (50)
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS

	save = get_node_or_null("/root/Save")
	gs = get_node_or_null("/root/GameState") as GameStateData

	_resolve_refs()
	_harden_input()

	if not _validate_required_nodes():
		push_error("[ShopOverlay] Missing required nodes. Check scene paths.")
		return

	if _btn_close and not _btn_close.pressed.is_connected(_on_close):
		_btn_close.pressed.connect(_on_close)
	if _btn_upgrades and not _btn_upgrades.pressed.is_connected(func(): _show_category("upgrades")):
		_btn_upgrades.pressed.connect(func(): _show_category("upgrades"))
	if _btn_items and not _btn_items.pressed.is_connected(func(): _show_category("items")):
		_btn_items.pressed.connect(func(): _show_category("items"))

	_update_coins_label()
	_show_category("upgrades")
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close()

func _resolve_refs() -> void:
	_root = get_node_or_null("Root") as Control
	_dim = get_node_or_null("Root/Dim") as ColorRect
	_panel = get_node_or_null("Root/Center/Panel") as Panel
	_title = get_node_or_null("Root/Center/Panel/VBox/Header/Title") as Label
	_btn_close = get_node_or_null("Root/Center/Panel/VBox/Header/Close") as Button
	_coins_lbl = get_node_or_null("Root/Center/Panel/VBox/Bar/CoinsLabel") as Label
	_btn_upgrades = get_node_or_null("Root/Center/Panel/VBox/Bar/Tabs/Upgrades") as Button
	_btn_items = get_node_or_null("Root/Center/Panel/VBox/Bar/Tabs/Items") as Button
	_items_container = get_node_or_null("Root/Center/Panel/VBox/Scroll/ItemsContainer") as VBoxContainer

func _harden_input() -> void:
	# Dim should STOP events, panel should accept, everything else default
	if _dim:
		_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	if _panel:
		_panel.mouse_filter = Control.MOUSE_FILTER_PASS

func _validate_required_nodes() -> bool:
	var ok := true
	ok = ok and _root != null
	ok = ok and _panel != null
	ok = ok and _items_container != null
	ok = ok and _btn_close != null
	ok = ok and _btn_upgrades != null
	ok = ok and _btn_items != null
	ok = ok and _coins_lbl != null
	return ok

# -------- Rendering ----------
func _show_category(name: String) -> void:
	current_category = name
	_clear_items()
	if name == "upgrades":
		if _items_container: _render_upgrades(_items_container)
	else:
		if _items_container: _render_items_placeholder(_items_container)

func _clear_items() -> void:
	if _items_container == null:
		return
	for c in _items_container.get_children():
		c.queue_free()

func _render_upgrades(container: VBoxContainer) -> void:
	for item_data in shop_items:
		var upgrade_key: String = String(item_data.get("upgrade_key", ""))
		var max_level: int = int(item_data.get("max_level", 0))
		var cost: int = int(item_data.get("cost", 0))
		var nm: String = String(item_data.get("name", ""))
		var desc: String = String(item_data.get("description", ""))
		var cur_coins: int = 0
		if save and "coins_banked" in save.data:
			cur_coins = int(save.data.get("coins_banked", 0))
		var current_level: int = 0
		if save:
			current_level = save.get_upgrade(upgrade_key)
		var can_upgrade: bool = (current_level < max_level)
		var can_afford: bool = (cur_coins >= cost)

		var card := Panel.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 80)
		container.add_child(card)

		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(v)

		var title := Label.new()
		title.text = "%s (Level %d/%d)" % [nm, current_level, max_level]
		title.add_theme_font_size_override("font_size", 16)
		v.add_child(title)

		var desc_lbl := Label.new()
		desc_lbl.text = desc
		desc_lbl.modulate = Color(0.8, 0.8, 0.8)
		v.add_child(desc_lbl)

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(row)

		var cost_lbl := Label.new()
		cost_lbl.text = "Cost: %d" % cost
		cost_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(cost_lbl)

		var buy_btn := Button.new()
		row.add_child(buy_btn)

		if can_upgrade and can_afford:
			buy_btn.text = "Buy"
			buy_btn.pressed.connect(func(): _buy_upgrade(item_data))
		else:
			if not can_upgrade:
				buy_btn.text = "MAX"
				buy_btn.disabled = true
			else:
				buy_btn.text = "Can't Afford"
				buy_btn.disabled = true

func _render_items_placeholder(container: VBoxContainer) -> void:
	var lbl := Label.new()
	lbl.text = "Consumable items coming soon!"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	container.add_child(lbl)

# -------- Actions ----------
func _buy_upgrade(item_data: Dictionary) -> void:
	if save == null:
		return
	var cost: int = int(item_data.get("cost", 0))
	var upgrade_key: String = String(item_data.get("upgrade_key", ""))

	var cur_coins: int = int(save.data.get("coins_banked", 0))
	if cur_coins < cost:
		return

	save.data["coins_banked"] = cur_coins - cost
	save.inc_upgrade(upgrade_key)

	_update_coins_label()
	_show_category(current_category)

func _update_coins_label() -> void:
	if _coins_lbl == null or save == null:
		return
	var banked: int = int(save.data.get("coins_banked", 0))
	_coins_lbl.text = "Coins: %d" % banked

# -------- Close ----------
func _on_close() -> void:
	visible = false
	queue_free()
	emit_signal("overlay_closed")
