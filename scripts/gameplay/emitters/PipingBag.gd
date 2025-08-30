extends Node2D
class_name PipingBagEmitter

# PipingBag - cone sprays with arc and cadence parameters
@export var arc_degrees: float = 45.0  # Spread of the cone in degrees
@export var cadence: float = 0.1        # Time between shots in seconds
@export var bullet_speed: float = 200.0  # Speed of bullets
@export var bullet_life: float = 3.0    # Lifetime of bullets
@export var burst_count: int = 5        # Number of shots per burst
@export var burst_interval: float = 1.0  # Time between bursts

var bullet_pool: BulletPool
var is_active: bool = false
var current_burst: int = 0

func _ready() -> void:
	add_to_group("emitter")

func _on_tree_entered() -> void:
	# Find bullet pool when entering tree
	bullet_pool = get_tree().get_first_node_in_group("bullet_pool") as BulletPool

func start_emission() -> void:
	is_active = true
	current_burst = 0
	_fire_burst()

func stop_emission() -> void:
	is_active = false

func _fire_burst() -> void:
	if not is_active or not bullet_pool:
		return
	
	# Fire a burst of bullets in a cone pattern
	for i in range(burst_count):
		var angle_offset = (float(i) / float(burst_count - 1) - 0.5) * deg_to_rad(arc_degrees)
		var direction = Vector2.RIGHT.rotated(angle_offset)
		var velocity = direction * bullet_speed
		
		# Add some randomness for more natural spread
		var random_spread = deg_to_rad(arc_degrees * 0.1)
		velocity = velocity.rotated(randf_range(-random_spread, random_spread))
		
		bullet_pool.fire(global_position, velocity, bullet_life)
		
		# Small delay between shots in burst
		if i < burst_count - 1:
			await get_tree().create_timer(cadence).timeout
	
	# Schedule next burst
	current_burst += 1
	if is_active:
		await get_tree().create_timer(burst_interval).timeout
		_fire_burst()

func apply_speed_scale(scale: float) -> void:
	# Apply speed scaling to all timing and velocity parameters
	cadence /= scale
	burst_interval /= scale
	bullet_speed *= scale
