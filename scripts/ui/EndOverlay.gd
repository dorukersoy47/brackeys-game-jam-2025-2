extends CanvasLayer
class_name EndOverlay

# --- Assign in inspector (preferred) ---
@export var dim_path: NodePath          # ColorRect "Dim"
@export var panel_path: NodePath        # Panel "Panel"
@export var title_path: NodePath        # Label "Title"
@export var stats_path: NodePath        # Label "Stats"
@export var back_button_path: NodePath  # Button "BackButton"
@export var start_overlay_path: NodePath  # StartOverlay (CanvasLayer) in Main

@onready var gs: GameStateData = get_node("/root/GameState") as GameStateData
@onready var save_node: Node = get_node("/root/Save")

var dim: ColorRect = null
var panel: Panel = null
var title_lbl: Label = null
var stats_lbl: Label = null
var back_btn: Button = null
var start_overlay: CanvasLayer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95
	visible = false

	_resolve_refs()

	# Let clicks pass through the dimmer; the Panel will catch them.
	if dim:
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if panel:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# Wire button + game over signal
	if back_btn and not back_btn.pressed.is_connected(_on_back_to_menu):
		back_btn.pressed.connect(_on_back_to_menu)
	if gs and not gs.run_over.is_connected(_on_run_over):
		gs.run_over.connect(_on_run_over)

func _resolve_refs() -> void:
	dim = _get_node_safe(dim_path, "Dim") as ColorRect
	panel = _get_node_safe(panel_path, "Panel") as Panel
	title_lbl = _get_node_safe(title_path, "Title") as Label
	stats_lbl = _get_node_safe(stats_path, "Stats") as Label
	back_btn = _get_node_safe(back_button_path, "BackButton") as Button

	# StartOverlay: prefer exported path, else find by name, else by group "start_menu"
	if start_overlay_path != NodePath("") and has_node(start_overlay_path):
		start_overlay = get_node(start_overlay_path) as CanvasLayer
	else:
		var found := find_child("StartOverlay", true, false)
		if found and found is CanvasLayer:
			start_overlay = found as CanvasLayer
		else:
			var candidates := get_tree().get_nodes_in_group("start_menu")
			if candidates.size() > 0 and candidates[0] is CanvasLayer:
				start_overlay = candidates[0] as CanvasLayer

func _get_node_safe(path: NodePath, fallback: String) -> Node:
	if path != NodePath("") and has_node(path):
		return get_node(path)
	return find_child(fallback, true, false)

# -------------------- Flow --------------------

func _on_run_over(extracted: bool) -> void:
	# Hide StartOverlay while showing the summary
	if start_overlay:
		start_overlay.visible = false

	# Title
	if title_lbl:
		if extracted:
			title_lbl.text = "Extraction Complete"
		else:
			title_lbl.text = "Run Over"

	# Stats content
	_update_stats_text(extracted)

	visible = true
	if back_btn:
		back_btn.grab_focus()

func _on_back_to_menu() -> void:
	visible = false
	get_tree().paused = false
	if start_overlay:
		start_overlay.visible = true

# -------------------- Stats --------------------

func _update_stats_text(extracted: bool) -> void:
	if stats_lbl == null or gs == null:
		return

	var survived: float = gs.survival_time
	var current_bm: float = gs.bm
	var at_risk: int = gs.unbanked
	var banked_total: int = gs.banked

	var best_survival: float = 0.0
	var best_peak_bm: float = 1.0
	var best_biscuits: int = 0

	# Safely read best stats from Save
	if typeof(save_node) == TYPE_OBJECT:
		var d: Variant = save_node.get("data")
		if typeof(d) == TYPE_DICTIONARY:
			var best: Dictionary = (d as Dictionary).get("best", {}) as Dictionary
			if best.has("survival"):
				best_survival = float(best.get("survival"))
			if best.has("peak_bm"):
				best_peak_bm = float(best.get("peak_bm"))
			if best.has("biscuits"):
				best_biscuits = int(best.get("biscuits"))

	var status_line := ""
	if extracted:
		status_line = "You extracted successfully."
	else:
		status_line = "You were defeated."

	var lines: Array[String] = []
	lines.append(status_line)
	lines.append("Survived: %0.1f\nCurrent BM: ×%0.1f"% [survived, current_bm])
	lines.append("At-Risk (lost if defeated): %d" % at_risk)
	lines.append("Banked (total): %d" % banked_total)
	lines.append("--- Best Records ---")
	lines.append("Best Survival:\n%0.1f s\nPeak BM: ×%0.1f\nBiscuits: %d"
		% [best_survival, best_peak_bm, best_biscuits])

	stats_lbl.text = "\n".join(lines)
