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
## Screen pixels per pond pixel in the fish pictures. 2 matches the pond
## (which is drawn at half resolution and doubled); 1 is smaller. Bigger pond
## fish get their chunkier pond pixels on top of this.
@export_range(1, 4) var icon_pixel_size: int = 2
## Longest a fish picture may get (pixels); bigger fish use smaller pixels
## to fit.
@export var max_icon_length: float = 120.0
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
## Draws the fish picture (set by the list manager).
var icon_renderer: FishIconRenderer

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

## The fish picture arrived (FishIconRenderer.request).
func _on_icon_ready(tex: Texture2D, fish: fish_conf, px_scale: int) -> void:
	if fish_resource != fish or not is_instance_valid(icon):
		return   # the row shows another fish now
	var s := px_scale
	while s > 1 and tex.get_width() * s > max_icon_length:
		s -= 1
	icon.texture = tex
	icon.custom_minimum_size = tex.get_size() * s


func _apply_display_mode() -> void:
	if fish_resource == null or income_label == null:
		return
	if _is_pond:
		income_label.text = "%sg" % FishLabelDisplay.num(fish_resource.mass)
	else:
		income_label.text = "$%s/s" % FishLabelDisplay.num(PassiveSystems.fish_income(fish_resource))
	# Picture: drawn like the fish in the pond (its pond size and pixel size;
	# toilet fish are all size 1), then blown up with hard pixel edges.
	if icon_renderer:
		var density := Pond.icon_density(fish_resource) if _is_pond else 1.0
		var px_scale := icon_pixel_size * (Pond.pixel_scale_of(fish_resource) if _is_pond else 1)
		# A method on this row, not an inline function: if the row is freed
		# before the picture arrives (the list rebuilt), Godot knows and the
		# renderer skips it.
		icon_renderer.request(fish_resource, density, _on_icon_ready.bind(fish_resource, px_scale))


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
