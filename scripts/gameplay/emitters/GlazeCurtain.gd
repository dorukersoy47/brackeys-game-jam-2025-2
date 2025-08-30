extends Node2D
class_name GlazeCurtainEmitter

# GlazeCurtain - sweeping beams with width and sweep speed parameters
@export var beam_width: float = 200.0    # Width of the beam in pixels
@export var sweep_speed: float = 90.0    # Sweep speed in degrees per second
@export var sweep_arc: float = 180.0     # Total sweep arc in degrees
@export var beam_density: int = 8       # Number of bullets per beam
@export var beam_interval: float = 3.0   # Time between beam sweeps
@export var bullet_speed: float = 250.0  # Speed of beam bullets
@export var bullet_life: float = 2.0    # Lifetime of beam bullets

var bullet_pool: BulletPool
var is_active: bool = false
var current_angle: float = 0.0

func _ready() -> void:
	add_to_group("emitter")

func _on_tree_entered() -> void:
	# Find bullet pool when entering tree
	bullet_pool = get_tree().get_first_node_in_group("bullet_pool") as BulletPool

func start_emission() -> void:
	is_active = true
	current_angle = 0.0
	_sweep_beam()

func stop_emission() -> void:
	is_active = false

func _sweep_beam() -> void:
	if not is_active or not bullet_pool:
		return
	
	# Calculate sweep direction
	var direction = Vector2.RIGHT.rotated(deg_to_rad(current_angle))
	
	# Fire beam as a line of bullets
	for i in range(beam_density):
		var offset = (float(i) / float(beam_density - 1) - 0.5) * beam_width
		var perpendicular = Vector2.UP.rotated(deg_to_rad(current_angle))
		var spawn_pos = global_position + perpendicular * offset
		
		bullet_pool.fire(spawn_pos, direction * bullet_speed, bullet_life)
	
	# Update angle for next sweep
	current_angle += sweep_speed * 0.1  # Small time step for smooth sweep
	if current_angle >= sweep_arc:
		current_angle = 0.0
		# Wait before starting new sweep
		if is_active:
			await get_tree().create_timer(beam_interval).timeout
	else:
		# Continue sweeping
		if is_active:
			await get_tree().create_timer(0.1).timeout
	
	if is_active:
		_sweep_beam()

func apply_speed_scale(scale: float) -> void:
	# Apply speed scaling to timing and velocity parameters
	sweep_speed *= scale
	beam_interval /= scale
	bullet_speed *= scale
