extends Sprite2D
class_name RootIconEffect

@onready var timer = $Timer
var player_node: Node2D = null

func _ready():
	# Set up root icon effect
	timer.wait_time = 0.3  # 0.3 seconds duration
	timer.one_shot = true
	timer.start()
	
	# Find and root the player
	find_and_root_player()

func find_and_root_player():
	# Find the player node
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_node = players[0]
		if player_node and player_node.has_method("set_movement_disabled"):
			player_node.set_movement_disabled(true)
			# Position the icon above the player
			global_position = player_node.global_position + Vector2(0, -40)

func _on_timer_timeout():
	# Unroot the player
	if player_node and player_node.has_method("set_movement_disabled"):
		player_node.set_movement_disabled(false)
	queue_free()
