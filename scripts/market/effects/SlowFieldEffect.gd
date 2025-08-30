extends ColorRect
class_name SlowFieldEffect

@onready var timer = $Timer
var slow_multiplier = 0.9  # 10% slow
var tips_multiplier = 0.9  # 10% tips reduction

func _ready():
	# Set up the slow field overlay
	self_modulate.a = 0.1  # Subtle blue tint
	timer.wait_time = 10.0  # 10 seconds duration
	timer.one_shot = true
	timer.start()
	
	# Apply slow effect to game state
	apply_slow_effect()

func apply_slow_effect():
	# This will be connected to the game state to apply pattern speed reduction
	if has_node("/root/GameState"):
		var gs = get_node("/root/GameState")
		if gs.has_method("apply_pattern_speed_modifier"):
			gs.apply_pattern_speed_modifier(slow_multiplier)
		if gs.has_method("apply_tips_multiplier"):
			gs.apply_tips_multiplier(tips_multiplier)

func _on_timer_timeout():
	# Remove effects
	if has_node("/root/GameState"):
		var gs = get_node("/root/GameState")
		if gs.has_method("remove_pattern_speed_modifier"):
			gs.remove_pattern_speed_modifier(slow_multiplier)
		if gs.has_method("remove_tips_multiplier"):
			gs.remove_tips_multiplier(tips_multiplier)
	queue_free()
