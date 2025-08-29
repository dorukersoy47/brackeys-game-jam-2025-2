extends CharacterBody2D
class_name Player

@onready var save: Node = get_node("/root/Save")
@onready var gs: GameStateData = get_node("/root/GameState") as GameStateData
@onready var camera: Camera2D = get_viewport().get_camera_2d()
@onready var rng: RNGService = get_node("/root/RNG") as RNGService
@onready var run_inv: RunInventory = get_node("/root/RunInv") as RunInventory
@onready var market_db: MarketDB = get_node("/root/DB") as MarketDB

@export var hurtbox_path: NodePath   # set this to the CollisionShape2D used as the hitbox/hurtbox

const BASE_SPEED := 220.0
@export var max_hp := 3
var hp := 3

var focus := false
var dash_cd := 0.0
var dash_iframes := 0.2
var dash_cooldown := 0.8
var is_dashing := false
var cashout_hold := 0.0
var cashout_time := 2.0

var damage_flash_timer := 0.0
var invulnerable_timer := 0.0
const INVULNERABLE_TIME := 1.0

# Item system variables
var temp_shield := 0

var _hurtbox: CollisionShape2D = null

func _ready() -> void:
		add_to_group("player")

		# --- Physics layers/masks ---
		collision_layer = 0
		set_collision_layer_value(1, true)     # Player layer = 1
		collision_mask = 0
		set_collision_mask_value(4, true)      # Detect EnemyBullet (layer 4)
		set_collision_mask_value(5, true)      # Collide with World walls (layer 5)  << IMPORTANT

		# Hook hurtbox
		if hurtbox_path != NodePath(""):
				_hurtbox = get_node_or_null(hurtbox_path) as CollisionShape2D
		if _hurtbox == null:
				_hurtbox = get_node_or_null("Hitbox") as CollisionShape2D
		if _hurtbox == null:
				_hurtbox = get_node_or_null("CollisionShape2D") as CollisionShape2D

		gs.connect("request_player_hp_delta", _on_hp_delta)

		# upgrades
		max_hp = 3 + save.get_upgrade("hp")
		hp = max_hp
		dash_iframes += save.get_upgrade("dash_iframes") * 0.05
		cashout_time = max(0.6, cashout_time - save.get_upgrade("cashout") * 0.2)

		_update_health_ui()

func _physics_process(_delta: float) -> void:
		_update_movement()
		_update_dash(_delta)
		_update_cashout(_delta)
		_update_damage_effects(_delta)

func _input(event: InputEvent) -> void:
		if event.is_action_pressed("Special"):
				_use_active_item()
		elif event.is_action_pressed("item_cycle"):
				_cycle_active_item()

func _update_movement() -> void:
		var dir := Vector2.ZERO
		dir.y = int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
		dir.x = int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
		dir = dir.normalized()

		focus = Input.is_action_pressed("Focus")
		var spd: float = BASE_SPEED * (1.0 + save.get_upgrade("move") * 0.10)
		if focus:
				spd *= 0.5
		if is_dashing:
				spd *= 2.0
		velocity = dir * spd
		move_and_slide()  # collides with walls because mask(5) and TM_Walls layer(5)

func _update_dash(delta: float) -> void:
		dash_cd -= delta
		if Input.is_action_just_pressed("Dash") and dash_cd <= 0.0:
				is_dashing = true
				dash_cd = dash_cooldown
				if _hurtbox:
						_hurtbox.disabled = true
				await get_tree().create_timer(dash_iframes).timeout
				if _hurtbox:
						_hurtbox.disabled = false
				is_dashing = false

func _update_cashout(delta: float) -> void:
		if Input.is_action_pressed("CashOut"):
				cashout_hold += delta
				velocity *= 0.7
				if cashout_hold >= cashout_time:
						gs.bank_unbanked_full_extract()
						cashout_hold = 0.0
		else:
				cashout_hold = 0.0

