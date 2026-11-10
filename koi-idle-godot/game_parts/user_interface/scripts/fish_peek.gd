# fish_peek.gd
# A little window that follows one fish up close (fish_peek.tscn). Click a
# fish in the toilet or the pond and it opens next to the click.
#
# The window has its own SubViewport looking into the same world as the toilet
# / pond view (world_2d is shared), with its own camera following the fish.
# So it's the real fish, swimming live, not a copy; it just renders that part
# of the water at a higher zoom.
#
# Drag it by the title bar. × or Esc closes it. It closes by itself when the
# fish leaves (flushed, caught, sold) or the view switches.
class_name FishPeek
extends PanelContainer

## How much of the window's width the fish's body fills (0.5 = half).
@export_range(0.1, 1.0, 0.05) var fill := 0.35
## Zoom limits (× the normal view), so tiny and huge fish stay sensible.
@export var min_zoom := 1.0
@export var max_zoom := 12.0
## How quickly the camera catches up with the fish (higher = snappier).
@export var follow_speed := 6.0

@onready var _title: Label = %PeekTitle
@onready var _info: Label = %PeekInfo
@onready var _close: Button = %PeekClose
@onready var _bar: Control = %PeekBar
@onready var _view: SubViewport = %PeekView
@onready var _camera: Camera2D = %PeekCamera

var _fish: Node2D
var _source: SubViewport
var _dragging := false
var _drag_offset := Vector2.ZERO


func _ready() -> void:
	visible = false
	_close.pressed.connect(close)
	_bar.gui_input.connect(_on_bar_input)


## Opens on `fish` (a swimming fish node) from the `source` view, placed near
## `screen_pos` and kept on screen.
func open(fish: Node2D, source: SubViewport, screen_pos: Vector2) -> void:
	_fish = fish
	if _source != source:
		_source = source
		_view.world_2d = source.world_2d
	_camera.position = fish.body_center_global()
	_camera.zoom = Vector2.ONE * _target_zoom()
	_camera.reset_smoothing()
	_update_text()
	visible = true
	reset_size()
	var screen := get_viewport_rect().size
	var p := screen_pos + Vector2(24, -size.y * 0.5)
	if p.x + size.x > screen.x:
		p.x = screen_pos.x - size.x - 24
	position = p.clamp(Vector2.ZERO, screen - size)


func close() -> void:
	visible = false
	_fish = null


func is_showing(fish: Node2D) -> bool:
	return visible and _fish == fish


func _process(delta: float) -> void:
	if not visible:
		return
	if not is_instance_valid(_fish) or not _fish.is_inside_tree():
		close()
		return
	var t := 1.0 - exp(-follow_speed * delta)
	_camera.position = _camera.position.lerp(_fish.body_center_global(), t)
	_camera.zoom = _camera.zoom.lerp(Vector2.ONE * _target_zoom(), t)
	_update_text()


## Zoom so the body fills `fill` of the window (fish grow, so it's redone).
func _target_zoom() -> float:
	var length: float = _fish.body_length() if _fish.has_method("body_length") else 20.0
	return clampf(_view.size.x * fill / maxf(length, 1.0), min_zoom, max_zoom)


func _update_text() -> void:
	var f: fish_conf = _fish.fish_res if "fish_res" in _fish else null
	if f == null:
		_title.text = "Fish"
		_info.text = ""
		return
	_title.text = "%s · %s" % [Ranks.get_rank(f.rank).display_name, f.ID]
	var income := "$%s/s" % FishLabelDisplay.num(PassiveSystems.fish_income(f))
	if f in SaveManager.load_saved_data().list_of_retired_fish:
		_info.text = "%s · grows to %s" % [Prestige.mass_text(f.mass), Prestige.mass_text(FishGrowthManager.max_mass(f))]
	else:
		_info.text = "%s · %s" % [Prestige.mass_text(f.mass), income]


func _on_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_drag_offset = get_global_mouse_position() - position
	elif event is InputEventMouseMotion and _dragging:
		var screen := get_viewport_rect().size
		position = (get_global_mouse_position() - _drag_offset).clamp(Vector2.ZERO, screen - size)
