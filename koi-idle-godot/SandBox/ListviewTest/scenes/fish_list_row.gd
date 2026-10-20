#fish_list_row.gd
extends PanelContainer

signal row_hovered(fish: fish_conf)
signal row_clicked(fish: fish_conf)
signal row_unhovered(fish: fish_conf)

var fish_resource: fish_conf = null

## Row backgrounds. Left empty, they're made from UIPalette (clear / a faint
## highlight / the accent colour).
@export var normal_color:   StyleBox = null
@export var hover_color:    StyleBox = null
@export var selected_color: StyleBox = null
## Length (pixels) of a fish picture at size 1. Pond fish are drawn bigger by
## the pond's growth size (Pond.size_of: up to 4x); toilet fish all at 1.
@export var icon_base_length: float = 26.0
## Space inside the row at the left and right (the list header uses the same,
## so the columns line up).
@export var side_margin: float = 8.0

# Row value labels — named without "Heading" suffix
@onready var id_label:     Label = %RowNameLabel
@onready var rank_label:   Label = %RowRankLabel
@onready var income_label: Label = %RowIncomeLabel
@onready var icon:         TextureRect = %FishIcon

var _selected := false
var _is_pond := false

# ── Godot callbacks ───────────────────────────────────────────────────────────
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var pal := UIPalette.get_palette()
	if not normal_color:
		normal_color = _row_style(Color(0, 0, 0, 0))
	if not hover_color:
		hover_color = _row_style(Color(pal.text, 0.07))
	if not selected_color:
		selected_color = _row_style(Color(pal.accent, 0.25))
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
		income_label.text = "%sg" % FishLabelDisplay.num(fish_resource.mass)
	else:
		income_label.text = "$%s/s" % FishLabelDisplay.num(PassiveSystems.fish_income(fish_resource))
	# Picture size: the fish's size in the pond (growth), 1 for toilet fish.
	var f := Pond.size_of(fish_resource) if _is_pond else 1.0
	var w := icon_base_length * f * float(FishIconRenderer.PICTURE_SIZE.x) / (27.0 * FishIconRenderer.RENDER_SCALE)
	icon.custom_minimum_size = Vector2(w, w * FishIconRenderer.PICTURE_SIZE.y / FishIconRenderer.PICTURE_SIZE.x)


func _row_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.content_margin_left = side_margin
	s.content_margin_right = side_margin
	return s

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
	if fish_resource:
		row_unhovered.emit(fish_resource)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	   and event.button_index == MOUSE_BUTTON_LEFT \
	   and event.pressed:
		if fish_resource:
			_selected = !_selected
			row_clicked.emit(fish_resource)

## Mark this row selected without a click (e.g. picked on a chart).
func select() -> void:
	_selected = true
	if selected_color:
		add_theme_stylebox_override("panel", selected_color)


func deselect() -> void:
	_selected = false
	if normal_color:
		add_theme_stylebox_override("panel", normal_color)
	else:
		remove_theme_stylebox_override("panel")
