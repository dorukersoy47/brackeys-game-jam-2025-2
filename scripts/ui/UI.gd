extends CanvasLayer

var gs: GameStateData
var run_inv: RunInventory
var market_db: MarketDB
var health_bar: ProgressBar
var health_hearts: HBoxContainer
var risk_bar: ProgressBar
var banked_label: Label
var unbanked_label: Label
var multiplier_label: Label
var status_text: Label
var damage_overlay: ColorRect
var damage_indicator: Label

var item_hud: HBoxContainer
var item_labels: Array[Label] = []

var damage_flash_timer := 0.0
var current_damage_indicators: Array = []

func _ready() -> void:
		gs = get_node("/root/GameState") as GameStateData

		# Autoloads by YOUR names
		run_inv = get_node_or_null("/root/RunInv") as RunInventory
		market_db = get_node_or_null("/root/DB") as MarketDB
		if not run_inv: push_warning("Autoload RunInv not found at /root/RunInv")
		if not market_db: push_warning("Autoload DB not found at /root/DB")

		add_to_group("ui")
		visible = false

		health_bar = get_node_or_null("MainContainer/TopBar/HealthSection/HealthBar")
		health_hearts = get_node_or_null("MainContainer/TopBar/HealthSection/HealthHearts")
		risk_bar = get_node_or_null("MainContainer/TopBar/RiskSection/RiskBar")
		banked_label = get_node_or_null("MainContainer/TopBar/CoinSection/BankedCoins")
		unbanked_label = get_node_or_null("MainContainer/TopBar/CoinSection/UnbankedCoins")
		multiplier_label = get_node_or_null("MainContainer/TopBar/CoinSection/Multiplier")
		status_text = get_node_or_null("MainContainer/BottomBar/StatusSection/StatusText")
		damage_overlay = get_node_or_null("DamageOverlay")
		damage_indicator = get_node_or_null("DamageIndicator")

		_setup_item_hud()

		var back_btn := get_node_or_null("MainContainer/BottomBar/ControlsSection/BackButton") as Button
		if back_btn: back_btn.visible = false
		var shop_btn := get_node_or_null("MainContainer/BottomBar/ControlsSection/ShopButton") as Button
		if shop_btn: shop_btn.visible = false

		if gs:
				if not gs.coins_changed.is_connected(_on_coins): gs.coins_changed.connect(_on_coins)
				if not gs.banked_changed.is_connected(_on_banked): gs.banked_changed.connect(_on_banked)
				if not gs.bm_changed.is_connected(_on_bm): gs.bm_changed.connect(_on_bm)
				if not gs.risk_tier_changed.is_connected(_on_heat): gs.risk_tier_changed.connect(_on_heat)
				if not gs.run_started.is_connected(_on_run_started): gs.run_started.connect(_on_run_started)
				if not gs.run_over.is_connected(_on_run_over): gs.run_over.connect(_on_run_over)

		if run_inv and not run_inv.changed.is_connected(_on_inventory_changed):
				run_inv.changed.connect(_on_inventory_changed)

		set_process(true)

# ----- Item HUD -----
func _setup_item_hud() -> void:
		item_hud = get_node_or_null("MainContainer/ItemHUD") as HBoxContainer
		if not item_hud:
				item_hud = HBoxContainer.new()
				item_hud.name = "ItemHUD"
				item_hud.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
				item_hud.position = Vector2(20, -100)
				item_hud.add_theme_constant_override("separation", 10)
				add_child(item_hud)

		item_labels.clear()
		for i in range(3):
				var item_label := Label.new()
				item_label.text = "[ ]"
				item_label.add_theme_font_size_override("font_size", 14)
				item_label.add_theme_color_override("font_color", Color.WHITE)
				item_labels.append(item_label)
				item_hud.add_child(item_label)

		_update_item_hud()

func _update_item_hud() -> void:
		if not run_inv or item_labels.is_empty() or not market_db:
				return

		var equipped_items: Array = []
		if run_inv.has_method("get_equipped_items"):
				equipped_items = run_inv.get_equipped_items()
		elif "equipped" in run_inv:
				equipped_items = run_inv.equipped

		var active_cursor: int = 0
		if "active_item_cursor" in run_inv:
				active_cursor = int(run_inv.active_item_cursor)

		for i in range(item_labels.size()):
				var label := item_labels[i]
				if i < equipped_items.size():
						var item_id: StringName = equipped_items[i]
						var def := market_db.get_item(item_id)
						var count := run_inv.count(item_id) if run_inv.has_method("count") else 0
						if def:
								label.text = "[%s] %dx" % [def.display_name.left(3), count]
						else:
								label.text = "[%s] %dx" % [String(item_id).left(3), count]
						label.add_theme_color_override("font_color", Color.YELLOW if i == active_cursor else Color.WHITE)
				else:
						label.text = "[ ]"
						label.add_theme_color_override("font_color", Color.GRAY)

func _on_inventory_changed() -> void:
		_update_item_hud()
		
# ----- HUD signal handlers -----

func _on_run_started() -> void:
		visible = true
		_update_item_hud()

func _on_run_over(_extracted: bool) -> void:
		visible = false

func _on_coins(v: int) -> void:
		if unbanked_label:
				unbanked_label.text = "🍪 %d" % v

func _on_banked(v: int) -> void:
		if banked_label:
				banked_label.text = "💰 %d" % v

func _on_bm(v: float) -> void:
		if multiplier_label:
				multiplier_label.text = "BM ×%.1f" % v

func _on_heat(tier: int) -> void:
		if risk_bar:
				risk_bar.value = tier
