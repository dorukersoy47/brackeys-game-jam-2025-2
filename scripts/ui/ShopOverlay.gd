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

# Loadout slot references
var loadout_slots: Array[Label] = []
var loadout_panels: Array[Panel] = []

# Style boxes for dynamic UI elements
var panel_style: StyleBoxFlat
var slot_style: StyleBoxFlat

func _ready() -> void:
								print("=== SHOPOVERLAY _READY START ===")
								# Create style boxes
								_create_style_boxes()
								
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

func _create_style_boxes() -> void:
								# Create panel style for item/upgrade cards
								panel_style = StyleBoxFlat.new()
								panel_style.bg_color = Color(0.25, 0.25, 0.3, 1)
								panel_style.corner_radius_top_left = 8
								panel_style.corner_radius_top_right = 8
								panel_style.corner_radius_bottom_right = 8
								panel_style.corner_radius_bottom_left = 8
								panel_style.content_margin_left = 20
								panel_style.content_margin_right = 20
								panel_style.content_margin_top = 16
								panel_style.content_margin_bottom = 16
								
								# Create slot style for loadout slots
								slot_style = StyleBoxFlat.new()
								slot_style.bg_color = Color(0.25, 0.25, 0.3, 1)
								slot_style.corner_radius_top_left = 6
								slot_style.corner_radius_top_right = 6
								slot_style.corner_radius_bottom_right = 6
								slot_style.corner_radius_bottom_left = 6
								slot_style.content_margin_left = 12
								slot_style.content_margin_right = 12
								slot_style.content_margin_top = 8
								slot_style.content_margin_bottom = 8

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
								btn_tab_up = _get_node_safe(tab_upgrades_path, "UpgradesTab") as Button
								btn_tab_it = _get_node_safe(tab_items_path, "ItemsTab") as Button
								lbl_coins = _get_node_safe(coins_label_path, "CoinsLabel") as Label
								list_container = _get_node_safe(list_container_path, "ItemsContainer") as VBoxContainer
								
								# Get loadout slot references
								for i in range(3):
																var slot_label = get_node("Root/Center/Panel/VBoxContainer/LoadoutSection/LoadoutSlots/Slot%d/SlotLabel%d" % [i+1, i+1]) as Label
																var slot_panel = get_node("Root/Center/Panel/VBoxContainer/LoadoutSection/LoadoutSlots/Slot%d" % [i+1]) as Panel
																if slot_label and slot_panel:
																								loadout_slots.append(slot_label)
																								loadout_panels.append(slot_panel)
								
								print("Dim found: ", dim != null)
								print("Panel found: ", panel != null)
								print("Close button found: ", btn_close != null)
								print("Upgrades tab found: ", btn_tab_up != null)
								print("Items tab found: ", btn_tab_it != null)
								print("Coins label found: ", lbl_coins != null)
								print("List container found: ", list_container != null)
								print("Loadout slots found: ", loadout_slots.size())
								
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
																lbl_coins.text = str(coins)

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

								var row := Panel.new()
								row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
								if panel_style:
																row.add_theme_stylebox_override("panel", panel_style)
								row.custom_minimum_size = Vector2(0, 100)

								var content := HBoxContainer.new()
								content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
								content.add_theme_constant_override("separation", 16)
								row.add_child(content)

								var info_container := VBoxContainer.new()
								info_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
								info_container.add_theme_constant_override("separation", 8)
								content.add_child(info_container)

								var name_lbl := Label.new()
								name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
								name_lbl.text = upgrade_def.display_name
								name_lbl.add_theme_font_size_override("font_size", 20)
								name_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.7, 1))
								info_container.add_child(name_lbl)

								var level_lbl := Label.new()
								level_lbl.text = "Level %d/%d" % [level, max_level]
								level_lbl.add_theme_font_size_override("font_size", 14)
								level_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
								info_container.add_child(level_lbl)

								var desc_lbl := Label.new()
								desc_lbl.text = upgrade_def.desc
								desc_lbl.add_theme_font_size_override("font_size", 13)
								desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
								desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
								info_container.add_child(desc_lbl)

								var action_container := VBoxContainer.new()
								action_container.alignment = BoxContainer.ALIGNMENT_CENTER
								action_container.add_theme_constant_override("separation", 12)
								content.add_child(action_container)

								var cost_lbl := Label.new()
								cost_lbl.text = "Cost: %d 🪙" % cost
								cost_lbl.add_theme_font_size_override("font_size", 16)
								cost_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1))
								action_container.add_child(cost_lbl)

								var buy_btn := Button.new()
								buy_btn.custom_minimum_size = Vector2(140, 40)
								buy_btn.add_theme_font_size_override("font_size", 14)
								if can_upgrade and can_afford:
												buy_btn.text = "UPGRADE"
												buy_btn.add_theme_color_override("font_color", Color(0.2, 1, 0.2, 1))
												buy_btn.pressed.connect(func(): market_controller.buy_upgrade(upgrade_def))
								elif not can_upgrade:
												buy_btn.text = "MAX LEVEL"
												buy_btn.disabled = true
												buy_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
								else:
												buy_btn.text = "NEED %d 🪙" % (cost - coins)
												buy_btn.disabled = true
												buy_btn.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
								action_container.add_child(buy_btn)

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

								var row := Panel.new()
								row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
								if panel_style:
																row.add_theme_stylebox_override("panel", panel_style)
								row.custom_minimum_size = Vector2(0, 120)

								var content := HBoxContainer.new()
								content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
								content.add_theme_constant_override("separation", 16)
								row.add_child(content)

								var info_container := VBoxContainer.new()
								info_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
								info_container.add_theme_constant_override("separation", 8)
								content.add_child(info_container)

								var header := HBoxContainer.new()
								header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
								info_container.add_child(header)

								var name_lbl := Label.new()
								name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
								name_lbl.text = item_def.display_name
								name_lbl.add_theme_font_size_override("font_size", 20)
								name_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.7, 1))
								header.add_child(name_lbl)

								var owned_lbl := Label.new()
								owned_lbl.text = "Owned: %d" % owned_count
								owned_lbl.add_theme_font_size_override("font_size", 14)
								owned_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
								header.add_child(owned_lbl)

								var desc_lbl := Label.new()
								desc_lbl.text = item_def.desc
								desc_lbl.add_theme_font_size_override("font_size", 13)
								desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
								desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
								info_container.add_child(desc_lbl)

								var rarity_lbl := Label.new()
								rarity_lbl.text = "Rarity: %s" % item_def.rarity.capitalize()
								rarity_lbl.add_theme_font_size_override("font_size", 12)
								rarity_lbl.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3, 1))
								info_container.add_child(rarity_lbl)

								var action_container := VBoxContainer.new()
								action_container.alignment = BoxContainer.ALIGNMENT_CENTER
								action_container.add_theme_constant_override("separation", 12)
								content.add_child(action_container)

								var cost_lbl := Label.new()
								cost_lbl.text = "Cost: %d 🪙" % cost
								cost_lbl.add_theme_font_size_override("font_size", 16)
								cost_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1))
								action_container.add_child(cost_lbl)

								var buy_btn := Button.new()
								buy_btn.custom_minimum_size = Vector2(140, 40)
								buy_btn.add_theme_font_size_override("font_size", 14)
								if can_afford and can_buy_more:
												buy_btn.text = "BUY"
												buy_btn.add_theme_color_override("font_color", Color(0.2, 1, 0.2, 1))
												buy_btn.pressed.connect(func(): market_controller.buy_item_to_stash(item_def))
								elif not can_buy_more:
												buy_btn.text = "MAX STASH"
												buy_btn.disabled = true
												buy_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
								else:
												buy_btn.text = "NEED %d 🪙" % (cost - coins)
												buy_btn.disabled = true
												buy_btn.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
								action_container.add_child(buy_btn)

								if owned_count > 0:
												var equip_btn := Button.new()
												equip_btn.custom_minimum_size = Vector2(140, 40)
												equip_btn.add_theme_font_size_override("font_size", 14)
												var loadout: Array = save_node.get_loadout()
												if item_def.id in loadout:
																equip_btn.text = "UNEQUIP"
																equip_btn.add_theme_color_override("font_color", Color(1, 0.6, 0.2, 1))
																equip_btn.pressed.connect(func(): _unequip_item(item_def.id))
												else:
																equip_btn.text = "EQUIP"
																equip_btn.add_theme_color_override("font_color", Color(0.2, 0.8, 1, 1))
																equip_btn.pressed.connect(func(): _equip_item(item_def.id))
												action_container.add_child(equip_btn)

								list_container.add_child(row)
								print("Added row for item: ", item_def.display_name)

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
																_update_loadout_display()
																_show_items_tab()  # Refresh

