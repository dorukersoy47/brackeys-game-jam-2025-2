extends ItemEffect

var harvester_timer := 0.0
var original_coin_rate := 0.0

func use(player: Node, gs: Node) -> void:
	# Double coin pickups for 8 seconds
	original_coin_rate = gs.base_coin_rate
	gs.base_coin_rate *= 2.0
	harvester_timer = 8.0
	
	emit_signal("consumed", item_id)

func _process(delta: float) -> void:
	if harvester_timer > 0:
		harvester_timer -= delta
		if harvester_timer <= 0:
			# Restore original coin rate
			var gs = get_node("/root/GameState") as GameStateData
			if gs:
				gs.base_coin_rate = original_coin_rate
			queue_free()

func on_run_end(player: Node, gs: Node) -> void:
	# Clean up coin rate modification
	if harvester_timer > 0 and gs:
		gs.base_coin_rate = original_coin_rate
	harvester_timer = 0.0
	queue_free()
