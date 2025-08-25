extends Node
class_name BulletPool

@export var bullet_scene: PackedScene
@export var capacity: int = 400

# Declare types; initialize in _ready() to avoid Variant inference warnings
var _pool: Array[Node2D]
var _free: Array[int]
var _in_use: Array[bool]

func _ready() -> void:
	# Explicitly initialize the arrays
	_pool = []        # typed by the var declaration above
	_free = []
	_in_use = []

	if bullet_scene == null:
		push_warning("BulletPool: bullet_scene is not set in the Inspector.")
		return

	for i: int in range(capacity):
		var inst: Node = bullet_scene.instantiate()
		if not (inst is Node2D):
			push_error("BulletPool: bullet_scene must instance to Node2D/Area2D.")
			return

		var b: Node2D = inst as Node2D
		b.visible = false
		b.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(b)

		_pool.append(b)
		_free.append(i)
		_in_use.append(false)

# -------- pooling core --------

func _acquire() -> Node2D:
	if _free.is_empty():
		return null
	var idx: int = _free.pop_back()
	_in_use[idx] = true
	return _pool[idx]

func _release(b: Node2D) -> void:
	var idx: int = _pool.find(b)
	if idx == -1:
		return
	if _in_use[idx]:
		_in_use[idx] = false
		_free.append(idx)
	b.visible = false
	b.process_mode = Node.PROCESS_MODE_DISABLED

# Allow bullets to return themselves
func release_bullet(b: Node2D) -> void:
	_release(b)

# -------- property helper (strict typing; no inferred locals) --------

func _has_property(obj: Object, prop: String) -> bool:
	var plist: Array = obj.get_property_list()
	for entry in plist:
		var dict_entry: Dictionary = entry   # property list entries are Dictionaries
		var name_val: Variant = dict_entry.get("name", "")
		var name_str: String = str(name_val)
		if name_str == prop:
			return true
	return false

# -------- public API --------

# Fire a bullet with position + velocity (+ optional lifetime).
func fire(pos: Vector2, vel: Vector2, lifetime: float = 6.0) -> void:
	var b: Node2D = _acquire()
	if b == null:
		return

	# Place
	b.global_position = pos

	# Velocity (supports property or setter)
	if _has_property(b, "velocity"):
		b.set("velocity", vel)
	elif b.has_method("set_velocity"):
		b.call("set_velocity", vel)

	# Lifetime (supports property or setter)
	var self_destructs: bool = false
	if _has_property(b, "lifetime"):
		b.set("lifetime", lifetime)
		self_destructs = true
	elif b.has_method("set_lifetime"):
		b.call("set_lifetime", lifetime)
		self_destructs = true

	# Activate
	if b.has_method("activate"):
		b.call("activate")
	else:
		b.visible = true
		b.process_mode = Node.PROCESS_MODE_INHERIT
		b.set_process(true)
		b.set_physics_process(true)

	# Fallback lifetime if bullet doesn't self-manage
	if not self_destructs:
		var wr: WeakRef = weakref(b)
		var timer: SceneTreeTimer = get_tree().create_timer(lifetime)
		timer.timeout.connect(func() -> void:
			var obj: Object = wr.get_ref()
			if obj is Node2D:
				_release(obj as Node2D)
		)

# Convenience: fire by angle
func spawn_from_angle(pos: Vector2, angle_rad: float, speed: float, lifetime: float = 6.0) -> void:
	var vel: Vector2 = Vector2.RIGHT.rotated(angle_rad) * speed
	fire(pos, vel, lifetime)
