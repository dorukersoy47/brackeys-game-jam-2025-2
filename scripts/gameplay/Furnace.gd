extends CharacterBody2D
class_name Furnace

@onready var rng: RNGService = get_node("/root/RNG") as RNGService
@onready var gs: GameStateData = get_node("/root/GameState") as GameStateData

# Exported for flexible wiring in the scene
@export var bullet_pool_path: NodePath
@export var arena_path: NodePath

var pool: BulletPool
var arena_node: Node2D
var active_patterns: Array[String] = []

# --- Phases (hybrid) ---
# v1: INACTIVE + player F/E interaction + art swaps
# v2: gate all gameplay on gs.running
enum Phase { INACTIVE, NORMAL, SHAKING, MOBILE }
var current_phase := Phase.INACTIVE
var phase_timer := 0.0

# Visual / sprite setup (keep v1 paths & node name)
var sprite: Sprite2D
var original_scale := Vector2.ONE
var last_facing_direction := 1 # 1 right, -1 left
var unlit_texture: Texture2D
var normal_texture: Texture2D
var mobile_texture: Texture2D

# Camera shake (keep v1 extras)
var camera: Camera2D
var camera_shake_intensity := 0.0

# Movement (mobile phase)
var mobile_speed := 150.0
var movement_direction := Vector2.ZERO
var movement_change_timer := 0.0

# Path-based movement
var path_points: Array[Vector2] = []
var current_path_index := 0
var path_progress := 0.0
var movement_pattern := "circle" # circle, figure8, spiral, random

# Pattern timing
var pattern_cooldown := 0.0
var base_pattern_interval := 2.0

# Game interaction
var game_active := false
var interaction_distance := 80.0

func _ready() -> void:
		add_to_group("furnace")

		# Cache original position/scale
		original_scale = scale

		# Resolve bullet pool
		if bullet_pool_path:
				pool = get_node(bullet_pool_path) as BulletPool

		# Resolve arena
		if arena_path:
				arena_node = get_node(arena_path) as Node2D
		elif get_parent() and get_parent().name == "Arena":
				arena_node = get_parent() as Node2D
		else:
				arena_node = get_tree().get_first_node_in_group("arena") as Node2D

		# Camera for shake
		camera = get_tree().get_first_node_in_group("camera") as Camera2D
		if not camera:
				camera = get_viewport().get_camera_2d()

		# Sprites (keep v1 node name + paths)
		sprite = $furnace if has_node("furnace") else null
		unlit_texture = load("res://art/furnace/furnace-unlit-64x64.png")
		normal_texture = load("res://art/furnace/furnace-64x64.png")
		mobile_texture = load("res://art/furnace/furnace-walking-64x64.png")

		# Start unlit in INACTIVE
		if sprite and unlit_texture:
				sprite.texture = unlit_texture
				sprite.visible = true
				sprite.modulate = Color.WHITE

		# Connect game state signals
		gs.connect("risk_tier_changed", _on_heat_changed)
		gs.connect("pulse_started", _on_pulse_started)

		_enter_inactive_phase()

func _process(delta: float) -> void:
		# Always allow input (F to start / E to cash out)
		_handle_input()

		# Update camera shake regardless
		if camera_shake_intensity > 0.0:
				camera_shake_intensity = max(0.0, camera_shake_intensity - delta * 5.0)
				_apply_camera_shake()

		# --- v2 gating: block gameplay until gs.running is true ---
		if not gs or not gs.running:
				# Idle bob while not running
				if sprite:
						var t := Time.get_ticks_msec() / 1000.0
						sprite.scale = original_scale * (1.0 + 0.02 * sin(t * 2.5))
				return
		else:
				# Ensure scale is restored during gameplay
				if sprite:
						sprite.scale = original_scale

		# From here on, gameplay is active
		phase_timer += delta
		pattern_cooldown -= delta

		match current_phase:
				Phase.INACTIVE:
						# Shouldn't normally happen while gs.running, but no-op if it does
						pass
				Phase.NORMAL:
						_process_normal_phase(delta)
				Phase.SHAKING:
						_process_shaking_phase(delta)
				Phase.MOBILE:
						_process_mobile_phase(delta)

