#fish_list_row.gd
extends PanelContainer

signal row_hovered(fish: fish_conf)
signal row_clicked(fish: fish_conf)

var fish_resource: fish_conf = null

@export var normal_color:   StyleBox = null
@export var hover_color:    StyleBox = null
@export var selected_color: StyleBox = null

# Row value labels — named without "Heading" suffix
@onready var id_label:     Label = %RowNameLabel
@onready var rank_label:   Label = %RowRankLabel
@onready var income_label: Label = %RowIncomeLabel

var _selected := false
var _is_pond := false

# ── Godot callbacks ───────────────────────────────────────────────────────────
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not normal_color:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(1, 1, 1, 0.0)
		normal_color = s
	if not hover_color:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(1, 1, 1, 0.08)
		hover_color = s
	if not selected_color:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.3, 0.6, 1.0, 0.3)
		selected_color = s
	add_theme_stylebox_override("panel", normal_color)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	_apply_display_mode()

# ── Display mode ──────────────────────────────────────────────────────────────
func update_display(is_pond: bool) -> void:
	_is_pond = is_pond
	_apply_display_mode()

func _apply_display_mode() -> void:
	if fish_resource == null or income_label == null:
		return
	if _is_pond:
		income_label.text = "%.2fg" % fish_resource.mass
	else:
		income_label.text = "$%.2f" % fish_resource.income

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
	   and event.pressed:
		if fish_resource:
			_selected = !_selected
			row_clicked.emit(fish_resource)

func deselect() -> void:
	_selected = false
	if normal_color:
		add_theme_stylebox_override("panel", normal_color)
	else:
		remove_theme_stylebox_override("panel")
