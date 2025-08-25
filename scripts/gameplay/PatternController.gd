extends Node
class_name PatternController

@export var spawn_enabled: bool = true
@export var bullet_pool_path: NodePath
@export var origin_path: NodePath
@export var min_interval: float = 1.2
@export var max_interval: float = 2.0

@onready var pool: BulletPool = get_node_or_null(bullet_pool_path) as BulletPool
@onready var origin: Node2D = get_node_or_null(origin_path) as Node2D
@onready var gs: Node = get_node_or_null("/root/GameState")

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var timer: Timer

func _ready() -> void:
	rng.randomize()
	timer = Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_on_timer_timeout)
	_schedule_next()

func _process(_delta: float) -> void:
	# Guard everything behind this flag; Furnace is your main spawner now.
	if not spawn_enabled:
		return

func _on_timer_timeout() -> void:
	# Always reschedule so the timer stays alive even when disabled.
	_schedule_next()
	if not spawn_enabled or pool == null:
		return

	var pat: int = rng.randi_range(0, 2)
	if pat == 0:
		_radial_burst(12)
	elif pat == 1:
		_aimed_cone(5, deg_to_rad(20.0))
	else:
		_wall_sweep(18)

func _schedule_next() -> void:
	var iv: float = lerp(min_interval, max_interval, rng.randf())
	timer.start(iv)

# ---------------- helpers ----------------

func _heat() -> int:
	if gs and "heat" in gs:
		return int(gs.heat)
	return 0

func _origin_pos() -> Vector2:
	if origin:
		return origin.global_position
	var p: Node = get_parent()
	if p is Node2D:
		return (p as Node2D).global_position
	return Vector2.ZERO

func _speed() -> float:
	return 160.0 + 40.0 * float(_heat())

# ---------------- patterns (simple, compile-safe) ----------------

func _radial_burst(count: int) -> void:
	var speed: float = _speed()
	var base: float = rng.randf() * TAU
	var pos: Vector2 = _origin_pos()
	for i in range(count):
		var a: float = base + TAU * float(i) / float(count)
		pool.fire(pos, Vector2.RIGHT.rotated(a) * speed, 6.0)

func _aimed_cone(count: int, spread: float) -> void:
	var pos: Vector2 = _origin_pos()
	var player: Node2D = get_tree().get_root().find_child("Player", true, false) as Node2D
	var target: Vector2 = pos + Vector2.RIGHT
	if player:
		target = player.global_position
	var dir_angle: float = pos.direction_to(target).angle()
	var start: float = dir_angle - spread * 0.5
	var speed: float = _speed() * 1.1
	for i in range(count):
		var t: float = 0.0
		if count > 1:
			t = float(i) / float(count - 1)
		var a: float = start + spread * t
		pool.fire(pos, Vector2.RIGHT.rotated(a) * speed, 6.0)

func _wall_sweep(count: int) -> void:
	var pos: Vector2 = _origin_pos()
	var a: float = 0.0
	if (rng.randi() % 2) == 0:
		a = 0.0           # left→right
	else:
		a = PI            # right→left
	var speed: float = _speed() * 0.9
	for _i in range(count):
		pool.fire(pos, Vector2.RIGHT.rotated(a) * speed, 6.0)

# ---------------- optional pulse hooks (guarded) ----------------

func _on_pulse_started() -> void:
	if not spawn_enabled:
		return
	# (kept for future boss/pulse events)