# ------------------------------
# Phase processing
# ------------------------------
func _process_normal_phase(_delta: float) -> void:
		# After 60s, enter shaking
		if phase_timer >= 60.0:
				_enter_shaking_phase()
				return

		# Fire patterns at cadence, limited by heat
		if pattern_cooldown <= 0.0 and active_patterns.size() < get_max_patterns():
				_start_random_pattern()
				pattern_cooldown = base_pattern_interval

func _process_shaking_phase(_delta: float) -> void:
		# Simple "warning" period then go mobile
		if phase_timer >= 2.0:
				_enter_mobile_phase()

func _process_mobile_phase(delta: float) -> void:
		# Handle stun timer
		if is_stunned:
				stun_timer -= delta
				if stun_timer <= 0.0:
						unstun_boss()
				return  # Don't process movement or patterns while stunned

		# Initialize movement path on first frame
		if is_equal_approx(phase_timer, 0.0):
				_setup_movement_pattern()

		# Move along the chosen pattern
		_update_pattern_movement(delta)

		# Face traveling direction
		_update_sprite_facing()

		# Slightly faster fire rate in mobile
		if pattern_cooldown <= 0.0 and active_patterns.size() < get_max_patterns() + 1:
				_start_random_pattern()
				pattern_cooldown = base_pattern_interval * 0.7

# ------------------------------
# Player interaction (v1 style)
# ------------------------------
func _handle_input() -> void:
		var player = get_tree().get_first_node_in_group("player") as Node2D
		if not player:
				return

		var distance = global_position.distance_to(player.global_position)

		# F / Start to activate (only when INACTIVE and close)
		if current_phase == Phase.INACTIVE and distance <= interaction_distance:
				if Input.is_action_just_pressed("Start"):
						_activate_furnace()

		# E / CashOut to end run (from NORMAL or MOBILE)
		if current_phase == Phase.NORMAL or current_phase == Phase.MOBILE:
				if Input.is_action_just_pressed("CashOut"):
						_deactivate_furnace()

func _activate_furnace() -> void:
		game_active = true
		# Small delay, then start the run and enter NORMAL (keeps v1 feel)
		await get_tree().create_timer(3.0).timeout
		_enter_normal_phase()
		if gs:
				gs.start_run() # sets gs.running = true

func _deactivate_furnace() -> void:
		game_active = false

		# Move back to arena center (or viewport center)
		if arena_node:
				global_position = arena_node.global_position
		else:
				global_position = get_viewport().size / 2.0

		_enter_inactive_phase()

		# End the run safely (also flips gs.running = false, which gates all gameplay)
		if gs:
				gs.end_run(true)

# ------------------------------
# Phase transitions
# ------------------------------
func _enter_inactive_phase() -> void:
		current_phase = Phase.INACTIVE
		phase_timer = 0.0

		# Stop patterns & movement
		active_patterns.clear()
		velocity = Vector2.ZERO

		# Unlit art
		if sprite and unlit_texture:
				sprite.texture = unlit_texture
				sprite.visible = true
				sprite.modulate = Color.WHITE
				scale = original_scale
				sprite.flip_h = false
				last_facing_direction = 1

		_update_ui_status("INACTIVE")

func _enter_normal_phase() -> void:
		current_phase = Phase.NORMAL
		phase_timer = 0.0

		# Lit / stationary art
		if sprite and normal_texture:
				sprite.texture = normal_texture
				sprite.visible = true
				sprite.modulate = Color.WHITE
				scale = original_scale
				sprite.flip_h = false
				last_facing_direction = 1

		_update_ui_status("NORMAL")

func _enter_shaking_phase() -> void:
		current_phase = Phase.SHAKING
		phase_timer = 0.0
		camera_shake_intensity = 15.0

		# Visual warning
		if sprite:
				sprite.modulate = Color.RED

		# Halt current patterns briefly during warning
		active_patterns.clear()
		pattern_cooldown = 3.0

		_update_ui_status("SHAKING")

