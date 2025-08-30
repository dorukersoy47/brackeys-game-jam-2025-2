extends Node2D
class_name PatternController

signal phase_started(phase_id: int)

@onready var rng: RNGService = get_node("/root/RNG") as RNGService
@onready var gs: GameStateData = get_node("/root/GameState") as GameStateData

@export var bullet_pool_path: NodePath
var pool: BulletPool
var active_types: Array[String] = []
var elite_pending := false

# Timeline scheduler variables
var current_phase_id: int = 0
var timeline: Array[Dictionary] = []
var timeline_time: float = 0.0
var is_timeline_running: bool = false

# Speed scaling
var speed_scale: float = 1.0

# Emitter instances
var emitters: Dictionary = {}

const DEFAULT_PATTERN_SPEED = 1.0

func _ready() -> void:
				add_to_group("pattern_controller")
				pool = get_node(bullet_pool_path) as BulletPool
				gs.connect("risk_tier_changed", _on_heat)
				gs.connect("pulse_started", _on_pulse_started)
				gs.connect("request_bullet_clear", _on_bullet_clear)
				
				# Initialize emitters
				_initialize_emitters()

func _initialize_emitters() -> void:
				# Create and configure emitters
				var emitter_scenes = {
						"piping_bag": preload("res://scenes/hazards/PipingBag.tscn"),
						"sprinkle_cannon": preload("res://scenes/hazards/SprinkleCannon.tscn"),
						"glaze_curtain": preload("res://scenes/hazards/GlazeCurtain.tscn"),
						"mixer_arm": preload("res://scenes/hazards/MixerArm.tscn")
				}
				
				for emitter_name in emitter_scenes:
						var scene = emitter_scenes[emitter_name]
						if scene:
								var emitter = scene.instantiate()
								add_child(emitter)
								emitters[emitter_name] = emitter

# Timeline scheduler methods
func start_timeline(phase_config: Array) -> void:
				# Start a new timeline phase
				current_phase_id += 1
				timeline = phase_config
				timeline_time = 0.0
				is_timeline_running = true
				emit_signal("phase_started", current_phase_id)

func stop_timeline() -> void:
				is_timeline_running = false
				# Stop all emitters
				for emitter in emitters.values():
						if emitter.has_method("stop_emission"):
								emitter.stop_emission()

func add_timeline_phase(duration: float, emitter_configs: Array) -> void:
				# Add a phase to the timeline
				var phase = {
						"duration": duration,
						"emitters": emitter_configs,
						"start_time": timeline_time
				}
				timeline.append(phase)

func _process(delta: float) -> void:
				# Process timeline scheduler
				if is_timeline_running:
						_process_timeline(delta)
				
				# Simple scheduler: decide patterns based on heat and time
				if active_types.size() < 1:
								_start_pattern(_pick_pattern())
				if gs.heat >= 1 and active_types.size() < 2 and rng.randf() < 0.005:
								_start_pattern(_pick_pattern())

func _process_timeline(delta: float) -> void:
				timeline_time += delta * speed_scale
				
				# Check if we need to start/stop emitters based on timeline
				for phase in timeline:
						var phase_start = phase["start_time"]
						var phase_end = phase_start + phase["duration"]
						
						if timeline_time >= phase_start and timeline_time < phase_end:
								# Start emitters for this phase
								for emitter_config in phase["emitters"]:
										var emitter_name = emitter_config["name"]
										if emitters.has(emitter_name):
												var emitter = emitters[emitter_name]
												if emitter.has_method("start_emission"):
														emitter.start_emission()
														# Apply emitter-specific configuration
														_configure_emitter(emitter, emitter_config)
						elif timeline_time >= phase_end:
								# Stop emitters for this phase
								for emitter_config in phase["emitters"]:
										var emitter_name = emitter_config["name"]
										if emitters.has(emitter_name):
												var emitter = emitters[emitter_name]
												if emitter.has_method("stop_emission"):
														emitter.stop_emission()
				
				# Check if timeline is complete
				if timeline_time > 0 and timeline_time >= timeline[-1]["start_time"] + timeline[-1]["duration"]:
						stop_timeline()

func _configure_emitter(emitter: Node, config: Dictionary) -> void:
				# Apply configuration to emitter
				for param in config:
						if param != "name" and emitter.has_method("set"):
								emitter.set(param, config[param])

# Speed scaling methods
func apply_speed_scale(scale: float) -> void:
				# Apply speed scaling to all emitters and timeline
				speed_scale = scale
				
				# Apply to all emitters
				for emitter in emitters.values():
						if emitter.has_method("apply_speed_scale"):
								emitter.apply_speed_scale(scale)

func get_speed_scale() -> float:
				return speed_scale

func reset_speed_scale() -> void:
				apply_speed_scale(DEFAULT_PATTERN_SPEED)

func trigger_elite_burst() -> void:
				elite_pending = true