func _update_damage_effects(delta: float) -> void:
		if damage_flash_timer > 0:
				damage_flash_timer -= delta
				var flash_intensity = damage_flash_timer / 0.2
				modulate = Color(1.0, 1.0 - flash_intensity * 0.5, 1.0 - flash_intensity * 0.5)
		else:
				modulate = Color.WHITE

		if invulnerable_timer > 0:
				invulnerable_timer -= delta
				if fmod(invulnerable_timer, 0.1) < 0.05:
						modulate.a = 0.5
				else:
						modulate.a = 1.0

func take_damage(dmg: int = 1) -> void:
		if is_dashing or invulnerable_timer > 0:
				return
		
		# Check temp shield first
		if temp_shield > 0:
				temp_shield -= 1
				_play_guard_effect()
				return  # Negate damage
		
		hp = max(0, hp - dmg)
		_damage_effects()
		_update_health_ui_with_damage(dmg)
		if camera:
				_camera_shake(0.3, 10.0)
		if hp <= 0:
				gs.end_run(false)

func _damage_effects() -> void:
		damage_flash_timer = 0.2
		invulnerable_timer = INVULNERABLE_TIME
		_screen_flash()

func _camera_shake(duration: float, intensity: float) -> void:
		if not camera:
				return
		var original_offset = camera.offset
		var t := 0.0
		while t < duration:
				t += get_process_delta_time()
				var k := intensity * (1.0 - t / duration)
				camera.offset = Vector2(rng.randf_range(-k, k), rng.randf_range(-k, k))
				await get_tree().process_frame
		camera.offset = original_offset

func _screen_flash() -> void:
		var flash := ColorRect.new()
		flash.color = Color(1,0,0,0.3)
		flash.size = get_viewport_rect().size
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		get_tree().root.add_child(flash)
		var tw := create_tween()
		tw.tween_property(flash, "color:a", 0.0, 0.2)
		await tw.finished
		if is_instance_valid(flash):
				flash.queue_free()

func _update_health_ui_with_damage(damage_amount: int) -> void:
		var ui = get_tree().get_first_node_in_group("ui")
		if ui and ui.has_method("update_health"):
				ui.update_health(hp, max_hp)
		if ui and ui.has_method("show_damage_effect"):
				ui.show_damage_effect(damage_amount, global_position)

func _update_health_ui() -> void:
		var ui = get_tree().get_first_node_in_group("ui")
		if ui and ui.has_method("update_health"):
				ui.update_health(hp, max_hp)

func _on_hp_delta(delta_frac: float) -> void:
		var change := int(ceil(hp * -delta_frac))
		hp = clamp(hp - change, 1, max_hp)
		_update_health_ui()

# Item system methods
func add_temp_shield(n: int) -> void:
		temp_shield = min(temp_shield + n, 3)  # Cap for sanity
		_show_item_feedback("shield")

func _use_active_item() -> void:
		if not run_inv:
				return
		
		var active_item_id = run_inv.get_active_item()
		if active_item_id.is_empty():
				return
		
		if run_inv.count(active_item_id) <= 0:
				return
		
		var item_def = market_db.get_item(active_item_id)
		if not item_def:
				return
		
		# Create and use the item effect
		var effect_scene = item_def.effect_scene
		if effect_scene:
				var effect = effect_scene.instantiate()
				effect.item_id = active_item_id
				add_child(effect)
				
				# Connect to consumption signal
				effect.consumed.connect(func(_id):
						run_inv.consume(_id)
						_show_item_feedback(_id)
				)
				
				effect.use(self, gs)
		else:
				# Fallback for items without effects
				run_inv.consume(active_item_id)
				_show_item_feedback(active_item_id)

func _cycle_active_item() -> void:
		if run_inv:
				run_inv.cycle_active_item()

func _show_item_feedback(item_id: StringName) -> void:
		# Visual feedback for item usage
		var item_def = market_db.get_item(item_id)
		if item_def:
				print("Used item: ", item_def.display_name)
				# Could add screen flash, icon ping, sound effect here

func _play_guard_effect() -> void:
		# Visual effect for shield blocking damage
		modulate = Color.CYAN
		var tw := create_tween()
		tw.tween_property(self, "modulate", Color.WHITE, 0.2)
		# Could add shield particle effect here
