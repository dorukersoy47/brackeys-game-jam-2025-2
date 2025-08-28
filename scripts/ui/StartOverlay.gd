extends CanvasLayer

# --- Optional (recommended): assign these in the Inspector ---
@export var ui_layer_path: NodePath                     # CanvasLayer with your in-game UI (group "ui")
@export var dim_path: NodePath                          # ColorRect that dims the screen
@export var panel_path: NodePath                        # Panel containing the menu
@export var btn_start_path: NodePath                    # StartButton
@export var btn_shop_path: NodePath                     # ShopButton
@export var btn_quit_path: NodePath                     # QuitButton
@export var stats_label_path: NodePath                  # Label that shows best run stats

# You can also assign the Shop overlay scene here (or keep default)
@export var shop_overlay_scene: PackedScene = preload("res://scenes/ShopOverlay.tscn")

# --- Autoloads ---
@onready var gs: GameStateData = get_node("/root/GameState") as GameStateData

# --- Resolved refs (don’t edit below) ---
var ui_layer: CanvasLayer = null
var dim: ColorRect = null
var panel: Panel = null
var btn_start: Button = null
var btn_shop: Button = null
var btn_quit: Button = null
var stats_label: Label = null

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_resolve_all_refs()

	# Block clicks to game; allow panel/buttons to receive
	if dim:
		dim.mouse_filter = Control.MOUSE_FILTER_STOP

	# Overlay visible at boot; hide in-game UI until run starts
	visible = true
	if ui_layer:
		ui_layer.visible = false

	# Wire buttons (safe connects)
	if btn_start and not btn_start.pressed.is_connected(_on_start_game):
		btn_start.pressed.connect(_on_start_game)
	if btn_shop and not btn_shop.pressed.is_connected(_on_open_shop):
		btn_shop.pressed.connect(_on_open_shop)
	if btn_quit and not btn_quit.pressed.is_connected(_on_quit):
		btn_quit.pressed.connect(_on_quit)

	# Listen for run end → show this menu again
	if gs and not gs.run_over.is_connected(_on_run_over):
		gs.run_over.connect(_on_run_over)

	_update_stats_text()

# ---------------- Helpers ----------------

func _resolve_all_refs() -> void:
	# UI layer: from export, group fallback
	ui_layer = _resolve_node_as(ui_layer_path, "ui_layer") as CanvasLayer
	if ui_layer == null:
		ui_layer = get_tree().get_first_node_in_group("ui") as CanvasLayer

	# Overlay widgets (exported paths first, fallback by name search)
	dim = _resolve_node_as(dim_path, "Dim") as ColorRect
	panel = _resolve_node_as(panel_path, "Panel") as Panel
	btn_start = _resolve_node_as(btn_start_path, "StartButton") as Button
	btn_shop = _resolve_node_as(btn_shop_path, "ShopButton") as Button
	btn_quit = _resolve_node_as(btn_quit_path, "QuitButton") as Button
	stats_label = _resolve_node_as(stats_label_path, "Stats") as Label

	# Log missing nodes to help you wire things quickly
	if btn_start == null: push_warning("[StartOverlay] StartButton not found. Assign btn_start_path in Inspector or name the node \"StartButton\" under this overlay.")
	if btn_shop == null:  push_warning("[StartOverlay] ShopButton not found. Assign btn_shop_path or name the node \"ShopButton\".")
	if btn_quit == null:  push_warning("[StartOverlay] QuitButton not found. Assign btn_quit_path or name the node \"QuitButton\".")
	if stats_label == null: push_warning("[StartOverlay] Stats label not found. Assign stats_label_path or name it \"Stats\".")

func _resolve_node_as(path: NodePath, fallback_name: String) -> Node:
	if path != NodePath("") and has_node(path):
		return get_node(path)
	# Recursive name search under this overlay
	return find_child(fallback_name, true, false)

# ---------------- Button handlers ----------------

func _on_start_game() -> void:
	# Show in-game UI and start run
	if ui_layer:
		ui_layer.visible = true
	if gs:
		gs.start_run()
	visible = false

func _on_open_shop() -> void:
	if shop_overlay_scene == null:
		push_warning("[StartOverlay] shop_overlay_scene is not set.")
		return
	var overlay := shop_overlay_scene.instantiate() as CanvasLayer
	if overlay == null:
		push_warning("[StartOverlay] Failed to instance ShopOverlay scene.")
		return
	# Sit below StartOverlay but above game UI
	overlay.layer = 90
	add_child(overlay)
	# If the overlay emits "overlay_closed", return to menu (optional)
	if overlay.has_signal("overlay_closed") and not overlay.is_connected("overlay_closed", Callable(self, "_on_shop_closed")):
		overlay.connect("overlay_closed", Callable(self, "_on_shop_closed"))

func _on_shop_closed() -> void:
	# Menu already visible; nothing else required
	pass

func _on_quit() -> void:
	get_tree().quit()

# ---------------- GameState callbacks ----------------

func _on_run_over(_extracted: bool) -> void:
	# Hide in-game UI, show start menu again
	if ui_layer:
		ui_layer.visible = false
	visible = true
	_update_stats_text()

# ---------------- Stats text ----------------

func _update_stats_text() -> void:
	if stats_label == null or gs == null:
		return

	var best: Dictionary = {}
	if gs.Save != null and typeof(gs.Save.data) == TYPE_DICTIONARY and "best" in gs.Save.data:
		best = (gs.Save.data.get("best", {}) as Dictionary)

	var best_survival: float = 0.0
	var best_peak_bm: float = 1.0
	var best_biscuits: int = 0

	if best.has("survival"):
		best_survival = float(best.get("survival"))
	if best.has("peak_bm"):
		best_peak_bm = float(best.get("peak_bm"))
	if best.has("biscuits"):
		best_biscuits = int(best.get("biscuits"))

	stats_label.text = "Best: %0.1fs  •  Peak BM ×%0.1f  •  Biscuits %d" % [best_survival, best_peak_bm, best_biscuits]
