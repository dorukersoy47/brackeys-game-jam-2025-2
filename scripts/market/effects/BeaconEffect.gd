extends ItemEffect

func use(player: Node, gs: Node) -> void:
	# Force shrine spawn within 5s
	if gs.has_method("force_shrine_spawn"):
		gs.force_shrine_spawn(5.0)
	emit_signal("consumed", item_id)
