extends Node2D
class_name MixerArmEmitter

# MixerArm - rotating bar with length, rotation speed, and bursts parameters
@export var arm_length: float = 150.0    # Length of the rotating arm
@export var rotation_speed: float = 60.0 # Rotation speed in degrees per second
@export var burst_interval: float = 1.5  # Time between bursts
@export var bullets_per_burst: int = 3   # Number of bullets per burst
@export var bullet_speed: float = 180.0  # Speed of bullets
@export var bullet_life: float = 2.5    # Lifetime of bullets
@export var arm_segments: int = 5       # Number of segments along the arm

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
	_start_rotation()

func stop_emission() -> void:
	is_active = false

func _start_rotation() -> void:
	if not is_active:
		return
	
	# Rotate continuously and fire bursts
	while is_active:
		# Update rotation
		current_angle += rotation_speed * burst_interval
		if current_angle >= 360.0:
			current_angle -= 360.0
		
		# Fire burst from arm segments
		_fire_burst()
		
		# Wait for next burst
		if is_active:
			await get_tree().create_timer(burst_interval).timeout

func _fire_burst() -> void:
	if not bullet_pool:
		return
	
	# Fire bullets from different segments along the arm
	for i in range(bullets_per_burst):
		# Calculate position along the arm
		var segment_ratio = float(i) / float(max(1, bullets_per_burst - 1))
		var distance = arm_length * segment_ratio
		
		# Calculate spawn position
		var direction = Vector2.RIGHT.rotated(deg_to_rad(current_angle))
		var spawn_pos = global_position + direction * distance
		
		# Calculate bullet velocity (perpendicular to arm for spreading effect)
		var bullet_direction = direction.rotated(deg_to_rad(90))
		var velocity = bullet_direction * bullet_speed
		
		# Add some randomness for natural spread
		var random_angle = deg_to_rad(15.0)
		velocity = velocity.rotated(randf_range(-random_angle, random_angle))
		
		bullet_pool.fire(spawn_pos, velocity, bullet_life)

func apply_speed_scale(scale: float) -> void:
	# Apply speed scaling to timing and velocity parameters
	rotation_speed *= scale
	burst_interval /= scale
	bullet_speed *= scale