func _start_pattern(kind: String) -> void:
				if active_types.has(kind):
								return
				if active_types.size() >= 2:
								return
				active_types.append(kind)
				match kind:
								"radial": await _radial_burst()
								"spiral": await _spiral_stream()
								"aimed": await _aimed_volley()
								"wall": await _wall_sweep()
								"orbit": await _orbit_mines()
								"flower": await _flower_pulse()
				active_types.erase(kind)

func _pick_pattern() -> String:
				var all := ["radial","spiral","aimed","wall","orbit","flower"]
				return all[rng.randi_range(0, all.size()-2 + int(gs.heat>1))]

func _on_heat(_tier: int) -> void:
				pass

func _on_pulse_started() -> void:
				await _flower_pulse(true)
				gs.pulse_end(true)

# --- Pattern Implementations ---
func _radial_burst() -> void:
				var n := 12 + gs.heat * 6
				var speed := 120.0 + gs.heat * 30.0
				var pos := global_position
				for i in range(n):
								var ang := TAU * (float(i)/n)
								pool.fire(pos, Vector2.RIGHT.rotated(ang) * speed, 4.0)
				await get_tree().create_timer(1.0).timeout

func _spiral_stream() -> void:
				var pos := global_position
				var rpm := 60.0 + gs.heat * 20.0
				var speed := 100.0 + gs.heat * 25.0
				var t := 0.0
				var dur := 2.0
				while t < dur:
								var ang := deg_to_rad((t * rpm) * 6.0)
								pool.fire(pos, Vector2.RIGHT.rotated(ang) * speed, 4.0)
								t += 0.08
								await get_tree().create_timer(0.08).timeout

func _aimed_volley() -> void:
				var player := get_tree().get_first_node_in_group("player") as Node2D
				if not player: return
				var pos := global_position
				var spread := deg_to_rad(10.0 + gs.heat * 5.0)
				var dir := (player.global_position - pos).angle()
				for angle in [dir-spread, dir, dir+spread]:
								pool.fire(pos, Vector2.RIGHT.rotated(angle) * 180.0, 4.0)
				await get_tree().create_timer(0.6).timeout

