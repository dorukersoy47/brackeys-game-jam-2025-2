extends CharacterBody2D
class_name Player

# ---- Tunables ----
@export var move_speed: float = 220.0
@export var dash_speed_mult: float = 2.0
@export var dash_cooldown: float = 0.35
@export var dash_iframes: float = 0.12
@export var max_hp: int = 3

# Scene wiring
@export var sprite_path: NodePath       # set to your Sprite2D (optional)
@export var hitbox_path: NodePath       # set to your CollisionShape2D (your node is named "Hitbox")

# Debug HUD
@export var show_input_debug: bool = true

# ---- State ----
var hp: int = 3
var is_dashing: bool = false
var dash_cd: float = 0.0

var _sprite: Sprite2D
var _hitbox: CollisionShape2D
var _dbg: Label

func _ready() -> void:
	# Run even if something else pauses the tree
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)            # <— we will move in _process, not physics
	set_physics_process(false)   # (disable to avoid confusion)

	add_to_group("player")
	hp = max_hp

	# Sprite hookup (robust)
	_sprite = null
	if sprite_path != NodePath(""):
		_sprite = get_node_or_null(sprite_path) as Sprite2D
	if _sprite == null:
		_sprite = get_node_or_null("Sprite") as Sprite2D
	if _sprite == null:
		_sprite = get_node_or_null("Sprite2D") as Sprite2D

	# Hitbox hookup (fixes CollisionShape2D vs Hitbox)
	_hitbox = null
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

	# read input every frame (actions → defaults → raw keys)
	var dir: Vector2 = _read_dir()

	# move using plain transform (works even if physics is off)
	var speed: float = move_speed * (dash_speed_mult if is_dashing else 1.0)
	global_position += dir * speed * delta

	# dash (edge-trigger)
	if (not is_dashing) and dash_cd <= 0.0 and Input.is_action_just_pressed("Dash"):
		_start_dash_iframes()

	# visual while dashing
	if _sprite:
		_sprite.modulate = Color(1,1,1,0.75) if is_dashing else Color(1,1,1,1)

	# live debug HUD
	if _dbg:
		_dbg.text = "dir=%s  pos=%s  paused=%s  proc=ON" % [
			str(dir), str(global_position), str(get_tree().paused)
		]

func _read_dir() -> Vector2:
	# 1) your custom actions
	var dx := int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	var dy := int(Input.is_action_pressed("move_down"))  - int(Input.is_action_pressed("move_up"))
	var dir := Vector2(dx, dy)

	# 2) default ui_* fallback
	if dir == Vector2.ZERO:
		var ux := int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left"))
		var uy := int(Input.is_action_pressed("ui_down"))  - int(Input.is_action_pressed("ui_up"))
		dir = Vector2(ux, uy)

	# 3) raw keys fallback (works even if actions are misnamed/missing)
	if dir == Vector2.ZERO:
		var rx := 0
		var ry := 0
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D): rx = 1
		if Input.is_key_pressed(KEY_LEFT)  or Input.is_key_pressed(KEY_A): rx = -1
		if Input.is_key_pressed(KEY_DOWN)  or Input.is_key_pressed(KEY_S): ry = 1
		if Input.is_key_pressed(KEY_UP)    or Input.is_key_pressed(KEY_W): ry = -1
		dir = Vector2(rx, ry)

	return dir.normalized()

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
