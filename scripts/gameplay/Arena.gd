extends Node2D
class_name Arena

@onready var gs: GameStateData = get_node("/root/GameState") as GameStateData

var shrink_level: float = 0.0

func _ready() -> void:
	# Do NOT start the run here. StartOverlay will call gs.start_run()
	add_to_group("arena")

func shrink_arena(amount: float) -> void:
	shrink_level = clamp(shrink_level + amount, 0.0, 0.3)
	scale = Vector2(1.0 - shrink_level, 1.0 - shrink_level)

func get_shrink_level() -> float:
	return shrink_level
