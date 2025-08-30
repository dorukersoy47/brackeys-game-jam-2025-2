extends ItemEffect

@onready var arm_timer = $Timer

func use(player: Node, gs: Node) -> void:
		# Set up arm timer (0.7s delay)
		arm_timer.wait_time = 0.7
		arm_timer.one_shot = true
		arm_timer.start()
		
		# Show arming state
		if player.has_method("show_shield_arming"):
				player.show_shield_arming()

func _on_timer_timeout():
		# Grants a temporary guard that cancels next damage instance
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
				var player = players[0]
				if player.has_method("add_temp_shield"):
						player.add_temp_shield(1)
						player.hide_shield_arming()
		
		# Emit tool used signal
		emit_tool_used_signal("oven_mitt", "Oven Mitt armed!")
		
		emit_signal("consumed", item_id)

func emit_tool_used_signal(tool_id: StringName, message: String):
		# Emit signal for UI updates
		if has_node("/root/GameState"):
				var game_state = get_node("/root/GameState")
				if game_state.has_signal("tool_used"):
						game_state.emit_signal("tool_used", tool_id, message)
