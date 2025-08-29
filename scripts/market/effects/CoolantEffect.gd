extends ItemEffect

var heat_reduction_timer := 0.0
var original_heat_rate := 0.0

func use(player: Node, gs: Node) -> void:
	# Reduce heat by 1 tier and temporarily slow heat growth
	if gs.heat > 0:
		gs.heat -= 1
		gs.emit_signal("risk_tier_changed", gs.heat)
	
	# Slow heat growth for 10 seconds
	original_heat_rate = gs.risk_tier_period
	gs.risk_tier_period *= 2.0  # Double the time between heat increases
	heat_reduction_timer = 10.0
	
	emit_signal("consumed", item_id)

func _process(delta: float) -> void:
	if heat_reduction_timer > 0:
		heat_reduction_timer -= delta
		if heat_reduction_timer <= 0:
			# Restore original heat rate
			var gs = get_node("/root/GameState") as GameStateData
			if gs:
				gs.risk_tier_period = original_heat_rate
			queue_free()

func on_run_end(player: Node, gs: Node) -> void:
	# Clean up heat rate modification
	if heat_reduction_timer > 0 and gs:
		gs.risk_tier_period = original_heat_rate
	heat_reduction_timer = 0.0
	queue_free()