func _enter_mobile_phase() -> void:
		current_phase = Phase.MOBILE
		phase_timer = 0.0

		# Mobile art
		if sprite and mobile_texture:
				sprite.texture = mobile_texture
				sprite.visible = true
				sprite.modulate = Color.ORANGE
				scale = original_scale * 1.2
		elif sprite:
				sprite.modulate = Color.ORANGE
				scale = original_scale * 1.2

		_change_movement_direction()
		_update_ui_status("MOBILE")

# ------------------------------
# UI helpers (missing before)
# ------------------------------
func _update_ui_status(phase: String) -> void:
		var ui = get_tree().get_first_node_in_group("ui")
		if ui and ui.has_method("update_furnace_status"):
				ui.update_furnace_status(phase)

# ------------------------------
# Movement helpers
# ------------------------------
func _change_movement_direction() -> void:
		var angle = rng.randf_range(0.0, TAU)
		movement_direction = Vector2.RIGHT.rotated(angle)

func _setup_movement_pattern() -> void:
		var patterns = ["circle", "figure8", "spiral", "random"]
		movement_pattern = patterns[rng.randi() % patterns.size()]

		var arena_center = arena_node and arena_node.global_position or global_position

		path_points.clear()
		current_path_index = 0
		path_progress = 0.0

		match movement_pattern:
				"circle":
						var radius = 150.0
						for i in range(8):
								var a = (TAU * i) / 8.0
								path_points.append(arena_center + Vector2.RIGHT.rotated(a) * radius)
				"figure8":
						var rx = 120.0
						var ry = 80.0
						for i in range(12):
								var t = (float(i) / 12.0) * TAU
								var x = arena_center.x + rx * sin(t)
								var y = arena_center.y + ry * sin(t * 2.0)
								path_points.append(Vector2(x, y))
				"spiral":
						for i in range(16):
								var a2 = (TAU * i) / 16.0
								var r = 50.0 + (i * 8.0)
								path_points.append(arena_center + Vector2.RIGHT.rotated(a2) * r)
				"random":
						for i in range(6):
								var ro = Vector2(rng.randf_range(-150.0, 150.0), rng.randf_range(-150.0, 150.0))
								path_points.append(arena_center + ro)

func _update_pattern_movement(delta: float) -> void:
		# Fallback simple wander if no path
		if path_points.size() == 0:
				movement_change_timer -= delta
				if movement_change_timer <= 0.0:
						_change_movement_direction()
						movement_change_timer = rng.randf_range(2.0, 4.0)
				velocity = movement_direction * mobile_speed
				move_and_slide()
				return

		# Follow waypoints
		var target_point = path_points[current_path_index]
		var direction = (target_point - global_position).normalized()
		var distance = global_position.distance_to(target_point)

		if distance > 10.0:
				velocity = direction * mobile_speed
				move_and_slide()
		else:
				current_path_index = (current_path_index + 1) % path_points.size()
				if current_path_index == 0 and rng.randf() < 0.3:
						_setup_movement_pattern()

func _update_sprite_facing() -> void:
		if not sprite:
				return
		if velocity.length() > 0.1:
				var d = velocity.normalized()
				if d.x > 0.1:
						if last_facing_direction == -1:
								sprite.flip_h = false
								last_facing_direction = 1
				elif d.x < -0.1:
						if last_facing_direction == 1:
								sprite.flip_h = true
								last_facing_direction = -1

# ------------------------------
# Patterns
# ------------------------------
func get_max_patterns() -> int:
		return 1 + int(gs.heat / 2)

func _start_random_pattern() -> void:
		var patterns = ["radial", "spiral", "aimed", "wall", "orbit", "flower"]
		if current_phase == Phase.MOBILE:
				patterns.append_array(["cross_fire", "spiral_burst", "chaos_orb"])
		if patterns.is_empty():
				return
		var idx = rng.randi() % patterns.size()
		_start_pattern(patterns[idx])

