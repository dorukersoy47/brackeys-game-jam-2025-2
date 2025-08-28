extends CanvasLayer

var gs: GameStateData
var health_bar: ProgressBar
var health_hearts: HBoxContainer
var risk_bar: ProgressBar
var banked_label: Label
var unbanked_label: Label
var multiplier_label: Label
var shop_system: Control
var status_text: Label
var damage_overlay: ColorRect
var damage_indicator: Label

# Damage system variables
var damage_flash_timer: float = 0.0
var current_damage_indicators: Array = []

func _ready() -> void:
	gs = get_node("/root/GameState") as GameStateData
	add_to_group("ui")

	# Resolve nodes
	health_bar = get_node_or_null("MainContainer/TopBar/HealthSection/HealthBar")
	health_hearts = get_node_or_null("MainContainer/TopBar/HealthSection/HealthHearts")
	risk_bar = get_node_or_null("MainContainer/TopBar/RiskSection/RiskBar")
	banked_label = get_node_or_null("MainContainer/TopBar/CoinSection/BankedCoins")
	unbanked_label = get_node_or_null("MainContainer/TopBar/CoinSection/UnbankedCoins")
	multiplier_label = get_node_or_null("MainContainer/TopBar/CoinSection/Multiplier")
	shop_system = get_node_or_null("ShopSystem") as Control
	status_text = get_node_or_null("MainContainer/BottomBar/StatusSection/StatusText")
	damage_overlay = get_node_or_null("DamageOverlay")
	damage_indicator = get_node_or_null("DamageIndicator")

	# Critical: UI should not block menu clicks when visible=false
	if damage_overlay:
		damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Connect GS signals to update labels
	if gs:
		gs.connect("coins_changed", func(v): if unbanked_label: unbanked_label.text = "At-Risk: %d" % v)
		gs.connect("banked_changed", func(v): if banked_label: banked_label.text = "Banked: %d" % v)
		gs.connect("bm_changed", func(v): if multiplier_label: multiplier_label.text = "BM ×%.1f" % v)

	# Hide UI unless a run is active
	visible = (gs != null and gs.running)

	set_process(true)

func _process(delta: float) -> void:
	# Damage flash
	if damage_flash_timer > 0.0:
		damage_flash_timer -= delta
		if damage_overlay:
			damage_overlay.visible = true
			damage_overlay.color.a = clamp(damage_flash_timer * 0.5, 0.0, 1.0)
	else:
		if damage_overlay:
			damage_overlay.visible = false

	# Floating damage indicators
	for i in range(current_damage_indicators.size() - 1, -1, -1):
		var indicator = current_damage_indicators[i]
		if indicator and indicator.has_method("update"):
			indicator.update(delta)
			if indicator.has_method("is_finished") and indicator.is_finished():
				indicator.queue_free()
				current_damage_indicators.remove_at(i)

func set_active(active: bool) -> void:
	visible = active

func update_health(current_hp: int, max_hp: int) -> void:
	if health_bar:
		health_bar.value = float(current_hp) / float(max_hp) * 100.0

	if health_hearts:
		for child in health_hearts.get_children():
			child.queue_free()
		for i in range(max_hp):
			var heart = TextureRect.new()
			heart.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			heart.custom_minimum_size = Vector2(32, 32)
			heart.modulate = Color.RED if i < current_hp else Color.DARK_RED
			var placeholder = PlaceholderTexture2D.new()
			placeholder.size = Vector2(32, 32)
			heart.texture = placeholder
			health_hearts.add_child(heart)

	if status_text:
		if current_hp <= 0:
			status_text.text = "DEFEATED"
			status_text.modulate = Color.RED
		elif current_hp <= max_hp * 0.3:
			status_text.text = "CRITICAL"
			status_text.modulate = Color.ORANGE
		elif current_hp <= max_hp * 0.6:
			status_text.text = "DAMAGED"
			status_text.modulate = Color.YELLOW
		else:
			status_text.text = "Normal"
			status_text.modulate = Color.WHITE

func show_damage_effect(damage_amount: int, position: Vector2 = Vector2.ZERO) -> void:
	damage_flash_timer = 0.3
	if position != Vector2.ZERO:
		_create_floating_damage(damage_amount, position)
	else:
		if damage_indicator:
			damage_indicator.text = "-%d" % damage_amount
			damage_indicator.visible = true
			damage_indicator.modulate = Color.RED
			await get_tree().create_timer(0.5).timeout
			damage_indicator.visible = false

func _create_floating_damage(damage_amount: int, position: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = "-%d" % damage_amount
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.modulate = Color.RED
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.global_position = position
	lbl.z_index = 100
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", position.y - 50.0, 1.0)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.0)
	await tw.finished
	if is_instance_valid(lbl):
		lbl.queue_free()

func update_furnace_status(phase: String) -> void:
	if status_text:
		match phase:
			"NORMAL":
				status_text.text = "Normal"; status_text.modulate = Color.WHITE
			"SHAKING":
				status_text.text = "TRANSFORMING..."; status_text.modulate = Color.ORANGE
			"MOBILE":
				status_text.text = "MOBILE PHASE"; status_text.modulate = Color.RED

func show_game_over(victory: bool) -> void:
	if status_text:
		if victory:
			status_text.text = "VICTORY!"; status_text.modulate = Color.GREEN
		else:
			status_text.text = "GAME OVER"; status_text.modulate = Color.RED
