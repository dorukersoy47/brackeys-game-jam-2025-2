extends Area2D
class_name Bullet

@export var lifetime: float = 6.0

var velocity: Vector2 = Vector2.ZERO
var _age: float = 0.0

func _ready() -> void:
	# Detect player hits
	body_entered.connect(_on_body_entered)
	set_process(true)

func _process(delta: float) -> void:
	# Move
	position += velocity * delta
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	queue_redraw()  # (Godot 4) request _draw

func _on_body_entered(body: Node) -> void:
	# If player has take_hit(), call it; then remove bullet
	if body and body.has_method("take_hit"):
		body.call("take_hit")
	queue_free()

func _draw() -> void:
	# Simple visible bullet (orange disc)
	draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.5, 0.1))
