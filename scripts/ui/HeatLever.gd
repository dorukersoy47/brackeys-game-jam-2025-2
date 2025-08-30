extends Control
class_name HeatLever

signal heat_upshift_pressed()

@onready var gs: GameStateData = get_node("/root/GameState") as GameStateData
@onready var lever_container: HBoxContainer = $LeverContainer
@onready var cooldown_ring: TextureProgressBar = $CooldownRing
@onready var upshift_button: Button = $UpshiftButton
@onready var heat_labels: Array[Label] = []

var heat_tier_names = ["Warm", "Hot", "Inferno"]
var feedback_timer := 0.0
var feedback_color := Color.WHITE

func _ready() -> void:
		print("DEBUG: HeatLever _ready() called")
		
		# Check if critical nodes exist
		if not lever_container:
				print("DEBUG: HeatLever - lever_container is null!")
				return
		if not cooldown_ring:
				print("DEBUG: HeatLever - cooldown_ring is null!")
		if not upshift_button:
				print("DEBUG: HeatLever - upshift_button is null!")
		
		# Get heat tier labels
		for i in range(3):
				var label = lever_container.get_node_or_null("Heat%d" % i)
				if label:
						heat_labels.append(label)
						print("DEBUG: HeatLever found label Heat%d" % i)
				else:
						print("DEBUG: HeatLever could not find label Heat%d" % i)
		
		# Connect signals
		if gs:
				gs.connect("heat_changed", _on_heat_changed)
				gs.connect("heat_upshift_cooldown_started", _on_cooldown_started)
				print("DEBUG: HeatLever connected to GameState signals")
		else:
				print("DEBUG: HeatLever could not connect to GameState - gs is null")
		
		if upshift_button:
				upshift_button.connect("pressed", _on_upshift_pressed)
				print("DEBUG: HeatLever connected upshift button signal")
		else:
				print("DEBUG: HeatLever could not connect upshift button - button is null")
		
		# Initial state
		_update_display()
		print("DEBUG: HeatLever initial display updated")
		
		# Set up cooldown ring appearance
		if cooldown_ring:
				cooldown_ring.visible = false
				cooldown_ring.value = 0.0
				print("DEBUG: HeatLever cooldown ring initialized")
		else:
				print("DEBUG: HeatLever cooldown ring is null")

func _process(delta: float) -> void:
		if gs and gs.running and gs.heat_upshift_cooldown > 0:
				if cooldown_ring:
						cooldown_ring.value = (gs.heat_upshift_cooldown / gs.heat_upshift_cooldown_time) * 100.0
		
		# Update feedback color
		if feedback_timer > 0:
				feedback_timer -= delta
				var intensity = feedback_timer / 0.3
				lever_container.modulate = feedback_color.lerp(Color.WHITE, 1.0 - intensity)
		else:
				lever_container.modulate = Color.WHITE

func _on_heat_changed(tier: int) -> void:
		print("DEBUG: HeatLever received heat_changed signal, tier: ", tier)
		_update_display()
		# Show upshift feedback
		if tier > 0:
				show_heat_upshift_feedback()

func _on_cooldown_started(seconds: float) -> void:
		print("DEBUG: HeatLever received heat_upshift_cooldown_started signal, seconds: ", seconds)
		if cooldown_ring:
				cooldown_ring.value = 100.0
				cooldown_ring.visible = true
		if upshift_button:
				upshift_button.disabled = true
		show_cooldown_feedback()

func _on_upshift_pressed() -> void:
		print("DEBUG: HeatLever upshift button pressed")
		if gs and gs.heat_upshift_cooldown <= 0 and gs.heat_tier < 2:
				emit_signal("heat_upshift_pressed")
		else:
				# Show feedback for failed upshift
				if gs and gs.heat_upshift_cooldown > 0:
						print("DEBUG: Cannot upshift - cooldown active")
						show_cooldown_feedback()
				elif gs and gs.heat_tier >= 2:
						print("DEBUG: Cannot upshift - at max tier")
						show_max_tier_feedback()

func _update_display() -> void:
		if not gs:
				print("DEBUG: HeatLever _update_display() - gs is null")
				return
		
		print("DEBUG: HeatLever _update_display() - current heat tier: ", gs.heat_tier)
		
		# Update heat tier labels
		for i in range(heat_labels.size()):
				if i < heat_labels.size():
						var label = heat_labels[i]
						if label:
								print("DEBUG: HeatLever updating label ", i, " for tier ", gs.heat_tier)
								if i < gs.heat_tier:
										# Active tier - bright orange
										label.modulate = Color.ORANGE
										label.add_theme_color_override("font_color", Color.ORANGE)
								elif i == gs.heat_tier:
										# Current tier - bright yellow
										label.modulate = Color.YELLOW
										label.add_theme_color_override("font_color", Color.YELLOW)
								else:
										# Inactive tier - gray
										label.modulate = Color.GRAY
										label.add_theme_color_override("font_color", Color.GRAY)
		
		# Update cooldown ring
		if gs.heat_upshift_cooldown > 0:
				print("DEBUG: HeatLever - cooldown active: ", gs.heat_upshift_cooldown)
				if cooldown_ring:
						cooldown_ring.visible = true
						cooldown_ring.value = (gs.heat_upshift_cooldown / gs.heat_upshift_cooldown_time) * 100.0
				if upshift_button:
						upshift_button.disabled = true
						upshift_button.text = "COOLDOWN (%.1fs)" % gs.heat_upshift_cooldown
		else:
				print("DEBUG: HeatLever - no cooldown")
				if cooldown_ring:
						cooldown_ring.visible = false
				if upshift_button:
						if gs.heat_tier >= 2:
								upshift_button.disabled = true
								upshift_button.text = "MAX TIER"
						else:
								upshift_button.disabled = false
								upshift_button.text = "UPSHIFT (R)"

func show_heat_upshift_feedback() -> void:
		# Visual feedback for successful upshift
		feedback_timer = 0.3
		feedback_color = Color.YELLOW
		if lever_container:
				lever_container.modulate = Color.YELLOW

func show_heat_downshift_feedback() -> void:
		# Visual feedback for downshift
		feedback_timer = 0.3
		feedback_color = Color.RED
		if lever_container:
				lever_container.modulate = Color.RED

func show_cooldown_feedback() -> void:
		# Visual feedback when trying to upshift during cooldown
		feedback_timer = 0.2
		feedback_color = Color.GRAY
		if lever_container:
				lever_container.modulate = Color.GRAY

func show_max_tier_feedback() -> void:
		# Visual feedback when trying to upshift at max tier
		feedback_timer = 0.2
		feedback_color = Color.ORANGE
		if lever_container:
				lever_container.modulate = Color.ORANGE
