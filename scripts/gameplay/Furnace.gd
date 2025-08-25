extends Node2D
class_name Furnace

@export var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")
@export var base_speed: float = 180.0
@export var heat_speed_bonus: float = 50.0
@export var pattern_interval: float = 2.2   # seconds between patterns
@export var telegraph_time: float = 0.35

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _elapsed: float = 0.0
var _pattern_t: float = 0.0
var _rot: float = 0.0   # keeps continuity between patterns
var _telegraph_pts: PackedVector2Array = PackedVector2Array()
var _telegraph_t: float = 0.0

func _ready() -> void:
	_rng.randomize()
	set_process(true)

func _process(delta: float) -> void:
	_elapsed += delta
	_pattern_t -= delta
	if _telegraph_t > 0.0:
		_telegraph_t -= delta

	if _pattern_t <= 0.0:
		_run_random_pattern()
		_pattern_t = pattern_interval

	queue_redraw()  # (Godot 4) request _draw

func _draw() -> void:
	# furnace body (simple disc)
	draw_circle(Vector2.ZERO, 10.0, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2.ZERO, 8.0, Color(0.4, 0.1, 0.1))
	# telegraph
	if _telegraph_t > 0.0 and _telegraph_pts.size() > 1:
		for i in range(_telegraph_pts.size() - 1):
			draw_line(_telegraph_pts[i], _telegraph_pts[i + 1], Color(1.0, 0.4, 0.1), 2.0, true)

# ---------- difficulty helpers ----------

func _heat() -> int:
	if _elapsed < 45.0:
		return 0
	elif _elapsed < 90.0:
		return 1
	elif _elapsed < 135.0:
		return 2
	else:
		return 3

func _bullet_speed() -> float:
	return base_speed + heat_speed_bonus * float(_heat())

# ---------- patterns (all from center) ----------

func _run_random_pattern() -> void:
	var choice: int = _rng.randi_range(0, 2)
	if choice == 0:
		_pattern_arc_sweep()
	elif choice == 1:
		_pattern_rotating_fan()
	else:
		_pattern_spiral_stream()

func _pattern_arc_sweep() -> void:
	var span_deg: int = _rng.randi_range(100, 160)
	var center: float = _rot
	_telegraph_arc(center, span_deg, telegraph_time)
	await get_tree().create_timer(telegraph_time).timeout
	_fire_arc(center, span_deg, 7, _bullet_speed())
	_rot += deg_to_rad(_rng.randi_range(30, 60))

func _pattern_rotating_fan() -> void:
	var arms: int = 4 + _heat()   # 4..7 arms
	var bursts: int = 3
	for j in range(bursts):
		var base: float = _rot
		_telegraph_spokes(base, arms, 0.22)
		await get_tree().create_timer(0.22).timeout
		for i in range(arms):
			var ang: float = base + TAU * float(i) / float(arms)
			_fire(ang, _bullet_speed() * 0.95, 6.0)
		_rot += deg_to_rad(30.0 + 20.0 * float(_heat()))

func _pattern_spiral_stream() -> void:
	var dur: float = 1.4 + 0.2 * float(_heat())
	var rate: float = 0.06
	var dir: float = _rot
	var spin: float = deg_to_rad(180.0 + 40.0 * float(_heat()))
	_telegraph_ring(0.25)
	await get_tree().create_timer(0.25).timeout
	var t: float = 0.0
	while t < dur:
		_fire(dir, _bullet_speed(), 6.0)
		dir += spin * rate
		t += rate
		await get_tree().create_timer(rate).timeout
	_rot = dir

# ---------- telegraph drawing ----------

func _telegraph_arc(center: float, span_deg: float, dur: float) -> void:
	_telegraph_pts.clear()
	var steps: int = 24
	var start: float = center - deg_to_rad(span_deg * 0.5)
	var end: float = center + deg_to_rad(span_deg * 0.5)
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var ang: float = lerp(start, end, t)
		_telegraph_pts.append(Vector2.RIGHT.rotated(ang) * 52.0)
	_telegraph_t = dur

func _telegraph_spokes(base: float, arms: int, dur: float) -> void:
	_telegraph_pts.clear()
	for i in range(arms):
		var ang: float = base + TAU * float(i) / float(arms)
		_telegraph_pts.append(Vector2.ZERO)
		_telegraph_pts.append(Vector2.RIGHT.rotated(ang) * 44.0)
	_telegraph_t = dur

func _telegraph_ring(dur: float) -> void:
	_telegraph_pts.clear()
	var steps: int = 28
	for i in range(steps + 1):
		var ang: float = TAU * float(i) / float(steps)
		_telegraph_pts.append(Vector2.RIGHT.rotated(ang) * 40.0)
	_telegraph_t = dur

# ---------- firing ----------

func _fire_arc(center_ang: float, span_deg: float, count: int, speed: float) -> void:
	if count <= 0:
		return
	var start: float = center_ang - deg_to_rad(span_deg * 0.5)
	var step: float = deg_to_rad(span_deg) / float(count - 1)
	for i in range(count):
		var a: float = start + step * float(i)
		_fire(a, speed, 6.0)

func _fire(angle: float, speed: float, lifetime: float) -> void:
	if bullet_scene == null:
		return
	var b: Node = bullet_scene.instantiate()
	if not (b is Bullet):
		# If someone swapped the scene to a different script, try generic init
		if b is Area2D:
			var area: Area2D = b as Area2D
			if area.has_variable("velocity"):
				area.set("velocity", Vector2.RIGHT.rotated(angle) * speed)
		add_child(b)
		b.global_position = global_position
		return
	var bullet: Bullet = b as Bullet
	bullet.velocity = Vector2.RIGHT.rotated(angle) * speed
	bullet.lifetime = lifetime
	add_child(bullet)
	bullet.global_position = global_position