func _start_pattern(pattern_name: String) -> void:
		if active_patterns.has(pattern_name):
				return
		active_patterns.append(pattern_name)
		match pattern_name:
				"radial": await _radial_burst()
				"spiral": await _spiral_stream()
				"aimed": await _aimed_volley()
				"wall": await _wall_sweep()
				"orbit": await _orbit_mines()
				"flower": await _flower_pulse()
				"cross_fire": await _cross_fire()
				"spiral_burst": await _spiral_burst()
				"chaos_orb": await _chaos_orb()
		active_patterns.erase(pattern_name)

func _radial_burst() -> void:
		var n = 12 + gs.heat * 6
		var speed = 120.0 + gs.heat * 30.0
		for i in range(n):
				var ang = TAU * (float(i) / n)
				_fire_fireball(global_position, Vector2.RIGHT.rotated(ang) * speed, 4.0)
		await get_tree().create_timer(1.0).timeout

func _spiral_stream() -> void:
		var rpm = 60.0 + gs.heat * 20.0
		var speed = 100.0 + gs.heat * 25.0
		var t = 0.0
		var dur = 2.0
		while t < dur:
				var ang = deg_to_rad((t * rpm) * 6.0)
				_fire_fireball(global_position, Vector2.RIGHT.rotated(ang) * speed, 4.0)
				t += 0.08
				await get_tree().create_timer(0.08).timeout

func _aimed_volley() -> void:
		var player = get_tree().get_first_node_in_group("player") as Node2D
		if not player:
				return
		var spread = deg_to_rad(10.0 + gs.heat * 5.0)
		var dir = (player.global_position - global_position).angle()
		for angle in [dir - spread, dir, dir + spread]:
				_fire_fireball(global_position, Vector2.RIGHT.rotated(angle) * 180.0, 4.0)
		await get_tree().create_timer(0.6).timeout

func _wall_sweep() -> void:
		# Fixed vertical sweep to move DOWN (v2 fix), plus cross uses correct axes
		var rect = get_viewport_rect()
		var size = rect.size
		var heat = gs.heat
		var cols = 8 + heat * 2
		var speed = 160.0 + heat * 30.0
		var col_spacing = size.x / float(cols + 1)
		var mode = rng.randi_range(0, 3)

		match mode:
				0:
						# Horizontal laser sweep: move DOWN
						var life = (size.y + 120.0) / speed
						for i in range(cols):
								var x_pos = rect.position.x + (i + 1) * col_spacing
								var pos = Vector2(x_pos, rect.position.y - 40.0)
								_fire_laser(pos, Vector2(0, speed), life)
								await get_tree().create_timer(0.1).timeout
				1:
						# Vertical laser sweep: move RIGHT
						var life2 = (size.x + 120.0) / speed
						for i in range(cols):
								var y_pos = rect.position.y + (i + 1) * (size.y / float(cols + 1))
								var pos2 = Vector2(rect.position.x - 40.0, y_pos)
								_fire_laser(pos2, Vector2(speed, 0), life2)
								await get_tree().create_timer(0.1).timeout
				_:
						# Cross: horizontal line moves RIGHT, vertical line moves DOWN (fixed)
						var life3 = max(size.x, size.y) / speed
						# Horizontal row at furnace Y
						for i in range(cols):
								var x_pos2 = rect.position.x + (i + 1) * col_spacing
								var p1 = Vector2(x_pos2, global_position.y)
								_fire_laser(p1, Vector2.RIGHT * speed, life3)
						# Vertical column at furnace X (DOWN)
						for i2 in range(cols):
								var y_pos2 = rect.position.y + (i2 + 1) * (size.y / float(cols + 1))
								var p2 = Vector2(global_position.x, y_pos2)
								_fire_laser(p2, Vector2(0, speed), life3)

		await get_tree().create_timer(0.5).timeout

func _orbit_mines() -> void:
		var n = 6 + gs.heat * 3
		var radius = 100.0
		var speed = 80.0
		for i in range(n):
				var ang = TAU * (float(i) / n)
				var pos = global_position + Vector2.RIGHT.rotated(ang) * radius
				var vel = Vector2.RIGHT.rotated(ang + PI / 2.0) * speed
				_fire_fireball(pos, vel, 6.0)
		await get_tree().create_timer(0.8).timeout

