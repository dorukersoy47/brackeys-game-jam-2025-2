class_name ItemEffect
extends Node
signal consumed(item_id: StringName)
var item_id: StringName

func apply_on_pickup(player: Node, gs: Node) -> void:
	# For PASSIVE effects (e.g., +coin rate while held)
	pass

func use(player: Node, gs: Node) -> void:
	# For ACTIVE/CONSUMABLE effects when the player presses Q
	# Call emit_signal("consumed", item_id) if this consumes a stack
	pass

func on_run_end(player: Node, gs: Node) -> void:
	# Clean up persistent effects if needed
	pass
