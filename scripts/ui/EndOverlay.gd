extends CanvasLayer
# No class_name on purpose (avoids global-class conflicts)

signal back_to_menu

# Autoloads
var gs: GameStateData = null

# Scene refs (must match EndOverlay.tscn)
var _root: Control = null
var _dim: ColorRect = null
var _panel: Panel = null
var _title: Label = null
var _stats: Label = null
var _btn_back: Button = null

# Data
var _extracted: bool = false
var _survival: float = 0.0
var _peak_bm: float = 1.0
var _biscuits: int = 0

func _ready() -> void:
	layer = 95                       # below StartOverlay (100), above game UI (50)
	process_mode = Node.PROCESS_MODE_ALWAYS
	gs = get_node_or_null("/root/GameState") as GameStateData

	_resolve_refs()

	# Block clicks to the game; allow panel to receive input
	if _dim:
		_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	if _btn_back and not _btn_back.pressed.is_connected(_on_back):
		_btn_back.pressed.connect(_on_back)

	_render_text()

func _rescue(v: Node) -> bool:
	return v != null and is_instance_valid(v)

func _resolve_refs() -> void:
	_root = get_node_or_null("Root") as Control
	_dim = get_node_or_null("Root/Dim") as ColorRect
	_panel = get_node_or_null("Root/Center/Panel") as Panel
	_title = get_node_or_null("Root/Center/Panel/VBox/Title") as Label
	_stats = get_node_or_null("Root/Center/Panel/VBox/Stats") as Label
	_btn_back = get_node_or_null("Root/Center/Panel/VBox/BackButton") as Button

func setup(extracted: bool, survival: float, peak_bm: float, biscuits: int) -> void:
	_extracted = extracted
	_survival = survival
	_peak_bm = peak_bm
	_biscuits = biscuits
	_render_text()

func _render_text() -> void:
	if not _rescue(_title) or not _rescue(_stats):
		return

	if _extracted:
		_title.text = "Extraction Complete!"
	else:
		_title.text = "Run Over"

	_stats.text = "Survival: %0.1fs\nPeak BM: ×%0.1f\nBiscuits: %d" % [_survival, _peak_bm, _biscuits]

func _on_back() -> void:
	emit_signal("back_to_menu")
	queue_free()
