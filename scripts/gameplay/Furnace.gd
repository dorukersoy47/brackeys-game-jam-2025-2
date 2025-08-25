extends Node2D
class_name Furnace

@export var bullet_pool_path: NodePath
@export var telegraph_duration: float = 0.45
@export var base_speed: float = 170.0
@export var heat_speed_bonus: float = 50.0
@export var wave_period: float = 10.0
@export var arc_bullet_spacing_deg: float = 6.0

@onready var _pool: Node = get_node_or_null(bullet_pool_path)
@onready var _telegraph: Line2D = $Telegraph
var _sfx: AudioStreamPlayer = null

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _rot: float = 0.0

func _ready() -> void:
	_rng.randomize()
	if has_node("Sfx"):
		_sfx = $Sfx
	_telegraph.clear_points()
	call_deferred("_pattern_cycle")

func _pattern_cycle() -> void:
	while is_inside_tree():
		await _run_random_pattern()
		var wait_time: float = wave_period * 0.4
		await get_tree().create_timer(wait_time).timeout

func _run_random_pattern() -> void:
	var choice: int = _rng.randi_range(0, 2)
	if choice == 0:
		await _pattern_arc_sweep()
	elif choice == 1:
		await _pattern_rotating_fan()
	else:
		await _pattern_spiral_gush()

func _g_heat() -> int:
	# Prefer /root/GameState if present; else fake tiers by time.
	if has_node("/root/GameState"):
		var gs: Node = get_node("/root/GameState")
		# If GameState has a 'heat' property, use it
		if "heat" in gs:
			return int(gs.heat)
	var t: float = Time.get_ticks_msec() / 1000.0
	if t < 60.0:
		return 0
	elif t < 120.0:
		return 1
	elif t < 180.0:
		return 2
	else:
		return 3

func _speed() -> float:
	return base_speed + heat_speed_bonus * float(_g_heat())

# ---------------- Patterns ----------------

func _pattern_arc_sweep() -> void:
	var span_deg: int = _rng.randi_range(90, 140)
	var center: float = _rot
	await _telegraph_arc(
		center - deg_to_rad(span_deg / 2.0),
		center + deg_to_rad(span_deg / 2.0),
		telegraph_duration
	)
	_spray_arc(center, span_deg, _speed())
	_pulse_mouth()
	_rot += deg_to_rad(_rng.randi_range(25, 55))

func _pattern_rotating_fan() -> void:
	var arms: int = _rng.randi_range(3, 5)
	var duration: float = 2.2 + 0.2 * float(_g_heat())
	var rate: float = 0.15
	var spin: float = deg_to_rad(70.0 + 20.0 * float(_g_heat()))
	var t: float = 0.0
	while t < duration:
		var base: float = _rot
		_telegraph_spokes(base, arms, 0.25)
		await get_tree().create_timer(0.25).timeout
		for i in range(arms):
			var ang: float = base + TAU * float(i) / float(arms)
			_fire_bullet(ang, _speed() * 0.9)
		_pulse_mouth()
		_rot += spin * rate
		t += rate
		await get_tree().create_timer(rate).timeout

func _pattern_spiral_gush() -> void:
	var duration: float = 1.6 + 0.2 * float(_g_heat())
	var rate: float = 0.05
	var t: float = 0.0
	var dir: float = _rot
	var spiral_speed: float = deg_to_rad(180.0 + 60.0 * float(_g_heat()))
	_telegraph_ring(0.3)
	await get_tree().create_timer(0.3).timeout
	while t < duration:
		_fire_bullet(dir, _speed())
		dir += spiral_speed * rate
		t += rate
		await get_tree().create_timer(rate).timeout
	_pulse_mouth()
	_rot = dir

# ---------------- Telegraphs ----------------

func _telegraph_arc(a0: float, a1: float, dur: float) -> void:
	_telegraph.clear_points()
	var steps: int = 24
	for i in range(steps + 1):
		var tt: float = float(i) / float(steps)
		var ang: float = lerp(a0, a1, tt)
		_telegraph.add_point(Vector2.RIGHT.rotated(ang) * 48.0)
	_telegraph.width = 2.0
	_telegraph.default_color = Color(1, 0.45, 0.1, 0.9)
	await get_tree().create_timer(dur).timeout
	_telegraph.clear_points()

func _telegraph_spokes(base: float, arms: int, dur: float) -> void:
	_telegraph.clear_points()
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(arms):
		var ang: float = base + TAU * float(i) / float(arms)
		pts.append(Vector2.ZERO)
		pts.append(Vector2.RIGHT.rotated(ang) * 40.0)
	_telegraph.points = pts
	_telegraph.width = 2.0
	_telegraph.default_color = Color(1, 0.7, 0.2, 0.9)
	await get_tree().create_timer(dur).timeout
	_telegraph.clear_points()

func _telegraph_ring(dur: float) -> void:
	_telegraph.clear_points()
	var steps: int = 32
	for i in range(steps + 1):
		var ang: float = TAU * float(i) / float(steps)
		_telegraph.add_point(Vector2.RIGHT.rotated(ang) * 36.0)
	_telegraph.width = 2.0
	_telegraph.default_color = Color(1, 0.2, 0.0, 0.9)
	await get_tree().create_timer(dur).timeout
	_telegraph.clear_points()

# ---------------- Firing helpers ----------------

func _spray_arc(center_ang: float, span_deg: float, speed: float) -> void:
	var count: int = int(ceil(span_deg / arc_bullet_spacing_deg))
	var start: float = center_ang - deg_to_rad(span_deg * 0.5)
	for i in range(count):
		var a: float = start + deg_to_rad(float(i) * arc_bullet_spacing_deg)
		_fire_bullet(a, speed)

func _fire_bullet(angle: float, speed: float, lifetime: float = 6.0) -> void:
	if is_instance_valid(_pool):
		var vel: Vector2 = Vector2.RIGHT.rotated(angle) * speed
		if _pool.has_method("fire"):
			_pool.fire(global_position, vel, lifetime)
	if _sfx and _sfx.stream:
		_sfx.play()

func _pulse_mouth() -> void:
	if has_node("Mouth"):
		var m: Node2D = $Mouth
		m.scale = Vector2(1.12, 1.12)
		await get_tree().process_frame
		m.scale = Vector2.ONE
