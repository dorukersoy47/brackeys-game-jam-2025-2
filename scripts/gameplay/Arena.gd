extends Node2D
class_name Arena

@onready var gs = get_node("/root/GameState")

var shrink_level := 0.0

func _ready() -> void:
	add_to_group("arena")
	if gs and gs.has_method("start_run"):
		gs.start_run()
	_ensure_furnace()

func shrink_arena(amount: float) -> void:
	shrink_level = clamp(shrink_level + amount, 0.0, 0.3)
	scale = Vector2(1.0 - shrink_level, 1.0 - shrink_level)

func _ensure_furnace() -> void:
	if has_node("Furnace"):
		return
	var scene: PackedScene = preload("res://scenes/Furnace.tscn")
	var f = scene.instantiate()
	f.name = "Furnace"
	add_child(f)
	# Place near the visual center; adjust if your arena origin differs
	var center := get_viewport_rect().size * 0.5
	f.global_position = center
	# Auto-wire BulletPool if present
	var pool := get_tree().get_root().find_child("BulletPool", true, false)
	if pool:
		f.bullet_pool_path = f.get_path_to(pool)
	else:
		push_warning("BulletPool node not found. Set Furnace.bullet_pool_path in the editor.")
