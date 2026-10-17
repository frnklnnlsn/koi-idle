extends MarginContainer

signal hovered(fish_resource:fish_conf)
signal unhovered(fish_resource:fish_conf)
signal selected_deselected(fish_resource:fish_conf)
## Mouse drag of this card (the shop decides what it means: up = keep,
## down = trash). Positions are global mouse positions.
signal drag_started(card: Control, mouse: Vector2)
signal drag_moved(card: Control, mouse: Vector2)
signal drag_ended(card: Control, mouse: Vector2)
var fish_resource:fish_conf

## Pixels the mouse must move with the button held before it counts as a drag
## rather than a click.
const DRAG_THRESHOLD := 8.0
var _press_pos := Vector2.ZERO
var _pressing := false
var dragging := false
var _just_dragged := false

var focused:bool = false
## True while the keyboard cursor is on this card.
var is_cursor := false
var _number: Label
var _cursor_frame: Panel
var _picked_frame: Panel
## True while the card is box-selected.
var is_picked := false


func _ready() -> void:
	# See-through fish viewport, so the card's rarity colour shows behind it.
	$SubViewportContainer/FishViewport.transparent_bg = true
	$card_button.gui_input.connect(_on_button_input)
	if fish_resource:
		_apply_rarity()


## The fish picture, for drawing a copy of the card while it's dragged.
func fish_texture() -> Texture2D:
	return $SubViewportContainer/FishViewport.get_texture()


func _on_button_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_press_pos = event.global_position
		else:
			_pressing = false
			if dragging:
				dragging = false
				_just_dragged = true   # so this release isn't also a click...
				set_deferred("_just_dragged", false)   # ...but only this one
				drag_ended.emit(self, event.global_position)
	elif event is InputEventMouseMotion and _pressing:
		if not dragging and event.global_position.distance_to(_press_pos) > DRAG_THRESHOLD:
			dragging = true
			drag_started.emit(self, event.global_position)
		if dragging:
			drag_moved.emit(self, event.global_position)


## Background colour by the fish's combined rarity across all three stats
## (FishStats tiers: Uncommon green, Rare blue, Epic purple, Legendary gold).
## Common fish keep the plain card.
func _apply_rarity() -> void:
	var cz := FishStats.fish_combined_z(fish_resource)
	var tier := FishStats.tier_index(cz)
	$card_button.tooltip_text = "%s  (top %s%% overall)" % [FishStats.TIERS[tier][0], FishStats._pct(FishStats.top_percent(cz))]
	if tier == FishStats.TIERS.size() - 1:
		return
	var style := StyleBoxFlat.new()
	var c: Color = FishStats.TIERS[tier][2]
	style.bg_color = Color(c, 0.4)
	style.set_corner_radius_all(3)
	var bg := Panel.new()
	bg.name = "RarityBackground"
	bg.add_theme_stylebox_override("panel", style)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)   # behind the fish and the button

func _on_card_button_pressed():
	if _just_dragged:
		_just_dragged = false
		return
	
	#print(self.has_theme_stylebox("normal"))
	if focused == false:
		focused = true
		
	else:
		focused = false

	selected_deselected.emit(fish_resource)
	


func _on_card_button_mouse_entered():
	hovered.emit(fish_resource)
	self.set_scale(Vector2(1.5,1.5))


func _on_card_button_mouse_exited():
	unhovered.emit(fish_resource)
	self.set_scale(Vector2(1.5, 1.5) if is_cursor else Vector2(1, 1))


## The small number in the corner, used by keyboard commands like ":3,7d".
func set_number(n: int) -> void:
	if _number == null:
		_number = Label.new()
		_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_number.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_number.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_number.add_theme_font_size_override("font_size", 11)
		_number.add_theme_color_override("font_color", Color(UIPalette.get_palette().text, 0.8))
		_number.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		_number.add_theme_constant_override("outline_size", 3)
		add_child(_number)
	_number.text = str(n)


## Box-selected on / off: a tint and frame in the palette's picked colour (the
## cursor's gold frame draws over it).
func set_picked(on: bool) -> void:
	is_picked = on
	if on and _picked_frame == null:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(UIPalette.get_palette().picked, 0.22)
		style.border_color = UIPalette.get_palette().picked
		style.set_border_width_all(2)
		style.set_corner_radius_all(3)
		_picked_frame = Panel.new()
		_picked_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_picked_frame.add_theme_stylebox_override("panel", style)
		add_child(_picked_frame)
		if _cursor_frame:
			move_child(_cursor_frame, -1)
	if _picked_frame:
		_picked_frame.visible = on


## Keyboard cursor on / off: same enlarged look as mouse hover, plus a frame.
func set_cursor(on: bool) -> void:
	is_cursor = on
	set_scale(Vector2(1.5, 1.5) if on else Vector2(1, 1))
	z_index = 1 if on else 0
	if on and _cursor_frame == null:
		var style := StyleBoxFlat.new()
		style.draw_center = false
		style.border_color = UIPalette.get_palette().accent
		style.set_border_width_all(2)
		style.set_corner_radius_all(3)
		_cursor_frame = Panel.new()
		_cursor_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cursor_frame.add_theme_stylebox_override("panel", style)
		add_child(_cursor_frame)   # after the picked frame, so it draws on top
	if _cursor_frame:
		_cursor_frame.visible = on
