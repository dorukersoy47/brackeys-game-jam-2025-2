extends ItemEffect

var anchor_timer := 0.0
var moving_hazards: Array[Node] = []
var root_icon_instance = null

func use(player: Node, gs: Node) -> void:
		# Find all moving hazards
		moving_hazards = get_tree().get_nodes_in_group("moving_hazards")
		
		# Root player for 0.3s
		var root_icon = preload("res://scripts/market/effects/RootIcon.tscn").instantiate()
		root_icon_instance = root_icon
		get_tree().current_scene.add_child(root_icon)
		
		# Freeze moving hazards for 2s
		if moving_hazards.size() > 0:
				for hazard in moving_hazards:
						if hazard.has_method("freeze"):
								hazard.freeze(2.0)
				emit_tool_used_signal("proofing_weight", "Proofing Weight! (hazards frozen)")
		else:
				# No moving hazards found
				emit_tool_used_signal("proofing_weight", "Proofing Weight! (No movers)")
		
		anchor_timer = 2.0
		
		emit_signal("consumed", item_id)

func _process(delta: float) -> void:
		if anchor_timer > 0:
				anchor_timer -= delta
				if anchor_timer <= 0:
						# Restore moving hazards
						for hazard in moving_hazards:
								if hazard and is_instance_valid(hazard) and hazard.has_method("unfreeze"):
										hazard.unfreeze()
						
						emit_tool_expired_signal("proofing_weight")
						queue_free()

func on_run_end(player: Node, gs: Node) -> void:
		# Clean up hazard freezing
		for hazard in moving_hazards:
				if hazard and is_instance_valid(hazard) and hazard.has_method("unfreeze"):
						hazard.unfreeze()
		
		# Remove root icon if it exists
		if root_icon_instance and is_instance_valid(root_icon_instance):
				root_icon_instance.queue_free()
		
		anchor_timer = 0.0
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
