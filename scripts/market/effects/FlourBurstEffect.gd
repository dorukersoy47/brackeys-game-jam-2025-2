extends ItemEffect

func use(player: Node, gs: Node) -> void:
		# Clear all bullets on screen
		if gs.has_method("emit_signal"):
				gs.emit_signal("request_bullet_clear")
		
		# Create dust cloud effect
		var dust_cloud = preload("res://scripts/market/effects/DustCloud.tscn").instantiate()
		get_tree().current_scene.add_child(dust_cloud)
		
		# Emit tool used signal
		emit_tool_used_signal("flour_burst", "Flour Burst! (visibility ↓)")
		
		emit_signal("consumed", item_id)

func emit_tool_used_signal(tool_id: StringName, message: String):
		# Emit signal for UI updates
		if has_node("/root/GameState"):
				var game_state = get_node("/root/GameState")
				if game_state.has_signal("tool_used"):
						game_state.emit_signal("tool_used", tool_id, message)