func _flower_pulse() -> void:
		var petals = 8 + gs.heat * 4
		var speed = 140.0
		for i in range(petals):
				var ang = TAU * (float(i) / petals)
				_fire_fireball(global_position, Vector2.RIGHT.rotated(ang) * speed, 4.0)
				_fire_fireball(global_position, Vector2.RIGHT.rotated(ang) * speed * 0.7, 4.0)
		await get_tree().create_timer(0.6).timeout

func _cross_fire() -> void:
		var speed = 150.0
		var spread = deg_to_rad(15.0)
		# Horizontal cross
		for offset in [-spread, 0.0, spread]:
				_fire_fireball(global_position, Vector2.RIGHT.rotated(offset) * speed, 4.0)
				_fire_fireball(global_position, Vector2.LEFT.rotated(offset) * speed, 4.0)
		# Vertical cross
		for offset in [-spread, 0.0, spread]:
				_fire_fireball(global_position, Vector2.UP.rotated(offset) * speed, 4.0)
				_fire_fireball(global_position, Vector2.DOWN.rotated(offset) * speed, 4.0)
		await get_tree().create_timer(0.5).timeout

func _spiral_burst() -> void:
		var spirals = 3 + gs.heat
		var speed = 120.0 + gs.heat * 20.0
		for s in range(spirals):
				var offset_angle = TAU * s / spirals
				for i in range(12):
						var ang = offset_angle + (TAU * i / 12.0)
						_fire_fireball(global_position, Vector2.RIGHT.rotated(ang) * speed, 4.0)
				await get_tree().create_timer(0.2).timeout

func _chaos_orb() -> void:
		var orbs = 4 + gs.heat
		var speed = 100.0
		for i in range(orbs):
				var ang = rng.randf_range(0.0, TAU)
				var pos = global_position + Vector2.RIGHT.rotated(ang) * 80.0
				var vel = Vector2.RIGHT.rotated(ang + rng.randf_range(-0.5, 0.5)) * speed
				_fire_fireball(pos, vel, 3.0)
		await get_tree().create_timer(0.8).timeout

# ------------------------------
# Bullet helpers
# ------------------------------
func _fire_fireball(pos: Vector2, vel: Vector2, life: float, damage: int = 1) -> void:
		if pool:
				pool.fire_fireball(pos, vel, life, damage)
		else:
				push_warning("Furnace: Bullet pool not connected!")

func _fire_laser(pos: Vector2, vel: Vector2, life: float, damage: int = 2) -> void:
		if pool:
				pool.fire_laser(pos, vel, life, damage)
		else:
				push_warning("Furnace: Bullet pool not connected!")

# ------------------------------
# Signals
# ------------------------------
func _on_heat_changed(_tier: int) -> void:
		# Hook for dynamic tuning by heat (kept as stub)
		pass

func _on_pulse_started() -> void:
		await _flower_pulse()
		gs.pulse_end(true)

# ------------------------------
# Stun system for Anchor item
# ------------------------------
var stun_timer := 0.0
var is_stunned := false

func stun_boss(duration: float) -> void:
		if current_phase != Phase.MOBILE:
				return  # Only works in mobile phase
		
		is_stunned = true
		stun_timer = duration
		velocity = Vector2.ZERO
		
		# Visual feedback
		if sprite:
				sprite.modulate = Color.BLUE

func unstun_boss() -> void:
		is_stunned = false
		stun_timer = 0.0
		
		# Restore normal mobile phase color
		if sprite and mobile_texture:
				sprite.modulate = Color.ORANGE

# ------------------------------
# Camera shake
# ------------------------------
func _apply_camera_shake() -> void:
		if camera:
				var off := Vector2(
						rng.randf_range(-camera_shake_intensity, camera_shake_intensity),
						rng.randf_range(-camera_shake_intensity, camera_shake_intensity)
				)
				camera.offset = off
