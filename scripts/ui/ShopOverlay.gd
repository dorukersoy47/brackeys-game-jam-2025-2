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
@onready var market_db: MarketDB = get_node("/root/DB")
@onready var market_controller: MarketController = get_node("/root/MrktController")

var dim: ColorRect
var panel: Panel
var btn_close: Button
var btn_tab_up: Button
var btn_tab_it: Button
var lbl_coins: Label
var list_container: VBoxContainer

# Loadout management
var loadout_container: HBoxContainer
var save_loadout_button: Button

func _ready() -> void:
				print("=== SHOPOVERLAY _READY START ===")
				# HIGHER than StartOverlay
				layer = max(layer, 200)
				process_mode = Node.PROCESS_MODE_ALWAYS
				visible = true

				_resolve_refs()
				_setup_modal_behavior()
				_connect_buttons()
				_update_coins_label()
				_setup_loadout_ui()
				_show_upgrades_tab()

				# Connect market controller signals
				market_controller.purchase_ok.connect(_on_purchase_ok)
				market_controller.purchase_denied.connect(_on_purchase_denied)

				# Only pause if opened from gameplay; Start menu will set pause_game=false
				if pause_game:
								get_tree().paused = true
				
				print("ShopOverlay _ready completed")
				print("=== SHOPOVERLAY _READY END ===")

func _exit_tree() -> void:
				if pause_game:
								get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
				if event.is_action_pressed("ui_cancel"):
								_on_close()

# ---------- Setup ----------

func _resolve_refs() -> void:
				print("=== SHOPOVERLAY _RESOLVE_REFS START ===")
				dim = _get_node_safe(dim_path, "Dim") as ColorRect
				panel = _get_node_safe(panel_path, "Panel") as Panel
				btn_close = _get_node_safe(close_button_path, "CloseButton") as Button
				btn_tab_up = _get_node_safe(tab_upgrades_path, "TabUpgrades") as Button
				btn_tab_it = _get_node_safe(tab_items_path, "TabItems") as Button
				lbl_coins = _get_node_safe(coins_label_path, "CoinsLabel") as Label
				list_container = _get_node_safe(list_container_path, "ItemsList") as VBoxContainer
				
				print("Dim found: ", dim != null)
				print("Panel found: ", panel != null)
				print("Close button found: ", btn_close != null)
				print("Upgrades tab found: ", btn_tab_up != null)
				print("Items tab found: ", btn_tab_it != null)
				print("Coins label found: ", lbl_coins != null)
				print("List container found: ", list_container != null)
				
				print("Save node reference: ", save_node)
				print("MarketDB reference: ", market_db)
				print("MarketController reference: ", market_controller)
				print("=== SHOPOVERLAY _RESOLVE_REFS END ===")

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
				print("=== SHOPOVERLAY _SHOW_ITEMS_TAB START ===")
				_clear_list()
				_populate_items()
				print("=== SHOPOVERLAY _SHOW_ITEMS_TAB END ===")

func _update_coins_label() -> void:
				if lbl_coins and typeof(save_node) == TYPE_OBJECT:
								var coins := int((save_node.get("data") as Dictionary).get("coins_banked", 0))
								lbl_coins.text = "Coins: %d" % coins

func _clear_list() -> void:
				if list_container:
								for c in list_container.get_children():
												c.queue_free()

func _populate_upgrades() -> void:
		if list_container == null:
				return

		var coins: int = int(save_node.data.coins_banked)
		var upgrades: Array = market_db.get_all_upgrades()  # ideally Array[UpgradeDef]

		for upgrade_def in upgrades:
				var level: int = int(save_node.get_upgrade(upgrade_def.stat_key))
				var max_level: int = int(upgrade_def.max_level)
				var cost: int = int(market_controller.get_upgrade_price(upgrade_def))
				var can_upgrade: bool = level < max_level
				var can_afford: bool = coins >= cost

				var row := HBoxContainer.new()
				row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

				var name_lbl := Label.new()
				name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				name_lbl.text = "%s (Lv %d/%d)" % [upgrade_def.display_name, level, max_level]
				row.add_child(name_lbl)

				var desc_lbl := Label.new()
				desc_lbl.text = upgrade_def.desc
				desc_lbl.add_theme_color_override("font_color", Color.GRAY)
				row.add_child(desc_lbl)

				var buy_btn := Button.new()
				if can_upgrade and can_afford:
						buy_btn.text = "Buy %d" % cost
						buy_btn.pressed.connect(func(): market_controller.buy_upgrade(upgrade_def))
				elif not can_upgrade:
						buy_btn.text = "MAX"
						buy_btn.disabled = true
				else:
						buy_btn.text = "Can't Afford"
						buy_btn.disabled = true
				row.add_child(buy_btn)

				list_container.add_child(row)