func _wall_sweep() -> void:
				# Versatile wall pattern: random orientation & origin with moving gaps
				# Modes: 0=top→down, 1=bottom→up, 2=left→right, 3=right→left,
				#        4=center→sides (horizontal), 5=center→up&down (vertical)
				var rect := get_viewport_rect()
				var size := rect.size
				var top := rect.position.y
				var left := rect.position.x
				var right := left + size.x
				var bottom := top + size.y
				var center := rect.position + size * 0.5

				var heat := gs.heat
				var cols := 10 + heat * 2       # grid density
				var rows := 6 + heat            # pulses
				var speed := 140.0 + heat * 30.0
				var row_interval := 0.16        # time between pulses

				var col_spacing := size.x / float(cols + 1)
				var row_spacing := size.y / float(rows + 1)

				var mode := rng.randi_range(0, 5)

				if mode == 0:
								# Top → Down
								var life := (size.y + 120.0) / speed
								var gap := rng.randi_range(0, cols - 1)
								var gap2 := gap if heat < 2 else (gap + rng.randi_range(1, max(1, cols - 1))) % cols
								for step in range(rows):
												if heat >= 1: gap = clamp(gap + rng.randi_range(-1, 1), 0, cols - 1)
												if heat >= 2: gap2 = clamp(gap2 + rng.randi_range(-1, 1), 0, cols - 1)
												for c in range(cols):
																if c == gap or c == gap2: continue
																var x_pos := left + (c + 1) * col_spacing
																var pos := Vector2(x_pos, top - 40.0)
																pool.fire(pos, Vector2(0, speed), life)
												await get_tree().create_timer(row_interval).timeout
				elif mode == 1:
								# Bottom → Up
								var life := (size.y + 120.0) / speed
								var gap := rng.randi_range(0, cols - 1)
								var gap2 := gap if heat < 2 else (gap + rng.randi_range(1, max(1, cols - 1))) % cols
								for step in range(rows):
												if heat >= 1: gap = clamp(gap + rng.randi_range(-1, 1), 0, cols - 1)
												if heat >= 2: gap2 = clamp(gap2 + rng.randi_range(-1, 1), 0, cols - 1)
												for c in range(cols):
																if c == gap or c == gap2: continue
																var x_pos := left + (c + 1) * col_spacing
																var pos := Vector2(x_pos, bottom + 40.0)
																pool.fire(pos, Vector2(0, -speed), life)
												await get_tree().create_timer(row_interval).timeout
				elif mode == 2:
								# Left → Right
								var life := (size.x + 120.0) / speed
								var gap := rng.randi_range(0, rows - 1)
								var gap2 := gap if heat < 2 else (gap + rng.randi_range(1, max(1, rows - 1))) % rows
								for step in range(cols):
												if heat >= 1: gap = clamp(gap + rng.randi_range(-1, 1), 0, rows - 1)
												if heat >= 2: gap2 = clamp(gap2 + rng.randi_range(-1, 1), 0, rows - 1)
												for r in range(rows):
																if r == gap or r == gap2: continue
																var y_pos := top + (r + 1) * row_spacing
																var pos := Vector2(left - 40.0, y_pos)
																pool.fire(pos, Vector2(speed, 0), life)
												await get_tree().create_timer(row_interval).timeout
				elif mode == 3:
								# Right → Left
								var life := (size.x + 120.0) / speed
								var gap := rng.randi_range(0, rows - 1)
								var gap2 := gap if heat < 2 else (gap + rng.randi_range(1, max(1, rows - 1))) % rows
								for step in range(cols):
												if heat >= 1: gap = clamp(gap + rng.randi_range(-1, 1), 0, rows - 1)
												if heat >= 2: gap2 = clamp(gap2 + rng.randi_range(-1, 1), 0, rows - 1)
												for r in range(rows):
																if r == gap or r == gap2: continue
																var y_pos := top + (r + 1) * row_spacing
																var pos := Vector2(right + 40.0, y_pos)
																pool.fire(pos, Vector2(-speed, 0), life)
												await get_tree().create_timer(row_interval).timeout
				elif mode == 4:
								# Center → Sides (Horizontal explosion)
								var life := (size.x * 0.5 + 120.0) / speed
								var gap := rng.randi_range(0, rows - 1)
								var gap2 := gap if heat < 2 else (gap + rng.randi_range(1, max(1, rows - 1))) % rows
								for step in range(cols):
												if heat >= 1: gap = clamp(gap + rng.randi_range(-1, 1), 0, rows - 1)
												if heat >= 2: gap2 = clamp(gap2 + rng.randi_range(-1, 1), 0, rows - 1)
												for r in range(rows):
																if r == gap or r == gap2: continue
																var y_pos := top + (r + 1) * row_spacing
																var p := Vector2(center.x, y_pos)
																pool.fire(p, Vector2(speed, 0), life)
																pool.fire(p, Vector2(-speed, 0), life)
												await get_tree().create_timer(row_interval).timeout
				else:
								# Center → Up & Down (Vertical explosion)
								var life := (size.y * 0.5 + 120.0) / speed
								var gap := rng.randi_range(0, cols - 1)
								var gap2 := gap if heat < 2 else (gap + rng.randi_range(1, max(1, cols - 1))) % cols
								for step in range(rows):
												if heat >= 1: gap = clamp(gap + rng.randi_range(-1, 1), 0, cols - 1)
												if heat >= 2: gap2 = clamp(gap2 + rng.randi_range(-1, 1), 0, cols - 1)
												for c in range(cols):
																if c == gap or c == gap2: continue
																var x_pos := left + (c + 1) * col_spacing
																var p := Vector2(x_pos, center.y)
																pool.fire(p, Vector2(0, speed), life)
																pool.fire(p, Vector2(0, -speed), life)
												await get_tree().create_timer(row_interval).timeout

func _orbit_mines() -> void:
				# spawn mines that detach
				var center := global_position
				var count := 2 + gs.heat
				for i in range(count):
								var ang := TAU * (float(i)/count)
								var pos := center + Vector2.RIGHT.rotated(ang) * 60.0
								pool.fire(pos, Vector2.ZERO, 2.0)
								await get_tree().create_timer(0.5).timeout
				# detach phase
				for i in range(count):
								var ang := TAU * (float(i)/count)
								pool.fire(center, Vector2.RIGHT.rotated(ang) * 140.0, 3.0)
				await get_tree().create_timer(0.8).timeout

func _flower_pulse(boss := false) -> void:
				var petals := 16 if boss else 10
				var speed := 160.0 if boss else 120.0
				var waves := 12 if boss else 6
				for w in range(waves):
								var phase := w * 0.35
								for i in range(petals):
												var ang := TAU * i/float(petals) + phase
												pool.fire(global_position, Vector2.RIGHT.rotated(ang) * speed, 5.0)
								await get_tree().create_timer(0.25).timeout

func _on_bullet_clear() -> void:
				# Clear all active bullets with visual effect
				var bullets = get_tree().get_nodes_in_group("EnemyBullet")
				for bullet in bullets:
								if bullet.has_method("explode_and_free"):
												bullet.explode_and_free()
								else:
												bullet.queue_free()
				
				# Visual feedback for bullet clear
				var flash := ColorRect.new()
				flash.color = Color(1, 1, 0, 0.3)  # Yellow flash
				flash.size = get_viewport_rect().size
				flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
				get_tree().root.add_child(flash)
				var tw := create_tween()
				tw.tween_property(flash, "color:a", 0.0, 0.3)
				await tw.finished
				if is_instance_valid(flash):
								flash.queue_free()