func _unequip_item(item_id: StringName) -> void:
								var loadout = save_node.get_loadout()
								var index = loadout.find(item_id)
								if index != -1:
																loadout.remove_at(index)
																save_node.set_loadout(loadout)
																_update_loadout_display()
																_show_items_tab()  # Refresh

func _setup_loadout_ui() -> void:
								_update_loadout_display()

func _update_loadout_display() -> void:
								var loadout: Array = save_node.get_loadout()
								print("Updating loadout display: ", loadout)
								
								for i in range(3):
																if i < loadout_slots.size():
																		var slot_label = loadout_slots[i]
																		var slot_panel = loadout_panels[i]
																		
																		if i < loadout.size():
																				var item_def = market_db.get_item(loadout[i])
																				if item_def:
																						slot_label.text = item_def.display_name
																						slot_label.add_theme_color_override("font_color", Color(1, 0.9, 0.7, 1))
																						if slot_style:
																								slot_panel.add_theme_stylebox_override("panel", slot_style)
																				else:
																						slot_label.text = "EMPTY"
																						slot_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
																		else:
																				slot_label.text = "EMPTY"
																				slot_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))

func _on_purchase_ok(kind: StringName, id: StringName) -> void:
								_update_coins_label()
								_update_loadout_display()
								# Refresh current tab
								if btn_tab_up and btn_tab_up.button_pressed:
																_show_upgrades_tab()
								elif btn_tab_it and btn_tab_it.button_pressed:
																_show_items_tab()

func _on_purchase_denied(reason: String) -> void:
								# Could show a toast or notification here
								print("Purchase denied: ", reason)