func _populate_items() -> void:
		print("=== SHOPOVERLAY _POPULATE_ITEMS START ===")
		if list_container == null:
				print("ERROR: list_container is null!")
				return

		print("list_container found, proceeding...")
		var coins: int = int(save_node.data.coins_banked)
		var items: Array = market_db.get_all_items()  # ideally Array[ItemDef]
		
		print("Coins available: ", coins)
		print("Items array from MarketDB: ", items.size())
		print("MarketDB items keys: ", market_db.items.keys())

		for i in range(items.size()):
				var item_def = items[i]
				print("Processing item ", i, ": ", item_def.display_name if item_def else "NULL")
				
				if not item_def:
						print("Skipping null item at index ", i)
						continue
						
				var owned_count: int = int(save_node.get_item_count(item_def.id))
				var cost: int = int(item_def.cost)
				var can_afford: bool = coins >= cost
				var can_buy_more: bool = owned_count < item_def.max_stack * 5

				print("Item: ", item_def.display_name, " owned: ", owned_count, " cost: ", cost, " can_afford: ", can_afford, " can_buy_more: ", can_buy_more)

				var row := HBoxContainer.new()
				row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

				var name_lbl := Label.new()
				name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				name_lbl.text = "%s (%d owned)" % [item_def.display_name, owned_count]
				row.add_child(name_lbl)

				var desc_lbl := Label.new()
				desc_lbl.text = item_def.desc
				desc_lbl.add_theme_color_override("font_color", Color.GRAY)
				row.add_child(desc_lbl)

				var buy_btn := Button.new()
				if can_afford and can_buy_more:
						buy_btn.text = "Buy %d" % cost
						buy_btn.pressed.connect(func(): market_controller.buy_item_to_stash(item_def))
				elif not can_buy_more:
						buy_btn.text = "MAX STASH"
						buy_btn.disabled = true
				else:
						buy_btn.text = "Can't Afford"
						buy_btn.disabled = true
				row.add_child(buy_btn)

				if owned_count > 0:
						var equip_btn := Button.new()
						var loadout: Array = save_node.get_loadout()
						if item_def.id in loadout:
								equip_btn.text = "Unequip"
								equip_btn.pressed.connect(func(): _unequip_item(item_def.id))
						else:
								equip_btn.text = "Equip"
								equip_btn.pressed.connect(func(): _equip_item(item_def.id))
						row.add_child(equip_btn)

				list_container.add_child(row)
				print("Added row for item: ", item_def.display_name)

		# Loadout section
		var loadout_header := Label.new()
		loadout_header.text = "Loadout (3 slots max):"
		loadout_header.add_theme_font_size_override("font_size", 16)
		loadout_header.add_theme_color_override("font_color", Color.YELLOW)
		list_container.add_child(loadout_header)

		var loadout_row := HBoxContainer.new()
		loadout_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var loadout: Array = save_node.get_loadout()
		print("Current loadout: ", loadout)
		for i in range(3):
				var slot_btn := Button.new()
				slot_btn.custom_minimum_size = Vector2(100, 40)
				if i < loadout.size():
						var def := market_db.get_item(loadout[i])
						if def:
								slot_btn.text = def.display_name
								slot_btn.pressed.connect(func(): _unequip_item(loadout[i]))
						else:
								slot_btn.text = "Empty"
								slot_btn.disabled = true
				else:
						slot_btn.text = "Empty"
						slot_btn.disabled = true
				loadout_row.add_child(slot_btn)

		list_container.add_child(loadout_row)
		print("Total children in list_container: ", list_container.get_child_count())
		print("=== SHOPOVERLAY _POPULATE_ITEMS END ===")

# Helper methods for item management
func _equip_item(item_id: StringName) -> void:
				var loadout = save_node.get_loadout()
				if loadout.size() >= 3:
								return  # Max slots
				
				if item_id not in loadout and save_node.get_item_count(item_id) > 0:
								loadout.append(item_id)
								save_node.set_loadout(loadout)
								_show_items_tab()  # Refresh

func _unequip_item(item_id: StringName) -> void:
				var loadout = save_node.get_loadout()
				var index = loadout.find(item_id)
				if index != -1:
								loadout.remove_at(index)
								save_node.set_loadout(loadout)
								_show_items_tab()  # Refresh

func _setup_loadout_ui() -> void:
				# This could be expanded to show loadout in a more prominent way
				pass

func _on_purchase_ok(kind: StringName, id: StringName) -> void:
				_update_coins_label()
				# Refresh current tab
				if btn_tab_up and btn_tab_up.button_pressed:
								_show_upgrades_tab()
				elif btn_tab_it and btn_tab_it.button_pressed:
								_show_items_tab()

func _on_purchase_denied(reason: String) -> void:
				# Could show a toast or notification here
				print("Purchase denied: ", reason)
