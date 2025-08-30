extends ItemEffect

var multiplier_timer := 0.0
var original_multiplier := 1.0

func use(player: Node, gs: Node) -> void:
		# Instantly bank +100 tips
		gs.coins_banked += 100
		
		# Apply -10% total multiplier for 30s
		original_multiplier = 1.0
		if gs.has_method("apply_total_multiplier"):
				gs.apply_total_multiplier(0.9)  # 10% reduction
		
		multiplier_timer = 30.0
		
		emit_tool_used_signal("till_sweep", "Till Sweep! (+100 tips, multiplier ↓)")
		
		emit_signal("consumed", item_id)

func _process(delta: float) -> void:
		if multiplier_timer > 0:
				multiplier_timer -= delta
				if multiplier_timer <= 0:
						# Restore original multiplier
						var gs = get_node("/root/GameState")
						if gs and gs.has_method("remove_total_multiplier"):
								gs.remove_total_multiplier(0.9)
						
						emit_tool_expired_signal("till_sweep")
						queue_free()

func on_run_end(player: Node, gs: Node) -> void:
		# Clean up multiplier modification
		if multiplier_timer > 0 and gs:
				if gs.has_method("remove_total_multiplier"):
						gs.remove_total_multiplier(0.9)
		multiplier_timer = 0.0
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
