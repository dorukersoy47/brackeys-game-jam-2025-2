extends Node2D
class_name SprinkleCannonEmitter

# SprinkleCannon - burst pellets with pellet count and spread parameters
@export var pellet_count: int = 12      # Number of pellets per burst
@export var spread_degrees: float = 60.0 # Spread of pellets in degrees
@export var burst_interval: float = 2.0  # Time between bursts
@export var bullet_speed: float = 150.0  # Speed of pellets
@export var bullet_life: float = 2.5    # Lifetime of pellets
@export var random_speed_variation: float = 0.3  # Random speed variation (0.0 to 1.0)

var bullet_pool: BulletPool
var is_active: bool = false

func _ready() -> void:
	add_to_group("emitter")

func _on_tree_entered() -> void:
	# Find bullet pool when entering tree
	bullet_pool = get_tree().get_first_node_in_group("bullet_pool") as BulletPool

func start_emission() -> void:
	is_active = true
	_fire_burst()

func stop_emission() -> void:
	is_active = false

func _fire_burst() -> void:
	if not is_active or not bullet_pool:
		return
	
	# Fire a burst of pellets with spread
	for i in range(pellet_count):
		var angle = (float(i) / float(pellet_count)) * deg_to_rad(spread_degrees)
		var direction = Vector2.RIGHT.rotated(angle)
		
		# Add random speed variation
		var speed_multiplier = 1.0 + randf_range(-random_speed_variation, random_speed_variation)
		var velocity = direction * bullet_speed * speed_multiplier
		
		# Add small random spread for more natural pattern
		var random_spread = deg_to_rad(spread_degrees * 0.05)
		velocity = velocity.rotated(randf_range(-random_spread, random_spread))
		
		bullet_pool.fire(global_position, velocity, bullet_life)
	
	# Schedule next burst
	if is_active:
		await get_tree().create_timer(burst_interval).timeout
		_fire_burst()

func apply_speed_scale(scale: float) -> void:
	# Apply speed scaling to timing and velocity parameters
	burst_interval /= scale
	bullet_speed *= scale
