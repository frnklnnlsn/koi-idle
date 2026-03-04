# fish_list_row.gd
# Attach this to the root node of fish_list_row.tscn (an HBoxContainer).
#
# Scene structure expected:
#   HBoxContainer  ← this script
#   ├── SubViewportContainer
#   │     └── SubViewport    (unique name: FishViewport)
#   ├── Label                (unique name: RowNameLabel)
#   ├── Label                (unique name: RowRankLabel)
#   ├── Label                (unique name: RowIncomeLabel)
#   └── ... (any spacers / extra labels you want)
extends HBoxContainer

signal row_hovered(fish: fish_conf)
signal row_clicked(fish: fish_conf)

## Set by FishListManager immediately after instantiation.
var fish_resource: fish_conf = null

## Visual feedback — swap these to match your theme.
@export var normal_color:  StyleBox = null
@export var hover_color:   StyleBox = null
@export var selected_color: StyleBox = null

var _selected := false

# ── Godot callbacks ───────────────────────────────────────────────────────────

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

# ── Interaction ───────────────────────────────────────────────────────────────

func _on_mouse_entered() -> void:
	if not _selected and hover_color:
		add_theme_stylebox_override("panel", hover_color)
	if fish_resource:
		row_hovered.emit(fish_resource)

func _on_mouse_exited() -> void:
	if not _selected:
		if normal_color:
			add_theme_stylebox_override("panel", normal_color)
		else:
			remove_theme_stylebox_override("panel")

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	   and event.button_index == MOUSE_BUTTON_LEFT \
	   and event.pressed \
	   and fish_resource:
		_selected = !_selected
		if _selected and selected_color:
			add_theme_stylebox_override("panel", selected_color)
		elif normal_color:
			add_theme_stylebox_override("panel", normal_color)
		else:
			remove_theme_stylebox_override("panel")
		row_clicked.emit(fish_resource)

## Deselect this row externally (e.g. when another row is clicked).
func deselect() -> void:
	_selected = false
	if normal_color:
		add_theme_stylebox_override("panel", normal_color)
	else:
		remove_theme_stylebox_override("panel")
