extends CharacterBody2D
class_name Player

# ---- Tunables ----
@export var move_speed: float = 220.0
@export var dash_speed_mult: float = 2.0
@export var dash_cooldown: float = 0.35
@export var dash_iframes: float = 0.12
@export var max_hp: int = 3

# Scene wiring
@export var sprite_path: NodePath       # optional Sprite2D
@export var hitbox_path: NodePath       # set this to your "Hitbox" CollisionShape2D

# Debug HUD
@export var show_input_debug: bool = true

# ---- State ----
var hp: int = 3
var is_dashing: bool = false
var dash_cd: float = 0.0

var _sprite: Sprite2D = null
var _hitbox: CollisionShape2D = null
var _dbg: Label = null
var _last_key_event: String = ""   # last key seen via _unhandled_input

func _ready() -> void:
	# Make sure we still run if the tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	set_process(true)
	set_physics_process(false)           # we’ll move in _process to remove physics dependency
	set_process_input(true)
	set_process_unhandled_input(true)

	add_to_group("player")
	hp = max_hp

	# Sprite hookup (robust)
	if sprite_path != NodePath(""):
		_sprite = get_node_or_null(sprite_path) as Sprite2D
	if _sprite == null:
		_sprite = get_node_or_null("Sprite") as Sprite2D
	if _sprite == null:
		_sprite = get_node_or_null("Sprite2D") as Sprite2D

	# Hitbox hookup (your node is named "Hitbox")
	if hitbox_path != NodePath(""):
		_hitbox = get_node_or_null(hitbox_path) as CollisionShape2D
	if _hitbox == null:
		_hitbox = get_node_or_null("Hitbox") as CollisionShape2D
	if _hitbox == null:
		_hitbox = get_node_or_null("CollisionShape2D") as CollisionShape2D

	# Debug label
	if show_input_debug:
		_dbg = Label.new()
		_dbg.name = "InputDebug"
		_dbg.position = Vector2(16, -24)
		add_child(_dbg)

func _process(delta: float) -> void:
	# cooldown
	if dash_cd > 0.0:
		dash_cd -= delta

	# ---- POLLED input (works even if events are swallowed elsewhere) ----
	var dir: Vector2 = _read_dir_polled()

	# move by directly editing transform so physics can’t block us
	var speed: float = move_speed * (dash_speed_mult if is_dashing else 1.0)
	global_position += dir * speed * delta

	# dash from action edge (use polled action)
	if (not is_dashing) and dash_cd <= 0.0 and Input.is_action_just_pressed("Dash"):
		_start_dash_iframes()

	# visual while dashing
	if _sprite:
		if is_dashing:
			_sprite.modulate = Color(1,1,1,0.75)
		else:
			_sprite.modulate = Color(1,1,1,1)

	# live debug HUD
	if _dbg:
		var paused_str: String = str(get_tree().paused)
		var pos_str: String = str(global_position)
		var dir_str: String = str(dir)
		var key_str: String = _last_key_event if _last_key_event != "" else "-"
		_dbg.text = "dir=%s  pos=%s  paused=%s  evt=%s  proc=ON" % [dir_str, pos_str, paused_str, key_str]

# Read WASD/Arrows three ways: your actions → ui_* → raw keys
func _read_dir_polled() -> Vector2:
	var dx: int = int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	var dy: int = int(Input.is_action_pressed("move_down"))  - int(Input.is_action_pressed("move_up"))
	var dir: Vector2 = Vector2(dx, dy)

	if dir == Vector2.ZERO:
		var ux: int = int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left"))
		var uy: int = int(Input.is_action_pressed("ui_down"))  - int(Input.is_action_pressed("ui_up"))
		dir = Vector2(ux, uy)

	if dir == Vector2.ZERO:
		var rx: int = 0
		var ry: int = 0
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D): rx = 1
		if Input.is_key_pressed(KEY_LEFT)  or Input.is_key_pressed(KEY_A): rx = -1
		if Input.is_key_pressed(KEY_DOWN)  or Input.is_key_pressed(KEY_S): ry = 1
		if Input.is_key_pressed(KEY_UP)    or Input.is_key_pressed(KEY_W): ry = -1
		dir = Vector2(rx, ry)

	return dir.normalized()

# Event path: proves whether key events reach the scene
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_last_key_event = "key=%s phys=%s" % [str((event as InputEventKey).keycode), str((event as InputEventKey).physical_keycode)]
		# don’t accept the event; we want to see if anything else handles it too

func _start_dash_iframes() -> void:
	is_dashing = true
	dash_cd = dash_cooldown
	if _hitbox:
		_hitbox.disabled = true
	await get_tree().create_timer(dash_iframes).timeout
	if _hitbox:
		_hitbox.disabled = false
	is_dashing = false

func take_hit(dmg: int = 1) -> void:
	if is_dashing:
		return
	hp -= max(dmg, 1)
	if hp <= 0:
		hp = max_hp
		global_position = Vector2(320, 180)
