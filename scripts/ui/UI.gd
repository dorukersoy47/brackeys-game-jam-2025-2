extends CanvasLayer

var gs: GameStateData
var health_bar: ProgressBar
var health_hearts: HBoxContainer
var risk_bar: ProgressBar
var banked_label: Label
var unbanked_label: Label
var multiplier_label: Label
var status_text: Label
var damage_overlay: ColorRect
var damage_indicator: Label

# Damage system variables
var damage_flash_timer := 0.0
var current_damage_indicators: Array = []

func _ready() -> void:
	gs = get_node("/root/GameState") as GameStateData
	add_to_group("ui")

	# Start hidden; StartOverlay shows menu; HUD appears only when run starts
	visible = false

	# Get UI nodes
	health_bar = get_node_or_null("MainContainer/TopBar/HealthSection/HealthBar")
	health_hearts = get_node_or_null("MainContainer/TopBar/HealthSection/HealthHearts")
	risk_bar = get_node_or_null("MainContainer/TopBar/RiskSection/RiskBar")
	banked_label = get_node_or_null("MainContainer/TopBar/CoinSection/BankedCoins")
	unbanked_label = get_node_or_null("MainContainer/TopBar/CoinSection/UnbankedCoins")
	multiplier_label = get_node_or_null("MainContainer/TopBar/CoinSection/Multiplier")
	status_text = get_node_or_null("MainContainer/BottomBar/StatusSection/StatusText")
	damage_overlay = get_node_or_null("DamageOverlay")
	damage_indicator = get_node_or_null("DamageIndicator")

	# Hide any in-HUD back/shop button if it exists (HUD should not navigate)
	var back_btn := get_node_or_null("MainContainer/BottomBar/ControlsSection/BackButton") as Button
	if back_btn:
		back_btn.visible = false
	var shop_btn := get_node_or_null("MainContainer/BottomBar/ControlsSection/ShopButton") as Button
	if shop_btn:
		shop_btn.visible = false

	# Connect game state signals
	if gs:
		if not gs.coins_changed.is_connected(_on_coins):
			gs.coins_changed.connect(_on_coins)
		if not gs.banked_changed.is_connected(_on_banked):
			gs.banked_changed.connect(_on_banked)
		if not gs.bm_changed.is_connected(_on_bm):
			gs.bm_changed.connect(_on_bm)
		if not gs.risk_tier_changed.is_connected(_on_heat):
			gs.risk_tier_changed.connect(_on_heat)
		# Visibility control
		if not gs.run_started.is_connected(_on_run_started):
			gs.run_started.connect(_on_run_started)
		if not gs.run_over.is_connected(_on_run_over):
			gs.run_over.connect(_on_run_over)

	# Process for damage flash
	set_process(true)

func _process(delta: float) -> void:
	# Update damage flash
	if damage_flash_timer > 0.0:
		damage_flash_timer -= delta
		if damage_overlay:
			damage_overlay.visible = true
			damage_overlay.color.a = min(0.5, max(0.0, damage_flash_timer * 0.5))
	else:
		if damage_overlay:
			damage_overlay.visible = false

	# Update floating indicators (if any custom controls added there)
	for i in range(current_damage_indicators.size() - 1, -1, -1):
		var indicator = current_damage_indicators[i]
		if indicator and indicator.has_method("update"):
			indicator.update(delta)
			if indicator.has_method("is_finished") and indicator.is_finished():
				indicator.queue_free()
				current_damage_indicators.remove_at(i)

# ----- UI visibility driven by game state -----

func _on_run_started() -> void:
	visible = true

func _on_run_over(_extracted: bool) -> void:
	visible = false

# ----- Small signal relays -----

func _on_coins(v: int) -> void:
	if unbanked_label:
		unbanked_label.text = "At-Risk: %d" % v

func _on_banked(v: int) -> void:
	if banked_label:
		banked_label.text = "Banked: %d" % v

func _on_bm(v: float) -> void:
	if multiplier_label:
		multiplier_label.text = "BM ×%.1f" % v

func _on_heat(tier: int) -> void:
	if risk_bar:
		risk_bar.value = tier

# ----- Public API called by Player -----

func update_health(current_hp: int, max_hp: int) -> void:
	# Health bar
	if health_bar:
		health_bar.value = float(current_hp) / float(max_hp) * 100.0

	# Hearts
	if health_hearts:
		for child in health_hearts.get_children():
			child.queue_free()
		for i in range(max_hp):
			var heart := TextureRect.new()
			heart.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			heart.custom_minimum_size = Vector2(32, 32)
			if i < current_hp:
				heart.modulate = Color.RED
			else:
				heart.modulate = Color.DARK_RED
			var tex := PlaceholderTexture2D.new()
			tex.size = Vector2(32, 32)
			heart.texture = tex
			health_hearts.add_child(heart)

	# Status banner
	if status_text:
		if current_hp <= 0:
			status_text.text = "DEFEATED"
			status_text.modulate = Color.RED
		elif current_hp <= int(round(max_hp * 0.3)):
			status_text.text = "CRITICAL"
			status_text.modulate = Color.ORANGE
		elif current_hp <= int(round(max_hp * 0.6)):
			status_text.text = "DAMAGED"
			status_text.modulate = Color.YELLOW
		else:
			status_text.text = "Normal"
			status_text.modulate = Color.WHITE

func show_damage_effect(damage_amount: int, position: Vector2 = Vector2.ZERO) -> void:
	# Flash the screen
	damage_flash_timer = 0.3
	# Optional: floating damage numbers (omitted unless you spawn labels here)

func update_furnace_status(phase: String) -> void:
	if status_text:
		if phase == "NORMAL":
			status_text.text = "Normal"
			status_text.modulate = Color.WHITE
		elif phase == "SHAKING":
			status_text.text = "TRANSFORMING..."
			status_text.modulate = Color.ORANGE
		elif phase == "MOBILE":
			status_text.text = "MOBILE PHASE"
			status_text.modulate = Color.RED

func show_game_over(victory: bool) -> void:
	# EndOverlay handles the overlay; HUD stays hidden after run_over
	pass
