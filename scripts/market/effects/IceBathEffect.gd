extends ItemEffect

var heat_reduction_timer := 0.0
var original_heat_rate := 0.0
var original_pattern_speed := 1.0
var original_tips_multiplier := 1.0
var slow_field_instance = null

func use(player: Node, gs: Node) -> void:
		# Check if already slowed to prevent stacking
		if gs.has_method("get_effective_pattern_speed"):
				var current_speed = gs.get_effective_pattern_speed()
				if current_speed < 1.0:  # Already slowed
						emit_tool_used_signal("ice_bath", "Ice Bath! (already slowed)")
						emit_signal("consumed", item_id)
						return
		
		# Check if heat exists, otherwise apply pattern speed reduction
		if gs.heat > 0:
				# Drop heat tier
				gs.heat -= 1
				gs.emit_signal("risk_tier_changed", gs.heat)
				emit_tool_used_signal("ice_bath", "Ice Bath! (heat tier dropped)")
		else:
				# Apply pattern speed reduction and tips multiplier reduction
				original_pattern_speed = 1.0
				original_tips_multiplier = 1.0
				
				# Create slow field effect
				slow_field_instance = preload("res://scripts/market/effects/SlowField.tscn").instantiate()
				get_tree().current_scene.add_child(slow_field_instance)
				
				# Apply modifiers
				if gs.has_method("apply_pattern_speed_modifier"):
						gs.apply_pattern_speed_modifier(0.9)  # 10% reduction
				if gs.has_method("apply_tips_multiplier"):
						gs.apply_tips_multiplier(0.9)  # 10% reduction
				
				emit_tool_used_signal("ice_bath", "Ice Bath! (pattern speed ↓, tips ↓)")
		
		# Start 10-second timer
		heat_reduction_timer = 10.0
		
		emit_signal("consumed", item_id)

func _process(delta: float) -> void:
		if heat_reduction_timer > 0:
				heat_reduction_timer -= delta
				if heat_reduction_timer <= 0:
						# Restore original values
						var gs = get_node("/root/GameState")
						if gs:
								if gs.has_method("remove_pattern_speed_modifier"):
										gs.remove_pattern_speed_modifier(0.9)
								if gs.has_method("remove_tips_multiplier"):
										gs.remove_tips_multiplier(0.9)
						
						# Remove slow field if it exists
						if slow_field_instance and is_instance_valid(slow_field_instance):
								slow_field_instance.queue_free()
						
						emit_tool_expired_signal("ice_bath")
						queue_free()

func on_run_end(player: Node, gs: Node) -> void:
		# Clean up all modifications
		if heat_reduction_timer > 0 and gs:
				if gs.has_method("remove_pattern_speed_modifier"):
						gs.remove_pattern_speed_modifier(0.9)
				if gs.has_method("remove_tips_multiplier"):
						gs.remove_tips_multiplier(0.9)
		
		# Remove slow field if it exists
		if slow_field_instance and is_instance_valid(slow_field_instance):
				slow_field_instance.queue_free()
		
		heat_reduction_timer = 0.0
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
