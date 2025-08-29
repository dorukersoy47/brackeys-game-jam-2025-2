extends ItemEffect

var anchor_timer := 0.0
var furnace_node: Node = null

func use(player: Node, gs: Node) -> void:
	# Freeze furnace for 2s, mobile phase only
	furnace_node = get_tree().get_first_node_in_group("furnace")
	if furnace_node and furnace_node.has_method("stun_boss"):
		furnace_node.stun_boss(2.0)
		anchor_timer = 2.0
	
	emit_signal("consumed", item_id)

func _process(delta: float) -> void:
	if anchor_timer > 0:
		anchor_timer -= delta
		if anchor_timer <= 0:
			# Restore furnace movement
			if furnace_node and furnace_node.has_method("unstun_boss"):
				furnace_node.unstun_boss()
			queue_free()

func on_run_end(player: Node, gs: Node) -> void:
	# Clean up furnace stun
	if anchor_timer > 0 and furnace_node and furnace_node.has_method("unstun_boss"):
		furnace_node.unstun_boss()
	anchor_timer = 0.0
	queue_free()
