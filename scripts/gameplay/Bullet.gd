extends Area2D
class_name Bullet

@export var speed := 140.0
var velocity := Vector2.ZERO
var lifetime := 4.0
var alive := false

# Bullet type and properties
enum BulletType { FIREBALL, LASER }
var bullet_type = BulletType.FIREBALL
var is_laser := false
var damage := 1

# Visual effects
@export var fireball_sprite: Texture2D
@export var laser_sprite: Texture2D
@export var fireball_particle_texture: Texture2D
@export var laser_particle_texture: Texture2D

# Visual settings
@export var fireball_scale: Vector2 = Vector2(1, 1)
@export var laser_scale: Vector2 = Vector2(0.3, 2.0)
@export var fireball_color: Color = Color.ORANGE
@export var laser_color: Color = Color.RED
@export var fireball_tilt_degrees: float = 0.0

var original_scale := Vector2.ONE
var trail_particles: GPUParticles2D

func _ready() -> void:
	original_scale = scale

	# --- Collisions: EnemyBullet (layer 4) hits Player (mask 1) ---
	collision_layer = 0
	set_collision_layer_value(4, true)
	collision_mask = 0
	set_collision_mask_value(1, true)
	# set_collision_mask_value(5, true) # enable if bullets should hit World
	monitoring = true
	monitorable = true

	if get_node_or_null("CollisionShape2D") == null:
		push_warning("Bullet: missing CollisionShape2D child — no collisions will occur.")

	if not is_connected("body_entered", Callable(self, "_on_body_entered")):
		body_entered.connect(_on_body_entered)

	# Visual defaults
	if not fireball_sprite:
		fireball_sprite = create_default_texture(fireball_color, Vector2(16, 16))
	if not laser_sprite:
		laser_sprite = create_default_texture(laser_color, Vector2(8, 32))
	if not fireball_particle_texture:
		fireball_particle_texture = fireball_sprite
	if not laser_particle_texture:
		laser_particle_texture = laser_sprite

	if bullet_type == BulletType.FIREBALL:
		_setup_fireball_trail()
	elif bullet_type == BulletType.LASER:
		_setup_laser_visual()

func create_default_texture(color: Color, size: Vector2) -> Texture2D:
	var image := Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

func _setup_fireball_trail() -> void:
	trail_particles = GPUParticles2D.new()
	trail_particles.amount = 6
	trail_particles.lifetime = 0.3
	trail_particles.process_material = create_fireball_material()
	trail_particles.texture = fireball_particle_texture
	trail_particles.emitting = false
	add_child(trail_particles)

func _setup_laser_visual() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.scale = laser_scale
		sprite.modulate = laser_color

func create_fireball_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	m.direction = Vector3(0, 0, -1)
	m.spread = 120.0
	m.gravity = Vector3.ZERO
	m.initial_velocity_min = 20.0
	m.initial_velocity_max = 40.0
	m.scale_min = 0.2
	m.scale_max = 0.4
	m.color = fireball_color
	m.emission_sphere_radius = 3.0
	return m

func fire(pos: Vector2, vel: Vector2, life: float) -> void:
	global_position = pos
	velocity = vel
	lifetime = life
	alive = true
	visible = true
	monitoring = true

	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		if bullet_type == BulletType.FIREBALL:
			sprite.texture = fireball_sprite
			sprite.scale = fireball_scale
			sprite.modulate = fireball_color
		else:
			sprite.texture = laser_sprite
			sprite.scale = laser_scale
			sprite.modulate = laser_color

	if trail_particles:
		trail_particles.emitting = (bullet_type == BulletType.FIREBALL)

	if vel != Vector2.ZERO:
		rotation = vel.angle()
		if bullet_type == BulletType.FIREBALL:
			rotation += deg_to_rad(fireball_tilt_degrees)

func _physics_process(delta: float) -> void:
	if not alive:
		return

	lifetime -= delta
	if lifetime <= 0.0:
		_despawn()
		return

	global_position += velocity * delta

	if trail_particles and bullet_type == BulletType.FIREBALL:
		trail_particles.global_position = global_position - velocity.normalized() * 10.0

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		var player := body as Player
		if player:
			player.take_damage(damage)
		_create_impact_effect(global_position)
		_despawn()

func _create_impact_effect(pos: Vector2) -> void:
	var p := GPUParticles2D.new()
	p.amount = 12
	p.lifetime = 0.2
	p.one_shot = true
	p.process_material = create_impact_material()
	# choose impact texture without ternary
	if bullet_type == BulletType.FIREBALL:
		p.texture = fireball_particle_texture
	else:
		p.texture = laser_particle_texture
	p.global_position = pos
	get_tree().root.add_child(p)
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(p):
		p.queue_free()

func create_impact_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.direction = Vector3(0, 0, 1)
	m.spread = 180.0
	m.gravity = Vector3.ZERO
	m.initial_velocity_min = 60.0
	m.initial_velocity_max = 120.0
	m.scale_min = 0.1
	m.scale_max = 0.3
	# choose color without ternary
	if bullet_type == BulletType.FIREBALL:
		m.color = fireball_color
	else:
		m.color = laser_color
	return m

func _despawn() -> void:
	alive = false
	visible = false
	monitoring = false
	if trail_particles:
		trail_particles.emitting = false
