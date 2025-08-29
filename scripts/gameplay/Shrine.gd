extends Area2D
class_name Shrine

@onready var gs: GameState = get_node("/root/GameState") as GameState
@onready var market_controller: MarketController = get_node("/root/MrktController") as MarketController
@onready var run_inv: RunInventory = get_node("/root/RunInv") as RunInventory
@onready var market_db: MarketDB = get_node("/root/DB") as MarketDB
@onready var rng: RNGService = get_node("/root/RNG") as RNGService

@export var active_time := 6.0

var offering_items := []
var is_market_mode := false

func _ready() -> void:
		gs.connect("spawn_shrine", _on_spawn)

func _on_spawn() -> void:
		visible = true
		monitoring = true
		$CollisionShape2D.disabled = false
		
		# Decide between banking mode and market mode
		if rng.randf() < 0.3:  # 30% chance for market mode
				_enter_market_mode()
		else:
				_enter_banking_mode()
		
		await get_tree().create_timer(active_time).timeout
		_despawn()

func _enter_banking_mode() -> void:
		is_market_mode = false
		offering_items.clear()
		modulate = Color.WHITE  # Normal color

func _enter_market_mode() -> void:
		is_market_mode = true
		# Select 1-2 random items to offer
		var all_items = market_db.get_all_items()
		offering_items.clear()
		
		var offer_count = 1 + rng.randi() % 2  # 1 or 2 items
		for i in range(offer_count):
				if all_items.size() > 0:
						var random_index = rng.randi() % all_items.size()
						var item = all_items[random_index]
						offering_items.append(item)
						all_items.remove_at(random_index)
		
		modulate = Color.YELLOW  # Market mode color

func _on_body_entered(body: Node) -> void:
		if body.is_in_group("player"):
				if is_market_mode:
						_show_market_ui()
				else:
						gs.bank_at_shrine()
						_despawn()

func _despawn() -> void:
		visible = false
		monitoring = false
		$CollisionShape2D.disabled = true

func _show_market_ui() -> void:
		# Simple console output for now - could be expanded to a proper UI
		print("Shrine Market Mode - Items available:")
		for item in offering_items:
				var shrine_price = int(item.cost * 1.25)  # 25% markup
				print("- %s: %d coins (shrine price)" % [item.display_name, shrine_price])
		
		# For now, just buy the first available item if player can afford it
		if offering_items.size() > 0:
				var item = offering_items[0]
				var shrine_price = int(item.cost * 1.25)
				if gs.unbanked >= shrine_price:
						market_controller.buy_item_midrun(gs, run_inv, item, shrine_price)
						print("Purchased: %s" % item.display_name)
						_despawn()
				else:
						print("Not enough unbanked coins for: %s" % item.display_name)
