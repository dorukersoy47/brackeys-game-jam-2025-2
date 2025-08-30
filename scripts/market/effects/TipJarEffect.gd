extends ItemEffect

var harvester_timer := 0.0
var original_tips_rate := 0.0
var hazard_tween = null

func use(player: Node, gs: Node) -> void:
		# Double tips for 8 seconds
		original_tips_rate = gs.base_coin_rate
		gs.base_coin_rate *= 2.0
		harvester_timer = 8.0
		
		# Apply hazard tugging effect
		apply_hazard_tugging()
		
		emit_tool_used_signal("tip_jar", "Tip Jar! (double tips, hazard tug)")
		
		emit_signal("consumed", item_id)

func apply_hazard_tugging():
		# Apply very low force tugging to minor hazards
		var hazards = get_tree().get_nodes_in_group("minor_hazards")
		for hazard in hazards:
				if hazard.has_method("apply_tug_force"):
						hazard.apply_tug_force(Vector2(10, 0))  # Very low force

func _process(delta: float) -> void:
		if harvester_timer > 0:
				harvester_timer -= delta
				if harvester_timer <= 0:
						# Restore original tips rate
						var gs = get_node("/root/GameState")
						if gs:
								gs.base_coin_rate = original_tips_rate
						
						emit_tool_expired_signal("tip_jar")
						queue_free()

func on_run_end(player: Node, gs: Node) -> void:
		# Clean up tips rate modification
		if harvester_timer > 0 and gs:
				gs.base_coin_rate = original_tips_rate
		harvester_timer = 0.0
		queue_free()

func emit_tool_used_signal(tool_id: StringName, message: String):
		# Emit signal for UI updates
		if has_node("/root/GameState"):
				var game_state = get_node("/root/GameState")
				if game_state.has_signal("tool_used"):
						game_state.emit_signal("tool_used", tool_id, message)

func emit_tool_expired_signal(tool_id: StringName):
		# Emit signal for UI updates
		if has_node("/root/GameState"):
				var game_state = get_node("/root/GameState")
				if game_state.has_signal("tool_expired"):
						game_state.emit_signal("tool_expired", tool_id)
