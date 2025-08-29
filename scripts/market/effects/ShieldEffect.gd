extends ItemEffect

func use(player: Node, gs: Node) -> void:
	# Grants a temporary guard that cancels next damage instance
	if player.has_method("add_temp_shield"):
		player.add_temp_shield(1)
	emit_signal("consumed", item_id)
