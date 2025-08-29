extends ItemEffect

func use(player: Node, gs: Node) -> void:
	# Clear all bullets on screen
	if gs.has_method("emit_signal"):
		gs.emit_signal("request_bullet_clear")
	emit_signal("consumed", item_id)
