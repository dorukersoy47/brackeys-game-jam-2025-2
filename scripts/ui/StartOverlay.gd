extends CanvasLayer
class_name StartOverlay

@export var ui_layer_path: NodePath
@export var dim_path: NodePath
@export var panel_path: NodePath
@export var btn_start_path: NodePath
@export var btn_shop_path: NodePath
@export var btn_quit_path: NodePath
@export var stats_label_path: NodePath
@export var shop_overlay_scene: PackedScene = preload("res://scenes/ShopOverlay.tscn")

@onready var gs: GameStateData = get_node("/root/GameState") as GameStateData

var ui_layer: CanvasLayer
var dim: ColorRect
var panel: Panel
var btn_start: Button
var btn_shop: Button
var btn_quit: Button
var stats_label: Label

var _shop_ref: CanvasLayer = null  # keep reference to avoid spawning duplicates

func _ready() -> void:
	# Start menu should be on a sane layer but *below* the shop
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("start_menu")

	_resolve_all_refs()

	# Dim should not eat clicks when Start menu is the only thing showing
	if dim:
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE

	visible = true

	if btn_start and not btn_start.pressed.is_connected(_on_start_game):
		btn_start.pressed.connect(_on_start_game)
	if btn_shop and not btn_shop.pressed.is_connected(_on_open_shop):
		btn_shop.pressed.connect(_on_open_shop)
	if btn_quit and not btn_quit.pressed.is_connected(_on_quit):
		btn_quit.pressed.connect(_on_quit)

	_update_stats_text()

func _resolve_all_refs() -> void:
	ui_layer = _get_node_safe(ui_layer_path, "UI") as CanvasLayer
	dim = _get_node_safe(dim_path, "Dim") as ColorRect
	panel = _get_node_safe(panel_path, "Panel") as Panel
	btn_start = _get_node_safe(btn_start_path, "StartButton") as Button
	btn_shop = _get_node_safe(btn_shop_path, "ShopButton") as Button
	btn_quit = _get_node_safe(btn_quit_path, "QuitButton") as Button
	stats_label = _get_node_safe(stats_label_path, "Stats") as Label

func _get_node_safe(path: NodePath, fallback_name: String) -> Node:
	if path != NodePath("") and has_node(path):
		return get_node(path)
	return find_child(fallback_name, true, false)

func _on_start_game() -> void:
	if gs:
		gs.start_run()
	visible = false

func _on_open_shop() -> void:
	# Avoid opening more than one
	if _shop_ref and is_instance_valid(_shop_ref):
		if _shop_ref is CanvasLayer:
			var cl := _shop_ref as CanvasLayer
			if cl.layer <= layer:
				cl.layer = layer + 1
		return

	if shop_overlay_scene == null:
		return

	var overlay := shop_overlay_scene.instantiate() as CanvasLayer
	if overlay == null:
		return

	# Put it above StartOverlay
	overlay.layer = max(layer + 1, 200)

	# If it’s actually your ShopOverlay, set pause_game safely
	if overlay is ShopOverlay:
		(overlay as ShopOverlay).pause_game = false
	else:
		# Fallback if you kept it untyped
		if overlay.has_method("set"):
			overlay.set("pause_game", false)

	get_tree().root.add_child(overlay)
	_shop_ref = overlay

	# ✅ Correct way to check/connect a signal
	if overlay.has_signal("closed"):
		overlay.connect("closed", Callable(self, "_on_shop_closed"))

	# Keep reference tidy if user closes via other means
	overlay.tree_exited.connect(func(): _shop_ref = null)

func _on_shop_closed() -> void:
	_shop_ref = null
	if btn_shop:
		btn_shop.grab_focus()

func _on_quit() -> void:
	get_tree().quit()

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

	stats_label.text = "Best: %0.1fs\nPeak BM ×%0.1f\nBiscuits %d" % [best_survival, best_peak_bm, best_biscuits]
